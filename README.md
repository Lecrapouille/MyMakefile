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
- **Third parties are targets** with a `GIT` URL: cloned on the first build,
  then compiled like the other targets.

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
| `TYPE`             | `executable` (default with sources), `test`, `static`, `shared`, `library` (static and shared), `header-only` (default without sources) |
| `SOURCES`          | Files and patterns: `src/*.cpp`, `src/**/*.cpp` (recursive) |
| `INCLUDES`         | Include directories for this target only |
| `PUBLIC_INCLUDES`  | Include directories for this target and for the targets depending on it |
| `DEFINES`          | Macros for this target only, without `-D`: `FOO BAR=1` |
| `PUBLIC_DEFINES`   | Macros for this target and for the targets depending on it |
| `DEPENDS`          | Targets this one uses: their public includes and macros, and their libraries |
| `PKG_CONFIG`       | pkg-config packages: their flags go to this target and to the targets depending on it |
| `CXXFLAGS`, `CFLAGS`, `LDFLAGS` | Additional flags for this target only |
| `LIBS`             | Libraries at the end of the link line, e.g. `-lpthread`; also for the targets depending on it |
| `WARNINGS`         | `strict` (default), `default` (`-Wall -Wextra`) or `none` |
| `NAME`             | Name of the file built, if not the name of the target |
| `DESCRIPTION`      | One line about the target |
| `PROJECT_INFO`     | `1` to generate `project_info.hpp` (version, git commit, data paths) |
| `DATA`             | Data directory: written in `project_info.hpp` and installed |
| `ARGS`             | Arguments for `make run-<target>` and `make check` |
| `INSTALL`          | `no` to keep the target out of `make install` |
| `CLEAN`            | Files and patterns removed by `make veryclean` |
| `BUNDLE`, `ICON`, `BUNDLE_ID` | macOS: `1` to build `<name>.app` too, with its `.icns` icon |
| `GIT`, `VERSION`, `COMMIT` | Third party: see below |

Targets are linked in the right order whatever the order of the `DEPENDS`.
A dependency cycle or an unknown target stops make with an error.

### Paths and `HERE`

In a file listed in `SUBMAKEFILES`, paths are relative to the directory of
that file; in the main `Makefile`, to the root of the project. While a file of
`SUBMAKEFILES` is read, `HERE` holds its directory, for the flags that need a
path (`--preload-file $(abspath $(HERE)data)`). Use `:=` with `HERE`, since its
value changes from one file to the next.

### Third parties

A target with a `GIT` URL is cloned into `external/<name>` (`EXTERNAL_DIR`)
the first time it is needed, then built as any other target. Its paths are
relative to its clone, its warnings are disabled and its public includes are
system includes, so that its headers do not raise warnings in your code.

```makefile
TARGETS += imgui
imgui.GIT := https://github.com/ocornut/imgui.git
imgui.VERSION := docking          # branch or tag; or imgui.COMMIT := <sha1>
imgui.TYPE := static
imgui.SOURCES := imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp
imgui.PUBLIC_INCLUDES := .
```

## Options

| Option             | Values |
| ------------------ | ------ |
| `COMPILATION_MODE` | `debug`, `normal` (default: `-O2 -g`), `release` |
| `TOOLCHAIN`        | `gcc` (default), `clang` (default on macOS), `mingw`, `emscripten`, `msvc` |
| `COVERAGE=1`, `SANITIZER=address` | Instrumentation, for every target |
| `V=1`              | Show the commands |
| `COLORS=0`, `COLORS=1` | Colors off, or on even when the output is not a terminal; `NO_COLOR` also turns them off |
| `BUILD_DIR`        | `build` by default |
| `PREFIX`, `DESTDIR`| Where `make install` copies the files |
| `CXX`, `CC`, `AR`, `CXXFLAGS`, `LDFLAGS` | The usual make variables, applied to every target |

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
| `install` | Installs executables, bundles, libraries, public headers, pkg-config files and data in `DESTDIR`/`PREFIX` |
| `doc` | Doxygen documentation in `doc/doxygen/`, with the footer of the license found in `LICENSE` |
| `format`, `check-format` | clang-format the sources and headers of the project, or fail if one is not formatted |
| `lint` | cppcheck, target by target with their flags |
| `compile-commands` | Writes `compile_commands.json` for clangd |
| `tarball` | Archive of the sources, third parties included, in `build/dist/` |
| `rpm` | RPM package built with `make install` |
| `list-targets`, `show-flags`, `help` | Print the targets, their flags, the goals and the options |

A change of flags rebuilds the targets concerned, and only them.

`clean`, `distclean`, `veryclean` and `install` are double-colon rules: a
project adds its own recipe with `clean::`.

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

Not yet: cache of third parties shared between projects, lock file of their
versions. Dropped: the OBS package (its script was missing), gprof, Coverity,
benchmark and size statistics goals, the progress bar.

## License

Dual licensed, GPL v3 or commercial: see [LICENSING.md](LICENSING.md).
