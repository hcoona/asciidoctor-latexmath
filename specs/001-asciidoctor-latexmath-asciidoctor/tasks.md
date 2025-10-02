# Tasks: Asciidoctor Latexmath Offline Rendering Extension (Regenerated)

**Input**: Design documents from `/workspace/asciidoctor-extensions/asciidoctor-latexmath/specs/001-asciidoctor-latexmath-asciidoctor/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/ (renderer_pipeline, cache_key, processors, error_handling, statistics), quickstart.md

## Legend
[P] = Parallel-capable (different files, no unmet dependency)
All contract & integration specs MUST exist and FAIL before dependent implementation (Principle P2 / P1 / P5).

## Generation Sources
- Contracts (5) → contract spec tasks (renderer pipeline, cache key, processors, error handling, statistics)
- Data Model (8 entities) → model/interface stub tasks
- Acceptance Scenarios (5) → integration spec tasks
- Research decisions → setup, security, timeout, concurrency, statistics, attribute parity tasks

## Phase 3.1: Setup
- [ ] T001 Create gem skeleton & version file: `lib/asciidoctor-latexmath.rb`, `lib/asciidoctor/latexmath/version.rb` (ensure NO BlockMacro registration per P1).
- [ ] T002 Add RSpec + Aruba setup: `spec/spec_helper.rb`, enable `aruba/rspec`, temp dir helpers (FR-041).
- [ ] T003 [P] Add StandardRB config `.standard.yml` + Rake task `lint` + `bundle exec standardrb` CI target (P4).
- [ ] T004 [P] Add GitHub Actions CI workflow `.github/workflows/ci.yml` (matrix: 3.1,3.2,3.3; steps: install, lint, spec) (P4).
- [ ] T005 [P] Initialize `.rspec` with color + `--require spec_helper`.

## Phase 3.2: Tests First (Contracts & Integration) – ALL must fail initially
### Contract Specs
- [ ] T006 [P] Processors contract spec: `spec/processors/processors_contract_spec.rb` (only 2 processors, no BlockMacro, alias warn once, precedence outline) (P1,P2).
- [ ] T007 [P] Renderer pipeline contract spec: `spec/rendering/pipeline_contract_spec.rb` (stage order, signature diff, timeout placeholder) (P5).
- [ ] T008 [P] Cache key & disk cache contract spec: `spec/cache/cache_key_contract_spec.rb` (field ordering, any field change alters digest, atomic write expectations, tool version impact) (P5).
- [ ] T009 [P] Error handling contract spec: `spec/errors/error_handling_contract_spec.rb` (error classes enumerated, on-error policies abort/log behaviors pending) (FR-014/045/046).
- [ ] T010 [P] Statistics contract spec: `spec/statistics/statistics_contract_spec.rb` (single line format regex, suppression rules, rounding) (FR-022/035).
### Integration (Acceptance) Specs
- [ ] T011 [P] Primary story end-to-end: `spec/integration/primary_story_spec.rb` (svg default, caching across runs) (Scenario 1).
- [ ] T012 [P] Missing tool failure: `spec/integration/missing_tool_spec.rb` (simulate absent dvisvgm & pdf2svg; actionable error) (Scenario 2 / FR-004).
- [ ] T013 [P] Nocache png with ppi: `spec/integration/nocache_png_spec.rb` (%nocache twice, ppi valid & invalid → invalid pending) (Scenario 3 / FR-015/018).
- [ ] T014 [P] Concurrency atomicity: `spec/integration/concurrency_spec.rb` (two processes same formula: single artifact) (Scenario 4 / FR-013).
- [ ] T015 [P] Stem alias equivalence: `spec/integration/stem_alias_spec.rb` (stem: vs latexmath: single render) (Scenario 5 / FR-001/011).
### Additional Behavior Specs (Pre-Implementation)
- [ ] T016 [P] Accessibility markup spec: `spec/integration/accessibility_spec.rb` (alt=raw latex, role=math, data-latex-original) (FR-043).
- [ ] T017 [P] Attribute precedence spec: `spec/integration/attribute_precedence_spec.rb` (element > doc; positional overrides) (FR-006/009/016/037).
- [ ] T018 [P] Alias deprecation spec: `spec/integration/deprecated_alias_spec.rb` (one info log for cache-dir) (FR-037).
- [ ] T019 [P] Conflict detection spec: `spec/integration/conflict_detection_spec.rb` (different signatures same basename error) (FR-040).
- [ ] T020 [P] Error placeholder spec: `spec/integration/error_placeholder_spec.rb` (on-error=log placeholder sections order) (FR-046).

## Phase 3.3: Core Models & Interfaces (stubs only; run after T006–T020 exist)
- [ ] T021 [P] Stub MathExpression: `lib/asciidoctor/latexmath/math_expression.rb` (attrs, TODO invariants).
- [ ] T022 [P] Stub RenderRequest: `lib/asciidoctor/latexmath/render_request.rb`.
- [ ] T023 [P] Stub PipelineSignature: `lib/asciidoctor/latexmath/rendering/pipeline_signature.rb` (digest placeholder).
- [ ] T024 [P] Stub CacheEntry: `lib/asciidoctor/latexmath/cache/cache_entry.rb`.
- [ ] T025 [P] Skeleton DiskCache: `lib/asciidoctor/latexmath/cache/disk_cache.rb` (fetch/store/with_lock raise NotImplementedError).
- [ ] T026 [P] Stub ToolchainRecord: `lib/asciidoctor/latexmath/rendering/toolchain_record.rb`.
- [ ] T027 [P] Renderer interface/base: `lib/asciidoctor/latexmath/rendering/renderer.rb` (IRenderer methods + result struct).
- [ ] T028 [P] ConflictRegistry: `lib/asciidoctor/latexmath/support/conflict_registry.rb` (register! skeleton).

## Phase 3.4: Core Services & Pipeline
- [ ] T029 Attribute resolver: `lib/asciidoctor/latexmath/attribute_resolver.rb` (precedence chain, alias normalization, ppi/timeout validation stubs) depends: T021,T022.
- [ ] T030 Tool detection & version capture: `lib/asciidoctor/latexmath/rendering/tool_detector.rb` (one-time detection, signatures) depends: T026.
- [ ] T031 Cache key implementation: `lib/asciidoctor/latexmath/cache/cache_key.rb` (ordered fields, digest) depends: T023,T024,T025.
- [ ] T032 Pipeline orchestrator: `lib/asciidoctor/latexmath/rendering/pipeline.rb` (sequential execution, timing hooks) depends: T027,T023.
- [ ] T033 Pdflatex renderer stage: `lib/asciidoctor/latexmath/rendering/pdflatex_renderer.rb` depends: T032,T030.
- [ ] T034 [P] Pdf→SVG renderer stage: `lib/asciidoctor/latexmath/rendering/pdf_to_svg_renderer.rb` depends: T033.
- [ ] T035 [P] Pdf→PNG renderer stage: `lib/asciidoctor/latexmath/rendering/pdf_to_png_renderer.rb` depends: T033.
- [ ] T036 Processors (block + inline): `lib/asciidoctor/latexmath/processors/{block_processor,inline_macro_processor}.rb` depends: T029,T030,T031,T032,T033–T035,T028.
- [ ] T037 Extension wiring entrypoint: `lib/asciidoctor-latexmath.rb` (register only processors) depends: T036.

## Phase 3.5: Behavior Implementation & Edge Cases
- [ ] T038 Cache store + hit logic: integrate DiskCache + CacheKey (FR-005/011/012) depends: T031,T025,T037.
- [ ] T039 Atomic write & concurrency lock: temp + rename + optional lock file (FR-013) depends: T038.
- [ ] T040 Conflict detection raising TargetConflictError (FR-040) depends: T028,T036,T038.
- [ ] T041 Nocache & keep-artifacts flows (FR-007/015/021) depends: T036,T038.
- [ ] T042 Timeout enforcement + process kill (FR-023/034) depends: T033–T035.
- [ ] T043 Security restrictions (no shell-escape, sanitized args) (FR-017/036) depends: T033–T035.
- [ ] T044 Attribute precedence & alias normalization full logic (makes T017/T018 green) depends: T029,T036.
- [ ] T045 Error placeholder + on-error policy (FR-014/045/046) depends: T036,T041,T042.
- [ ] T046 Statistics collection & emission (FR-022/035) depends: T038,T042.
- [ ] T047 Accessibility markup injection (FR-043) depends: T036.
- [ ] T048 PPI validation & range errors (FR-018) depends: T029,T036.
- [ ] T049 Stem alias handling (FR-001/011) depends: T036.
- [ ] T050 Cache key tool signature integration (FR-020) depends: T030,T031.

## Phase 3.6: Performance, Determinism & Documentation
- [ ] T051 [P] Performance smoke spec: `spec/performance/render_perf_spec.rb` (skip if tools missing) depends: T042,T046.
- [ ] T052 [P] Determinism spec: `spec/integration/determinism_spec.rb` (two runs identical checksum + no re-render) depends: T038,T050.
- [ ] T053 [P] Statistics suppression & rounding spec (make T010/T046 green) `spec/statistics/statistics_behavior_spec.rb` depends: T046.
- [ ] T054 README attributes & usage table (FR-027) depends: T044,T046,T047.
- [ ] T055 Update DESIGN.md remove BlockMacro references; add cache key diagram depends: T054.
- [ ] T056 Add examples: `examples/block_svg.adoc`, `examples/png_cached.adoc`, `examples/inline_mix.adoc`, `examples/error_placeholder.adoc` depends: T045,T041.
- [ ] T057 Add CHANGELOG entry & set version 0.1.0 depends: T054–T056.
- [ ] T058 Release rake tasks + gem build verification (reproducibility spot-check) depends: T057.
- [ ] T059 [P] Performance baseline doc `specs/001-asciidoctor-latexmath-asciidoctor/performance-baseline.md` (capture p50/p95 cold/warm) depends: T051.
- [ ] T060 Final verification checklist (run suite twice; capture stats line; ensure no duplicate stats output) depends: T051–T058.

## Dependencies (Summary)
T002 → T001
T003,T004,T005 → T001
T006–T020 → T002
T021–T028 → T006–T020 & T002
T029 → T021,T022
T030 → T026
T031 → T023,T024,T025
T032 → T027,T023
T033 → T032,T030
T034,T035 → T033
T036 → T029,T030,T031,T032,T033,T034,T035,T028
T037 → T036
T038 → T031,T025,T037
T039 → T038
T040 → T028,T036,T038
T041 → T036,T038
T042 → T033,T034,T035
T043 → T033,T034,T035
T044 → T029,T036
T045 → T036,T041,T042
T046 → T038,T042
T047 → T036
T048 → T029,T036
T049 → T036
T050 → T030,T031
T051 → T042,T046
T052 → T038,T050
T053 → T046
T054 → T044,T046,T047
T055 → T054
T056 → T045,T041
T057 → T054,T055,T056
T058 → T057
T059 → T051
T060 → T051,T052,T053,T058

## Parallel Execution Examples
Group A (Contract Specs): T006 T007 T008 T009 T010
Group B (Acceptance Specs): T011 T012 T013 T014 T015
Group C (Behavior Pre-impl Specs): T016 T017 T018 T019 T020
Group D (Entity Stubs): T021 T022 T023 T024 T025 T026 T027 T028
Group E (Renderer Stages): T034 T035
Group F (Perf/Determinism/Stats later): T051 T052 T053

## Validation Checklist
- [ ] 5 contract files → 5 contract spec tasks (T006–T010)
- [ ] 8 entities → 8 stub tasks (T021–T028)
- [ ] 5 acceptance scenarios → 5 integration tests (T011–T015)
- [ ] Additional critical behaviors (accessibility, alias, conflict, placeholder, precedence) covered (T016–T020)
- [ ] Tests precede implementation (T006–T020 before T021+)
- [ ] External tool detection + timeout tasks (T030,T042)
- [ ] Security restrictions task (T043)
- [ ] Concurrency & atomic write tasks (T039,T014 integration, T039 impl)
- [ ] Statistics tasks (T010 contract, T046 impl, T053 behavior)
- [ ] Accessibility task (T047 impl + T016 spec)
- [ ] Determinism & performance tasks (T051,T052)
- [ ] Documentation & release tasks (T054–T058)
- [ ] Performance baseline doc (T059) for FR-042 future hard thresholds
- [ ] Final verification (T060)

## Notes
- Each task commit message: "T0xx: <short description>".
- Specs may use `pending` for behavior dependent on future tasks (reduce brittle red states).
- Aruba specs MUST isolate FS; never rely on global HOME (FR-041).
- Keep contract specs minimal—expand only after base green to avoid over-constraining implementation order.
- Statistics line is immutable contract; any future field addition requires new FR + version bump.

---
*Based on Constitution v2.0.0 – see `.specify/memory/constitution.md`*

