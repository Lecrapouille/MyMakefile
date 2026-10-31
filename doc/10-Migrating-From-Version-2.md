# 🔄 10. Migrating from version 2

**What you will learn**

- what replaces each variable, goal and file of MyMakefile 2;
- how to move a project of several Makefiles to one make graph;
- what is not ported.

**Prerequisites**: [chapter 3](03-Targets.md). Version 2 is kept by the tag `v2.0.0` and the branch `version-2`.

---

## 1. 🧭 The idea

In version 2, each library and each application had its own `Makefile`, a `TARGET_NAME`, and global variables (`USER_CXXFLAGS`, `INCLUDES`...); the main `Makefile` called the others with a recursive `$(MAKE)` (`DIRS_WITH_MAKEFILE`), and the third parties were cloned and compiled by bash scripts.

In version 3, every library, application and test is a **target** of one make graph, with its own variables, declared in the main `Makefile` or in a `.mk` file next to its sources. Moving a project means: one target per former `Makefile`, its global variables become variables of the target, its `DIRS_WITH_MAKEFILE` becomes `SUBMAKEFILES`, and its third parties become targets with a `GIT` URL.

## 2. 📝 An example

Version 2, `src/Makefile` of a library and `demo/Makefile` of an application using it:

```makefile
# src/Makefile
P := ..
M := $(P)/.makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0
TARGET_NAME := MyLib
TARGET_DESCRIPTION := My library
include $(M)/project/Makefile
LIB_FILES := $(call rwildcard,$(P)/src,*.cpp)
INCLUDES := $(P)/include
include $(M)/rules/Makefile
```

```makefile
# demo/Makefile
P := ..
M := $(P)/.makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0
TARGET_NAME := MyDemo
include $(M)/project/Makefile
SRC_FILES := $(call rwildcard,$(P)/demo/src,*.cpp)
INCLUDES := $(P)/include
INTERNAL_LIBS := $(call internal-lib,MyLib)
DIRS_WITH_MAKEFILE := $(P)/src
PKG_LIBS := glfw3
include $(M)/rules/Makefile
```

Version 3, one `Makefile` and one `.mk` file:

```makefile
# Makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0

TARGETS := MyLib
MyLib.TYPE := library
MyLib.DESCRIPTION := My library
MyLib.SOURCES := src/**/*.cpp
MyLib.PUBLIC_INCLUDES := include

SUBMAKEFILES := demo/demo.mk

include .makefile/MyMakefile.mk
```

```makefile
# demo/demo.mk
TARGETS += MyDemo
MyDemo.SOURCES := src/**/*.cpp
MyDemo.DEPENDS := MyLib
MyDemo.PKG_CONFIG := glfw3
```

`MyDemo` gets the include folder and the library of `MyLib` from `DEPENDS`, and `make -j` compiles both at the same time.

## 3. 🔤 Variables

| Version 2 | Version 3 |
|-----------|-----------|
| `P`, `M`, `include $(M)/project/Makefile`, `include $(M)/rules/Makefile` | `include .makefile/MyMakefile.mk`, once, at the end of the main `Makefile`. Paths are relative to the file declaring them |
| `TARGET_NAME` | The name of the target in `TARGETS`; `t.NAME` for another file name |
| `TARGET_DESCRIPTION` | `t.DESCRIPTION` |
| `SRC_FILES`, `LIB_FILES` | `t.SOURCES`; `t.TYPE` tells an application from a library |
| `INCLUDES` | `t.INCLUDES`, or `t.PUBLIC_INCLUDES` to give them to the targets depending on it |
| `DEFINES` | `t.DEFINES` (without `-D`), or `t.PUBLIC_DEFINES` |
| `USER_CXXFLAGS`, `USER_CCFLAGS`, `USER_LDFLAGS` | `t.CXXFLAGS`, `t.CFLAGS`, `t.LDFLAGS`; or `CXXFLAGS`... on the command line for every target |
| `PKG_LIBS` | `t.PKG_CONFIG` |
| `STATIC_PKG_LIBS` | `PKG_CONFIG_STATIC := 1` |
| `LINKER_FLAGS`, `NOT_PKG_LIBS` | `t.LDFLAGS`, `t.LIBS` |
| `INTERNAL_LIBS := $(call internal-lib,foo)` | `t.DEPENDS := foo`: the targets, not the paths of their files |
| `THIRD_PARTIES_LIBS`, `external/manifest` and its scripts | Targets with `t.GIT` and `t.VERSION` ([chapter 4](04-Third-Parties.md)) |
| `DIRS_WITH_MAKEFILE` | `SUBMAKEFILES`: `.mk` files read by the same make |
| `DO_NOT_COMPILE_STATIC_LIB`, `DO_NOT_COMPILE_SHARED_LIB` | `t.TYPE := shared`, `static`, or `library` for both |
| `PREVENT_SHARED_LIB_UNLOAD` | `t.NODELETE := 1` |
| `CUSTOM_RPATH` | `t.RPATH` |
| `CXX_STANDARD := --std=c++14` | `CXX_STANDARD := c++14` |
| `BUILD` | `BUILD_DIR`; the configuration is a subfolder: `build/linux-gcc-normal` |
| `THIRD_PARTIES` | `EXTERNAL_DIR`; the third parties live in the cache by default |
| `VERBOSE`, `DEBUG` | `V=1` |
| `OS`, `ARCHI` | `TARGET_OS`, `TARGET_ARCH` |
| `USE_ASAN=1` | `SANITIZER=address` |
| `MACOS_BUNDLE_ICON` | `t.BUNDLE := 1`, `t.ICON` |
| `GENERATED_DOXYGEN_DIR`, `COVERAGE_HTML_RAPPORT`... | `DOXYGEN_DIR`, `COVERAGE_DIR` |

`COMPILATION_MODE`, `PREFIX`, `DESTDIR`, `BINDIR`, `LIBDIR`, `INCLUDEDIR`, `DATADIR`, `INSTALL_VERSIONED`, `FORCE_LOWER_CASE`, `EXPORT_MACRO` (`API_LINKAGE`), `NATIVE`, `FAST_MATH`, `GPROF` keep their meaning.

## 4. 🧰 Goals

| Version 2 | Version 3 |
|-----------|-----------|
| `make run -- --arg` | `make run-<target> ARGS="--arg"` |
| `make check`, `make tests` | `make check` |
| `make format-source-code` | `make format`, `make check-format` |
| `make coverity-scan` | `make coverity` |
| `make pre-build`, `make post-build` | `PRE_BUILD`, `POST_BUILD`, `t.POST_BUILD` ([chapter 3](03-Targets.md)) |
| `make compiler-info`, `make project-version`... | `make help`, `make -s print-PROJECT_VERSION`, `make ci-info` |
| `make download-external-libs`, `make compile-external-libs` | Nothing: the third parties are fetched and built when needed |
| `make rebuild`, `make clean`, `make veryclean`, `make install`, `make doc`, `make coverage`, `make lint`, `make tarball`, `make rpm`, `make gprof`, `make size-analysis`, `make check-harden` | The same |

## 5. 📝 `project_info.hpp`

| Version 2 | Version 3 |
|-----------|-----------|
| Always generated | `t.PROJECT_INFO := 1` |
| `#include "project_info.hpp"` | `#include "<name>/project_info.hpp"` |
| `project::info::` | `generated::<name in lower case>::`, `-` and `.` replaced by `_` |

## 6. 🚫 Not ported

| Version 2 | Why, or instead |
|-----------|-----------------|
| The OBS package | Its script was missing |
| `make benchmark` | `make run-<target>` under `time` |
| The percentage of progress | It was the number of objects compiled over the number of objects of the target: wrong as soon as the build is incremental, and computed with a process per file. make cannot know before running how many objects are out of date, so the messages give the target and the file instead |
| `make build-stats`, `make show-paths`, `make check-deps` | `make list-targets`, `make show-flags`, the checks of pkg-config packages |

---

Next: [11. Reference](11-Reference.md) — every variable and every goal.
