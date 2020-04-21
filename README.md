# MyMakefile

`MyMakefile` is a central build system based on GNU Makefile for compiling my GitHub C/C++ projects for Linux and Mac OS X (any maybe for Windows but I cannot test it **help wanted**). It allows me to reduce the size of my Makefiles by avoiding duplicating the same boring code over all my projects and therefore to update all my Makefiles in once. If for your own project, you are not interested in CMake and need to maintain a small makefile, you may be interested in this project.
Two choices: -- simply copy/paste it inside your project -- or, better, use it as a git submodule (to follow my evolutions).

Here, my personal projects using this repo as a git submodule:

* https://github.com/Lecrapouille/SimTaDyn
* https://github.com/Lecrapouille/SimForth
* https://github.com/Lecrapouille/OpenGLCppWrapper
* https://github.com/Lecrapouille/ChessNeuNeu

Why this project?

So you don't have to make yours or configure another one for more than 30 seconds.

Or maybe you wanted to ask: why not simply using CMake instead of this project, CMake is a Makefile generator after all and architecture agnostic? The answer would be yes for big projects but I personally never liked CMake for generating makefiles containing more lines than he equivalent hand-made Maykefile, especially for small projects such as mine.

## MyMakefile Features

MyMakefile allows you to:

* Define a target as a binary or a static/shared library for Linux and OS X.
* In the case of a library, a [pkg-config](https://en.wikipedia.org/wiki/Pkg-config) file is automatically created.
* Define macros for installing your program, its resources, docs, libraries, include files, pkg-config inside your OS.
* Define by default plenty of compilation flags for GCC and clang compilers. Some are made for hardening your binary.
* If you do not like my default compilation/link flags, you can replace it by yours.
* Enable/disable the good optimization flags (-Ox) as well as enabling/disabling asserts (NDEBUG) depending on if your project is in debug or release mode.
* Hide by default all these awful lines made of GCC compilation flags. Colorful information messages are displayed instead
with the percentage of compiled files (in the way of the CMake progress bar).
* Works with parallel builds (-jX option, where X is the number of your CPU cores).
* If you do not like the default compiler, you can tell your own.
* Compiled files are placed in a build directory instead of being created within source files.
* Generate .d files inside the build directory holding dependencies files (when one header file is modified, dependent source files are also compiled).
* Have make rules such as gcov (code coverage report), Coverity Scan (static analyzer of code), doxgen (documentation generator), asan (AddressSanitizer), check for a hardened target.
* Generate a Doxygen file with project parameters (such as project name, version ...). The generated HTML follows the style follows of the library SFML.
* Have a rule for compressing your project (without .git or generated documentation) in a tar.gz tarball with the date and the version. Names collision of tarballs is managed.
* Auto-generate the help and its comments for your own rules.
* You do not have to write Makefile rules for compiling your project or installing your project: use macros instead. You can add your own personal Makefile rules anyway.

**Current constraint: You have to define one target by Makefile. This can be easily bypassed.**

## Inside MyMakefile

* Makefile.header: is the part of your Makefile to be included as header part. It contains the code for knowing your architecture, your compiler, destination folder for installation.
It defines your project folder name (build, doc, external). It also checks against uninitialized variables.
* Makefile.macros: contains code for defining paths, libraries/project names, installation ...
* Makefile.color: define colorful displays and progress bar for hiding the misery of compilation.
* Makefile.flags: add all GCC/clang compilation flags findable in the world and more :)
* Makefile.help: Allow Makefile to auto parse and display its own rules.
* Makefile.footer: is the part of your Makefile to be included as footer part: it defines a set of Makefile rules (like compiling c++ files or linking the project, ...).
* Some Bash scripts exist and are called by Makefile rules:
 - targz.sh: for creating a backup of the code source project. The code source is compressed. git files, compiled and generated files (like doc) are not taken into account.
 - version.sh: for creating a version.h file needed when compiling the project.

## Prerequisites

You probably have to install:
- the basic calculator `bc` tool: `apt-get install bc` needed for my progress bar. I guess it was a bash builtin but it seems not!
- tools called by MyMakefile: gcov, doxygen, hardening-check: `apt-get install gcovr doxygen devscripts`

## Minimal MyMakefile example

Here the minimal environement:
```
foo/
├── .makefile/
├── Makefile
├── src/
│   ├── main.cpp
│   └── main.hpp
└── VERSION
```

- `.makefile/` is simply this repo `git clone git@github.com:Lecrapouille/MyMakefile.git --depth=1 .makefile` (or better as git sub-module).
I personally add the `.` to hide it in my workspace but this is not mandatory.
- `VERSION` is an ASCII file containing a version number such as `0.1` or `1.0.3`. It seems useless but it has a great role when installing
your project in your operating system: you can install different versions of your project without they interfering each others.
- `src/` is the folder containing your code source. For example, a simple hello word made by the `main.cpp` file. The name is not important as well
and can arbitrary contains plenty of folders and source files.
- `Makefile` contains, for this example, the following code (explanations come in next sections):

```
P := .
M := $(P)/.makefile

PROJECT = CheckMyMakefile
TARGET = Test
DESCRIPTION = Project template testing MyMakefile
BUILD_TYPE = release

include $(M)/Makefile.header

OBJS = main.o

DEFINES = -DFOO -UBAR
VPATH = $(P)/src
INCLUDES = -I$(P)/src

all: $(TARGET)

include $(M)/Makefile.footer
```

Note:
* You do not have to write compilation rules or rules such as `clean:` or `doc:` ... rules they are already defined in Makefile.footer.
* If you want to add new rules add them before or after `include $(M)/Makefile.footer`.
* `OBJS` contains the list of all .o files (separated by spaces). Please just give their base names and not their source path.
* Use `VPATH` (separated by spaces) to define folders for finding your source files.
* Use `INCLUDES` (prepend by `-I` and separated by spaces) to define folders for finding your header files.
* Use `DEFINES` for defining your C/C++ macros.

#### Compilation

- To compile it just type `make` or `make -j8` change 8 to the number of cores of your CPU.
- To display compilation flags, simply compile with `VERBOSE=1 make -j8` or `V=1 make -j8`.
- To change the default compiler by yours (for ie clang++-6.0 instead of g++) do: `make CXX=clang++-6.0 -j8`
- If compiled with success, you can test it: `./build/CheckMyMakefile` (by default `$(BUILD)=build`).

#### Utility rules

- `make clean` remove `$(BUILD)` `$(GENDOC)/coverage`, `$(GENDOC)/html` folders.
- `make doc` generate Doxyfile and call doxygen. The report is generated inside `$(GENDOC)/html`.
- `check-harden` check if you code is hardening.
- `asan` use Address Sanitizer (USE_ASAN shall be set to 1).
- `gprof` use GNU profiler (USE_GPROF shall be set to 1).
- `coverage` call gcov against your code and generate a code coverage report inside `$(GENDOC)/coverage`.
- `coverity-scan` static analyzer of code (only if you have install coverity-scan): a tarball is created that you have to manually upload on their server
for obtaining the report.
- `tarball` compress your project in tar.gz tarball (without `.git`, `$(BUILD)`, `$(GENDOC)` folders). Name conflicts of tarball are managed.
- `which-compiler` show which is the default compiler.

The following commands are mine and will not work "as it" for you:
- `make obs` call the bash script `$(P)/.integration/opensuse-build-service.sh`. I used for building my projects on compilation farms.
- `download-external-libs` call the bash script `$(P)/$(THIRDPART)/download-external-libs.sh` I use it as alternative to git submodules.
I download github projects inside `$(P)/$(THIRDPART)`, rename them, refactorize them, etc ... This command is also used for my continuous integration tests.
- `compile-external-libs` call the bash script `$(P)//$(THIRDPART)/download-external-libs.sh` Compile my downloaded GitHub projects.
This command is also used for my continuous integration tests.

#### Installation

- Installation rule: you have to write your own install rule (usually named `install:`). Place it after the `all:`.
Some macros are here to help you: `@$(call RULE_INSTALL_DOC)`, `@$(call RULE_INSTALL_LIBRARIES)`,
`@$(call RULE_INSTALL_HEADER_FILES)`, `@$(call RULE_INSTALL_PKG_CONFIG)`. They respectively install the documentation (refered by `GENDOC`),
the .so (.dll or .dylib) and .a library files, .hpp files and .pc file inside your operating system.
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
│   ├── main.cpp
│   ├── foo.cpp
│   └── main.hpp
├── test/
│   ├── Makefile
│   ├── tests.cpp
│   ├── tests.hpp
│   └── VERSION
└── VERSION
```

- Add a `Makefile.common` holding shared information between `./Makefile` and `test/Makefile`
  (such as `PROJECT`, `VPATH`, `INCLUDES`, `DEFINES`, `THIRDPART_LIBS`, `LINKER_FLAGS`) and
  including `$(M)/Makefile.header`.
- Each Makefile defines `P` the path to the root of the project (`.` for `./Makefile` and `..` for `test/Makefile`) and include the `Makefile.common`.

Example `Makefile.common`:
```
PROJECT = CheckMyMakefile
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
include $(M)/Makefile.common
OBJS = tests.o foo.o
all: $(TARGET)
include $(M)/Makefile.footer
```

See my personal projects for more complete examples.

## Useful Macros

Explanations of the guts MyMakefile:
* **[Mandatory]** `P` shall indicate the relative path to the root folder (`.`, `..` etc).
* **[Mandatory]** `M` shall indicate the relative path of the folder containing the `MyMakefile` repo (usually `M := $(P)/.makefile`).
* **[Mandatory]** `PROJECT` is the main project name.
* **[Mandatory]** `TARGET` is the name of your binary or library that your Makefile file is compiling for. `TARGET` can be equal to `PROJECT` but
for the same project, you may want several binaries and therefore several Makefile targets (for example MyGame-lib, MyGame-exec, and MyGame-unit-tests).
When typing `make install` resources files will be install in their sub-folders (such as PROJECT/PROJECT_VERSION/TARGET/TARGET_VERSION/). The current constraint is
to have one Makefile file for each target (this is not a major problem if your create one folder by sub-project).
* **[Mandatory]** `DESCRIPTION` explain your target in few words. This information is used for pkg-config file when `TARGET` is a library (or soon for [Open Build Service](https://openbuildservice.org/)).
* **[Mandatory]** `BUILD_TYPE` allow compile the project either in `release` mode (compiled with -O2 and no gdb symbols) or `debug` mode (compiled with -O0 -g3 and extra compilation flags and use [backward-cpp](https://github.com/bombela/backward-cpp)) or `normal` mode (compiled -O2 -g). This mode is very slow and generates bigger executable size but nice for developement.
* **[Optional]** when `BUILD_TYPE=release` [backward-cpp](https://github.com/bombela/backward-cpp) is disabled.
* **[Optional]** You can activate gprof with `USE_GPROF=1` and `make gprof` rule.
* **[Optional]** You can activate address sanitizer with `USE_ASAN=1` and `make asan` rule.
* **[Default=.cpp]** `SUFFIX` allows choosing between a c++ or a c project.
* **[Default=--std=c++11]** `STANDARD` is only used for c++ projects. It defines the c++ standard (gnu++11, std++14, etc).
* **[Default=external/]** `THIRDPART` refers to the folder containing thirdpart libraries
(git cloned from GitHub for example). In my case, in `debug` mode, I compile my project against the https://github.com/bombela/backward-cpp (placed in `$(THIRDPART)` directory) for displaying the stack trace when a segfault occurred.
* **[Mandatory]** `OBJS` is the list of object files you want to compile. Do not include their path just their name with the extension `.o` (ie foo.o bar.o).
* **[Optional]** `VPATH` and `INCLUDES` allow to find .c or .cpp and .hpp or .h files. Use the macro `P` in paths (ie `$(P)/src`).
* **[Optional]** `COMPIL_FLAGS` if set it will had extra compilation flags to `CXXFLAGS`. By default `CXXFLAGS` is set with plenty of good compilation flags for clang and gcc.
* **[Optional]** `LINKER_FLAGS` if set it will had extra linkage flags to `LDFLAGS`. By default `LDFLAGS` is set with plenty of good linker flags for clang and gcc.
* **[Optional]** `CXXFLAGS` and `LDFLAGS` allow to replace default values by your own flags (in the case you do not desire to use default compilation/linker flags).
* **[Mandatory]** `Makefile.header` is mandatory else MyMakefile will not be called. Beware of placing it correctly (some variables are nevertheless checked by MyMakefile).
* **[Optional]** `DEFINES` hold your macro definitions.
* **[Optional]** `PKG_LIBS` defines system libraries known by the command `pkg-config` which will add extra flags to `CXXFLAGS` and `LDFLAGS`. In the case you want to force using static library you can add `--static` before the library name. For example: `PKG_LIBS += glew --static glfw3`.
* **[Optional]** `NOT_PKG_CONFIG` defines system libraries unknown from the command `pkg-config`. This will add  extra flags to `CXXFLAGS` and `LDFLAGS`.
* **[Optional]** `THIRDPART_OBJS` and `THIRDPART_LIBS` define .o, .a or .so (.dll or .dylib) files once your third part have been compiled. I personally add in `THIRDPART` shell scripts such as
 `download-external-libs.sh` (called by `make download-external-libs`) and `compile-external-libs.sh` (called by `make compile-external-libs`) to allow to git clone github projects and compile them.
This avoids having git submodules (which I dislike).
* **[Mandatory]** `all:` tell Makefile what to compile. In this case the binary `$(TARGET)` its libraries `$(STATIC_LIB_TARGET)`, `$(SHARED_LIB_TARGET)` and the pkg-config file `$(PKG_FILE)` (when typing `make install`).
* Including `Makefile.footer` is mandatory.

### How are made CXXFLAGS and LDFLAGS?

Here how INTERNALY `CXXFLAGS` and `LDFLAGS` are made:
```
CXXFLAGS := $(CXXFLAGS) $(PKGCFG_CFLAGS) $(OPTIM_FLAGS) $(DEFINES) $(INCLUDES) $(COMPIL_FLAGS)
LDFLAGS := $(LDFLAGS) $(THIRDPART_LIBS) $(NOT_PKG_LIBS) $(PKGCFG_LIBS) $(LINKER_FLAGS)
```

* `:= $(CXXFLAGS)` and `:= $(LDFLAGS)` have predefined flags but can be replaced by yours. 
* `$(PKGCFG_CFLAGS)` is made by `PKG_LIBS` when calling the option `--cflags`.
* `$(PKGCFG_LIBS)` is made by `PKG_LIBS` when calling the option `--libs`.
* `$(OPTIM_FLAGS)` is changed by `BUILD_TYPE=release` or `BUILD_TYPE=debug`.
* `$(DEFINES)` is defined by you.
* `$(INCLUDES)` is defined by you.
* `$(COMPIL_FLAGS)` and `$(LINKER_FLAGS)` are defined by you.
* `$(THIRDPART_LIBS)` are defined by after having compiled your external libraries.
* `$(NOT_PKG_LIBS)` are system libs when not define by a `pkg-config` file.

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

## Similar project

- https://github.com/Parrot-Developers/alchemy

