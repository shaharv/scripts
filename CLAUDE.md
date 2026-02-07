# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A collection of utility scripts for development environments, organized by domain:

- **cplus/** - C++ development tools: build (cmake, gcc, llvm), linting (cppcheck, clang-tidy), formatting (clang-format)
- **jenkins/** - Jenkins CI/CD utilities: workspace validation, Kubernetes pod management, Jenkinsfile validation
- **linux/** - Linux system utilities: distro detection, network polling, memory analysis, core dumps
- **ml/** - Machine learning examples: attention mechanism implementation and visualization
- **python/** - Python text processing utilities with shared utils module
- **qemu/** - QEMU virtual machine lifecycle management
- **spark/** - Apache Spark cluster management and TPC-DS benchmarking

## Linting

**Python:**
```bash
pylint --rcfile=python/.pylintrc python/*.py
```

**Jenkinsfile/Groovy validation:**
```bash
groovy jenkins/validate.groovy [path/to/Jenkinsfile]
```

**C++ (clang-tidy):**
```bash
ROOT_DIR=/path/to/project BUILD_DIR=/path/to/build cplus/tidy.sh
cplus/tidy.sh --file=myfile.cpp   # single file
cplus/tidy.sh --git-diff          # only changed files
cplus/tidy.sh --fix               # auto-fix issues
```

**C++ (clang-format):**
```bash
cplus/format.sh --method=diff     # check formatting
cplus/format.sh --method=in-place # apply formatting
cplus/format.sh --git-diff        # only changed files
```

## Key Patterns

**Bash scripts:** Use strict mode (`set -euo pipefail`), environment variable configuration with defaults (`${VAR:-default}`), and include usage functions.

**Shared utilities:**
- `linux/linux_distro_detect.sh` - Source this to get `$LINUX_DISTRO`, `$INSTALL_CMD`, `$PACKAGE_EXT` etc.
- `qemu/qemu_common.sh` - Common QEMU SSH/SCP commands and timeouts
- `python/utils.py` - File operations, regex validation, config parsing, process execution
- `jenkins/jenkins_utils.groovy` - Workspace validation helpers

**Environment variables for C++ tools:**
- `ROOT_DIR` - Project root (for .clang-tidy, .git)
- `BUILD_DIR` - Build directory (for compile_commands.json)
- `SRC_DIR` - Source directory to analyze
- `TARGET_BRANCH` - Base branch for git diff operations (default: origin/master)
