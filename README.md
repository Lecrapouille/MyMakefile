# MyMakefile

[MyMakefile](https://github.com/Lecrapouille/MyMakefile) is a build system based on GNU Make for C++ projects. It serves as an alternative to CMake for medium-sized projects, eliminating the need to write complex Makefile rules from scratch.

## 🤔 Why MyMakefile?

While CMake is a popular choice, MyMakefile offers several advantages for smaller projects:

- **Simplicity**: No complex syntax or obscure function names
- **Transparency**: Direct control over the build process
- **Efficiency**: Smaller, more readable Makefiles
- **Modern Features**: All the tools you need without the complexity

## 🌟 MyMakefile Goals

- Encapsulate all complex Makefile rules in two files that you can include in your project, handling:
  - File compilation
  - Application bundling (including macOS bundles)
  - Shared/static library management
  - System installation
  - Documentation generation
  - Compilation flag management
  - pkg-config integration
  - RPM creation
- Define your project structure in just a few lines of Makefile syntax
- Let MyMakefile handle all the complex build rules for you

## 🌐 Cross-Platform Support

- 🐧 Linux
- 🍎 macOS
- ~~🪟 Windows~~ (not yet supported)
- 🌐 [Emscripten](https://emscripten.org)
- 🧸 [ExaequOS](https://www.exaequos.com)

## 🚀 Quick Start

1. **Include MyMakefile in your project**:

```bash
# Option 1: Copy-paste
cp -r MyMakefile your-project/.makefile

# Option 2: Git submodule (recommended)
git submodule add https://github.com/Lecrapouille/MyMakefile.git .makefile
```

The dot prefix allows you to hide MyMakefile in your project, but it's not mandatory.

2. **Create your Makefile**:

```makefile
# Relative location of your project root folder P and MyMakefiles folder M
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

# Include MyMakefiles project file after your project definition
include $(M)/project/Makefile

# Define what and how to compile your target
INCLUDES := $(P)/include $(P)/src
VPATH := $(P)/src
DEFINES :=
SRC_FILES += src/main.cpp

# Include MyMakefiles rules file after your project configuration
include $(M)/rules/Makefile

# Optionally: add your custom Makefile rules here
```

3. **Build your project**:

```bash
make help         # Show all available options
make              # Start compilation
make install      # Install your project on your system
```

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

## 📋 Prerequisites

- 🐚 Bash interpreter (MyMakefile requires some bash assistance)
- 🛠️ Optional tools, called by MyMakefile:
  - `g++` or `clang++` (for compilation)
  - `gcovr` (for code coverage)
  - `doxygen` (for documentation)

## 🔧 Compiling for ExaequOS

[ExaequOS](https://www.exaequos.com) is a fork of [Emscripten](https://emscripten.org).
MyMakefile supports compilation for both platforms.

1. Install the ExaequOS Docker image:

```bash
# Follow instructions at https://github.com/Lecrapouille/docker-exa
```

2. Run the ExaequOS Docker image against your project folder.

3. Simply run `make` - your project will compile like a native Linux application.

4. After compilation, run `make install`

5. Open https://www.exaequos.com/ in your browser.

6. In Havoc (ExaequOS console), run:

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
