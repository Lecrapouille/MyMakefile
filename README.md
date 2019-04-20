# MyMakefile

This repo contains a collection of Makefile rules for compiling my github C++ projects. You can download it directly in your project or better to use it as a git submodule.

My Makefile can do the following things:
* colorful compilation messages: hide awful gcc compilation flags.
* display a progress bar (like CMake): show the percentage of compiled files (you probably have to install the basic calculator `bc` tool)
* compiled files are placed in a `build/` directory instead of stuck near source files.
* generate .d files inside the build dir and listing all dependencies files (when one header file is modified, dependent souce files are also compiled).
* can compile static or shared libraries (add `$(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET)` to your `all:` rule).
* can generate pkg-config file when you project is a library (add `$(PKG_FILE)` to your `all:` rule).
* give macros for installing your program, its resources, libraries and include files (`RULE_INSTALL_DOC RULE_INSTALL_LIBRARIES RULE_INSTALL_HEADER_FILES RULE_INSTALL_PKG_CONFIG`).
* have rules like gcov (code coverage report), coverity scan (static analyser of code), doxgen (documentation generator).
* have rule to compress your project (without .git or generated documentation) in a tar.gz tarball with the date and the version. Name collision of tarballs are managed (`make tarball`).
* can display the help of your makefile rules (`make help`).
* offer some extra extra extra compilation flags for c++ (`$(CXX_WHOLE_FLAGS)`).
* works with -jX option.

## Projects linked to this repo

* https://github.com/Lecrapouille/SimTaDyn
* https://github.com/Lecrapouille/OpenGLCppWrapper
* https://github.com/Lecrapouille/ChessNeuNeu

## Why this project ?

I do not why people like so much CMake. Of course for huge projects I understand but for my small personal project this repo is enough simple and complete. I never understood the need of developing a Makefile generator containing more lines of code than an equivalently hand-writen Makefile.

## Template for your project and Makefile

To make this Makefile working in your project, you should have the folder organization like this:

```
.makefile/
src/
Makefile
VERSION
```

Where:
* .makefile/ is this repo (can be a git submodule to get all updates).
* src/ contains all your code sources.
* VERSION an ASCII file containing your project version (like `0.1`). For the moment it is mandatory.
* Makefile is your personal project Makekeil including `.makefile/` files.

The template of Makefile looks like this one:
```
PROJECT = MyGame
TARGET = MyGame-unit-test
DESCRIPTION = bla bla
PROJECT_MODE = debug
P=.
M=$(P)/.makefile
include $(M)/Makefile.header
include $(P)/Makefile.common
OBJ += file1.o file2.o
CXXFLAGS += -std=c++11
LDFLAGS  +=
DEFINES +=
EXTERNAL_LIBS += -lz
VPATH += $(P)/src:$(P)/src/foo
INCLUDES += -I$(P)/src -I$(P)/src/foobar
include $(M)/Makefile.footer

# For binary
all: $(TARGET)

# For libraries:
# all: $(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET) $(PKG_FILE)
```

And that's all ! Nothing else.

Explanations:
* `PROJECT` is the main project name. `TARGET` can be `PROJECT` for your main makefile but you can also want to distinguish
the name of the main software to named of standalone sub-project binaries (like examples, standalone projects, unit tests).
Example: 
* `DESCRIPTION` is optional but used for pkg-config file.
* `PROJECT_MODE` set either to release or debug: compilations flags are changed (add -g option) and in my case, in debug mode, I compile my project against the https://github.com/bombela/backward-cpp (placed in $(THIRDPART) directory) for displaying the stack trace when a segfault occurred.
* `P` is mandatory and shall indicate the backward path of the project root folder.
* `M` indicates the relative folder path containing `MyMakefile` repo. Including `Makefile.header` is mandatory. Including `Makefile.common` is optional but sometimes you may want to share information like gcc compilation flags to other sub-projects of your project.
* `OBJ` defines the list of compiled file. Note the use of `+=` if you want to use backward-cpp. Note `OBJ` only contains the name of
compiled files (ie `foo1.o foo2.o`). Please do not prepend directory pathes (like `src/bar/foo1.o`). Use `VPATH` instead.
* `CXXFLAGS`, `LDFLAGS` and `DEFINES` respectively set gcc/g++ compilation flags, linker flags and macro definition (-D or -U like `-DNDEBUG`). Note the use of the mandatory `+=` because previous informations have been added by `Makefile.header`.
* `EXTERNAL_LIBS` define third part static/shared libraries.
* `VPATH` allows to expand `OBJ` with the project directories. `INCLUDES` allows to search header files (.h or .hpp files when doing `#include <mylib/file.hpp>`). Note the use of the mandatory `+=` because the build directory (`$(BUILD)`) is defined.
* Including `Makefile.footer` is mandatory.
* Define your `all:` rule by telling what to compile: project `$(TARGET)` or libraries `$(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET) $(PKG_FILE)`.

Note:
* You do not have to write compilation rules or clean rule they are already present in Makefile.footer
* If you want to add new rules add them after `include $(M)/Makefile.footer`. For example:
```
...
include $(M)/Makefile.footer

install: $(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET)
	@$(call RULE_INSTALL_DOC)
	@$(call RULE_INSTALL_LIBRARIES)
	@$(call RULE_INSTALL_HEADER_FILES)
	@$(call RULE_INSTALL_PKG_CONFIG)
```
* For more information and more complete examples, see my projects using it.

## Documentation

The Makefile.xxx files contain common Makefile rules for avoiding you have to duplicate code in your Makefile.
* Makefile.header: header part for Makefile: get architecture information, define macros, set libraries name ...
* Makefile.footer: footer part for Makefile: define a set of Makefile rules (like compiling c++ files or linking the project).
* Makefile.color: define colorful printf and progress bar for hiding the misery of compilation.
* Makefile.flags: add all g++ compilation flags findable in the world.
* Makefile.help: Allow Makefile to auto parse and display its own rules.

Some Bash scripts exist and are called by Makefile rules:
* targz.sh: for creating backup of the code source project. Code source is compressed. git files, compiled and generated files (like doc) are not taken into account.
* version.sh: for creating version.h file needed when compiling the project.
