# API

## By-project informations

The following variables are mandatory to compile your project:

- `P` for setting the local path to the project root. Usually `P := .` since top-level Makefile are placed in the project root folder.
- `M` setting the local path to MyMakefile root folder. I suggest you to add `M := $(P)/.MyMakefile` where MyMakefile is this current repo (ideally as git submodule) and with a `.` to make it hidden. 
- `PROJECT_NAME` for giving a name to your project. When installing the project on your operating system a top-level folders holding libraries, includes, docs, data ... is created.
- `PROJECT_VERSION` for giving a version for your binaries and libraries. This will avoid you to have conflicts if you have to install several versions of the same project on your operating system.
- `TARGET_NAME` for giving a name to your executable or library target.
- `TARGET_DESCRIPTION` for giving a short description of your target. Some generated files need this information.
- `COMPILATION_MODE` for compiling in `release` (no debug symbols, binary is stripped) or `debug` (gdb symbols plus display stack trace in case of segfault) mode or `normal` (gdb without stack trace) or `test` mode (a shortcut to debug with `USE_COVERAGE := 1` usefull for unit-test).

## By-project configuration

The following variables are optional to compile your project:

- `FORCE_LOWER_CASE` if set then `PROJECT_NAME` and `TARGET_NAME` will be forced to have lower case names.
- `BUILD` set to `build` by default. Directory name holding the compilation artifacts.
- `THIRDPART` set to `external` by default. Directory holding third-party libraries.
- `PROJECT_DOC` set to `doc` by default. Name of the directory holding documentation.
- `GENERATED_PROJECT_DOC` set to `doc` by default. Name of the directory holding generated documentation.
- `PROJECT_DATA` set to `data` by default. Name of the directory holding project data.
- `PROJECT_TESTS` set to `tests` by default. Name of the directory holding unit tests.

## C/C++/Linker

- `CC` define your C compiler.
- `CXX` define your C++ compiler.
- `CXX_STANDARD` define your C++ standard. By default: `--std=c++14`.

## By-system informations

The following variables are deduced by MyMakefile.

- `OS` defines the operating system you are using and building for. Currently we do not cross compile.
Values are:
  - `Linux` for operating system running i.e. on Ubuntu, Debian ...
  - `Windows` for Windows. `WIN_ENV` will define environement such as MinGW ...
  - `Darwin` for MacOS.
  - `Emscripten` or Emscripten and ExaquOS. While they are not real operating system, this allows us to simplify logic.
  To distinguish them use `ifdef EXAEQUOS`.
- `ARCHI`: Windows: 32, 64, Linu: x86_64 ...

Depending on your operating system, the following variables are created:
- `EXT_BINARY` to define application extension (.exe for Windows, .app for MacOS X ...).
- `EXT_DYNAMIC_LIB` to define shared library extension (.so for Linux, .dll for Windows, .dylib for MacOS).
- `EXT_STATIC_LIB` to define shared library extension (.a for Linux, .lib for Windows).

## Debug Makefile

- `VERBOSE` or shorter `V` when set, will show Makefile rules when executed. i.e. `V=1 make all`.
- Uncomment the following lines to debub shell commands:
```
OLD_SHELL := $(SHELL)
SHELL = $(warning [$@])$(OLD_SHELL) -x
```

## Makefile rules

### Gprof

- `make USE_GPROF=1 gprof`


## GNU standard paths

See https://www.gnu.org/prep/standards/html_node/Directory-Variables.html
the following variables are supported:

- `DESTDIR` set empty by default. Define where the project will be installed.
- `PREFIX` set to `/usr/local` by default. Define where the project will be installed.
- `INCLUDEDIR` set to `$(PREFIX)/include` by default. Define where to install includes.
- `LIBDIR` set to `$(PREFIX)/lib` by default. Define where to install libraries.
- `PKGLIBDIR` set to `$(LIBDIR)/pkgconfig` by default. Define where to install pkgconfig files.
- `DATADIR` set to `$(PREFIX)/share` by default. Define where to install data and documentation.
- `BINDIR` set to `$(PREFIX)/bin` by default. Define where to install standalone applications.
- `TMPDIR` set to `/tmp` by default. Define where to you can store temporary files.

Note for ExaequOS, the binary will be installed into `/media/localhost/$(TARGET_NAME)/exa`.

## Print helpers

- `print-simple($1,$2)` print simple colorfull text.
- `print-from($1,$2,$3)` print simple colorfull text for in-coming information.
- `print-to($1,$2,$3)` print simple colorfull text for out-coming information.

## Commands

- `make run` will call your compiled standalone application (if your project is not a pure library project) or `make run -- your list -of --arguments` to pass `your list -of --arguments` as command line to your application. Note: for Emscripten this will call your web browser.
