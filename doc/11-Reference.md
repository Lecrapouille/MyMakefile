# 📖 11. Reference

What you will find here: every variable of a target, every variable of a project, every option of the command line and every goal, checked against the engine. The learning chapters show them in use.

---

## 1. Variables of a target

Written `t.VARIABLE` for a target `t`. Paths are relative to the file declaring the target ([chapter 3](03-Targets.md)). Another name is reported as a typo.

### 1.1 What to build

| Variable | Meaning | Chapter |
|----------|---------|---------|
| `TYPE` | `executable` (default with sources), `test`, `static`, `shared`, `library`, `objects`, `header-only` (default without sources), `cmake` | [3](03-Targets.md) |
| `SOURCES` | Files and patterns (`*`, `**` recursive): `.c`, `.cpp`, `.cc`, `.cxx`, `.s`, `.S` | [3](03-Targets.md) |
| `GENERATED_SOURCES`, `GENERATED_HEADERS` | Files made by a rule of the project, relative to `$(GEN_DIR)` | [3](03-Targets.md) |
| `NAME` | Name of the file built, if not the name of the target | [3](03-Targets.md) |
| `EXT` | Extension of the executable, if not the one of the system | |
| `DESCRIPTION` | One line about the target: `project_info.hpp`, pkg-config file, Doxygen | [3](03-Targets.md) |

### 1.2 How to compile it

| Variable | Meaning | Chapter |
|----------|---------|---------|
| `INCLUDES`, `DEFINES` | Include folders and macros (without `-D`) of this target only | [3](03-Targets.md) |
| `PUBLIC_INCLUDES`, `PUBLIC_DEFINES` | The same, also for the targets depending on it | [3](03-Targets.md) |
| `CXXFLAGS`, `CFLAGS`, `ASFLAGS` | Flags of this target only | [5](05-Compilation.md) |
| `WARNINGS` | `strict` (default), `paranoid`, `default`, `none` (default of the third parties) | [5](05-Compilation.md) |
| `SYSTEM` | `1`: its public includes are system includes for the targets using it (default of the third parties) | [4](04-Third-Parties.md) |
| `PROJECT_INFO` | `1`: generate `<name>/project_info.hpp` | [3](03-Targets.md) |

### 1.3 How to link it

| Variable | Meaning | Chapter |
|----------|---------|---------|
| `DEPENDS` | Targets it uses: their public includes, macros, packages, libraries | [3](03-Targets.md) |
| `PKG_CONFIG` | pkg-config packages, also for the targets depending on it | [4](04-Third-Parties.md) |
| `LIBS` | Libraries at the end of the link line, also for the targets depending on it | [3](03-Targets.md) |
| `LDFLAGS` | Link flags of this target only | [5](05-Compilation.md) |
| `LIBRARIES` | Without sources: libraries built elsewhere. With `TYPE := cmake`: the libraries CMake builds | [4](04-Third-Parties.md) |
| `MERGE` | Static libraries (targets, CMake third parties or `.a` files) whose objects go in this static library | [3](03-Targets.md) |
| `RPATH` | Run time search paths, separated by `:` | [3](03-Targets.md) |
| `NODELETE` | `1`: the shared library is never unloaded (`-z nodelete`) | |

### 1.4 Running, installing, cleaning

| Variable | Meaning | Chapter |
|----------|---------|---------|
| `ARGS` | Arguments of `make run-<target>` and `make check` | [6](06-Goals.md) |
| `WORKDIR` | Folder it runs in, relative to the target (root of the project by default) | [3](03-Targets.md) |
| `POST_BUILD` | Commands run after the target is built | [3](03-Targets.md) |
| `DATA` | Data folder: in `project_info.hpp`, and installed | [7](07-Installation.md) |
| `PUBLIC_HEADERS`, `PRIVATE_HEADERS` | Headers installed besides those of `PUBLIC_INCLUDES`, headers not installed | [7](07-Installation.md) |
| `INSTALL` | `no`: not installed | [7](07-Installation.md) |
| `CLEAN` | Files and patterns removed by `make veryclean` | [6](06-Goals.md) |
| `BUNDLE`, `ICON`, `BUNDLE_ID` | macOS: build `<name>.app` too, its `.icns` icon, its identifier | [8](08-Platforms.md) |

### 1.5 Third parties

| Variable | Meaning | Chapter |
|----------|---------|---------|
| `GIT` | URL of the repository | [4](04-Third-Parties.md) |
| `VERSION` | Branch or tag (default branch without it) | [4](04-Third-Parties.md) |
| `COMMIT` | A commit, instead of `VERSION` | [4](04-Third-Parties.md) |
| `SUBMODULES` | `1`: also fetch its git submodules | [4](04-Third-Parties.md) |
| `MAKEFILES` | Its `.mk` files declaring targets, read once it is fetched: a project built by MyMakefile | [4](04-Third-Parties.md) |
| `PATH` | A local folder, never fetched | [4](04-Third-Parties.md) |
| `URL`, `SHA256`, `SUBDIR` | An archive, its checksum, its folder to use | [4](04-Third-Parties.md) |
| `CMAKE_ARGS` | Arguments of the configuration of a `cmake` target | [4](04-Third-Parties.md) |
| `DIR`, `LOCKED`, `LOCKED_REF` | Written by MyMakefile: the folder of the sources, the locked commit and its reference | |

## 2. Variables of a project

Set before the `include` of MyMakefile.

| Variable | Default | Meaning |
|----------|---------|---------|
| `PROJECT_NAME`, `PROJECT_VERSION` | required | Name and `major.minor.patch` version |
| `PROJECT_DESCRIPTION` | the first `DESCRIPTION` of a target | One line about the project |
| `TARGETS` | | The targets |
| `SUBMAKEFILES` | | `.mk` files declaring more targets |
| `CXX_STANDARD`, `C_STANDARD` | `c++17`, the default of the compiler | Standards |
| `COMPILATION_MODE` | `normal` | [Chapter 5](05-Compilation.md) |
| `PRE_BUILD`, `POST_BUILD` | | Commands run before compiling, after `all` |
| `CI_GOALS` | `all check` | Goals of `make ci` |
| `CLEAN_FILES` | | Files removed by `make veryclean` |
| `LICENSE` | found in the `LICENSE` file | `GPL-3.0`, `MIT`...: footer of Doxygen, RPM |
| `PROJECT_LOGO` | the logo of MyMakefile | Logo of the Doxygen documentation |
| `BUILD_DIR`, `EXTERNAL_DIR`, `DOC_DIR` | `build`, `external`, `doc` | Folders of the project |
| `EXTERNAL_LOCK` | `external/versions.lock` | Commits of the third parties |
| `EXTERNAL_CACHE`, `MYMAKEFILE_CACHE` | `~/.cache/mymakefile` | Cache of the third parties; empty: in `EXTERNAL_DIR` |
| `PKG_CONFIG_STATIC` | | `1`: static flags of the packages |
| `EXPORT_MACRO` | `API_LINKAGE` | Macro of the exported symbols of a DLL |

## 3. Options of the command line

### 3.1 Compilation

| Option | Values |
|--------|--------|
| `COMPILATION_MODE` | `debug`, `normal`, `release`, `release-with-debug`, `size`, `fast`, `test` |
| `TOOLCHAIN` | `gcc`, `clang`, `mingw`, `emscripten`, `msvc` |
| `CXX`, `CC`, `AR`, `CXXFLAGS`, `CFLAGS`, `LDFLAGS` | The usual variables of make, for every target |
| `SANITIZER` | `address`, `undefined`, `thread`, `memory`, `leak`, `hwaddress`, `cfi`, `safe-stack`, several joined by commas |
| `COVERAGE=1`, `GPROF=1`, `VALGRIND=1` | Instrumentation |
| `PGO=generate`, `PGO=use` | Profile guided optimization |
| `NATIVE=1`, `FAST_MATH=1`, `VECTORIZE_REPORT=1` | Optimizations |
| `LTO=0`, `HARDENING=0`, `STRIP=0`, `CCACHE=0` | Turn off what is on by default |
| `WERROR=1` | Warnings are errors, for the targets of the project |
| `BACKWARD=0`, `DBG_MACRO=0` | No debugging helpers in debug mode |
| `FORCE_LOWER_CASE=1` | Lower case names for the files built and installed |
| `MINGW_PREFIX` | Prefix of the MinGW cross compiler: `x86_64-w64-mingw32-` |
| `EMSCRIPTEN`, `EXAEQUOS` | Choose the Emscripten toolchain |
| `JOBS` | Jobs at the same time: all the cores by default |

### 3.2 Display

| Option | Values |
|--------|--------|
| `V=1` | Show the commands |
| `COLORS=0`, `COLORS=1`, `NO_COLOR` | Colors off, on even without a terminal, off |
| `PROGRESS=0` | No percentage before the compiled files |

### 3.3 Installation

| Option | Default |
|--------|---------|
| `DESTDIR` | empty |
| `PREFIX` | `/usr/local` |
| `BINDIR`, `LIBDIR`, `INCLUDEDIR`, `PKGLIBDIR` | `$(PREFIX)/bin`, `$(PREFIX)/lib`, `$(PREFIX)/include`, `$(LIBDIR)/pkgconfig` |
| `DATADIR`, `PROJECT_DATADIR`, `DOCDIR` | `$(PREFIX)/share`, `$(DATADIR)/<project>`, `$(DATADIR)/doc/<project>` |
| `INSTALL_VERSIONED=1` | Versions side by side |
| `COPY_RUNTIME_DLLS=0` | MSYS2: do not copy the DLLs beside the executables |
| `YES=1`, `DRY_RUN=1` | `make uninstall`: do not ask, only print |
| `DIST_NAME`, `DIST_DIR`, `DIST_ARCHIVE`, `DIST_FILES` | `make dist` |
| `EXAEQUOS_DIR`, `EXAEQUOS_PKGS` | `media/localhost`, `build/exaequos` |

### 3.4 Tools

Each tool is a variable, with its options when it has some:

| Variable | Default |
|----------|---------|
| `PKG_CONFIG` | `pkg-config` |
| `CMAKE` | `cmake` |
| `GDB` | `gdb`, `lldb` on macOS, `devenv /debugexe` with MSVC |
| `DOXYGEN`, `DOXYGEN_DIR`, `DOXYGEN_INPUTS` | `doxygen`, `doc/doxygen`, `README.md include src` |
| `GCOVR`, `COVERAGE_DIR`, `COVERAGE_EXCLUDE` | `gcovr`, `doc/code-coverage`, the third parties, the build and the tests |
| `CLANG_FORMAT`, `FORMAT_FILES` | `clang-format`, the sources and headers of the project |
| `CPPCHECK`, `CPPCHECK_FLAGS` | `cppcheck` |
| `CLANG_TIDY`, `CLANG_TIDY_FLAGS` | `clang-tidy`, `--quiet` |
| `VALGRIND_TOOL`, `VALGRIND_FLAGS` | `valgrind`, `--error-exitcode=1 --leak-check=full ...` |
| `GPROF_TOOL`, `GPROF_TARGET`, `PROFILE_DIR` | `gprof`, the first executable, `doc/profiling` |
| `SIZE`, `HARDENING_CHECK` | `size`, `hardening-check` or `checksec` |
| `TARBALL`, `TARBALL_EXCLUDE` | `build/dist/<project>-<version>-src.tar.gz` |
| `RPMBUILD`, `RPM_DIR` | `rpmbuild`, `build/rpm` |
| `COV_BUILD`, `COVERITY_ARCHIVE` | `cov-build`, `build/dist/<project>-coverity.tgz` |
| `RUNNER`, `TEST_RUNNER` | Emscripten: `emrun`, `node` |

## 4. Read-only variables

After the `include`, for the `.mk` files and the rules of the project:

| Variable | Value |
|----------|-------|
| `TARGET_OS` | `Linux`, `Darwin`, `Windows`, `Emscripten`... |
| `HOST_OS` | The system make runs on |
| `TARGET_ARCH` | `x86_64`, `arm64`, `wasm`... |
| `COMPILER_FAMILY` | `gcc`, `clang`, `msvc` |
| `BUILD` | The build folder of the configuration: `build/linux-gcc-normal` |
| `GEN_DIR` | `$(BUILD)/gen` |
| `HERE` | While a file of `SUBMAKEFILES` is read: its folder |
| `MYMAKEFILE` | The folder of MyMakefile |

## 5. Goals

| Goal | Does | Chapter |
|------|------|---------|
| `all` | Every target but the tests (default) | [2](02-Getting-Started.md) |
| `<target>` | One target and what it depends on | [2](02-Getting-Started.md) |
| `run-<target>` | Build and run an executable | [6](06-Goals.md) |
| `gdb-<target>` | Build and run an executable in the debugger | [6](06-Goals.md) |
| `check` | Build and run the tests | [6](06-Goals.md) |
| `coverage` | Coverage report of the tests | [6](06-Goals.md) |
| `memcheck` | The tests in valgrind | [6](06-Goals.md) |
| `gprof` | Profile `GPROF_TARGET` | [6](06-Goals.md) |
| `rebuild` | This configuration from scratch | [5](05-Compilation.md) |
| `compile-commands` | `compile_commands.json` | [6](06-Goals.md) |
| `install`, `uninstall`, `uninstall-dry-run` | Install, uninstall | [7](07-Installation.md) |
| `dist` | Archive of the binaries | [7](07-Installation.md) |
| `tarball`, `rpm` | Archive of the sources, RPM package | [6](06-Goals.md) |
| `doc` | Doxygen documentation | [6](06-Goals.md) |
| `format`, `check-format` | clang-format | [6](06-Goals.md) |
| `lint`, `tidy` | cppcheck, clang-tidy | [6](06-Goals.md) |
| `size-analysis`, `check-harden` | Sizes of the binaries, hardening of the executables | [6](06-Goals.md) |
| `coverity` | Archive for Coverity Scan | [6](06-Goals.md) |
| `clean-<target>`, `clean`, `distclean`, `veryclean` | Clean | [6](06-Goals.md) |
| `update-externals`, `cache-info`, `cache-clean` | Third parties | [4](04-Third-Parties.md) |
| `ci`, `ci-info`, `print-<VAR>` | Continuous integration | [9](09-Continuous-Integration.md) |
| `help`, `list-targets`, `show-flags` | Information | [6](06-Goals.md) |

---

Back to the [table of contents](README.md).
