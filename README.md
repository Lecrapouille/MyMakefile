# MyMakefile

This repo contains a collection of Makefile rules and macros for compiling my GitHub C++ projects for Linux
and Mac OS X (Help wanted: I cannot test it on Windows) for reducing the amount of copy/paste. If you are
not interested in CMake, you can use this project as a git submodule for your own project, it will help you
to write Makefiles in a few lines.

MyMakefile offers the following things:
* Define some default compilation flags for GCC and clang compilers like hardening your binary.
* Hide by default all this awful display of GCC compilation flags. It replaces them by colorful compilation messages
with the percentage of compiled files (in the way of a progress bar).
* You do not have to write Makefile rules for compiling your project or installing your project.
* Macros for installing your program, its resources, libraries and include files.
* The target of your project can be static or shared libraries. In this case, a pkg-config file is generated.
* You can add anyway Makefile rules for adding your personal rules.
* Compiled files are placed in a `build/` directory instead of being created within source files.
* Generate .d files inside the `build/` directory holding dependencies files (when one header file is modified, dependent source files are also compiled).
* Have utility rules like gcov (code coverage report), Coverity Scan (static analyzer of code), doxgen (documentation generator), asan (AddressSanitizer), check for hardened target.
* Have a rule for compressing your project (without .git or generated documentation) in a tar.gz tarball with the date and the version. Name collision of tarballs are managed.
* Generate a Doxygen files with project parameters (such as project name, version ...)
* Can display the auto-generated help of your makefile rules.
* Works with parallel builds (-jX option), accept to change your compiler.

## Projects using MyMakefile

* https://github.com/Lecrapouille/SimTaDyn
* https://github.com/Lecrapouille/OpenGLCppWrapper
* https://github.com/Lecrapouille/ChessNeuNeu

## Why this project?

I do not know why people like so much CMake. CMake is a Makefile generator adapted for your system. Of course, for huge projects, I can understand but for small personal projects, CMake is too complex. You can compare the number of lines of code needed for your CMake in comparison with the equivalently hand-written Makefile. If you write more lines of CMake than the Makefile, you can start interrogate yourself.

## Prerequisites

You probably have to install:
- the basic calculator `bc` tool: `apt-get install bc`
- tools like gcov, doxygen, hardening-check: `apt-get install gcovr doxygen devscripts`

## Template for your project and Makefile

To have MyMakefile working for your project, you should have the folder organization like this (another way is possible
I show my way to do it):

```
.makefile/
src/
tests/Makefile
external/
Makefile
Makefile.common
VERSION
```

Where:
* .makefile/ contains this repo. I suggest a git submodule to be updated easily. I renamed it and added a '.' char for hiding the misery.
* src/ contains all your code sources.
* external is for third-part libraries (ie. GitHub cloned projects).
* tests/ contains your unit tests.
* VERSION is an ASCII file containing your project version (such as `0.1`). For the moment it is mandatory because MyMakefile uses it when installing different versions of the same project/libraries inside your OS.
* Makefile.common is your common Makefile including `.makefile/` files and shared between Makefile and test/Makefile.
* Makefile and test/Makefile uses Makefile.common and contain specific rules.

## MyMakefile guts

* Makefile.header: is the header part of your Makefile: it contains code for knowing your architecture, your compiler, defines folder name for your project or installation. It also checks against uninitialized variables. It also includes your personal Makefile.common (if it exists).
* Makefile.macros: contains code for defining as paths, libraries/project names, installation macros ...
* Makefile.color: define colorful printf and progress bar for hiding the misery of compilation.
* Makefile.flags: add all GCC/clang compilation flags findable in the world.
* Makefile.help: Allow Makefile to auto parse and display its own rules.
* Makefile.footer: is the footer part of your Makefile: it defines a set of Makefile rules (like compiling c++ files or linking the project, ...).

Some Bash scripts exist and are called by Makefile rules:
* targz.sh: for creating a backup of the code source project. The code source is compressed. git files, compiled and generated files (like doc) are not taken into account.
* version.sh: for creating version.h file needed when compiling the project.

## How to write a simple Makefile

For more information and more complete examples, see my projects using it. They follow the next code.

```
P := .
M := $(P)/.makefile

PROJECT = MyGame
TARGET = $(PROJECT)-unit-tests
DESCRIPTION = blah blah
BUILD_TYPE = debug

SUFFIX = .cpp
STANDARD = --std=c++14
COMPIL_FLAGS = -W -Wall -Wextra

include $(M)/Makefile.header

OBJS += file1.o file2.o

DEFINES += -DFOOBAR -UFOO
VPATH += $(P)/src $(P)/src/foo
INCLUDES += -I$(P)/src -I$(P)/include/foobar

THIRDPART_LIBS += $(THIRDPART)/foo/libfoo.a
LINKER_FLAGS += -L/not/official/path -lesoteric
PKG_LIBS += gtk+-3.0

all: $(TARGET) $(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET) $(PKG_FILE)

include $(M)/Makefile.footer
```

And that's all! Nothing else.

Explanations:
* **[Mandatory]** `P` shall indicate the relative path of the root folder.
* **[Mandatory]** `M` shall indicate the relative path of the folder containing the `MyMakefile` repo.
* **[Mandatory]** `PROJECT` is the project name.
* **[Mandatory]** `TARGET` is the name of your binary or library the Makefile is compiling for. It can be equal to `PROJECT` but you may want to have a different name (for example MyGame and MyGame-unit-tests). When installing it will be located in sub-folders.
* **[Mandatory]** `DESCRIPTION` allows to explain your project in few words. This information is used for pkg-config file when TARGET is a library.
* **[Mandatory]** `BUILD_TYPE` compile the project either in release or debug mode.
* **[Default=.cpp]** `SUFFIX` allows choosing between a c++ or a c project.
* **[Default=--std=c++11]** `STANDARD` is only used for c++ projects. It defines the c++ standard.
* **[Default=external]** `THIRDPART` refers to the folder containing thirdpart libraries
(git cloned from GitHub for example). In my case, in debug mode, I compile my project against the https://github.com/bombela/backward-cpp (placed in `$(THIRDPART)` directory) for displaying the stack trace when a segfault occurred.
* **[Mandatory]** `OBJS` is the list of object files.
* **[Optional]** `VPATH` and `INCLUDES` allow to find cpp and hpp files. Use the macro P. This can save you in the case of multiple Makefiles and Makefile.common.
* **[Optional]** `COMPIL_FLAGS` if set it will had extra compilation to `CXXFLAGS`. By default `CXXFLAGS` is set with plenty of good compilation flags for clang and gcc.
* **[Optional]** `LINKER_FLAGS` if set it will had extra compilation to `LDFLAGS`. By default `LDFLAGS` is set with plenty of good linker flags for clang and gcc.
* **[Optional]** `CXXFLAGS` and `LDFLAGS` if you do not want to have default compilation/linker flags you can use yours by setting thess variables.
* **[Mandatory]** `Makefile.header` is mandatory. Beware of placing it correctly else some variables maybe not initialized and MyMakefile will detect it.
* **[Optional]** `DEFINES` store macro definitions.
* **[Optional]** `PKG_CONFIG` defines system libraries known by the command `pkg-config` which will add parameters to `CXXFLAGS` and `LDFLAGS`.
* **[Optional]** `NOT_PKG_CONFIG` defines system libraries unknown from the command `pkg-config`. This will add parameters to `LDFLAGS`.
* **[Optional]** `THIRDPART_OBJS` and `THIRDPART_LIBS` define third part object files and static/shared libraries from the compilation of external libraries placed inside the `$(THIRDPART)` folder.
* **[Mandatory]** `all:` tell Makefile what to compile. In this case the binary `$(TARGET)` its libraries `$(STATIC_LIB_TARGET)`, `$(SHARED_LIB_TARGET)` and the pkg-config file `$(PKG_FILE)` (when typing `make install`).
* Including `Makefile.footer` is mandatory.

Note:
* the use of the mandatory `+=` because information may have been added by `Makefile.header`.
* You do not have to write compilation rules or `clean:` or `doc:` ... rules they are already defined in Makefile.footer.
* If you want to add new rules add them before or after `include $(M)/Makefile.footer`. For example:

```
...
include $(M)/Makefile.footer

install: $(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET)
  @$(call RULE_INSTALL_DOC)
  @$(call RULE_INSTALL_LIBRARIES)
  @$(call RULE_INSTALL_HEADER_FILES)
  @$(call RULE_INSTALL_PKG_CONFIG)
```

## Verbosity

To show back compilation flags, simply compile with:
```
VERBOSE=1 make
```

or:
```
V=1 make
```

## Changing a parameter

For example you want to use clang++-6.0 instead of g++ do:
```
make CXX=clang++-6.0
```

You can also modify `DESTDIR` and `PREFIX` to tell to the `make install` rule where to install your software.
