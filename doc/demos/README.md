# 🧪 Demos

Each demo is a small project using `../../../MyMakefile.mk` (a project of yours includes `.makefile/MyMakefile.mk`). Run `make` in its folder; the build goes to `build/linux-gcc-<mode>/` on Linux with gcc. [Chapter 2](../02-Getting-Started.md) walks through them.

| Demo | Shows | Try | Read |
|------|-------|-----|------|
| [00](00/) | A single application, with the generated `project_info.hpp` | `make run-HelloWorld00` | [2](../02-Getting-Started.md), [3](../03-Targets.md) |
| [01](01/) | An application, and its unit tests declared in `tests/tests.mk`; a default compilation mode | `make check` | [2](../02-Getting-Started.md), [5](../05-Compilation.md) |
| [02](02/) | An application linked against a static library and a static and shared library, each declared next to its sources | `make list-targets`, `make run-HelloWorld02`, `make install DESTDIR=/tmp/inst` | [2](../02-Getting-Started.md), [3](../03-Targets.md), [7](../07-Installation.md) |
