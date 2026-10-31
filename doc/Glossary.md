# 🔤 Glossary

| Word | Meaning | Chapter |
|------|---------|---------|
| **Build folder** | The folder of one configuration: `build/linux-gcc-normal`. Variable `BUILD` | [5](05-Compilation.md) |
| **Cache** | `~/.cache/mymakefile`: the sources and builds of the third parties, shared by all your projects | [4](04-Third-Parties.md) |
| **Configuration** | A system, a toolchain, a compilation mode and an instrumentation: each has its build folder | [5](05-Compilation.md) |
| **Compilation mode** | `debug`, `normal`, `release`...: the optimizations and the debugging information | [5](05-Compilation.md) |
| **Dependency** | A target named in the `DEPENDS` of another one, which gets its public includes, macros, packages and libraries | [3](03-Targets.md) |
| **Goal** | What is given to `make`: `make check`, `make run-myapp` | [6](06-Goals.md) |
| **Lock file** | `external/versions.lock`: the commit of each third party. Commit it | [4](04-Third-Parties.md) |
| **Public** | Given to the targets depending on this one: `PUBLIC_INCLUDES`, `PUBLIC_DEFINES`, and always `PKG_CONFIG` and `LIBS` | [3](03-Targets.md) |
| **Sanitizer** | Instrumentation of the compiler finding memory errors, undefined behavior, data races | [5](05-Compilation.md) |
| **Submakefile** | A `.mk` file listed in `SUBMAKEFILES`, declaring targets next to their sources, with paths relative to it | [3](03-Targets.md) |
| **Target** | A name in `TARGETS` and its variables `name.VARIABLE`: an application, a test, a library, a third party | [3](03-Targets.md) |
| **Third party** | A target with `GIT`, `URL` or `PATH`: code you do not write, fetched and built by MyMakefile | [4](04-Third-Parties.md) |
| **Toolchain** | The compilers and tools: `gcc`, `clang`, `mingw`, `emscripten`, `msvc` | [8](08-Platforms.md) |
