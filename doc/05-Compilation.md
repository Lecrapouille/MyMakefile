# 🔨 5. Compilation

**What you will learn**

- choose a compilation mode and a toolchain;
- find a bug with a sanitizer;
- the warnings, the hardening and the optimizations MyMakefile gives, and how to change them;
- where the build goes, and what a change rebuilds.

**Prerequisites**: [chapter 3](03-Targets.md).

---

## 1. 🎚️ Compilation modes

`COMPILATION_MODE` chooses the optimizations and the debugging information, for every target:

| Mode | Flags | `assert()` | LTO | Stripped |
|------|-------|------------|-----|----------|
| `debug` | `-O0 -g3 -fno-omit-frame-pointer` | kept, and `_GLIBCXX_ASSERTIONS` | | |
| `normal` (default) | `-O2 -g` | kept, and `_GLIBCXX_ASSERTIONS` | | |
| `release` | `-O3 -funroll-loops` | removed (`NDEBUG`) | yes | yes |
| `release-with-debug` | `-O2 -g -funroll-loops` | removed | yes | |
| `size` | `-Os -fmerge-all-constants` | removed | yes | yes |
| `fast` | `-O3 -ffast-math -march=native` | removed | yes | yes |

`test` is `debug` with `COVERAGE=1`, as in MyMakefile 2.

```sh
make COMPILATION_MODE=debug
make COMPILATION_MODE=release
```

A project chooses its default with `COMPILATION_MODE ?= release` before the `include` ([demo 01](demos/01/Makefile)): `?=` lets the command line choose another one.

## 2. 📂 Where the build goes

Each configuration has its own folder in `BUILD_DIR` (`build` by default): the system, the toolchain, the mode, then the instrumentation.

| Command | Build folder |
|---------|--------------|
| `make` | `build/linux-gcc-normal` |
| `make COMPILATION_MODE=debug SANITIZER=address` | `build/linux-gcc-debug-address` |
| `make COVERAGE=1` | `build/linux-gcc-normal-coverage` |
| `emmake make COMPILATION_MODE=release` | `build/emscripten-release` |
| `make` in the image of ExaequOS | `build/exaequos-normal` |
| `make TOOLCHAIN=mingw` (cross compiler) | `build/windows-mingw-normal` |

In it: `bin/` the executables, `lib/` the libraries and their pkg-config files, `gen/` the generated headers, `obj/<target>/` the objects of each target. Two configurations never share an object, so switching from one to the other rebuilds nothing.

## 3. 🔁 What a change rebuilds

- A modified source or header rebuilds the objects including it (the compiler writes the headers each object includes).
- A change of flags, of macros, of include folders or of compiler rebuilds the targets concerned, and only them: MyMakefile keeps the flags each target was built with.
- A changed list of objects relinks the target.

`make rebuild` builds the current configuration from scratch. [ccache](https://ccache.dev) is used when it is installed: building again a commit already built, in another folder or after `make clean`, takes seconds. `CCACHE=0` does without.

## 4. 🚩 The flags

`make show-flags` prints the options and the flags of each target. On [demo 02](demos/02/), with gcc 16:

```text
TutorialMyMakefile: gcc 16 Linux x86_64 normal
  ccache=/usr/bin/ccache lto=no hardening=1 strip=no sanitizers=none coverage=no
HelloWorld02
  CXXFLAGS -std=c++17 -pipe -O2 -g -fstack-protector-strong -fstack-clash-protection -fcf-protection=full -Wall -Wextra -Wpedantic ... -fPIE -U_FORTIFY_SOURCE -D_GLIBCXX_ASSERTIONS -D_FORTIFY_SOURCE=3 -DAPI_LINKAGE= -Iinclude
  LDFLAGS  -pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack
  LIBS     build/linux-gcc-normal/lib/libfoo.a build/linux-gcc-normal/lib/libbar.a
```

**Warnings.** About 60 for gcc and clang, the newer ones given only to the compilers that know them; `-Wc++20-compat` when compiling C++17. A target chooses its level with `WARNINGS`:

| `WARNINGS` | Gives |
|------------|-------|
| `strict` (default) | All of them |
| `paranoid` | Also `-Weffc++` with gcc, `-Weverything` with clang |
| `default` | `-Wall -Wextra` |
| `none` | None: the default of the third parties |

`WERROR=1` makes them errors, for the targets of the project, never for the third parties.

**Hardening** (`HARDENING=0` to turn it off): `-fstack-protector-strong`, `-fstack-clash-protection`, `-fcf-protection=full` (x86_64), `_FORTIFY_SOURCE=3` (2 for older compilers), position independent executables, and on Linux `-z relro -z now -z noexecstack` at link. `make check-harden` checks the executables ([chapter 6](06-Goals.md)).

**Optimized modes**: `-ffunction-sections -fdata-sections` and `--gc-sections` (unused functions removed at link), LTO (`-flto=auto -ffat-lto-objects` with gcc, ThinLTO with clang when `ld.lld` and `llvm-ar` are there).

**Your own flags.** `t.CXXFLAGS`, `t.CFLAGS`, `t.ASFLAGS`, `t.LDFLAGS` for one target; the usual `CXXFLAGS`, `CFLAGS`, `LDFLAGS` of make, on the command line, for every target. `CXX_STANDARD` (`c++17` by default) and `C_STANDARD` choose the standards.

| Option | Does |
|--------|------|
| `LTO=0`, `HARDENING=0`, `STRIP=0`, `CCACHE=0` | Turn off what is on by default |
| `NATIVE=1` | `-march=native -mtune=native`: for this processor only |
| `FAST_MATH=1` | `-ffast-math` in any mode |
| `VECTORIZE_REPORT=1` | The loops the compiler vectorized |
| `PGO=generate`, then `PGO=use` | Profile guided optimization: build, run a typical workload, build again |
| `EXPORT_MACRO=API_LINKAGE` | The macro of the exported symbols: `__declspec(dllexport)` while building a DLL, empty otherwise. `API_LINKAGE` by default, as in MyMakefile 2 |
| `FORCE_LOWER_CASE=1` | Lower case names for the files built and installed (`libfoo`, not `libFoo`) |
| `JOBS=4` | Jobs run at the same time: all the cores by default |
| `V=1` | Show the commands |

## 5. 🔬 Sanitizers

`SANITIZER` instruments every target of the project:

| `SANITIZER` | Finds |
|-------------|-------|
| `address` | Out of bounds accesses, use after free, leaks |
| `undefined` | Undefined behavior: overflow, misaligned pointer, bad cast... (stops at the first one) |
| `thread` | Data races |
| `memory` | Reads of uninitialized memory (clang) |
| `leak` | Leaks only |
| `hwaddress` | `address` with the help of the hardware (arm64) |
| `cfi`, `safe-stack` | Control flow integrity, safe stack (clang) |

Several are joined by commas: `SANITIZER=address,undefined`. MyMakefile stops on the ones that cannot go together (`address` and `thread`...). `make run-<target>` and `make check` set their `*SAN_OPTIONS`, so that a report gives the stack and stops the program.

```sh
make COMPILATION_MODE=debug SANITIZER=address,undefined check
```

## 6. 🧪 Instrumentation

| Option | For |
|--------|-----|
| `COVERAGE=1` | `--coverage`, for `make coverage` ([chapter 6](06-Goals.md)) |
| `GPROF=1` | `-pg`, for `make gprof` |
| `VALGRIND=1` | Flags that make the reports of valgrind readable |

## 7. 🧰 Toolchains

`TOOLCHAIN` chooses the compilers:

| `TOOLCHAIN` | Compilers | Default |
|-------------|-----------|---------|
| `gcc` | `gcc`, `g++` | Linux, Windows (MSYS2) |
| `clang` | `clang`, `clang++`, `llvm-ar` | macOS |
| `mingw` | `x86_64-w64-mingw32-g++` from Linux, `g++` in MSYS2 | |
| `emscripten` | `emcc`, `em++` | when `CXX` is `em++` (`emmake make`), or `EMSCRIPTEN`, `EXAEQUOS` are set |
| `msvc` | `cl`, `lib`, `link` | experimental |

`CXX`, `CC` and `AR` given on the command line or in the environment win: `make CXX=g++-13`. [Chapter 8](08-Platforms.md) gives the details of each system.

After the `include`, the files of the project can test `TARGET_OS` (`Linux`, `Darwin`, `Windows`, `Emscripten`...), `HOST_OS`, `TARGET_ARCH` and `COMPILER_FAMILY` (`gcc`, `clang`, `msvc`).

---

Next: [6. Goals](06-Goals.md) — everything `make` can do besides building.
