# Demos

Each demo is a small project using `../../../MyMakefile.mk`. Run `make` in its
directory; the build goes to `build/linux-gcc-<mode>/` (on Linux with gcc).

## Demo 00

A single application, with the generated `project_info.hpp`.

```bash
make run-HelloWorld00
```

## Demo 01

An application, and its unit tests declared in `tests/tests.mk`.

```bash
make run-HelloWorld01
make check
```

## Demo 02

An application linked against two libraries, each declared next to its
sources: `src/foo/foo.mk` (static) and `src/bar/bar.mk` (static and shared).

```bash
make run-HelloWorld02
make list-targets
```
