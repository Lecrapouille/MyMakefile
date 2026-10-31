# 📚 MyMakefile documentation

This documentation goes step by step: each chapter uses the words of the chapters before it. If you never used MyMakefile, start at chapter 1 and read in order; if you come from MyMakefile 2, read [chapter 10](10-Migrating-From-Version-2.md) first; if you look for one variable, go to the [reference](11-Reference.md).

Every output shown in these pages was printed by `make`, most of them on the [demos](demos/README.md), not written by hand.

## 🧭 Part I — Discover

| # | Chapter | You will learn |
|---|---------|----------------|
| 1 | 🧩 [Introduction](01-Introduction.md) | What MyMakefile is, what version 3 changes, what it needs |
| 2 | 🚀 [Getting started](02-Getting-Started.md) | Add MyMakefile to a project, build and run an application, its tests and its libraries |

## 🎯 Part II — Describe a project

| # | Chapter | You will learn |
|---|---------|----------------|
| 3 | 🎯 [Targets](03-Targets.md) | Declare applications, libraries and tests, next to their sources; their dependencies; `project_info.hpp`; generated sources |
| 4 | 📦 [Third parties](04-Third-Parties.md) | Libraries fetched from git or as archives, locked to a commit, shared by all your projects; CMake projects; pkg-config packages |

## 🔨 Part III — Build

| # | Chapter | You will learn |
|---|---------|----------------|
| 5 | 🔨 [Compilation](05-Compilation.md) | Modes, toolchains, sanitizers, the flags MyMakefile gives, and when it rebuilds |
| 6 | 🧰 [Goals](06-Goals.md) | Run, test, cover, debug, format, lint, document, profile, clean |

## 🚚 Part IV — Ship

| # | Chapter | You will learn |
|---|---------|----------------|
| 7 | 🚚 [Installation](07-Installation.md) | `make install`, a safe `make uninstall`, headers, pkg-config files, archives of the binaries |
| 8 | 🖥️ [Platforms](08-Platforms.md) | Linux, macOS, Windows (MSYS2, cross compiler, MSVC), Emscripten and ExaequOS |
| 9 | 🤖 [Continuous integration](09-Continuous-Integration.md) | A GitHub Actions workflow for three systems, its caches and its artifacts |

## 📖 Part V — Reference

| # | Chapter | Contents |
|---|---------|----------|
| 10 | 🔄 [Migrating from version 2](10-Migrating-From-Version-2.md) | The variables, goals and habits of MyMakefile 2 and what replaces them |
| 11 | 📖 [Reference](11-Reference.md) | Every variable of a target, every option, every goal |
| — | 🔤 [Glossary](Glossary.md) | The words of these pages |

## 🗺️ Paths through the documentation

- **"I want to build something, now."** → [2](02-Getting-Started.md), then the [demos](demos/README.md).
- **"My project has a library, an application and tests."** → [2](02-Getting-Started.md), [3](03-Targets.md).
- **"I use Dear ImGui, zlib, MuJoCo..."** → [4](04-Third-Parties.md).
- **"My program crashes."** → [5](05-Compilation.md) (debug mode, sanitizers), [6](06-Goals.md) (`gdb-<target>`, `memcheck`).
- **"I want my project on Windows and in a browser."** → [8](08-Platforms.md), [9](09-Continuous-Integration.md).
- **"I come from MyMakefile 2."** → [10](10-Migrating-From-Version-2.md).
