# MyMakefile

This repo contains a collection of Makefile rules and macros for compiling my GitHub C++ projects for Linux
and Mac OS X (**Help wanted: I cannot test it on Windows**) for reducing Makefile sizes and the amount of
duplicated Makefile code.

If you are not interested in CMake and want a small makefile, you can use this project as a git submodule for
your own project, it will help you to write Makefiles in a few lines and offer the following things:

* The Makefile target can be a binary or static or shared libraries. In this case, a pkg-config file is automatically generated.
* Macros exist for installing your program, its resources, libraries and include files.
* Define by default plenty of compilation flags for GCC and clang compilers. Somea are made for hardening your binary.
* Enable/disable the good -Ox flags as well as enabling/disabling asserts.
* Hide by default all these awful lines made of GCC compilation flags. They are replaced by colorful information messages
with the percentage of compiled files (in the way of a progress bar of CMake).
* Works with parallel builds (-jX option), accept to select your prefered compiler.
* Compiled files are placed in a `build/` directory instead of being created within source files.
* Generate .d files inside the `build/` directory holding dependencies files (when one header file is modified, dependent source files are also compiled).
* Have utility rules like gcov (code coverage report), Coverity Scan (static analyzer of code), doxgen (documentation generator), asan (AddressSanitizer), check for hardened target.
* Have a rule for compressing your project (without .git or generated documentation) in a tar.gz tarball with the date and the version. Name collision of tarballs are managed.
* Generate a Doxygen files with project parameters (such as project name, version ...)
* Can display the auto-generated help of makefile rules.
* You do not have to write Makefile rules for compiling your project or installing your project: use macros instead. You can add your own your personal Makefile rules anyway.

## My personal projects using MyMakefile

* https://github.com/Lecrapouille/SimTaDyn
* https://github.com/Lecrapouille/OpenGLCppWrapper
* https://github.com/Lecrapouille/ChessNeuNeu

## Why this project?

Or the hidden question would be: why not simply using CMake instead of this project? CMake is a Makefile generator afterall!
The answer would be yes for big projects but I personally never liked CMake for generating makefiles holding more lines than
the equivalent hand-made Maykefile, specially for small projects such mine.

## Prerequisites

You probably have to install:
- the basic calculator `bc` tool: `apt-get install bc` needed for my progress bar.
- tools called by MyMakefile: gcov, doxygen, hardening-check: `apt-get install gcovr doxygen devscripts`

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

## Minimal MyMakefile example

Here the minimal environement:
```
foo/
├── .makefile/
├── Makefile
├── src/
│   ├── main.cpp
│   └── main.hpp
└── VERSION
```

- `.makefile/` is simply this repo `git clone git@github.com:Lecrapouille/MyMakefile.git --depth .makefile` (or better as git sub-module).
- VERSION is an ASCII file containing a version number such as `0.1` or `1.0.3`.
- src/ is the folder containing your code source. For example a simple hello word.
- Makefile is the follow (explanations come in next sections):

```
P := .
M := $(P)/.makefile

PROJECT = CheckMyMakefile
TARGET = Test
DESCRIPTION = Project template testing MyMakefile
BUILD_TYPE = release

include $(M)/Makefile.header

OBJS += main.o

DEFINES +=
VPATH += $(P)/src
INCLUDES += -I$(P)/src

all: $(TARGET)

include $(M)/Makefile.footer
```

### Compilation

- Compilation: `make` or `make -j8` with 8 is the number of CPU cores.
- If compiled with success, you can test it: `./build/CheckMyMakefile`

#### Verbosity

To show back compilation flags, simply compile with:
```
VERBOSE=1 make
```

or:
```
V=1 make
```

#### Changing your compiler

For example you want to use clang++-6.0 instead of g++ do:
```
make CXX=clang++-6.0
```

#### Installation

- Installation: you have to write your own install rule and type `make install`.
Some macros are here `@$(call RULE_INSTALL_DOC)`, `@$(call RULE_INSTALL_LIBRARIES)`,
`@$(call RULE_INSTALL_HEADER_FILES)`, `@$(call RULE_INSTALL_PKG_CONFIG)`.
- You can also modify `DESTDIR` and `PREFIX` to tell to the `make install` rule where to install your software:
`sudo make DESTDIR=/usr PREFIX=/usr/local/stow/foo install` will install binaries in `/usr/local/stow/foo/usr/local/bin`.

## A more complex example

Let suppose you want to add a unit test folder. Just do this:
```
foo/
├── .makefile/
├── Makefile
├── Makefile.common
├── src/
│   ├── main.cpp
│   ├── foo.cpp
│   └── main.hpp
├── test/
│   ├── Makefile
│   ├── tests.cpp
│   ├── tests.hpp
│   └── VERSION
└── VERSION
```

- Add a `Makefile.common` holding shared information between `./Makefile` and `test/Makefile`
  (such as `PROJECT`, `VPATH`, `INCLUDES`, `DEFINES`, `THIRDPART_LIBS`, `LINKER_FLAGS`) and
  including `$(M)/Makefile.header`.
- Each Makefile define `P` the path to the root of the project (`.` for `./Makefile` and `..` for `test/Makefile`).
  and include the `Makefile.common`.

Example `Makefile.common`:
```
PROJECT = OpenGLCppWrapper
include $(M)/Makefile.header
DEFINES += -DFOOBAR
VPATH += $(P)/src
INCLUDES += $(P)/src
```

And `test/Makefile`:
```
P := ..
M := $(P)/.makefile
TARGET = $(PROJECT)-UnitTest
DESCRIPTION = Unit tests for $(PROJECT)
BUILD_TYPE = release
include $(P)/Makefile.common
OBJS = tests.o foo.o
all: $(TARGET)
include $(M)/Makefile.footer
```

See my personal projects for more information.

## Explanation of macros Makefile

Explanations:
* **[Mandatory]** `P` shall indicate the relative path to the root folder.
* **[Mandatory]** `M` shall indicate the relative path of the folder containing the `MyMakefile` repo.
* **[Mandatory]** `PROJECT` is the main project name.
* **[Mandatory]** `TARGET` is the name of your binary or library that your Makefile file is compiling for. `TARGET` can be equal to `PROJECT` but
for a same project you may want several binaries and therefore several Makefile targets (for example MyGame-lib, MyGame-exec and MyGame-unit-tests).
When typing `make install` resources files will be install in their sub-folders (such as PROJECT/TARGET/). The current main constraint is
to have one Makefile file for each target.
* **[Mandatory]** `DESCRIPTION` explain your target in few words. This information is used for pkg-config file when `TARGET` is a library (or soon for [Open Build Service](https://openbuildservice.org/)).
* **[Mandatory]** `BUILD_TYPE` allow compile the project either in `release` mode (compiled with -O2 and no gdb symbols) or `debug` mode (compiled with -O0 -g3 and extra compilation flags and use [backward-cpp](https://github.com/bombela/backward-cpp)) or `normal` mode (compiled -O2 -g).
* **[Optional]** when `BUILD_TYPE=release` [backward-cpp](https://github.com/bombela/backward-cpp) is disabled but you can force using it by adding `USE_BACKWARD=1`.
* **[Default=.cpp]** `SUFFIX` allows choosing between a c++ or a c project.
* **[Default=--std=c++11]** `STANDARD` is only used for c++ projects. It defines the c++ standard.
* **[Default=external]** `THIRDPART` refers to the folder containing thirdpart libraries
(git cloned from GitHub for example). In my case, in `debug` mode, I compile my project against the https://github.com/bombela/backward-cpp (placed in `$(THIRDPART)` directory) for displaying the stack trace when a segfault occurred.
* **[Mandatory]** `OBJS` is the list of object files you want to compile. Do not include their path just their name with the extension `.o` (ie foo.o bar.o).
* **[Optional]** `VPATH` and `INCLUDES` allow to find .c or .cpp and .hpp or .h files. Use the macro `P` in paths (ie `$(P)/src`).
* **[Optional]** `COMPIL_FLAGS` if set it will had extra compilation flags to `CXXFLAGS`. By default `CXXFLAGS` is set with plenty of good compilation flags for clang and gcc.
* **[Optional]** `LINKER_FLAGS` if set it will had extra linkage flags to `LDFLAGS`. By default `LDFLAGS` is set with plenty of good linker flags for clang and gcc.
* **[Optional]** `CXXFLAGS` and `LDFLAGS` allow to replace default values by your own flags (in the case you do not desire to use default compilation/linker flags).
* **[Mandatory]** `Makefile.header` is mandatory else MyMakefile will not be called. Beware of placing it correctly (some variables are nevertheless checked by MyMakefile).
* **[Optional]** `DEFINES` hold your macro definitions.
* **[Optional]** `PKG_LIBS` defines system libraries known by the command `pkg-config` which will add extra flags to `CXXFLAGS` and `LDFLAGS`.
* **[Optional]** `NOT_PKG_CONFIG` defines system libraries unknown from the command `pkg-config`. This will add  extra flags to `CXXFLAGS` and `LDFLAGS`.
* **[Optional]** `THIRDPART_OBJS` and `THIRDPART_LIBS` define .o, .a or .so (.dll or .dylib) files once your third part have been compiled. I personally add in `THIRDPART` shell scripts such as
 `download-external-libs.sh` (called by `make download-external-libs`) and `compile-external-libs.sh` (called by `make compile-external-libs`) to allow to git clone github projects and compile them.
This avoid to have a git submodules (which I dislike).
* **[Mandatory]** `all:` tell Makefile what to compile. In this case the binary `$(TARGET)` its libraries `$(STATIC_LIB_TARGET)`, `$(SHARED_LIB_TARGET)` and the pkg-config file `$(PKG_FILE)` (when typing `make install`).
* Including `Makefile.footer` is mandatory.

Note:
* the use of the mandatory `+=` because information may have been added by `Makefile.header`.
* You do not have to write compilation rules or `clean:` or `doc:` ... rules they are already defined in Makefile.footer.
* If you want to add new rules add them before or after `include $(M)/Makefile.footer`. For example:

### Examples

```
P := .
M := $(P)/.makefile

PROJECT = CheckMyMakefile
TARGET = Test
DESCRIPTION = Project template testing MyMakefile
BUILD_TYPE = debug

SUFFIX = .cpp
STANDARD = --std=c++14
CXXFLAGS = -W -Wall
COMPIL_FLAGS = -Wextra

include $(M)/Makefile.header

OBJS += main.o

DEFINES += -DFOOBAR -UFOO
VPATH += $(P)/src $(P)/src/foo
INCLUDES += -I$(P)/src I$(P)/include

THIRDPART_LIBS += $(THIRDPART)/foo/libfoo.a
LINKER_FLAGS += -L/not/official/path -lesoteric
PKG_LIBS += gtk+-3.0

all: $(TARGET)

install: $(STATIC_LIB_TARGET) $(SHARED_LIB_TARGET)
  @$(call RULE_INSTALL_DOC)
  @$(call RULE_INSTALL_LIBRARIES)
  @$(call RULE_INSTALL_HEADER_FILES)
  @$(call RULE_INSTALL_PKG_CONFIG)

include $(M)/Makefile.footer
```
