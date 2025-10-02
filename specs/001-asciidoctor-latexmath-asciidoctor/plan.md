
# Implementation Plan: Asciidoctor Latexmath Offline Rendering Extension

**Branch**: `001-asciidoctor-latexmath-asciidoctor` | **Date**: 2025-10-02 | **Spec**: `./spec.md`
**Input**: Feature specification from `specs/001-asciidoctor-latexmath-asciidoctor/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Provide an Asciidoctor extension that renders `latexmath` block & inline expressions to SVG / PDF / PNG offline using the local LaTeX toolchain with deterministic caching, attribute parity with asciidoctor-diagram, and strict security/timeouts. Scope contraction (per Constitution v2.0.0) explicitly removes BlockMacro support present in earlier design drafts; only BlockProcessor + InlineMacroProcessor are implemented. Rendering pipeline: generate `.tex` → run chosen engine (`pdflatex`/`xelatex`/`lualatex`/`tectonic`) → optional PDF→SVG (dvisvgm / pdf2svg) or PDF→PNG (pdftoppm / magick / gs). Caching keyed by content + pipeline signature + tool versions ensures reproducibility; conflicts on explicit basenames with different signatures raise errors.

## Technical Context
**Language/Version**: Ruby (target 3.1+; compatible with Asciidoctor >= 2.0 < 3.0)
**Primary Dependencies**: asciidoctor (runtime), external LaTeX & conversion tools (`pdflatex|xelatex|lualatex|tectonic`, `dvisvgm|pdf2svg`, `pdftoppm|magick|gs`)
**Storage**: File system only (cache & artifacts directories)
**Testing**: RSpec 3.13 (TDD, contract + behavior specs)
**Target Platform**: Cross-platform (Linux primary CI; macOS/Windows later); offline capable
**Project Type**: Single Ruby gem (library extension)
**Performance Goals**: Cold SVG render p95 < 2500 ms for simple formula; warm cache hit overhead < 5 ms; PNG conversion p95 < 3000 ms
**Constraints**: Deterministic outputs, no TreeProcessor, no Mathematical gem, no unbounded parallelism, timeout default 120 s per render stage
**Scale/Scope**: Documents up to ~5k formulas per build; cache persists across builds; no eviction v1

## Constitution Check
*Initial & Post-Design Review – PASS*

| Principle | Compliance | Evidence |
|-----------|-----------|----------|
| P1 Processor Duo Only | PASS | Plan + data-model + contracts list only BlockProcessor & InlineMacroProcessor; tasks include test to ensure block macro untouched |
| P2 Interface-First TDD | PASS | research.md + contracts/*.md & data-model.md authored before implementation tasks (tasks 18+); tasks 2–17 are all failing specs first |
| P3 Diagram Parity | PASS | research.md parity table; differences documented (no block macro, naming of ppi) |
| P4 Quality & Toolchain | PASS | tasks include StandardRB setup, versioning, reproducible cache key tests, timeout tests |
| P5 Deterministic Caching & Security | PASS | cache_key contract; tool detection strategy; timeout & atomic write tasks; shell escape prohibition specified |

No violations requiring Complexity Tracking. Earlier DESIGN.md still references BlockMacro; flagged for update (Task 35) – not a runtime violation.

## Project Structure

### Documentation (this feature)
```
specs/001-asciidoctor-latexmath-asciidoctor/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── renderer_pipeline.md
│   ├── cache_key.md
│   └── processors.md
└── tasks.md (generated early per user override)
```

### Source Code (planned / existing)
```
lib/
├── asciidoctor-latexmath.rb              # entry; registers processors
└── asciidoctor/
      └── latexmath/
            ├── version.rb
            ├── configuration.rb
            ├── processors/
            │   ├── block_processor.rb
            │   └── inline_macro_processor.rb
            ├── rendering/
            │   ├── pipeline.rb
            │   ├── renderer.rb               # interface & base
            │   ├── pdflatex_renderer.rb
            │   ├── pdf_to_svg_renderer.rb
            │   ├── pdf_to_png_renderer.rb
            │   └── tool_detector.rb
            ├── cache/
            │   ├── cache_key.rb
            │   └── disk_cache.rb
            ├── support/
            │   ├── conflict_registry.rb
            │   └── logging.rb
            └── errors.rb
spec/
├── processors/
├── cache/
├── pipeline/
├── rendering/
└── support/
```

**Structure Decision**: Single Ruby gem library (no multi-app); directories above added incrementally by tasks.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate internal contracts** from functional requirements:
   - Map rendering responsibilities → interface specs (IRenderer, Pipeline, Cache, Processors)
   - Capture cache key specification & pipeline determinism in `/contracts/`

3. **Generate contract tests (spec stubs)** referencing contracts:
   - One spec per concern (cache key, pipeline signature, processors precedence)
   - All start failing (unimplemented / pending) to drive TDD

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
User override (plan.prompt.md) requested early generation of tasks; `tasks.md` has been created (see file) enumerating 44 tasks with TDD-first ordering, principle traceability, and parallelization hints.

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
**Phase Status**:
- [x] Phase 0: Research complete (research.md present)
- [x] Phase 1: Design complete (data-model + contracts + quickstart)
- [x] Phase 2: Task planning complete (tasks.md generated early)
- [ ] Phase 3: Tasks generated (N/A – already produced early, treated as satisfied)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved (see Clarifications in spec.md)
- [ ] Complexity deviations documented (none needed)

---
*Based on Constitution v2.0.0 - See `.specify/memory/constitution.md`*
