#include "foo.hpp"
#include "HelloWorld01/project_info.hpp"

namespace info = generated::HelloWorld01;
#include <iostream>

int main()
{
    std::cout << "Welcome to your project " << info::name
              << " version " << info::version::major << '.'
              << info::version::minor << " compiled in "
              << (info::compilation::mode ==
                          info::compilation::debug
                      ? "debug"
                      : (info::compilation::mode ==
                             info::compilation::release
                         ? "release"
                         : "normal"))
              << " mode " << std::endl
              << " application " << info::application::name
              << " summary: '" << info::application::summary << "'"
              << std::endl
              << "Your code was git cloned on branch "
              << info::git::branch << " SHA1 "
              << info::git::sha1 << std::endl;
    return foo(1, 2);
}
