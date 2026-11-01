# 📦 4. Third parties

**What you will learn**

- use a library from a git repository, compiled as a target of your project;
- lock it to a commit, and move it on;
- share its sources and its builds between all your projects;
- use a local copy, an archive, or a project built by CMake;
- embed the libraries of another project built by MyMakefile;
- use the packages of the system with pkg-config.

**Prerequisites**: [chapter 3](03-Targets.md).

---

## 1. 📦 A library from git

A target with a `GIT` URL is a **third party**: MyMakefile fetches it the first time it is needed, then builds it as any other target. Dear ImGui, for example:

```makefile
TARGETS += imgui
imgui.GIT := https://github.com/ocornut/imgui.git
imgui.VERSION := docking
imgui.TYPE := static
imgui.SOURCES := imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp \
    backends/imgui_impl_glfw.cpp backends/imgui_impl_opengl3.cpp
imgui.PUBLIC_INCLUDES := . backends
imgui.PKG_CONFIG := glfw3
```

- `VERSION` is a branch or a tag; `COMMIT` a commit; without both, the default branch.
- `SUBMODULES := 1` also fetches its git submodules (rapidyaml needs `ext/c4core`).
- `SOURCES` and `PUBLIC_INCLUDES` are relative to the sources of the third party.
- Its warnings are off (`WARNINGS := none`), and its `PUBLIC_INCLUDES` are system include folders (`-isystem`) for the targets using it, so that its headers raise no warning in your code.

```sh
$ make
*** Fetching: imgui => /home/me/.cache/mymakefile/sources/imgui/d682dc41f58b98c9343ffbaa7d94f07e9024b3ca [docking]
*** Locking: MyProject => external/versions.lock
...
*** Static library: imgui => /home/me/.cache/mymakefile/builds/imgui/d682dc41f58b98c9343ffbaa7d94f07e9024b3ca/linux-gcc-normal-1/libimgui.a
```

## 2. 🔒 Locked versions

A branch moves: built today and in a month, `docking` is not the same code. So MyMakefile resolves a `VERSION` once to a commit, and writes it in `external/versions.lock` (`EXTERNAL_LOCK`):

```makefile
# Commits of the third parties of MyProject, written by MyMakefile:
# commit this file. 'make update-externals' moves them to the last commit of
# their VERSION.

imgui.LOCKED_REF := docking
imgui.LOCKED := d682dc41f58b98c9343ffbaa7d94f07e9024b3ca
implot.LOCKED_REF := HEAD
implot.LOCKED := 72de27832d1e6299bcc930ce01073d899d420392
```

**Commit this file.** Everybody who clones the project, and the CI, then builds the same commits, without asking the network which commit a branch is on.

| You want to | Do |
|-------------|----|
| move the third parties to the last commit of their `VERSION` | `make update-externals`, then commit `versions.lock` |
| change the `VERSION` of one | edit it: its lock no longer matches and is resolved again |
| pin a commit for ever | `imgui.COMMIT := <sha1>` |

## 3. 🗄️ The shared cache

The sources of a third party are fetched once per commit, and compiled once per configuration and flags, in a cache shared by all your projects:

| System | Cache (`MYMAKEFILE_CACHE`) |
|--------|----------------------------|
| Linux, macOS | `$XDG_CACHE_HOME/mymakefile`, else `~/.cache/mymakefile` |
| Windows | `%LOCALAPPDATA%/mymakefile` |

```text
~/.cache/mymakefile/
├── sources/imgui/d682dc41.../               the sources of one commit
└── builds/imgui/d682dc41.../linux-gcc-normal-1/  its objects and library, for one configuration
```

The number after the configuration tells apart the sets of flags: a project building Dear ImGui with other flags gets `linux-gcc-normal-2`.

Two projects using the same commit of Dear ImGui compile it once. A third party in the cache is never modified: fix it upstream, or use a local copy (§4).

| Goal or variable | Does |
|------------------|------|
| `make cache-info` | Prints where each third party is |
| `make cache-clean` | Removes the cache, for all the projects |
| `EXTERNAL_CACHE=` (empty) | Clones the third parties in `external/` of the project instead, as MyMakefile 2 did. Needed when the code includes a third party by its folder (`"imgui/imgui.h"`, with `imgui.PUBLIC_INCLUDES := ..`) |

The fetch only takes the commit (`git fetch --depth 1`); a server refusing it gets a full clone.

## 4. 📁 A local copy, an archive

`PATH` uses a folder of yours, never fetched: to work on a third party and on your project at the same time.

```makefile
imgui.PATH := ../imgui
```

`URL` downloads an archive (`.tar.gz`, `.tar.xz`, `.zip`) with curl, once in the cache. `SHA256` refuses it if it is not the expected one; `SUBDIR` is the folder of the archive to use. With `LIBRARIES`, an archive of binaries is used without compiling anything:

```makefile
TARGETS += mujoco
mujoco.URL := https://github.com/google-deepmind/mujoco/releases/download/3.3.0/mujoco-3.3.0-linux-x86_64.tar.gz
mujoco.SHA256 := <sha256>
mujoco.SUBDIR := mujoco-3.3.0
mujoco.PUBLIC_INCLUDES := include
mujoco.LIBRARIES := lib/libmujoco.so      # its folder goes in the rpath
```

`LIBRARIES` also works without `URL`, for libraries built elsewhere, relative to the folder of the target.

## 5. 🏗️ Projects built by CMake

`TYPE := cmake`: the third party is configured, built and installed by its own CMake, in its own prefix in the cache, before the targets using it are compiled.

```makefile
TARGETS += zlib
zlib.GIT := https://github.com/madler/zlib.git
zlib.VERSION := v1.3.1
zlib.TYPE := cmake
zlib.CMAKE_ARGS := -DZLIB_BUILD_EXAMPLES=OFF
zlib.LIBRARIES := z
```

| Variable | Meaning |
|----------|---------|
| `LIBRARIES` | What to link: `z` for `libz.a` |
| `PUBLIC_INCLUDES` | Relative to the prefix: `include` by default |
| `CMAKE_ARGS` | Given to the configuration |

MyMakefile gives CMake the compilers, ccache, the build type of the compilation mode (`Debug`, `RelWithDebInfo`, `Release`, `MinSizeRel`), position independent code and static libraries (`BUILD_SHARED_LIBS=OFF`). With Emscripten, it runs `emcmake cmake`.

## 6. 🧩 Projects built by MyMakefile

A third party built by MyMakefile 3 declares its libraries in `.mk` files. `MAKEFILES` lists the ones to read once it is fetched: its targets join the project, with their paths relative to their files, and are compiled with the toolchain and the mode of the project.

```makefile
TARGETS += BlackThorn TimedPetriNetEditor myapp
BlackThorn.GIT := https://github.com/Lecrapouille/BlackThorn.git
BlackThorn.MAKEFILES := BlackThorn.mk external/external.mk
TimedPetriNetEditor.GIT := https://github.com/Lecrapouille/TimedPetriNetEditor.git
TimedPetriNetEditor.MAKEFILES := TimedPetriNet.mk external/external.mk
myapp.DEPENDS := blackthorn TimedPetriRuntime
```

- Their third parties are fetched in turn, at the commits of the `external/versions.lock` of the embedded project, and locked in the one of the project.
- A target the project declares too (Dear ImGui, used by several of them) keeps the declaration of the project: one copy in the final binary.
- Their targets are third parties: no warnings, not installed, built only when a target of the project depends on them.
- The options of their `.mk` files (`?=`) can be set by the project or on the command line.
- `make BlackThorn.PATH=../BlackThorn` builds with a local copy, to work on both at once.

A library meant to be embedded declares itself in a `.mk` file of its own, read by its `Makefile` through `SUBMAKEFILES`, and its options with `?=` in that file. [RobotIK](https://github.com/Lecrapouille/RobotIK) embeds Compages, BlackThorn and TimedPetriNetEditor this way.

## 7. 🖥️ Packages of the system

A library installed on the system and known to pkg-config is given by `PKG_CONFIG`, with the names of its `.pc` files:

```makefile
myapp.PKG_CONFIG := glfw3 glew
```

The flags pkg-config gives go to the target and to the targets depending on it. A missing package stops the build of the target needing it, with its name:

```text
MyMakefile: myapp needs the packages 'glfw3', unknown to pkg-config: install them or set PKG_CONFIG_PATH.  Stop.
```

`PKG_CONFIG_STATIC=1` asks pkg-config the flags of a static link (`--static`). `PKG_CONFIG` (not prefixed by a target) is the command, `pkg-config` by default, `x86_64-w64-mingw32-pkg-config` for the MinGW cross compiler. With ExaequOS, the missing packages are installed by its package manager ([chapter 8](08-Platforms.md)).

## 8. 🐞 Debugging helpers

In debug mode, as MyMakefile 2 did, MyMakefile adds two third parties to your targets:

| Third party | For | Turn it off |
|-------------|-----|-------------|
| [backward-cpp](https://github.com/bombela/backward-cpp) | The stack of a crash, with files and lines. Linux, when `libdw` is installed (`libdw-dev`); linked in your executables | `BACKWARD=0` |
| [dbg-macro](https://github.com/sharkdp/dbg-macro) | `dbg(x)` prints an expression, its value and its line | `DBG_MACRO=0` |

They are not used with the sanitizers that replace the handling of crashes, nor with `GPROF=1`.

---

Next: [5. Compilation](05-Compilation.md) — modes, toolchains and flags.
