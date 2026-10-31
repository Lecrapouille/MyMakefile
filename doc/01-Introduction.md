# 🧩 1. Introduction

**What you will learn**

- what MyMakefile is and what it does for you;
- what version 3 changes compared with version 2;
- what you need to use it.

**Prerequisites**: you have compiled a C or C++ program with `make` once.

---

## 1. 🧩 What MyMakefile is

MyMakefile is a build system for C and C++ projects, written in GNU Make. You declare **what** to build, in a few variables; MyMakefile writes the rules that build it:

```makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0

TARGETS := myapp
myapp.SOURCES := src/*.cpp

include .makefile/MyMakefile.mk
```

From these lines, `make` compiles each source in its own object, tracks the headers it includes, links the application, and adds the warnings, the hardening and the optimizations of the compilation mode. The same `Makefile` also gives `make run-myapp`, `make check`, `make install`, `make coverage`, `make doc`, `make format` and about thirty other goals ([chapter 6](06-Goals.md)).

MyMakefile is a submodule of your project, not a program to install: everyone who clones the project, and the CI, builds it with the same version of MyMakefile.

## 2. 🆕 What version 3 changes

Version 3 is a rewrite. Compared with [version 2](https://github.com/Lecrapouille/MyMakefile/tree/v2.0.0):

| Version 2 | Version 3 |
|-----------|-----------|
| One `Makefile` per library or application, called by a recursive `$(MAKE)` | **All the targets in one make graph**: libraries, applications and tests depend on each other by name, and `make -j` sees the whole project |
| A target is described by global variables (`TARGET_NAME`, `USER_CXXFLAGS`...) | A target is described by **its own variables**: `myapp.SOURCES`, `myapp.DEPENDS`... ([chapter 3](03-Targets.md)) |
| Paths relative to the project, `P := ../..` | A target can be declared **next to its sources**, in a `.mk` file, with paths relative to that file |
| Bash scripts to clone and compile the third parties | **No bash script**: GNU Make functions, recipes running with a POSIX shell or with `cmd.exe` |
| Third parties cloned in `external/` of each project | Third parties **locked to a commit** and **shared by all your projects** in a cache ([chapter 4](04-Third-Parties.md)) |
| One `build/` folder | **One build folder per configuration**: `build/linux-gcc-normal`, `build/emscripten-release`... and one object folder per target |
| | **ccache** when it is installed; a change of flags rebuilds only the targets concerned |

Version 2 is kept by the tag `v2.0.0` and the branch `version-2`. [Chapter 10](10-Migrating-From-Version-2.md) moves a project from version 2 to version 3.

## 3. 🧱 Requirements

GNU Make 4.2 or newer, on every system:

| System  | GNU Make |
|---------|----------|
| Linux   | `make` |
| macOS   | `brew install make`, then run `gmake` (the make of Apple is 3.81) |
| BSD     | `pkg install gmake`, then run `gmake` |
| Windows | MSYS2 (`mingw-w64-x86_64-make`, run `mingw32-make`), or `winget install ezwinports.make` |

BSD make and NMake are not supported: the engine relies on `$(eval)` and on the other functions of GNU Make.

Then a compiler (gcc, clang, MinGW, Emscripten or MSVC: [chapter 8](08-Platforms.md)), `git` for the third parties, and `pkg-config` for the packages of the system. The other tools (ccache, Doxygen, clang-format, gcovr, cppcheck, valgrind...) are used by the goals that need them, when they are installed.

## 4. 🗂️ What is in MyMakefile

| Path | Contents |
|------|----------|
| `MyMakefile.mk` | The file your `Makefile` includes |
| `engine/` | The engine: platform, toolchains, targets, third parties, goals, installation, tools |
| `assets/` | Templates of Doxygen, the default `.clang-format`, the icons |
| `.github/actions/setup` | A GitHub action that prepares a runner for MyMakefile ([chapter 9](09-Continuous-Integration.md)) |
| `doc/` | This documentation and its [demos](demos/README.md) |

## 5. 📜 License

MyMakefile is dual licensed, GPL v3 or commercial: see [LICENSING.md](../LICENSING.md).

---

Next: [2. Getting started](02-Getting-Started.md) — add MyMakefile to a project and build it.
