# 🖥️ 8. Platforms

**What you will learn**

- build on Linux, macOS and Windows;
- build Windows executables from Linux;
- build for a browser with Emscripten, and for ExaequOS.

**Prerequisites**: [chapter 5](05-Compilation.md).

---

## 1. 🐧 Linux

```sh
sudo apt-get install build-essential pkg-config ccache
make
```

gcc is the default; `make TOOLCHAIN=clang` uses clang, and `llvm-ar` when it is installed. In debug mode, `libdw-dev` gives backward-cpp the stack of a crash ([chapter 4](04-Third-Parties.md)).

## 2. 🍏 macOS

The make of Apple is 3.81, too old: install GNU Make and run `gmake`.

```sh
brew install make pkg-config ccache
gmake
```

clang is the default. On Apple Silicon, the packages of Homebrew are in `/opt/homebrew`: give their `.pc` files to pkg-config with `export PKG_CONFIG_PATH=$(brew --prefix)/lib/pkgconfig:$(brew --prefix)/share/pkgconfig`.

An application can also be built as a bundle, `<name>.app`, beside the executable:

```makefile
myapp.BUNDLE := 1
myapp.ICON := data/myapp.icns                  # optional
myapp.BUNDLE_ID := com.example.myapp           # default: com.<project>.<name>
```

## 3. 🪟 Windows with MSYS2

In the MINGW64 shell of [MSYS2](https://www.msys2.org):

```sh
pacman -S mingw-w64-x86_64-toolchain mingw-w64-x86_64-make mingw-w64-x86_64-pkg-config git
mingw32-make
```

The executables get `.exe`, the shared libraries are DLLs (`.dll` and their import library). `make install` and `make dist` copy beside an executable the DLLs of MSYS2 it needs, so that it runs outside of MSYS2 (`COPY_RUNTIME_DLLS=0` to do without). To have none, link it statically:

```makefile
ifeq ($(TARGET_OS),Windows)
    myapp.LDFLAGS := -static
endif
```

MSYS2 exports `MINGW_PREFIX=/mingw64`: MyMakefile ignores it, since it is the folder of MSYS2 and not the prefix of a cross compiler.

## 4. 🔀 Windows executables from Linux

With the MinGW cross compiler (`mingw-w64` on Debian, `mingw64-gcc-c++` on Fedora):

```sh
make TOOLCHAIN=mingw
```

The compilers are `x86_64-w64-mingw32-gcc` and `x86_64-w64-mingw32-g++`, pkg-config is `x86_64-w64-mingw32-pkg-config`, the build goes to `build/windows-mingw-normal/`. `MINGW_PREFIX=i686-w64-mingw32-` targets 32 bits.

## 5. 🧪 Windows with MSVC (experimental)

From a *Developer Command Prompt*, where `cl.exe`, `lib.exe` and `link.exe` are in the `PATH`, with the GNU Make of `winget install ezwinports.make`:

```bat
make TOOLCHAIN=msvc
make TOOLCHAIN=msvc CXX=clang-cl CC=clang-cl
```

Not supported yet: the tracking of the included headers (`cl.exe` cannot write a dependency file: a modified header needs `make clean`), pkg-config, and DLLs (a DLL exports nothing without `__declspec(dllexport)`, so a `library` target only builds its static library).

## 6. 🌐 Emscripten

[Emscripten](https://emscripten.org) compiles C and C++ to WebAssembly, for a browser. Run make under `emmake`: MyMakefile picks the Emscripten toolchain when the compiler is `em++`.

```sh
emmake make
emmake make run-myapp      # opens it in the browser with emrun
emmake make check          # runs the tests with node
```

- An executable is `bin/<name>.html` with its `.js` and `.wasm`; a test is a `.js`, run by `node` (`TEST_RUNNER`).
- There are no shared libraries: a `shared` or `library` target builds its static library.
- A `cmake` third party is configured with `emcmake cmake`.
- The libraries Emscripten ships are given with its flags, not with pkg-config:

```makefile
ifeq ($(TARGET_OS),Emscripten)
    myapp.LDFLAGS := -sUSE_GLFW=3 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 \
        --preload-file $(abspath $(HERE)data)@data
endif
```

`EMSCRIPTEN=1` also chooses this toolchain, without `emmake`.

## 7. 🖥️ ExaequOS

[ExaequOS](https://www.exaequos.com) is a desktop running in the browser, with its own Emscripten (`emscripten-exa`). Its environment sets `EXAEQUOS`; MyMakefile then uses the Emscripten toolchain. The docker image `lecrapouille/exaequos:light` has it all:

```sh
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:$PWD" -w "$PWD" lecrapouille/exaequos:light make
```

The libraries of ExaequOS (`glfw`, `exa-wayland`...) are packages of its package manager, `epm.py`. The build goes to `build/exaequos-<mode>/`, beside the one of Emscripten. A `PKG_CONFIG` package that pkg-config does not know is installed by `epm.py`, once, in `EXAEQUOS_PKGS` (`build/exaequos` by default), and pkg-config looks there; the packages of the tests (gtest...) are left out:

```makefile
ifdef EXAEQUOS
    PKG_CONFIG_STATIC := 1
    myapp.PKG_CONFIG := exa-wayland glfw
    myapp.LDFLAGS := -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sFULL_ES3
endif
```

```text
*** Installing ExaequOS packages: exa-wayland glfw => /home/me/myproject/build/exaequos
Package exa-wayland (0.0.1) installed Package glfw (3.4.0) installed
```

`make install` puts each application in `media/localhost/<name>/exa/`, with its `exa.html` ([chapter 7](07-Installation.md)).

---

Next: [9. Continuous integration](09-Continuous-Integration.md) — the same builds on GitHub Actions.
