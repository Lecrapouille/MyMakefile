# 🤖 9. Continuous integration

**What you will learn**

- the goals MyMakefile gives a CI;
- a GitHub Actions workflow building and testing on Linux, macOS and Windows;
- the caches of the third parties and of ccache;
- the artifacts of a build.

**Prerequisites**: [chapter 6](06-Goals.md), [chapter 7](07-Installation.md), [chapter 8](08-Platforms.md).

---

## 1. 🎯 What MyMakefile gives a CI

A CI should run the commands a developer runs. MyMakefile gives it what it would otherwise script:

| Goal | For |
|------|-----|
| `ci` | Everything to check, in one command: `CI_GOALS` (`all check` by default) |
| `dist` | The artifacts: what `make install` installs, plus `LICENSE`, `README`, `VERSION`, in a folder and its `.tar.gz` ([chapter 7](07-Installation.md)) |
| `ci-info` | `key=value` lines, for `$GITHUB_OUTPUT` |
| `print-<VAR>` | One variable: `make -s print-PROJECT_VERSION` |
| `check-format` | Fails on code not formatted |

`ci-info` on [demo 02](demos/02/):

```sh
$ make -s ci-info
name=TutorialMyMakefile
version=0.1.0
os=linux
arch=x86_64
toolchain=gcc
mode=normal
build=build/linux-gcc-normal
cache=/home/qq/.cache/mymakefile
dist_name=TutorialMyMakefile-0.1.0-linux-x86_64
dist_dir=build/dist/TutorialMyMakefile-0.1.0-linux-x86_64
dist_archive=build/dist/TutorialMyMakefile-0.1.0-linux-x86_64.tar.gz
```

A project adds goals to `ci` before the `include`: `CI_GOALS := all check check-format`.

## 2. 🧰 The action `setup`

The action `.github/actions/setup` of MyMakefile prepares a runner of GitHub for it:

- installs GNU Make 4, ccache and pkg-config, on Linux (apt), macOS (Homebrew) and Windows (MSYS2), plus the packages of the project;
- installs Emscripten if asked;
- restores the caches of the third parties and of ccache;
- gives the command of make of the runner: `make`, `gmake` or `mingw32-make`, and the shell of the next steps.

| Input | Meaning |
|-------|---------|
| `apt` | Packages of Ubuntu |
| `brew` | Packages of Homebrew |
| `msys2` | Packages of MSYS2 (MINGW64) |
| `emscripten` | `true` to install Emscripten |
| `lock` | The file of the versions of the third parties, key of their cache: `external/versions.lock` by default |

| Output | Meaning |
|--------|---------|
| `make` | The command of GNU Make on this runner |
| `shell` | The shell of the next steps: `bash`, or `msys2 {0}` on Windows |

## 3. 📝 A workflow for three systems

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            shell: bash
          - os: macos-latest
            shell: bash
          - os: windows-latest
            shell: msys2 {0}
    runs-on: ${{ matrix.os }}
    defaults:
      run:
        shell: ${{ matrix.shell }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - id: mymakefile
        uses: ./.makefile/.github/actions/setup
        with:
          apt: libglfw3-dev libglew-dev
          brew: glfw glew
          msys2: mingw-w64-x86_64-glfw mingw-w64-x86_64-glew
      - id: info
        run: ${{ steps.mymakefile.outputs.make }} -s ci-info >> "$GITHUB_OUTPUT"
      - run: ${{ steps.mymakefile.outputs.make }} ci
      - run: ${{ steps.mymakefile.outputs.make }} dist
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.info.outputs.dist_name }}
          path: ${{ steps.info.outputs.dist_dir }}/
```

For a web version, a job installs Emscripten (`emscripten: true`), runs `emmake make`, and publishes `bin/<name>.*` on GitHub Pages ([chapter 7](07-Installation.md)). For ExaequOS, a job runs `make` in the docker image `lecrapouille/exaequos:light` ([chapter 8](08-Platforms.md)).

## 4. 🗄️ Caches

| Cache | Key | Saves |
|-------|-----|-------|
| `~/.cache/mymakefile` (`%LOCALAPPDATA%/mymakefile` on Windows) | `hashFiles('external/versions.lock')` | The fetch and the build of the third parties: they change only with the lock file |
| ccache | the commit, restored from the last one | The objects of the project already compiled |

The action `setup` restores both. Without it, cache `~/.cache/mymakefile` with the key of the lock file.

## 5. 🎨 Logs

Colors are off when the output is not a terminal, as in a CI. GitHub shows them: `COLORS=1` turns them on (the action `setup` sets it). `NO_COLOR` or `COLORS=0` turns them off.

A package missing from pkg-config stops the build of the target needing it, with its name: the log says which package to add to `apt`, `brew` or `msys2`.

---

Next: [10. Migrating from version 2](10-Migrating-From-Version-2.md) — or the [reference](11-Reference.md).
