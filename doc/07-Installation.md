# 🚚 7. Installation

**What you will learn**

- install a project, and where its files go;
- uninstall it without risk for the other files of the system;
- choose the headers a library installs;
- use a library from its build folder, or from an archive, with pkg-config;
- make an archive of the binaries;
- install an application built for a browser.

**Prerequisites**: [chapter 3](03-Targets.md).

---

## 1. 📥 `make install`

`make install` builds the project, then copies in `DESTDIR` + `PREFIX`:

| What | Where (default) |
|------|-----------------|
| The executables (not the tests), and the macOS bundles | `BINDIR` (`$(PREFIX)/bin`) |
| The libraries, with the links of the shared ones | `LIBDIR` (`$(PREFIX)/lib`) |
| Their headers (§3) and their `project_info.hpp` | `INCLUDEDIR` (`$(PREFIX)/include`) |
| Their pkg-config files | `PKGLIBDIR` (`$(LIBDIR)/pkgconfig`) |
| The `DATA` folders of the targets | `PROJECT_DATADIR` (`$(PREFIX)/share/<project>`) |
| `LICENSE*`, `README*`, `AUTHORS`, `ChangeLog`... (`DIST_FILES`) | `DOCDIR` (`$(PREFIX)/share/doc/<project>`) |

`PREFIX` is `/usr/local` by default. `t.INSTALL := no` keeps a target out.

[Demo 02](demos/02/) installed in a folder of test:

```sh
$ make install DESTDIR=/tmp/inst
*** Installing: TutorialMyMakefile => /tmp/inst/usr/local
$ find /tmp/inst | sort
/tmp/inst/usr/local/bin/HelloWorld02
/tmp/inst/usr/local/include/bar.hpp
/tmp/inst/usr/local/include/foo.hpp
/tmp/inst/usr/local/lib/libbar.a
/tmp/inst/usr/local/lib/libbar.so
/tmp/inst/usr/local/lib/libbar.so.0
/tmp/inst/usr/local/lib/libbar.so.0.1.0
/tmp/inst/usr/local/lib/libfoo.a
/tmp/inst/usr/local/lib/pkgconfig/bar.pc
/tmp/inst/usr/local/lib/pkgconfig/foo.pc
```

It works with sh and with `cmd.exe`. On Windows with MSYS2, the DLLs of MSYS2 an executable needs are copied beside it, unless it is linked with `-static` (`COPY_RUNTIME_DLLS=0` to do without).

`INSTALL_VERSIONED=1` keeps several versions side by side, as MyMakefile 2 did: `include/<project>/<version>/`, `share/<project>/<version>/`, `bin/<name>-<version>` and `<name>-<version>.pc`, with links without the version.

## 2. 🗑️ `make uninstall`

A wrong variable must not remove the files of the user. So `make uninstall` removes only what exists among what `make install` writes, and:

- prints the list, then asks `Remove these files? [y/N]`. `YES=1` does not ask; without a terminal, as in a CI, the answer is no;
- only prints it with `DRY_RUN=1`, or with `make uninstall-dry-run`;
- refuses a relative `PREFIX`, `/` or `$HOME`, a path outside of the installation folders or being one of them, and a folder removed with its content whose name is not the one of the project;
- removes the folders of the headers only when they are empty.

```sh
$ make uninstall-dry-run DESTDIR=/tmp/inst
*** Would remove: TutorialMyMakefile (10 files, 0 directories)

  /tmp/inst/usr/local/bin/HelloWorld02
  /tmp/inst/usr/local/include/bar.hpp
  ...
```

## 3. 📑 The headers of a library

The headers a library installs are:

- **A**: the headers of its `PUBLIC_INCLUDES` folders;
- **B**: plus its `PUBLIC_HEADERS`, files or patterns anywhere;
- less its `PRIVATE_HEADERS`.

Each one is installed at the path the code includes it with: relative to the deepest include folder of the library holding it. Both ways can be mixed:

```makefile
mylib.PUBLIC_INCLUDES := include          # include/MyLib/Api.hpp -> MyLib/Api.hpp
mylib.INCLUDES := src
mylib.PUBLIC_HEADERS := src/**/*.hpp      # src/MyLib/Tool.hpp    -> MyLib/Tool.hpp
mylib.PRIVATE_HEADERS := src/MyLib/detail/*.hpp
```

## 4. 🔌 pkg-config files

Each library has two pkg-config files:

- **in the build folder**, `build/<configuration>/lib/pkgconfig/`, pointing to the sources and to the build. With `PKG_CONFIG_PATH=build/linux-gcc-normal/lib/pkgconfig`, another project uses your library without installing it;
- **installed**, finding its prefix from its own place (`prefix=${pcfiledir}/../..`), so that it works wherever the files are copied or unpacked.

```text
prefix=${pcfiledir}/../..
libdir=${prefix}/lib
includedir=${prefix}/include

Name: bar
Description: TutorialMyMakefile
Version: 0.1.0
Libs: -L${libdir} -lbar
Cflags: -I${includedir}
```

The `PKG_CONFIG` packages of a library go to its `Requires.private`, the libraries of the project it depends on too, and its `LIBS` to `Libs.private`.

A third party is not installed. An installed library depending on one would need it: put it in the library with `MERGE` ([chapter 3](03-Targets.md)), as MyMakefile 2 did, or make warns.

## 5. 📦 `make dist`

`make dist` gathers what `make install` would install, in the same tree but without `PREFIX`, plus the `DIST_FILES` and a `VERSION` file, in a folder and its archive:

```text
build/dist/<project>-<version>-<os>-<arch>/
build/dist/<project>-<version>-<os>-<arch>.tar.gz
```

The pkg-config files find their prefix, so the archive works where it is unpacked: it is the artifact of a CI ([chapter 9](09-Continuous-Integration.md)). `DIST_NAME`, `DIST_DIR` and `DIST_ARCHIVE` change the names.

## 6. 🌐 Emscripten

With Emscripten ([chapter 8](08-Platforms.md)), an application is not one file but three, written side by side by the linker: `<name>.html`, the page to open; `<name>.js`, which loads the program; `<name>.wasm`, the program. A `<name>.data` holds the files given with `--preload-file`. `make install` copies all of them in `BINDIR`. There are no shared libraries: a `shared` or `library` target installs its static library, its headers and its pkg-config file, for another project built with Emscripten.

[Demo 02](demos/02/) installed in a folder of test:

```sh
$ emmake make install DESTDIR=/tmp/inst
*** Linking: HelloWorld02 => build/emscripten-normal/bin/HelloWorld02.html
*** Installing: TutorialMyMakefile => /tmp/inst/usr/local
$ find /tmp/inst -type f | sort
/tmp/inst/usr/local/bin/HelloWorld02.html
/tmp/inst/usr/local/bin/HelloWorld02.js
/tmp/inst/usr/local/bin/HelloWorld02.wasm
/tmp/inst/usr/local/include/bar.hpp
/tmp/inst/usr/local/include/foo.hpp
/tmp/inst/usr/local/lib/libbar.a
/tmp/inst/usr/local/lib/libfoo.a
/tmp/inst/usr/local/lib/pkgconfig/bar.pc
/tmp/inst/usr/local/lib/pkgconfig/foo.pc
```

To put the application on a web server, or on GitHub Pages, copy `bin/<name>.*` of the build or of the installation: the page needs its `.js`, `.wasm` and `.data` beside it. A browser refuses to load a `.wasm` from a `file://` page: serve the folder (`emrun bin/HelloWorld02.html`, or `python3 -m http.server`).

`INSTALL_VERSIONED=1` does not rename these files: the page loads its `.js` and its `.wasm` by their names. `make dist` makes the same tree, in `build/dist/<project>-<version>-emscripten-wasm/`.

## 7. 🖥️ ExaequOS

With `EXAEQUOS`, `make install` puts each application in `media/localhost/<name>/exa/` (`EXAEQUOS_DIR`), with its `.js`, its `.wasm` and an `exa.html` page, as MyMakefile 2 did ([chapter 8](08-Platforms.md)).

---

Next: [8. Platforms](08-Platforms.md) — Linux, macOS, Windows, and the browser.
