# MyMakefile

> 💡 **If a compact Makefile-based build system is essential to you, this project is for you.**

📦 [MyMakefile](https://github.com/Lecrapouille/MyMakefile) is a **Makefile helper** for C and C++ (GNU Make): **a few lines** of variables, one `include`, and the usual complexity—rules, flags, build trees, target dependencies—**stays hidden**. Declare **several targets in one Makefile**, each with its own sources and dependencies, without boilerplate.

```makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0

TARGETS := mylib myapp
mylib.TYPE := library
mylib.SOURCES := src/**/*.cpp
mylib.PUBLIC_INCLUDES := include

myapp.SOURCES := app/*.cpp
myapp.DEPENDS := mylib

include .makefile/MyMakefile.mk
```

```sh
make                          # build
make run-myapp                # build and run
make check                    # build and run the tests
make COMPILATION_MODE=debug SANITIZER=address,undefined
make help
```

## ✨ What it does

| Topic | What MyMakefile gives | Chapter |
|-------|-----------------------|---------|
| 🎯 Targets | Applications, tests, static and shared libraries in one make graph, depending on each other by name, declared next to their sources; `project_info.hpp` | [3](doc/03-Targets.md) |
| 📦 Third parties | Libraries fetched from git or as archives, locked to a commit, shared between your projects in a cache; CMake projects; pkg-config packages | [4](doc/04-Third-Parties.md) |
| 🔨 Compilation | Six modes, about 60 warnings, hardening, LTO, sanitizers, ccache; one build folder per configuration; a change of flags rebuilds only what it concerns | [5](doc/05-Compilation.md) |
| 🧰 Goals | Run, debug, coverage, valgrind, gprof, clang-format, cppcheck, clang-tidy, Doxygen, tarball, RPM | [6](doc/06-Goals.md) |
| 🚚 Installation | `make install`, a `make uninstall` that asks before removing, relocatable pkg-config files, `make dist` | [7](doc/07-Installation.md) |
| 🖥️ Platforms | Linux, macOS, Windows (MSYS2, cross compiler, MSVC), Emscripten, ExaequOS | [8](doc/08-Platforms.md) |
| 🤖 CI | `make ci`, `make dist`, `make ci-info`, and a GitHub action preparing the runners | [9](doc/09-Continuous-Integration.md) |

## 🚀 Getting started

GNU Make 4.2 or newer (`gmake` on macOS, `mingw32-make` on MSYS2). Add MyMakefile to your project as a git submodule:

```sh
git submodule add https://github.com/Lecrapouille/MyMakefile.git .makefile
```

then follow [chapter 2](doc/02-Getting-Started.md) and its [demos](doc/demos/README.md).

## 📚 Documentation

The [documentation](doc/README.md) goes step by step, from a first application to the CI of a project built for five platforms. Coming from MyMakefile 2? Read [chapter 10](doc/10-Migrating-From-Version-2.md). Version 2 is kept by the tag `v2.0.0` and the branch `version-2`; the [ChangeLog](ChangeLog) lists the changes.

## 🛠️ MyMakefile Coding Style

Functions called with `$(call ...)` are in lower case with dashes (`rwildcard`, `print-to`); macros (`define`: templates of rules and of files) and variables in upper case (`TARGET_RULES`, `BUILD`). The variables of a target are `t.SOMETHING` when the user writes them, `t._SOMETHING` when MyMakefile computes them.

## 📜 License

Dual licensed, GPL v3 or commercial: see [LICENSING.md](LICENSING.md).
