<!--
Sync Impact Report
Version: (none) -> 1.0.0
Principles Added:
	P1 Processor Trio Only (No TreeProcessor / No Mathematical Gem)
	P2 Interface-First Waterfall + TDD Gating
	P3 Configuration Parity with Asciidoctor-Diagram
	P4 Quality, Style & Toolchain Discipline
	P5 Deterministic Rendering, Caching & Security
Sections Added: Core Principles; Development Workflow & Quality Gates; Documentation & Traceability Standards; Governance
Templates Updated:
	.specify/templates/plan-template.md ✅ (version reference updated)
	.specify/templates/spec-template.md ✅ (version reference added)
	.specify/templates/tasks-template.md ✅ (Ruby + extension domain examples)
	.specify/templates/agent-file-template.md ⚠ (unchanged – still generic)
Removed Sections: none
Follow-up TODOs: none
-->

# asciidoctor-latexmath Constitution

## Core Principles

### P1. Processor Trio Only (NON-NEGOTIABLE)
Rules:
- MUST implement exactly three entrypoints: BlockProcessor, BlockMacroProcessor, InlineMacroProcessor.
- MUST NOT register or rely on TreeProcessor (global AST mutation prohibited).
- MUST NOT depend on `Mathematical` gem or reuse its runtime image generation logic.
- Processors MUST delegate rendering to a shared, pure rendering pipeline (no side effects outside provided dirs).
- Attribute & option resolution MUST be deterministic and local to each invocation.
Rationale: Guarantees predictable extension behavior, minimizes global coupling, and aligns surface area with
Asciidoctor-Diagram conventions for user familiarity.

### P2. Interface-First Waterfall with Enforced TDD
Rules:
- Public API (processor names, attribute matrix, renderer pipeline contract) MUST be specified before code.
- For each new capability: write failing RSpec contract + behavior tests BEFORE implementation (Red → Green → Refactor).
- Waterfall stages (Interface Spec → Tests → Implementation → Documentation → Release) MUST NOT be reordered.
- Any change to a declared interface REQUIRES a matching spec diff + version evaluation (see Governance).
Rationale: Freezes expectations early, prevents scope drift, elevates test artifacts to first-class design assets.

### P3. Configuration & Behavior Parity with Asciidoctor-Diagram
Rules:
- Attribute naming, precedence (block > document > global), and cache invalidation semantics MUST mirror
	Asciidoctor-Diagram where an equivalent concept exists.
- When conflicts arise between Asciidoctor-Diagram and asciidoctor-mathematical, MUST follow Asciidoctor-Diagram.
- Unsupported formats or attributes MUST fail fast with a clear message listing supported values.
- Converter discovery & external tool resolution MUST be cached per process execution and not recomputed per node.
Rationale: Lowers cognitive load for existing users and reduces documentation surface.

### P4. Quality, Style & Toolchain Discipline
Rules:
- MUST use Standard Ruby (standardrb) for formatting & linting; CI MUST fail on style violations.
- MUST maintain 100% test pass before merging; mutation or coverage tooling SHOULD guard critical rendering logic.
- Semantic Versioning of the gem: MAJOR for breaking API/attribute changes, MINOR for additive behavior, PATCH for fixes.
- Build artifacts (gem, cache metadata) MUST be reproducible (content hash = deterministic pipeline signature + sources).
- All external command invocations (e.g., `pdflatex`, `pdf2svg`) MUST be wrapped with argument sanitization & timeout.
Rationale: Enforces consistent contributor experience and dependable releases.

### P5. Deterministic Rendering, Caching & Security
Rules:
- Rendering pipeline MUST be pure: output = f(content, attributes, pipeline_signature) with no ambient state.
- Cache key MUST include: content hash, attribute hash (filtered & sorted), renderer version, toolchain versions.
- On cache hit MUST skip tool execution entirely.
- Shell execution MUST reject untrusted attribute injection (whitelisted args only) and enforce time & size limits.
- Inline rendering (data URI / embedded SVG) MUST be optional and disabled by default unless explicitly requested.
Rationale: Predictability improves performance, reproducibility, and security posture.

## Development Workflow & Quality Gates
Phases (Waterfall):
1. Interface Definition: Attribute matrix + processor responsibilities + renderer pipeline documented.
2. Test Authoring: RSpec specs (contract + behavior + error cases) created & failing.
3. Implementation Stage 1: Processor scaffolds & pipeline skeleton returning placeholders to make tests executable.
4. Implementation Stage 2: Full rendering logic, caching, external tool integration, performance tuning.
5. Documentation: Update README, DESIGN.md, class diagrams, usage examples, CHANGELOG entries.
6. Release: Version bump rationale recorded; tag + packaged gem.

Quality Gates (must PASS before advancing):
- Gate A (after Phase 1): All declared interfaces documented; no hidden attributes.
- Gate B (after Phase 2): All tests exist & fail for correct reasons (no pending or false positives).
- Gate C (after Stage 2 impl): All contract + behavior tests pass; style & security checks pass.
- Gate D (release): Changelog, version bump classification, reproducible build verification, cache determinism spot check.

## Documentation & Traceability Standards
Requirements:
- DESIGN.md MUST reflect latest pipeline architecture (update concurrently with implementation changes).
- `class-digram-v2.plantuml` (typo kept if present) MUST remain consistent with implemented classes or be updated.
- Every principle reference in specs MUST cite Principle ID (e.g., `# P2`) in test description for traceability.
- README MUST list supported attributes in a table including default, type, example, parity note (if from Diagram).
- LEARN.md serves as evolving knowledge log; entries MUST summarize new decisions with date + principle impact.
Artifacts Mapping:
- Interface Matrix → spec/support/interface_matrix.yml
- Cache Key Definition → documented in DESIGN.md & verified by spec/renderer/cache_spec.rb
- External Toolchain Requirements → README (Installation) section + CI check job.

## Governance
Authority & Scope:
- This Constitution supersedes ad-hoc conventions and individual contributor preferences.
Amendments:
- Proposal via PR including: diff, principle impact summary, version bump type justification (MAJOR/MINOR/PATCH).
- Requires approval by ≥2 maintainers OR unanimous approval if maintainer count <3.
Versioning (Constitution):
- MAJOR: Removal or redefinition of a Principle, or backward-incompatible governance change.
- MINOR: Addition of a new Principle, new mandatory workflow gate, or expansion adding new enforceable rule text.
- PATCH: Clarifications, typo fixes, wording improvements without semantic rule change.
Compliance Review:
- Per PR: Automated lints verify no TreeProcessor usage, disallowed dependencies, and interface documentation presence.
- Quarterly: Manual audit ensuring parity matrix matches current Asciidoctor-Diagram state.
Violation Handling:
- Open issue labeled `constitution-violation` referencing failing Principle IDs + reproduction.
- Fix MUST include regression test when applicable.
Record Keeping:
- Each release PR MUST reference Constitution version and list principle-related changes in CHANGELOG.
Guidance File:
- Primary runtime guidance: LEARN.md (living log) + DESIGN.md (architecture source of truth).

**Version**: 1.0.0 | **Ratified**: 2025-10-02 | **Last Amended**: 2025-10-02
