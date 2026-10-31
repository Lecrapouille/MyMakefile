#include "foo.hpp"
#include <iostream>

int main()
{
    // Not an assert(): the demo is compiled in release, where NDEBUG removes it.
    if (foo(1, 1) != 2)
    {
        std::cerr << "foo(1, 1) should be 2" << std::endl;
        return 1;
    }

    std::cout << "all tests good !" << std::endl;

    return 0;
}
