# MyMakefile

This repo contains a collection of Makefile rules for compiling my github projects. You can download it and use it for your project or use it as a git submodule.

My Makefile can do the following:
* colorful compilation messages: hide awful gcc compilation flags.
* display a progress bar (like CMake): show the percentage of compiled files.
* compiled files are placed in a build directory instead of stuck near source files.
* generate .d files listing all dependencies files (when one file is modified, dependencies files are also compiled)
* can compile static or shared libraries.
* can generate pkg-config file (when you project is a library).
* give macros for installing your program, its resources, libraries and include files.
* can call gcov (code coverage report), coverity scan (static analyser of code), doxgen (documentation generator).
* can compress your project (without .git or generated documentation) in a tar.gz tarball with the date and the version. Name collision of tarballs are managed.
* can display the help of your makefile rules.
* offer some extra extra extra compilation flags for c++.
* works with -jX option.

## Projects linked to this repo

* https://github.com/Lecrapouille/SimTaDyn
* https://github.com/Lecrapouille/OpenGLCppWrapper
* https://github.com/Lecrapouille/ChessNeuNeu

## Why this project ?

I do not why people like so much CMake. I never understood the need of developing a Makefile generator containing more lines of code than an equivalently hand-writen Makefile.
Of course for huge projects I understand but for my small personal project this repo is enough simple and complete.

## The template for your Makefile

To make this Makefile working in your project, you should have the folder organization like this:

```
.makefile/
src/
Makefile
VERSION
```

Where:
* .makefile/ is this repo
* src/ contains all your code sources
* VERSION an ASCII file containing your project version (like `0.1`).
* Makefile your personal project that you shall follow this template:

```
PROJECT = Foo
TARGET = Bar
DESCRIPTION=bla bla
PROJECT_MODE = debug
P=.
M=$(P)/.makefile
include $(M)/Makefile.header
include $(P)/Makefile.common
OBJ += file1.o file2.o
CXXFLAGS += -std=c++11
LDFLAGS  +=
DEFINES +=
EXTERNAL_LIBS +=
VPATH += $(P)/src:$(P)/src/foo
INCLUDES += -I$(P)/src -I$(P)/src/foo
include $(M)/Makefile.footer
```

And that's all ! Nothing else.

Explanations:
* PROJECT is the main project name. TARGET can be PROJECT but you can also want to distinguish
the name of the main software to named of standalone sub-project binaries (like examples, standalone projects, unit tests).
* DESCRIPTION is optional but use for pkg-config file for example.
* PROJECT_MODE set either to release or debug:compilations flags are changed and in my case I use the https://github.com/bombela/backward-cpp
project for displaying the stack trace when a segfault occurred.
* P shall indicates the backward position of the project root folder.
* M indicates the relative folder path containing this repo. Including Makefile.header is mandatory. Including Makefile.common is optional but
sometimes you may want to share information like gcc compilation flags to other sub-projects of your project.
* OBJ defines the list of compiled file. Note the use of the mandatory `+=` if you want to use backward-cpp. Note OBJ only contains the name of
the file. Please do not give prepend directory path. Use VPATH instead.
* CXXFLAGS, LDFLAGS and DEFINES respectively gcc/g++ compilation flags, linker flags and macro definition (-D or -U). Note the use of the mandatory `+=`
* EXTERNAL_LIBS define third part static/shared libraries.
* VPATH allows to expand OBJ with the project directories. INCLUDES allows to search header files (.h or .hpp files). Note the use of the mandatory `+=`
because the build directory is defined.
* Including Makefile.footer is mandatory.

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
