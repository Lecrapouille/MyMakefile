# MyMakefile 3 (experimental)

[MyMakefile](https://github.com/Lecrapouille/MyMakefile) is a build system for
C and C++ projects, written in GNU Make. You declare what to build; MyMakefile
writes the rules.

Version 3 is a rewrite. Compared with version 2:

- **Several targets in one make graph.** Libraries, applications and tests are
  declared side by side and depend on each other by name. There is no
  recursive `$(MAKE)` call and no `DIRS_WITH_MAKEFILE` any more, and `make -j`
  sees the whole project.
- **Declarations next to the sources.** A target can be declared in a `.mk`
  file in the directory it compiles, with paths relative to that directory.
- **No bash scripts.** Everything is done by GNU Make functions or by a
  single command (the compiler, `git`, `pkg-config`). Recipes run with a POSIX
  shell or with `cmd.exe`.
- **One build directory per configuration**, e.g. `build/linux-gcc-normal`
  and `build/emscripten-release`, and one object directory per target, so two
  targets can compile the same file with different flags.
- **Third parties are targets** with a `GIT` URL: their commits are locked,
  their sources and builds shared by all your projects in a cache.
- **ccache** is used when it is installed.

Branch `version-2` keeps the previous MyMakefile.

## Requirements

GNU Make 4.2 or newer, on every system:

| System  | GNU Make                                                     |
| ------- | ------------------------------------------------------------ |
| Linux   | `make`                                                       |
| macOS   | `brew install make`, then run `gmake` (Apple's make is 3.81) |
| BSD     | `pkg install gmake`, then run `gmake`                        |
| Windows | MSYS2 (`mingw-w64-x86_64-make`), or `winget install ezwinports.make` |

BSD make and NMake are not supported: the engine relies on `$(eval)` and on
the other functions of GNU Make.

## Quick start

Add MyMakefile to your project, for example as a git submodule:

```bash
git submodule add -b version-3 https://github.com/Lecrapouille/MyMakefile.git .makefile
```

Then write a `Makefile` at the root of your project:

```makefile
PROJECT_NAME := MyProject
PROJECT_VERSION := 1.0.0
CXX_STANDARD := c++17

TARGETS := mylib
mylib.TYPE := library
mylib.SOURCES := src/**/*.cpp
mylib.PUBLIC_INCLUDES := include

SUBMAKEFILES := app/app.mk tests/tests.mk

include .makefile/MyMakefile.mk
```

and `app/app.mk`, whose paths are relative to `app/`:

```makefile
TARGETS += myapp
myapp.SOURCES := src/*.cpp
myapp.DEPENDS := mylib
```

Then:

```bash
make                 # every target but the tests
make myapp           # myapp, and mylib before it
make run-myapp       # build and run it
make check           # build and run the tests
make COMPILATION_MODE=debug
make help
```

`doc/demos/` holds three small projects, and
[OpenGlassBox](https://github.com/Lecrapouille/OpenGlassBox) (branch
`mymakefile-v3`) a complete one: a library, three third parties, a demo
application, unit tests and a tool.

## Declaring a target

A target is a name added to `TARGETS`, plus variables prefixed by that name.

| Variable           | Meaning |
| ------------------ | ------- |
| `TYPE`             | `executable` (default with sources), `test`, `static`, `shared`, `library` (static and shared), `objects` (linked as objects in the targets using it), `header-only` (default without sources), `cmake` (a third party built by its CMake: see below) |
| `SOURCES`          | Files and patterns: `src/*.cpp`, `src/**/*.cpp` (recursive). C, C++ and assembly (`.s`, `.S`) |
| `INCLUDES`         | Include directories for this target only |
| `PUBLIC_INCLUDES`  | Include directories for this target and for the targets depending on it |
| `DEFINES`          | Macros for this target only, without `-D`: `FOO BAR=1` |
| `PUBLIC_DEFINES`   | Macros for this target and for the targets depending on it |
| `DEPENDS`          | Targets this one uses: their public includes and macros, and their libraries |
| `PKG_CONFIG`       | pkg-config packages: their flags go to this target and to the targets depending on it |
| `CXXFLAGS`, `CFLAGS`, `ASFLAGS`, `LDFLAGS` | Additional flags for this target only |
| `LIBS`             | Libraries at the end of the link line, e.g. `-lpthread`; also for the targets depending on it |
| `WARNINGS`         | `strict` (default), `paranoid` (also `-Weffc++`, or `-Weverything` with clang), `default` (`-Wall -Wextra`) or `none` |
| `RPATH`            | Run time search paths of the libraries, separated by `:` |
| `NODELETE`         | `1`: the shared library is never unloaded (`-z nodelete`) |
| `POST_BUILD`       | Commands run after the target is built |
| `MERGE`            | Static libraries (targets or `.a` files) whose objects are put in this static library, as `extract-objs-from-static-libs` did |
| `PUBLIC_HEADERS`, `PRIVATE_HEADERS` | Headers installed besides those of `PUBLIC_INCLUDES`, and headers not installed: see [Installation](#installation) |
| `NAME`             | Name of the file built, if not the name of the target |
| `DESCRIPTION`      | One line about the target |
| `PROJECT_INFO`     | `1` to generate `project_info.hpp` (version, git commit, data paths) |
| `DATA`             | Data directory: written in `project_info.hpp` and installed |
| `ARGS`             | Arguments for `make run-<target>` and `make check` |
| `INSTALL`          | `no` to keep the target out of `make install` |
| `CLEAN`            | Files and patterns removed by `make veryclean` |
| `BUNDLE`, `ICON`, `BUNDLE_ID` | macOS: `1` to build `<name>.app` too, with its `.icns` icon |
| `GIT`, `VERSION`, `COMMIT`, `PATH` | Third party: see below |

Targets are linked in the right order whatever the order of the `DEPENDS`.
MyMakefile stops with a message on: a dependency cycle, an unknown target, a
dependency on an executable, a source file or pattern matching nothing, a
library without sources, a name starting with `lib`, a missing
`PROJECT_NAME` or `PROJECT_VERSION`. It warns about variables of a target it
does not know (`app.SOURCE := ...`: a typo).

### Paths and `HERE`

In a file listed in `SUBMAKEFILES`, paths are relative to the directory of
that file; in the main `Makefile`, to the root of the project. While a file of
`SUBMAKEFILES` is read, `HERE` holds its directory, for the flags that need a
path (`--preload-file $(abspath $(HERE)data)`). Use `:=` with `HERE`, since its
value changes from one file to the next.

### Third parties

A target with a `GIT` URL is fetched the first time it is needed, then built
as any other target. Its paths are relative to its sources, its warnings are
disabled and its public includes are system includes, so that its headers do
not raise warnings in your code.

- **Locked versions.** Its `VERSION` (branch or tag, default branch without
  it) is resolved once to a commit, written in `external/versions.lock`
  (`EXTERNAL_LOCK`). Commit this file: everybody, and the CI, then build the
  same commits, without asking the network. `make update-externals` moves to
  the last commits.
- **Shared cache.** The sources are fetched once per commit, and compiled once
  per configuration and flags, in `~/.cache/mymakefile` (`EXTERNAL_CACHE`,
  `%LOCALAPPDATA%` on Windows): all your projects share them. `make
  cache-info` shows where they are, `make cache-clean` empties the cache.
  `EXTERNAL_CACHE=` (empty) clones them in `external/` of the project instead.
- **Local copy.** `imgui.PATH := ../imgui` uses a directory of yours, never
  fetched.
- **Built by their own CMake.** `TYPE := cmake`: configured, built and
  installed in its own prefix, in the cache too, before the targets using it
  are compiled. `LIBRARIES` names what to link (`z` for `libz.a`),
  `PUBLIC_INCLUDES` is relative to the prefix (`include` by default),
  `CMAKE_ARGS` are given to the configuration.

```makefile
TARGETS += zlib
zlib.GIT := https://github.com/madler/zlib.git
zlib.VERSION := v1.3.1
zlib.TYPE := cmake
zlib.CMAKE_ARGS := -DZLIB_BUILD_EXAMPLES=OFF
zlib.LIBRARIES := z
```

```makefile
TARGETS += imgui
imgui.GIT := https://github.com/ocornut/imgui.git
imgui.VERSION := docking          # branch or tag; or imgui.COMMIT := <sha1>
imgui.TYPE := static
imgui.SOURCES := imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp
imgui.PUBLIC_INCLUDES := .
```

In debug mode, as MyMakefile 2 did, the executables get
[backward-cpp](https://github.com/bombela/backward-cpp) (stack of a crash, on
Linux when `libdw` is installed; `BACKWARD=0` to do without) and every target
[dbg-macro](https://github.com/sharkdp/dbg-macro) (`dbg(...)`; `DBG_MACRO=0`).

## Compilation

| Option             | Values |
| ------------------ | ------ |
| `COMPILATION_MODE` | `debug` (`-O0 -g3`), `normal` (default: `-O2 -g`, assertions kept), `release` (`-O3`, LTO, stripped), `release-with-debug` (`-O2 -g`, LTO), `size` (`-Os`), `fast` (`-O3 -ffast-math -march=native`); `test` is `debug` with `COVERAGE=1`, as in MyMakefile 2 |
| `TOOLCHAIN`        | `gcc` (default), `clang` (default on macOS), `mingw`, `emscripten`, `msvc` |
| `SANITIZER`        | `address`, `undefined`, `thread`, `memory`, `leak`, `hwaddress`, `cfi`, `safe-stack`, or several: `address,undefined`. Incompatible ones stop make. `make run-<target>` and `make check` set their `*SAN_OPTIONS` |
| `COVERAGE=1`, `GPROF=1`, `VALGRIND=1` | Instrumentation, for every target |
| `PGO=generate`, `PGO=use` | Profile guided optimization |
| `NATIVE=1`, `FAST_MATH=1`, `VECTORIZE_REPORT=1` | Options of MyMakefile 2 |
| `LTO=0`, `HARDENING=0`, `STRIP=0`, `CCACHE=0` | Turn off what is on by default |
| `WERROR=1`         | Warnings are errors, for the targets of the project (not the third parties) |
| `JOBS=4`           | Jobs run at the same time: all the cores by default (GNU Make runs one without `-j`) |
| `EXPORT_MACRO`     | `API_LINKAGE` (as in MyMakefile 2): `__declspec(dllexport)` while building a DLL, empty otherwise |
| `PRE_BUILD`, `POST_BUILD` | Commands run before compiling, and after `all` |
| `V=1`              | Show the commands |
| `COLORS=0`, `COLORS=1` | Colors off, or on even when the output is not a terminal; `NO_COLOR` also turns them off |
| `BUILD_DIR`        | `build` by default |
| `PREFIX`, `DESTDIR`| Where `make install` copies the files |
| `CXX`, `CC`, `AR`, `CXXFLAGS`, `LDFLAGS` | The usual make variables, applied to every target |
| `FORCE_LOWER_CASE=1` | Lower case names for the files built and installed (`libfoo`, not `libFoo`) |

The flags, all from MyMakefile 2 and more (`make show-flags` prints them):

- **Warnings**: about 60 for gcc and clang, the newer ones given only to the
  compilers knowing them; `-Wc++20-compat` when compiling C++17.
- **Hardening**: `-fstack-protector-strong`, `-fstack-clash-protection`,
  `-fcf-protection=full` (x86_64), `_FORTIFY_SOURCE=3` (2 for older
  compilers) when optimized, position independent executables, and on Linux
  `-z relro -z now -z noexecstack` at link.
- **Optimized modes**: `-ffunction-sections -fdata-sections` and
  `--gc-sections`, LTO (`-flto=auto -ffat-lto-objects` with gcc, ThinLTO with
  clang when `ld.lld` and `llvm-ar` are there).
- **Debug**: `-fno-omit-frame-pointer`, `_GLIBCXX_ASSERTIONS` (also in
  normal), backward-cpp.

After the include, `TARGET_OS` (`Linux`, `Darwin`, `Windows`, `Emscripten`,
...), `HOST_OS` and `COMPILER_FAMILY` (`gcc`, `clang`, `msvc`) can be tested by
the target files.

## Goals

| Goal | Does |
| ---- | ---- |
| `all` | Builds every target but the tests (default) |
| `<target>` | Builds one target and what it depends on |
| `run-<target>` | Builds and runs an executable; `ARGS="..."` |
| `check` | Builds and runs the tests from the root of the project |
| `coverage` | Builds with coverage, runs the tests and writes the gcovr report in `doc/code-coverage/` |
| `rebuild` | Builds the current configuration from scratch |
| `clean-<target>`, `clean`, `distclean` | Remove the build of one target, of this configuration, of every configuration |
| `veryclean` | Also removes the clones of the third parties, the documentation, the coverage report, the leftovers of the tools (`*.gcda`, `*.orig`, `*~`...), the `CLEAN` files of every target and `CLEAN_FILES` |
| `install`, `uninstall` | See [Installation](#installation) |
| `doc` | Doxygen documentation in `doc/doxygen/`, with the footer of the license found in `LICENSE` |
| `format`, `check-format` | clang-format the sources and headers of the project, or fail if one is not formatted |
| `lint` | cppcheck, target by target with their flags |
| `compile-commands` | Writes `compile_commands.json` for clangd |
| `tarball` | Archive of the sources, third parties included, in `build/dist/` |
| `rpm` | RPM package built with `make install` |
| `update-externals`, `cache-info`, `cache-clean` | Third parties: see above |
| `gdb-<target>` | Builds and runs an executable in the debugger (`GDB=lldb`) |
| `tidy` | clang-tidy with `compile_commands.json` |
| `memcheck` | Runs the tests in valgrind: fails on a memory error or a leak |
| `gprof` | Builds with `GPROF=1`, runs `GPROF_TARGET` and writes the report in `doc/profiling/` |
| `size-analysis`, `check-harden` | Sizes of the binaries; hardening of the executables (hardening-check or checksec) |
| `coverity` | Archive of a build under `cov-build`, for Coverity Scan |
| `list-targets`, `show-flags`, `help` | Print the targets, their flags, the goals and the options |

A change of flags, or of compiler, rebuilds the targets concerned, and only
them.

`clean`, `distclean`, `veryclean`, `install` and `uninstall` are double-colon
rules: a project adds its own recipe with `clean::`.

## Installation

`make install` copies, in `DESTDIR` and the directories of MyMakefile 2
(`PREFIX`, `BINDIR`, `LIBDIR`, `INCLUDEDIR`, `PKGLIBDIR`, `DATADIR`): the
executables and bundles, the libraries (with the links of the shared ones),
their headers and pkg-config file, the `DATA` of the targets in
`share/<project>/`, and the license and readme in `share/doc/<project>/`.
`make uninstall` removes them. It works with sh and with cmd.exe.

The headers of a library are those of its `PUBLIC_INCLUDES` (a directory of
headers, A), plus its `PUBLIC_HEADERS` (files or patterns anywhere, B), less
its `PRIVATE_HEADERS`. Each one is installed at the path the code includes it
with: relative to the deepest include directory of the library holding it.
Both ways can be mixed:

```makefile
mylib.PUBLIC_INCLUDES := include          # include/MyLib/Api.hpp -> MyLib/Api.hpp
mylib.INCLUDES := src
mylib.PUBLIC_HEADERS := src/**/*.hpp      # src/MyLib/Tool.hpp    -> MyLib/Tool.hpp
mylib.PRIVATE_HEADERS := src/MyLib/detail/*.hpp
```

The build tree has its own pkg-config files: with
`PKG_CONFIG_PATH=build/linux-gcc-normal/lib/pkgconfig`, another project uses
a library of yours without installing it. The installed `.pc` file finds its
prefix from its own place, so that an archive of `make dist` works where it is
unpacked. A third party used by an installed library is not installed: put it
in the library with `MERGE`, as MyMakefile 2 did, or make warns.

`INSTALL_VERSIONED=1` keeps the versions side by side, as MyMakefile 2 did:
`include/<project>/<version>/`, `share/<project>/<version>/`,
`bin/<name>-<version>` and `<name>-<version>.pc`, with links without the
version. With `EXAEQUOS`, `make install` puts each application in
`media/localhost/<name>/exa/` with its `exa.html`, as MyMakefile 2 did.

## Continuous integration

MyMakefile gives a CI what it would otherwise script:

| Goal | For |
| ---- | --- |
| `ci` | Everything to check in one command: `CI_GOALS` (default `all check`) |
| `dist` | The artifacts: what `make install` copies, plus `LICENSE`, `README`, `VERSION`, in `build/dist/<project>-<version>-<os>-<arch>/` and its `.tar.gz`. The pkg-config file finds its own prefix, so the archive works where it is unpacked |
| `ci-info` | `key=value` lines: name, version, os, arch, toolchain, build, dist_dir... |
| `print-<VAR>` | One variable: `make -s print-PROJECT_VERSION` |
| `check-format` | Fails on unformatted code |

On GitHub Actions:

```yaml
- name: Describe the build
  id: info
  run: make -s ci-info >> "$GITHUB_OUTPUT"
- run: make ci
- run: make dist
- uses: actions/upload-artifact@v6
  with:
    name: ${{ steps.info.outputs.dist_name }}
    path: ${{ steps.info.outputs.dist_dir }}/
```

Cache `~/.cache/mymakefile` with the key `hashFiles('external/versions.lock')`
to fetch and build the third parties once.

The same commands run with `mingw32-make` on MSYS2, `gmake` on macOS and
`emmake make` for Emscripten (MyMakefile picks the Emscripten toolchain when
the compiler is `em++`). Colors are off in CI logs, which are not a terminal;
`COLORS=1` turns them on for GitHub, which shows them. A package missing from
pkg-config stops the build of the target needing it with its name.

## Platforms

| Platform | Status |
| -------- | ------ |
| Linux, gcc | Tested |
| Linux, clang; macOS | Written, not tested yet |
| Windows, MinGW (MSYS2 or cross compiler) | Written, not tested yet |
| Emscripten | Written, not tested yet |
| Windows, MSVC | Experimental: no header dependency tracking, no DLL |

## Not ported from version 2

The OBS package (its script was missing), the benchmark goal (`make
run-<target>` under `time`), the progress bar (see below), `make run --
args` (`make run-<target> ARGS="..."`).

The percentage of MyMakefile 2 was the number of objects compiled over the
number of objects of the target: wrong as soon as the build is incremental,
and computed with `expr`, a process per file. make cannot know, before
running, how many objects are out of date, so the messages give the target
and the file instead.

## Writing MyMakefile

Functions called with `$(call ...)` are in lower case with dashes
(`rwildcard`, `print-to`); macros (`define`: templates of rules and of files)
and variables in upper case (`TARGET_RULES`, `BUILD`). The variables of a
target are `t.SOMETHING` when the user writes them, `t._SOMETHING` when
MyMakefile computes them.

## License

Dual licensed, GPL v3 or commercial: see [LICENSING.md](LICENSING.md).
