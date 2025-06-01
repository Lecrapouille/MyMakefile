# API Documentation

## Makefile Help System

To view available variables that can be overridden and rules that can be called, execute in your console:

```bash
make help
```

To extend MyMakefile rules and documentation:

- Document default variables using `#? my single-line comment` before the variable declaration
- Document rules using `#? my single-line comment` before the rule definition
- Constraint: Only single-line comments are supported

### Example (Makefile)

```makefile
#? This is my variable documentation
FOO ?= bar

#? This is my rule documentation
foobar:
    ...
```

### Example (Console Output)

```bash
> make help

Usage:
  [VERBOSE=1] make [flags...] <target>

You can override the following flags:
  FOO               This is my variable documentation
    Default value: bar

Targets:
  foobar:           This is my rule documentation
```

## Debug and Verbose Options

The following variables can be combined for enhanced debugging:

- `VERBOSE` (or `V`): When set, displays Makefile rules content during execution
- `DEBUG` (or `D`): When set, shows shell commands during execution

Best practice is to modify these when calling make, and they can be combined with other makefile debug options:

- `--warn-undefined-variables`
- `--just-print`
- `--print-data-base`

### Example (Console)

```bash
> V=1 D=1 make all --warn-undefined-variables
```

## Compiler Configuration

You can override the default C/C++ compiler settings. It's recommended to set these when calling make:

- `CC`: Defines your C compiler
- `CXX`: Defines your C++ compiler
- `AR`: Defines your archiver (for static libraries)

**Note:** Additional variables can be overridden. Use `make help` to view all available options.

### Example (Console)

```bash
> make CXX=clang++ all
```

## Project Configuration

The following mandatory variables must be defined before including `project/Makefile` and at the top of your Makefile:

- `P`: Local path to project root (typically `P := .` for top-level Makefiles)
- `M`: Local path to MyMakefile root (suggested: `M := $(P)/.makefile`)
- `PROJECT_NAME`: Project identifier (used for installation paths)
- `PROJECT_VERSION`: Version number in `major.minor.patch` format
- `TARGET_NAME`: Executable or library target name
- `TARGET_DESCRIPTION`: Brief project description
- `COMPILATION_MODE`: Build mode selection
  - `release`: No debug symbols, stripped binary
  - `debug`: GDB symbols with stack trace on segfault
  - `normal`: GDB symbols without stack trace
  - `test`: Debug mode with code coverage (for unit testing)

Optional variables:

- `FORCE_LOWER_CASE`: When set, forces `PROJECT_NAME` and `TARGET_NAME` to lowercase. Useful when you used 'title case' convention but you want to install on operating system that need
lower case (i.e. RedHat). 

### Example (Makefile)

```makefile
P := .
M := $(P)/.makefile

PROJECT_NAME := MySuperProject
PROJECT_VERSION := 0.2.0
TARGET_NAME := $(PROJECT_NAME)
TARGET_DESCRIPTION := This is a real super project
COMPILATION_MODE := release
FORCE_LOWER_CASE := 1

include $(M)/project/Makefile
```

## Project Directory Structure

Optional configuration variables for project structure (define before including `project/Makefile`):

- `BUILD`: Build artifacts directory (default: `build`)
- `THIRD_PARTIES`: Third-party libraries directory (default: `external`)
- `PROJECT_DATA`: Project data directory (default: `data`)
- `PROJECT_DOC`: Documentation directory (default: `doc`)
- `PROJECT_GENERATED_DOC`: Generated documentation directory (default: `doc`)
- `PROJECT_TESTS`: Unit tests directory (default: `tests`)
- `PROJECT_TEMP_DIR`: Temporary files directory (default: `$(TMPDIR)/$(PROJECT_NAME)/$(PROJECT_VERSION)`)

### Example (Makefile)

```makefile
P := .
M := $(P)/.makefile

PROJECT_NAME := MySuperProject
PROJECT_VERSION := 0.2.0
TARGET_NAME := $(PROJECT_NAME)
TARGET_DESCRIPTION := This is a real super project
COMPILATION_MODE := release

BUILD := out
THIRD_PARTIES := thirdparties
PROJECT_DATA := demo/data
PROJECT_DOC := docs
PROJECT_GENERATED_DOC := docs/gen
PROJECT_TESTS := check

include $(M)/project/Makefile
```

## C/C++ Compiler and Linker Configuration

Optional compiler and linker settings (define before including `project/Makefile`):

- `CXX_STANDARD`: C++ standard (default: `--std=c++14`)
- `REGEXP_CXX_HEADER_FILES`: C++ header file patterns (default: `*.hpp *.ipp *.tpp *.hh *.h *.hxx *.incl`)
- `USER_CXXFLAGS`: Override default C++ compilation flags
- `USER_CCFLAGS`: Override default C compilation flags
- `USER_LDFLAGS`: Override default linker flags

### Example (Makefile)

```makefile
P := .
M := $(P)/.makefile

PROJECT_NAME := MySuperProject
PROJECT_VERSION := 0.2.0
TARGET_NAME := $(PROJECT_NAME)
TARGET_DESCRIPTION := This is a real super project
COMPILATION_MODE := release

CXX_STANDARD := --std=c++11
USER_CXX_FLAGS := -Wno-old-style-cast

include $(M)/project/Makefile
```

## Documentation Configuration

- `DOXYGEN_INPUTS`: Doxygen input files
- `GENERATED_DOXYGEN_DIR`: Doxygen output directory (default: `$(PROJECT_GENERATED_DOC_DIR)/doxygen`)
- `GPROF_ANALYSIS`: Profiling analysis output (default: `$(PROJECT_GENERATED_DOC_DIR)/profiling/analysis.txt`)
- `COVERAGE_RAPPORT`: Code coverage report location
- `MACOS_BUNDLE_ICON`: macOS application bundle icon
- `PATH_PROJECT_LOGO`: Project logo path

## System Information

The following variables are automatically determined by MyMakefile and available after including `project/Makefile`:

- `OS`: Operating system identifier
  - `Linux`: Linux-based systems (Ubuntu, Debian, etc.)
  - `Windows`: Windows systems (with `WIN_ENV` for environment specifics)
  - `Darwin`: macOS systems
  - `Emscripten`: Emscripten environment
  - `ExaequOS`: ExaequOS environment (check with `ifdef EXAEQUOS`)
- `ARCHI`: Architecture identifier (e.g., 32, 64, x86_64)

System-specific extensions:

- `EXT_BINARY`: Executable extension (`.exe` for Windows, `.app` for macOS)
- `EXT_DYNAMIC_LIB`: Shared library extension (`.so` for Linux, `.dll` for Windows, `.dylib` for macOS)
- `EXT_STATIC_LIB`: Static library extension (`.a` for Linux, `.lib` for Windows)

## Makefile Rules

### Profiling

```bash
make USE_GPROF=1 gprof
```

## GNU Standard Installation Paths

Following the GNU standards (https://www.gnu.org/prep/standards/html_node/Directory-Variables.html):

- `DESTDIR`: Installation root (default: empty)
- `PREFIX`: Installation prefix (default: `/usr/local`)
- `INCLUDEDIR`: Header files location (default: `$(PREFIX)/include`)
- `LIBDIR`: Library files location (default: `$(PREFIX)/lib`)
- `PKGLIBDIR`: pkg-config files location (default: `$(LIBDIR)/pkgconfig`)
- `DATADIR`: Data and documentation location (default: `$(PREFIX)/share`)
- `BINDIR`: Executable files location (default: `$(PREFIX)/bin`)
- `TMPDIR`: Temporary files location (default: `/tmp`)

**Note:** For ExaequOS, binaries are installed to `/media/localhost/$(TARGET_NAME)/exa` regardless of `DESTDIR` and `BINDIR` settings.

## Print Helper Functions

- `print-simple($1,$2)`: Print colored text
- `print-from($1,$2,$3)`: Print colored text for incoming information
- `print-to($1,$2,$3)`: Print colored text for outgoing information

## Common Commands

- `make run`: Execute the compiled application (for non-library projects)
- `make run -- your list -of --arguments`: Run with command-line arguments
- **Note:** For Emscripten, this will launch your web browser
