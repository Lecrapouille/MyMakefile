# 🚀 2. Getting started

**What you will learn**

- add MyMakefile to a project;
- build and run an application, with the `project_info.hpp` MyMakefile generates;
- add unit tests, declared next to their sources;
- split a project in libraries;
- where to go next.

**Prerequisites**: [chapter 1](01-Introduction.md); GNU Make 4.2 and a compiler.

---

## 1. 📦 Add MyMakefile to a project

As a git submodule, in `.makefile/`:

```sh
git submodule add https://github.com/Lecrapouille/MyMakefile.git .makefile
```

Someone who clones the project then needs `git clone --recursive`, or `git submodule update --init` after the clone.

The demos of this chapter are in [`doc/demos/`](demos/README.md). They include `../../../MyMakefile.mk` instead of `.makefile/MyMakefile.mk`, since they live inside MyMakefile. Run `make` in their folder.

## 2. 👋 A single application

[`doc/demos/00/Makefile`](demos/00/Makefile):

```makefile
PROJECT_NAME := HelloWorld00
PROJECT_VERSION := 0.1.0

TARGETS := HelloWorld00
HelloWorld00.SOURCES := src/*.cpp
HelloWorld00.PROJECT_INFO := 1

include ../../../MyMakefile.mk
```

- `PROJECT_NAME` and `PROJECT_VERSION` are required.
- `TARGETS` lists the names of the things to build. Each one is described by variables prefixed by its name: here, its sources. A target with sources and no `TYPE` is an application.
- `PROJECT_INFO := 1` asks for a header holding the name, the version, the mode and the git commit of the project ([chapter 3](03-Targets.md)).
- The `include` comes last: MyMakefile reads the declarations above it.

```sh
$ make run-HelloWorld00
*** Generating: HelloWorld00 => build/linux-gcc-normal/gen/HelloWorld00/project_info.hpp
*** Compiling C++: HelloWorld00 <= src/main.cpp
*** Linking: HelloWorld00 => build/linux-gcc-normal/bin/HelloWorld00
*** Running: HelloWorld00
Welcome to your project HelloWorld00 version 0.1 compiled in normal mode
 application HelloWorld00 summary: ''
Your code was git cloned on branch master SHA1 ce923ae00e2e9330d5a1adc3424aee9102656fe7
```

The build goes to `build/linux-gcc-normal/`: one folder per system, compiler and mode, so that a debug build and a release build live side by side. `make COMPILATION_MODE=debug` builds in `build/linux-gcc-debug/` ([chapter 5](05-Compilation.md)).

The program includes the generated header as `"HelloWorld00/project_info.hpp"`, and finds its values in the namespace `generated::helloworld00`:

```cpp
#include "HelloWorld00/project_info.hpp"
namespace info = generated::helloworld00;

std::cout << info::name << " version " << info::version::major << '.' << info::version::minor;
```

## 3. 🧪 An application and its tests

[`doc/demos/01/Makefile`](demos/01/Makefile) declares the application, and lists in `SUBMAKEFILES` a file declaring its tests:

```makefile
PROJECT_NAME := TutorialMyMakefile
PROJECT_VERSION := 0.1.0
COMPILATION_MODE ?= release

TARGETS := HelloWorld01
HelloWorld01.DESCRIPTION := Hello World
HelloWorld01.SOURCES := src/*.cpp
HelloWorld01.INCLUDES := src
HelloWorld01.DEFINES := FOO
HelloWorld01.PROJECT_INFO := 1

SUBMAKEFILES := tests/tests.mk

include ../../../MyMakefile.mk
```

[`doc/demos/01/tests/tests.mk`](demos/01/tests/tests.mk) adds a target to `TARGETS`. Its paths are relative to `tests/`, the folder of the file:

```makefile
TARGETS += UnitTest-HelloWorld01
UnitTest-HelloWorld01.TYPE := test
UnitTest-HelloWorld01.SOURCES := ../src/foo.cpp unit-tests.cpp
UnitTest-HelloWorld01.INCLUDES := ../src
UnitTest-HelloWorld01.DEFINES := FOO
```

A `test` target is not built by `make`, only by `make check`, which builds and runs every test, from the root of the project:

```sh
$ make check
*** Compiling C++: UnitTest-HelloWorld01 <= src/foo.cpp
*** Compiling C++: UnitTest-HelloWorld01 <= tests/unit-tests.cpp
*** Linking: UnitTest-HelloWorld01 => build/linux-gcc-release/bin/UnitTest-HelloWorld01
*** Testing: UnitTest-HelloWorld01
foo 1 + 1 = 2
all tests good !
*** 1 test program(s) passed
```

`make check` fails as soon as a test program returns an error. The test framework is yours: Google Test, Catch2, doctest or a `main`, given with `PKG_CONFIG` or `LIBS` ([chapter 3](03-Targets.md)).

## 4. 📚 An application and its libraries

[`doc/demos/02/`](demos/02/) links an application against two libraries, each one declared in the folder of its sources:

```makefile
# Makefile
TARGETS := HelloWorld02
HelloWorld02.SOURCES := src/main.cpp
HelloWorld02.DEPENDS := foo bar

SUBMAKEFILES := src/foo/foo.mk src/bar/bar.mk
```

```makefile
# src/foo/foo.mk
TARGETS += foo
foo.TYPE := static
foo.SOURCES := foo.cpp
foo.PUBLIC_INCLUDES := ../../include
```

```makefile
# src/bar/bar.mk
TARGETS += bar
bar.TYPE := library
bar.SOURCES := *.cpp
bar.PUBLIC_INCLUDES := ../../include
```

- `DEPENDS` names the targets an application uses. It gets their `PUBLIC_INCLUDES` and links their libraries, in the right order.
- `static` builds `libfoo.a`, `shared` builds `libbar.so`, `library` builds both.

```sh
$ make
*** Compiling C++: HelloWorld02 <= src/main.cpp
*** Compiling C++: foo <= src/foo/foo.cpp
*** Compiling C++: bar <= src/bar/bar.cpp
*** Static library: foo => build/linux-gcc-normal/lib/libfoo.a
*** Static library: bar => build/linux-gcc-normal/lib/libbar.a
*** Shared library: bar => build/linux-gcc-normal/lib/libbar.so.0.1.0
*** Linking: HelloWorld02 => build/linux-gcc-normal/bin/HelloWorld02
$ make list-targets
HelloWorld02 (executable): foo bar
foo (static)
bar (library)
```

The three targets are in one make graph: `make -j` compiles `main.cpp`, `foo.cpp` and `bar.cpp` at the same time, and `make HelloWorld02` builds the two libraries first. MyMakefile runs with all the cores by default (`JOBS=4` to change it).

## 5. ❓ Help

`make help` prints the goals and the options, with the values of this project:

```sh
$ make help
TutorialMyMakefile 0.1.0, built in build/linux-gcc-normal by MyMakefile 3.0.0
  TOOLCHAIN=gcc (gcc 16) TARGET_OS=Linux COMPILATION_MODE=normal

Build:
  all                every target except the tests (default)
  <target>           one target and what it depends on
  run-<target>       build and run an executable, with ARGS="..."
...
```

`make V=1` shows the commands, `make show-flags` the flags of each target.

## 6. 🗺️ Where to go next

| You want to | Read |
|-------------|------|
| know every variable of a target | [3. Targets](03-Targets.md) |
| use a library from GitHub, an archive or the system | [4. Third parties](04-Third-Parties.md) |
| choose the optimizations, the warnings, a sanitizer | [5. Compilation](05-Compilation.md) |
| debug, cover, format, document the code | [6. Goals](06-Goals.md) |
| install, package, build on Windows or for a browser | [7](07-Installation.md), [8](08-Platforms.md), [9](09-Continuous-Integration.md) |

---

Next: [3. Targets](03-Targets.md) — every way to describe what to build.
