#!/usr/bin/env bash
# =============================================
#  crypty — test suite
#  Run from the project root: bash test/run_tests.sh
# =============================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

PASS=0
FAIL=0

pass() { echo -e "${GREEN}  [PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}  [FAIL]${NC} $1"; ((FAIL++)); }
info() { echo -e "${BLUE}  [INFO]${NC} $1"; }
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

# -----------------------------------------------
# 1. Build
# -----------------------------------------------
section "Test 1 — Build"

make clean > /dev/null 2>&1 || true
if make 2>&1; then
    pass "make succeeded"
else
    fail "make failed — stopping tests"
    exit 1
fi

[ -x "./encrypt_decrypt" ] && pass "encrypt_decrypt binary exists and is executable" \
                             || fail "encrypt_decrypt binary missing"

[ -x "./cryption" ]         && pass "cryption binary exists and is executable" \
                             || fail "cryption binary missing"

# -----------------------------------------------
# 2. .env sanity check
# -----------------------------------------------
section "Test 2 — .env file"

if [ ! -f ".env" ]; then
    fail ".env file not found — encryption key missing"
    exit 1
fi

ENV_KEY=$(cat .env | tr -d '[:space:]')
if [[ "$ENV_KEY" =~ ^[0-9]+$ ]] && [ "$ENV_KEY" -ge 1 ] && [ "$ENV_KEY" -le 255 ]; then
    pass ".env contains a valid numeric key: $ENV_KEY"
else
    fail ".env key is invalid (must be 1–255, got: '$ENV_KEY')"
fi

# -----------------------------------------------
# 3. Encrypt → Decrypt round-trip (text files)
# -----------------------------------------------
section "Test 3 — Encrypt/Decrypt round-trip (test/ directory)"

# Backup originals
BACKUP_DIR=$(mktemp -d)
cp test/test1.txt "$BACKUP_DIR/test1.txt"
cp test/test2.txt "$BACKUP_DIR/test2.txt"

ORIGINAL1=$(cat test/test1.txt)
ORIGINAL2=$(cat test/test2.txt)
info "Original test1.txt: '$ORIGINAL1'"
info "Original test2.txt: '$ORIGINAL2'"

# Encrypt
printf "test\nencrypt\n" | ./encrypt_decrypt > /dev/null 2>&1

ENCRYPTED1=$(cat test/test1.txt)
ENCRYPTED2=$(cat test/test2.txt)
info "Encrypted test1.txt (first 20 bytes, hex): $(head -c 20 test/test1.txt | xxd -p)"

if [ "$ENCRYPTED1" != "$ORIGINAL1" ]; then
    pass "test1.txt content changed after encryption"
else
    fail "test1.txt content unchanged after encryption — encryption may not have worked"
fi

if [ "$ENCRYPTED2" != "$ORIGINAL2" ]; then
    pass "test2.txt content changed after encryption"
else
    fail "test2.txt content unchanged after encryption"
fi

# Decrypt
printf "test\ndecrypt\n" | ./encrypt_decrypt > /dev/null 2>&1

DECRYPTED1=$(cat test/test1.txt)
DECRYPTED2=$(cat test/test2.txt)
info "Decrypted test1.txt: '$DECRYPTED1'"
info "Decrypted test2.txt: '$DECRYPTED2'"

if [ "$DECRYPTED1" = "$ORIGINAL1" ]; then
    pass "test1.txt round-trip: decrypted matches original"
else
    fail "test1.txt round-trip FAILED — expected '$ORIGINAL1', got '$DECRYPTED1'"
    # Restore backup
    cp "$BACKUP_DIR/test1.txt" test/test1.txt
fi

if [ "$DECRYPTED2" = "$ORIGINAL2" ]; then
    pass "test2.txt round-trip: decrypted matches original"
else
    fail "test2.txt round-trip FAILED — expected '$ORIGINAL2', got '$DECRYPTED2'"
    cp "$BACKUP_DIR/test2.txt" test/test2.txt
fi

rm -rf "$BACKUP_DIR"

# -----------------------------------------------
# 4. cryption standalone binary
# -----------------------------------------------
section "Test 4 — cryption standalone binary"

TEMP_FILE=$(mktemp)
echo -n "StandaloneTest" > "$TEMP_FILE"
ORIGINAL_CONTENT=$(cat "$TEMP_FILE")

info "Standalone test file content: '$ORIGINAL_CONTENT'"

./cryption "${TEMP_FILE},ENCRYPT"
AFTER_ENCRYPT=$(cat "$TEMP_FILE")

if [ "$AFTER_ENCRYPT" != "$ORIGINAL_CONTENT" ]; then
    pass "cryption: file changed after ENCRYPT"
else
    fail "cryption: file unchanged after ENCRYPT"
fi

./cryption "${TEMP_FILE},DECRYPT"
AFTER_DECRYPT=$(cat "$TEMP_FILE")

if [ "$AFTER_DECRYPT" = "$ORIGINAL_CONTENT" ]; then
    pass "cryption standalone round-trip: matches original"
else
    fail "cryption standalone round-trip FAILED — expected '$ORIGINAL_CONTENT', got '$AFTER_DECRYPT'"
fi

rm -f "$TEMP_FILE"

# -----------------------------------------------
# 5. cryption — wrong arg count
# -----------------------------------------------
section "Test 5 — cryption argument validation"

OUTPUT=$(./cryption 2>&1 || true)
if echo "$OUTPUT" | grep -q "Usage"; then
    pass "cryption prints usage when called without args"
else
    fail "cryption did not print usage — got: '$OUTPUT'"
fi

# -----------------------------------------------
# 6. Invalid directory handling
# -----------------------------------------------
section "Test 6 — Invalid directory input"

OUTPUT=$(printf "/nonexistent_dir_xyz\nencrypt\n" | ./encrypt_decrypt 2>&1 || true)
if echo "$OUTPUT" | grep -qi "invalid"; then
    pass "encrypt_decrypt reports invalid directory correctly"
else
    fail "encrypt_decrypt did not handle invalid directory — got: '$OUTPUT'"
fi

# -----------------------------------------------
# 7. Double encrypt (encrypt twice, decrypt twice)
# -----------------------------------------------
section "Test 7 — Double encrypt/decrypt"

TEMP_DIR=$(mktemp -d)
echo -n "DoubleEncTest" > "$TEMP_DIR/data.txt"
ORIG=$(cat "$TEMP_DIR/data.txt")

printf "${TEMP_DIR}\nencrypt\n" | ./encrypt_decrypt > /dev/null 2>&1
AFTER_E1=$(cat "$TEMP_DIR/data.txt")

printf "${TEMP_DIR}\nencrypt\n" | ./encrypt_decrypt > /dev/null 2>&1
AFTER_E2=$(cat "$TEMP_DIR/data.txt")

printf "${TEMP_DIR}\ndecrypt\n" | ./encrypt_decrypt > /dev/null 2>&1
printf "${TEMP_DIR}\ndecrypt\n" | ./encrypt_decrypt > /dev/null 2>&1
AFTER_DD=$(cat "$TEMP_DIR/data.txt")

if [ "$AFTER_E1" != "$ORIG" ] && [ "$AFTER_E2" != "$AFTER_E1" ]; then
    pass "Each encrypt pass changes the content distinctly"
else
    fail "Double encrypt did not produce two different states"
fi

if [ "$AFTER_DD" = "$ORIG" ]; then
    pass "Encrypt×2 then Decrypt×2 restores original"
else
    fail "Encrypt×2 / Decrypt×2 round-trip FAILED — expected '$ORIG', got '$AFTER_DD'"
fi

rm -rf "$TEMP_DIR"

# -----------------------------------------------
# Summary
# -----------------------------------------------
section "Results"
echo -e "${GREEN}Passed: $PASS${NC}   ${RED}Failed: $FAIL${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}$FAIL test(s) failed.${NC}"
    exit 1
fi
