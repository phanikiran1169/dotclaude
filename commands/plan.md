# Plan Command

Transform ideas and brainstormed concepts into detailed, actionable implementation plans with codebase awareness.

## Task

Create a clear, actionable implementation plan from user ideas or brainstormed documents, analyzing the existing codebase to ensure efficient integration without reinventing existing functionality.

## Process

### Phase 1: Input Processing

1. **Parse Arguments**

   - Extract input from $ARGUMENTS (can be a brainstorm file path or direct idea description)
   - If file path provided, use `Read` to load brainstormed content
   - Identify key features, goals, and requirements
2. **Understand Intent**

   - Use `mcp__sequential__sequentialthinking` to:
     - Break down the idea into core components
     - Identify technical requirements
     - Map features to implementation tasks
   - Extract success criteria and desired outcomes

### Phase 2: Codebase Analysis

3. **Examine Existing Code**

   - Use `mcp__serena__list_dir` to:
     - Get structured directory overview
     - Map project organization
     - Identify source folders and test locations
   - Use `mcp__serena__find_file` to:
     - Locate specific configuration files (package.json, requirements.txt, etc.)
     - Find existing feature implementations
     - Discover related components
   - Use `mcp__serena__search_for_pattern` to:
     - Search for existing implementations of similar features
     - Find related functionality that can be reused
     - Identify current architecture patterns
   - Use `mcp__serena__get_symbols_overview` to:
     - Map all functions, classes, and interfaces
     - Understand code structure and relationships
     - Identify key components and their purposes
   - Use `mcp__serena__find_symbol` to:
     - Locate specific functions or classes
     - Understand implementation details
     - Find usage patterns
   - Use `mcp__serena__find_referencing_symbols` to:
     - Trace dependencies and call chains
     - Understand component relationships
     - Identify impact of changes
   - Use `Read` to analyze:
     - package.json/requirements.txt for current tech stack
     - Configuration files for framework versions
     - README for documented stack decisions
   - Fallback to `Glob`, `Grep` for:
     - Finding all config files
     - Quick pattern matching across files
4. **Identify Current Tech Stack**

   - Analyze discovered files to determine:
     - **Languages**: JavaScript/TypeScript/Python/etc.
     - **Frameworks**: React/Vue/Express/Django/etc.
     - **Build tools**: Webpack/Vite/npm/yarn/pip/etc.
     - **Testing**: Jest/Mocha/Pytest/etc.
     - **Database**: From config files or connection strings
     - **State management**: Redux/MobX/Pinia/etc.
     - **UI libraries**: From package.json or imports
   - Research best practices for identified stack using:
     - `WebSearch` for current recommendations
     - `mcp__context7__` for library documentation
   - Prepare suggestions for:
     - Missing but beneficial tools
     - Upgrades to outdated dependencies
     - Alternative libraries for new features

### Phase 3: Interactive Clarification

5. **IMPORTANT: Ask Clarifying Questions**
   - Present findings from codebase analysis
   - Ask ONE BY ONE about:
     - **Scope confirmation**: "Based on existing [feature], should we extend it or create new?"
     - **Priority ordering**: "Which features are must-have vs nice-to-have?"
     - **Tech stack decisions**:
       - "Current stack uses [X]. Continue with this or switch?"
       - "For [feature], I suggest [library A] or [library B]. Preference?"
       - "Database: Use existing [DB] or add [suggested option]?"
       - "State management: Current is [X], adequate or upgrade?"
     - **Framework choices**: "For UI: [existing] vs [suggested alternatives]"
     - **Technical patterns**: "Current pattern is X, should we follow or change?"
     - **Development style**: "Use TDD approach or standard implementation?"
     - **Dependencies**: "Will need packages X, Y. Versions: [suggested]. Approve?"
     - **Breaking changes**: "This might affect [component]. Acceptable?"
   - Provide recommendations with each question
   - Wait for user response between each question
   - Document all decisions for the plan

### Phase 4: Plan Generation

6. **Strategic Planning**

   - Use `mcp__zen__planner` to:
     - Create sequential implementation steps
     - Consider dependencies between tasks
     - Estimate complexity and effort
     - Identify potential blockers
   - Structure tasks as:
     - **Clear objectives**: What needs to be accomplished
     - **Atomic units**: One feature/fix per task
     - **Logical ordering**: Dependencies considered
     - **Flexible approach**: TDD optional based on user preference
7. **Technical Validation**

   - Use `mcp__zen__analyze` to:
     - Validate architectural decisions
     - Check for potential issues
     - Ensure scalability considerations
   - Cross-reference with best practices

### Phase 5: Documentation

8. **Create Detailed Plan**

   - Generate comprehensive plan document using `Write`
   - Save to: `.claude/Plans/plan-{feature}-{DD-MM}.md`
   - Format:
     ```markdown
     # Implementation Plan: [Feature]
     Date: [DD-MM-YYYY]

     ## Overview
     **Goal**: [Main objective]
     **Scope**: [What's included/excluded]
     **Timeline Estimate**: [Rough estimate]

     ## Tech Stack Decisions
     ### Frontend
     - Framework: [React/Vue/Angular/etc.]
     - UI Library: [Material-UI/Tailwind/etc.]
     - State Management: [Redux/Context/Zustand/etc.]

     ### Backend
     - Runtime: [Node.js/Python/etc.]
     - Framework: [Express/FastAPI/etc.]
     - Database: [PostgreSQL/MongoDB/etc.]

     ### Libraries & Tools
     - [Library 1]: [Version] - [Purpose]
     - [Library 2]: [Version] - [Purpose]

     ### Development Approach
     - Testing: [TDD/Standard]
     - Pattern: [MVC/Microservices/etc.]

     ## Current State Analysis
     ### Existing Features
     - [Feature 1]: Located in [file:line]
     - [Feature 2]: Located in [file:line]

     ### Reusable Components
     - [Component]: Can be extended for [purpose]

     ### Required Changes
     - [File]: [Type of modification needed]

     ## Implementation Tasks

     ### Task 1: [Specific Task Name]
     **Objective**: [What this task accomplishes]
     **Files to modify**: 
     - [src/feature.js] - Add new functionality
     - [src/utils.js] - Update helper functions
     **Approach**: [High-level approach, TDD optional]
     **Success criteria**: [How to know it's done]

     ### Task 2: [Next Task]
     **Objective**: [What this task accomplishes]
     **Files to modify**: [List of files]
     **Dependencies**: Task 1 must be complete
     **Success criteria**: [How to know it's done]

     ## Dependencies
     - External packages: [List with versions]
     - Internal dependencies: [Files/modules]

     ## Testing Strategy
     - Unit tests: [Approach]
     - Integration tests: [Approach]
     - Manual testing: [Steps]

     ## Rollback Plan
     - How to revert if issues arise

     ## Success Criteria
     - [ ] [Measurable outcome 1]
     - [ ] [Measurable outcome 2]

     ## Final State
     After implementation:
     - User will be able to: [capability]
     - System will: [behavior]
     - Performance: [expectations]
     ```
9. **Review with User**

   - Present the plan summary
   - Highlight key decisions and trade-offs
   - Ask for final approval before saving
   - Make requested adjustments
10. **Finalize**

    - Save the approved plan
    - Provide usage instructions:
      - How to use with `/implement` command
      - Task tracking recommendations
      - Git workflow suggestions

## Arguments

- $ARGUMENTS: Either:
  - Path to brainstormed file (e.g., "Logs/Research/brainstorm-auth-08-10.md")
  - Direct idea description (e.g., "Add user authentication with OAuth")

## Expected Output

1. Comprehensive codebase analysis
2. Interactive Q&A session for requirement clarification
3. Detailed, atomic task breakdown
4. Saved plan document in Logs/Plans/
5. Clear implementation roadmap with specific file changes
6. Testing and rollback strategies

## Notes

- **Focused on strategy**: High-level planning, not implementation details
- **TDD-Optional**: User chooses development approach
- **Clear objectives**: What to accomplish, not how
- **Atomic tasks**: One feature/fix per task
- **Implementation flexibility**: Details handled by /implement command
- Respects existing codebase patterns
- Provides clear direction without over-specification
