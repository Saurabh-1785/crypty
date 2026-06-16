# crypty

A C++ tool for encrypting and decrypting all files inside a directory, using parallel child processes and a Caesar-cipher-style byte shift.

## How It Works

1. You point `crypty` at any directory on your system.
2. It recursively finds every regular file inside that directory.
3. Each file is turned into a `Task` (file path + action) and pushed onto a queue.
4. `ProcessManagement` drains the queue, calling `executeCryption` for each task.
5. `executeCryption` opens the file in binary read/write mode, reads it byte by byte, shifts every byte by the key stored in `.env`, and writes it back in-place.
6. To reverse the operation, run again with `decrypt` — the same shift is subtracted.

The encryption uses a simple modular arithmetic byte-shift:
- **Encrypt:** `byte = (byte + key) % 256`
- **Decrypt:** `byte = (byte - key + 256) % 256`

## Project Structure

```
crypty/
├── main.cpp                          # Entry point — reads dir + action, builds task queue
├── Makefile                          # Builds encrypt_decrypt and cryption binaries
├── .env                              # Holds the numeric shift key (e.g. 42) — not committed
├── test/                             # Sample files for manual testing
│   ├── test1.txt
│   └── test2.txt
└── src/app/
    ├── encryptDecrypt/
    │   ├── Cryption.hpp / .cpp       # Core byte-shift encrypt/decrypt logic
    │   └── CryptionMain.cpp          # Standalone cryption binary entry point
    ├── fileHandling/
    │   ├── IO.hpp / .cpp             # Opens files in binary r/w mode
    │   └── ReadEnv.hpp / .cpp        # Reads the shift key from .env
    └── processes/
        ├── Task.hpp                  # Task struct: file path + action + fstream
        └── ProcessManagement.hpp/.cpp# Queue + task execution (with optional fork support)
```

## Prerequisites

- Linux / macOS
- `g++` with C++17 support (`g++ --version`)
- `make`
- `gdb` (optional, for debugging in VS Code)

## Setup

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd crypty

# 2. Create your .env file with a numeric key (1–255)
echo "42" > .env

# 3. Build
make
```

This produces two binaries:
| Binary | Purpose |
|---|---|
| `./encrypt_decrypt` | Main program — processes a whole directory |
| `./cryption` | Standalone helper — processes one task string |

## Usage

```bash
# Encrypt all files in the test/ directory
./encrypt_decrypt
# > Enter the directory path: test
# > Enter the action (encrypt/decrypt): encrypt

# Decrypt them back
./encrypt_decrypt
# > Enter the directory path: test
# > Enter the action (encrypt/decrypt): decrypt
```

> **Note:** Encrypting and then decrypting with the same key restores the original file content exactly.

## VS Code Debugging

The `.vscode/` folder is pre-configured for Linux (GDB):

- **Build task:** `Ctrl+Shift+B` runs `make`
- **Debug `encrypt_decrypt`:** Select *"Debug encrypt_decrypt"* in the Run & Debug panel and press `F5`
- **Debug `cryption`:** Select *"Debug cryption (standalone)"* — launches with `test/test1.txt,ENCRYPT` as the argument

## Branches

| Branch | Approach |
|---|---|
| `add/childProcessing` | Uses `fork()` to spawn a child process per task |
| `add/multithreading` | Uses POSIX threads + shared memory + semaphores |

The `main` branch runs tasks in-process (no fork) by calling `executeCryption` directly, which is useful for debugging.

## Cleaning Up

```bash
make clean   # removes all .o files and compiled binaries
```
