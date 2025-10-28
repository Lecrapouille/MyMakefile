# MyMakefile

[MyMakefile](https://github.com/Lecrapouille/MyMakefile) is a build system based on GNU Make for C++ projects. It eliminates the need to write complex Makefile rules from scratch by offering plenty of rules and macros.

**Note:** I no longer develop in C but MyMakefile should also work.

## 🤔 Why MyMakefile?

While CMake is a popular choice, MyMakefile serves as an alternative to CMake for medium-sized projects. Indeed, it offers several advantages for smaller C++ projects:

- **Simplicity**: No complex CMake syntax or its obscure function names.
- **Efficiency**: Smaller code you have to write, more readable Makefiles.
- **Modern Features**: Call engineer tools you usually need without the complexity.

**Limitations:** MyMakefile does not support multiple targets in a single Makefile file, but you can build a project that generates multiple libraries, standalone applications, and demos.

## 🌟 MyMakefile Goals

- Encapsulate all complex Makefile rules in two files that you can include in your project, handling:
  - C++ file compilation
  - A small manifest file for downloading third-party libraries
  - Compilation flag management
  - Application bundling (including macOS bundles)
  - Shared/static library creation (contrary to CMake, both are created)
  - Installation on your system (header files, doc, libraries)
  - Creation/installation of pkg-config files
  - Documentation generation (Doxygen)
  - Unit tests and code coverage
  - RPM creation
  - Code formatting (clang-format integration)
  - Static analysis (cppcheck integration)
- Define your project structure in just a few lines of Makefile syntax.
- Let MyMakefile handle all the complex build rules for you.

## 🌐 Cross-Platform Support

- 🐧 Linux
- 🍎 Mac OS
- ~~🪟 Windows~~ (not yet supported)
- 🌐 [Emscripten](https://emscripten.org)
- 🧸 [ExaequOS](https://www.exaequos.com)

## 🚀 Quick Start

1. **Include MyMakefile in your project**:

Either you copy directly this repo in your project or better to include it as submodule.

```bash
# Option 1: Copy-paste
cp -r MyMakefile your-project/.makefile

# Option 2: Git submodule (recommended)
git submodule add https://github.com/Lecrapouille/MyMakefile.git .makefile
```

The dot prefix allows you to hide MyMakefile in your project, but it's not mandatory. The folder name is up to you.

2. **Create your first Makefile**:

```makefile
# Relative location of your project root folder P and MyMakefile folder M
P := .
M := $(P)/.makefile

# Your minimal project definition
PROJECT_NAME := my-project
PROJECT_VERSION := 1.0.0
TARGET_NAME := my-app
TARGET_DESCRIPTION := brief explanation of the target

# Optional definitions
COMPILATION_MODE := release
CXX_STANDARD := --std=c++14

# Include MyMakefile project file after your project definition
include $(M)/project/Makefile

# Define what and how to compile your target
INCLUDES := $(P)/include $(P)/src
VPATH := $(P)/src
DEFINES :=
SRC_FILES += src/main.cpp
# For compiling a library, replace SRC_FILES with LIB_FILES

# Include MyMakefile rules file after your project configuration
include $(M)/rules/Makefile

# Optionally: add your custom Makefile rules here
```

First, you must define macros P and M. P indicates the relative path to the root project. M indicates where to find the MyMakefile folder.

The project definition is mandatory and allows you to define your project name and the target name (which is either a stand-alone application or library). You have to define a description to your target and a version to your project.

Compilation definitions are up to you: release, debug, unit test, and the C++ standard.

You must include the two MyMakefile files at the correct location in your Makefile. One sets variables for your project and the other defines Makefile rules. As a consequence, order and position matter.

Finally, you can give options to your compiler for finding C++ sources and header files, define project macros and the list of C++ files to compile.

3. **Build your project**:

```bash
make help                     # Show all available options
make [OPTIONS1]               # Start compilation
sudo make install [OPTIONS2]  # Install your project on your system
```

Like traditional makefile you can pass OPTIONS1 to makefile, for example which compiler you prefer (CXX). OPTIONS define where to install your project on your system.

## 📚 Projects Using MyMakefile

Here are some of my projects that use MyMakefile instead of CMake:

- 🎨 [TimedPetriNetEditor](https://github.com/Lecrapouille/TimedPetriNetEditor)
- 🎮 [OpenGlassBox](https://github.com/Lecrapouille/OpenGlassBox)
- 📦 [Zipper](https://github.com/Lecrapouille/zipper)
- 🛣️ [Highway](https://github.com/Lecrapouille/Highway)
- 🎮 [OpenGLCppWrapper](https://github.com/Lecrapouille/OpenGLCppWrapper)
- 🔬 [SimTaDyn](https://github.com/Lecrapouille/SimTaDyn)
- 🧮 [SimForth](https://github.com/Lecrapouille/SimForth)
- ♟️ [ChessNeuNeu](https://github.com/Lecrapouille/ChessNeuNeu)
- 🔗 [LinkAgainstMyLibs](https://github.com/Lecrapouille/LinkAgainstMyLibs)

**Note:** They may not refer to the HEAD of MyMakefile and may use old syntax.

## 📋 Prerequisites

- 🐚 Bash interpreter (MyMakefile requires some bash assistance)
- 🛠️ Optional tools, called by MyMakefile:
  - `g++` or `clang++` (for compilation).
  - `gcovr` (for code coverage).
  - `doxygen` (for documentation).
  - `git` (for downloading third-parties).

## 🔧 Compiling for MacOS

By default, the behavior will compile like done with Linux. To create Bundle applications, you have to add
the following code:

```makefile
ifeq ($(OS),Darwin)
BUILD_MACOS_APP_BUNDLE := 1
APPLE_IDENTIFIER := lecrapouille
MACOS_BUNDLE_ICON := <your path>/<your icon name>.icns
endif
```

## 🔧 Compiling for Emscripten

Nothing to do, follow the Emscripten documentation for compiling a project. MyMakefile shall detect it and compile for Emscripten.

## 🔧 Compiling for ExaequOS

[ExaequOS](https://www.exaequos.com) is a fork of [Emscripten](https://emscripten.org) and better alternative (POSIX compliant). MyMakefile also supports the compilation for this platform.

- Install the ExaequOS Docker image:

```bash
# Follow instructions at https://github.com/Lecrapouille/docker-exa
```

- Run the ExaequOS Docker image against your project folder.
- Simply run `make` - your project will compile like a native Linux application.
- After compilation, run `make install`
- Open [https://www.exaequos.com/](https://www.exaequos.com) in your browser.
- In Havoc (ExaequOS console), run:

```bash
/media/localhost/<your-application>
```

## 📦 Compiling to RPM

```bash
make rpm
```

## 📖 Documentation

- For detailed API documentation, see [API.md](doc/API.md).

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.
