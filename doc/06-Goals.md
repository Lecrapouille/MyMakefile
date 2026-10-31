# 🧰 6. Goals

**What you will learn**

- run, test and debug the programs of the project;
- measure the coverage of the tests, profile, check the memory;
- format, lint and document the code;
- clean what MyMakefile wrote.

**Prerequisites**: [chapter 5](05-Compilation.md).

---

A **goal** is what you give to `make`: `make check`, `make run-myapp`. Each goal below uses a tool only when you call it, and its variable gives the command: `make doc DOXYGEN=/opt/doxygen/bin/doxygen`. `make help` lists them all.

## 1. ▶️ Build and run

| Goal | Does |
|------|------|
| `all` | Builds every target but the tests (the default) |
| `<target>` | Builds one target and what it depends on |
| `run-<target>` | Builds and runs an executable: `make run-myapp ARGS="--size 3"` (default `t.ARGS`) |
| `check` | Builds and runs every `test` target, from the root of the project; stops at the first that fails |
| `rebuild` | Builds the current configuration from scratch |
| `compile-commands` | Writes `compile_commands.json`, for clangd and the editors |

## 2. 🐞 Debug

| Goal | Does | Tool |
|------|------|------|
| `gdb-<target>` | Builds an executable and runs it in the debugger, with its `ARGS` | `GDB`: gdb, lldb on macOS |
| `memcheck` | Runs the tests in valgrind: fails on a memory error or a definite leak | `VALGRIND_TOOL`, `VALGRIND_FLAGS` |

For a crash, build in debug mode: the stack is printed by backward-cpp ([chapter 4](04-Third-Parties.md)). For a memory or threading bug, a sanitizer finds it faster than valgrind ([chapter 5](05-Compilation.md)).

## 3. 📊 Measure

| Goal | Does | Writes |
|------|------|--------|
| `coverage` | Builds with `COVERAGE=1` in its own folder, runs the tests, writes the gcovr report. The third parties, the build and the folders of the tests are left out (`COVERAGE_EXCLUDE`) | `doc/code-coverage/` (`COVERAGE_DIR`): HTML and `lcov.info` |
| `gprof` | Builds with `GPROF=1`, runs `GPROF_TARGET` (the first executable by default) and writes the report of gprof | `doc/profiling/` (`PROFILE_DIR`) |
| `size-analysis` | Prints the sizes of the sections of the executables and libraries | |
| `check-harden` | Checks the hardening of the executables: PIE, RELRO, stack protector, fortify (`hardening-check` of Debian, or `checksec`) | |

## 4. ✨ Code quality

| Goal | Does | Tool |
|------|------|------|
| `format` | Formats the sources of the project and the headers beside them and in their include folders, never the third parties | `CLANG_FORMAT`, `FORMAT_FILES` |
| `check-format` | Fails when a file is not formatted: for a CI | |
| `lint` | cppcheck, target by target with their own flags | `CPPCHECK`, `CPPCHECK_FLAGS` (add `--error-exitcode=1` for a CI) |
| `tidy` | clang-tidy, with `compile_commands.json` | `CLANG_TIDY`, `CLANG_TIDY_FLAGS` (add `--warnings-as-errors='*'` for a CI) |
| `coverity` | Builds under `cov-build` and archives the result for [Coverity Scan](https://scan.coverity.com) | `COV_BUILD` |

`format` uses the `.clang-format` of the project. A project without one gets a copy of the one of MyMakefile, to commit or to edit.

## 5. 📚 Documentation

`make doc` writes the documentation of the code with Doxygen, in `doc/doxygen/` (`DOXYGEN_DIR`). MyMakefile fills its templates ([`assets/doxygen/`](../assets/doxygen/)) with the name, the version and the description of the project, its logo (`PROJECT_LOGO`), and a footer of the license found in the `LICENSE` file (GPL, LGPL, MIT, BSD, Apache). `DOXYGEN_INPUTS` lists what is documented: `README.md include src` when they exist.

## 6. 📦 Archives

| Goal | Writes |
|------|--------|
| `tarball` | The sources, third parties included, in `build/dist/<project>-<version>-src.tar.gz` |
| `rpm` | An RPM package built with `make install`, in `build/rpm/` |
| `dist` | The binaries, as `make install` would install them: [chapter 7](07-Installation.md) |

## 7. 🧹 Clean

| Goal | Removes |
|------|---------|
| `clean-<target>` | The build of one target |
| `clean` | The build of the current configuration |
| `distclean` | The builds of every configuration (`build/`) and `compile_commands.json` |
| `veryclean` | Also the clones of the third parties in `external/`, the documentation, the coverage report, the leftovers of the tools (`*.gcda`, `*.orig`, `*~`...), the `t.CLEAN` files of every target and `CLEAN_FILES` |
| `cache-clean` | The cache of the third parties, shared by all your projects |

`clean`, `distclean` and `veryclean` are double-colon rules: a project adds its own recipe with `clean::` ([chapter 3](03-Targets.md)).

## 8. ℹ️ Information

| Goal | Prints |
|------|--------|
| `help` | The goals and the options, with the values of the project |
| `list-targets` | The targets, their type and their dependencies |
| `show-flags` | The options and the flags of each target |
| `print-<VAR>` | One variable: `make -s print-PROJECT_VERSION` |
| `ci-info` | `key=value` lines for a CI ([chapter 9](09-Continuous-Integration.md)) |
| `cache-info` | Where each third party is in the cache |

`help`, `list-targets`, `print-<VAR>` and `ci-info`, like the cleaning goals, neither fetch the third parties nor call pkg-config: they answer at once, even on a fresh clone.

---

Next: [7. Installation](07-Installation.md) — install, uninstall, and archives of the binaries.
