# Scan Project and Generate CLAUDE.md

Analyze the current project and generate a comprehensive CLAUDE.md file with project documentation.

## Execution Steps

1. **Detect Project Type**
   - Check for language indicators:
     - `package.json` or `*.js/ts` → JavaScript/TypeScript
     - `requirements.txt`, `pyproject.toml`, or `*.py` → Python
     - `Cargo.toml` or `*.rs` → Rust
     - `go.mod` or `*.go` → Go
     - `CMakeLists.txt`, `Makefile`, or `*.c/*.cpp` → C/C++
     - `pom.xml`, `build.gradle`, or `*.java` → Java
   - Identify build systems and package managers
   - Note framework indicators (React, Django, ROS, etc.)

2. **Analyze Project Structure**
   - Map directory tree (src/, include/, lib/, tests/, docs/, etc.)
   - Identify key organizational patterns
   - Locate configuration directories
   - Find data/resource directories

3. **Extract Functional Information**
   - Read and parse README.md if it exists
   - Examine main entry points (main.py, index.js, main.cpp, etc.)
   - Review package/project metadata files
   - Check docstrings/comments in primary files
   - Identify core functionality from file names and structure

4. **Document System Architecture**
   - Identify major components/modules
   - Note communication patterns (if observable)
   - Document data flow (if evident from structure)
   - Highlight key subsystems

5. **Catalog Dependencies**
   - List from package manifests (requirements.txt, package.json, Cargo.toml, etc.)
   - Note build dependencies
   - Identify system requirements if documented

6. **Extract Build & Run Instructions**
   - Check README for setup/build/run commands
   - Parse Makefile, CMakeLists.txt, package.json scripts
   - Note any setup.sh or install scripts
   - Document environment variables or configuration needs

7. **Identify Entry Points**
   - Main executables or scripts
   - CLI entry points
   - Server/daemon start commands
   - Test runners

8. **Generate CLAUDE.md**
   - Present findings to user in structured format
   - Get user approval before creating the file
   - Create CLAUDE.md in project root with all gathered information

## CLAUDE.md Structure

```markdown
# [Project Name]

## Project Overview
- **Purpose**: [What this project does]
- **Primary Languages**: [Language breakdown]
- **Project Type**: [Web app, library, CLI tool, system software, etc.]

## Functional Summary
[What the project accomplishes, key features, core problems it solves]

## System Architecture
[High-level component overview, how major pieces interact]

## Directory Structure
```
[Annotated tree structure showing key directories and their purposes]
```

## Dependencies & Build System
- **Build Tools**: [make, cmake, npm, cargo, etc.]
- **Key Dependencies**: [Major libraries and frameworks]
- **Package Manifests**: [List of dependency files]

## How to Build & Run
### Setup
[Environment setup, prerequisites]

### Build
[Build commands]

### Run
[Execution commands]

### Configuration
[Config files, environment variables]

## Entry Points
- [List of main executables, scripts, CLI commands]

## Additional Notes
[Any other relevant information discovered during scan]
```

## Important Notes
- Always present the generated content to the user before creating CLAUDE.md
- Follow the guideline: do not create files without user approval
- Be thorough but concise in documentation
- If information cannot be determined, note it as "Not found" rather than guessing
