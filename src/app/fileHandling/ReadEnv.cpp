#include "ReadEnv.hpp"
#include "IO.hpp"
#include <iostream>
#include <string>
#include <fstream>
#include <sstream>

std::string ReadEnv::getenv() {
    std::string env_path = ".env";
    IO io(env_path);
    std::fstream f_stream = io.getFileStream();
    std::stringstream buffer;
    buffer << f_stream.rdbuf();
    std::string content = buffer.str();
    // Trim trailing whitespace/newlines
    while (!content.empty() && (content.back() == '\n' || content.back() == '\r' || content.back() == ' ')) {
        content.pop_back();
    }
    return content;
}