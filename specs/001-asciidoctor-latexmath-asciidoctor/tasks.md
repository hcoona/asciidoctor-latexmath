# Tasks: Asciidoctor Latexmath Offline Rendering Extension

Input: Design documents from `specs/001-asciidoctor-latexmath-asciidoctor/`
Prerequisites: plan.md (required), research.md, data-model.md, contracts/

## Legend
[P] = Parallel-capable (different files, no unmet dependency)
All tests (contract + integration) MUST be written & red before any implementation task that satisfies them (Principle P2).

## Generation Sources
- Contracts → T005–T007 (contract test specs)
- Data Model (8 entities) → T013–T020 (model stub tasks)
- User Stories / Acceptance (Primary + 4 scenarios) → T008–T012 (integration specs)

## Phase 3.1: Setup
- [ ] T001 Create project skeleton (directories, `lib/asciidoctor-latexmath.rb`, `lib/asciidoctor/latexmath/version.rb`) ensuring no BlockMacro registration (enforces P1) and explicit absence of BlockMacro processor.
- [ ] T002 Add RSpec configuration & `spec/spec_helper.rb` with basic helper utilities (temp dir, tool stubs) AND integrate Aruba (`require 'aruba/rspec'`) setting up per-example isolated working dir & env (FR-041). Provide helper to invoke `asciidoctor` within sandbox.
- [ ] T003 [P] Add StandardRB config `.standard.yml` & Rake task `lint`.
- [ ] T004 [P] Add CI workflow `.github/workflows/ci.yml` (runs lint + specs on Ruby 3.1, 3.2, 3.3).

## Phase 3.2: Tests First (Contracts & Integration)  (All must FAIL initially)
- [ ] T005 [P] Contract spec for processors `spec/processors/processors_contract_spec.rb` (registration limits, alias warning, precedence outline, no BlockMacro) – prepares for T028.
- [ ] T006 [P] Contract spec for renderer pipeline `spec/rendering/pipeline_contract_spec.rb` (signature & stage ordering, timeout placeholder, determinism outline).
- [ ] T007 [P] Contract spec for cache key & disk cache `spec/cache/cache_key_contract_spec.rb` (field ordering, atomic write expectations, tool version impact).
- [ ] T008 [P] Integration spec (Aruba): primary user story end-to-end `spec/integration/primary_story_spec.rb` (svg default caching expectations; mark pending details) – asserts sandbox isolation (FR-041).
- [ ] T009 [P] Integration spec (Aruba): default svg caching reuse `spec/integration/svg_cache_hit_spec.rb` (renders once, second run hit metric expectation placeholder) – ensures separate examples do not share state (FR-041).
- [ ] T010 [P] Integration spec (Aruba): missing tool failure `spec/integration/missing_tool_spec.rb` (simulate absent dvisvgm + pdf2svg) – asserts temp dirs cleaned (FR-041, FR-004).
- [ ] T011 [P] Integration spec (Aruba): nocache png with ppi `spec/integration/nocache_png_spec.rb` (%nocache twice, format=png, ppi valid & out-of-range pending cases) – validates no cache write & PPI validation (FR-018, FR-015, FR-041).
- [ ] T012 [P] Integration spec (Aruba): parallel build atomicity `spec/integration/concurrency_spec.rb` (two sandboxed processes to same cache path) – asserts single artifact & no corruption (FR-013, FR-041).

## Phase 3.3: Core Models (Entity Stubs)  (Created after tests written, can run in parallel)
- [ ] T013 [P] Stub `MathExpression` model `lib/asciidoctor/latexmath/math_expression.rb` (attributes, invariants TODO markers).
- [ ] T014 [P] Stub `RenderRequest` model `lib/asciidoctor/latexmath/render_request.rb` (fields, validation placeholders).
- [ ] T015 [P] Stub `PipelineSignature` `lib/asciidoctor/latexmath/rendering/pipeline_signature.rb` (digest placeholder SHA256 helper).
- [ ] T016 [P] Stub `CacheEntry` `lib/asciidoctor/latexmath/cache/cache_entry.rb` (serializer scaffold).
- [ ] T017 [P] Skeleton `DiskCache` `lib/asciidoctor/latexmath/cache/disk_cache.rb` (fetch/store/with_lock signatures raise NotImplementedError).
- [ ] T018 [P] Stub `ToolchainRecord` `lib/asciidoctor/latexmath/rendering/toolchain_record.rb`.
- [ ] T019 [P] Renderer interface & base `lib/asciidoctor/latexmath/rendering/renderer.rb` (abstract methods, simple result struct).
- [ ] T020 [P] Implement `ConflictRegistry` `lib/asciidoctor/latexmath/support/conflict_registry.rb` (thread-safe map, basic register! skeleton).

## Phase 3.4: Core Services & Processing
- [ ] T021 Attribute resolution & normalization `lib/asciidoctor/latexmath/attribute_resolver.rb` (precedence chain, alias mapping, validation stubs) depends: T013,T014.
- [ ] T022 Tool detection & version capture `lib/asciidoctor/latexmath/rendering/tool_detector.rb` depends: T018.
- [ ] T023 Cache key implementation `lib/asciidoctor/latexmath/cache/cache_key.rb` depends: T015,T016,T017.
- [ ] T024 Pipeline orchestrator `lib/asciidoctor/latexmath/rendering/pipeline.rb` depends: T015,T019.
- [ ] T025 Pdflatex renderer stage `lib/asciidoctor/latexmath/rendering/pdflatex_renderer.rb` depends: T024,T022.
- [ ] T026 [P] Pdf→SVG renderer stage `lib/asciidoctor/latexmath/rendering/pdf_to_svg_renderer.rb` depends: T025.
- [ ] T027 [P] Pdf→PNG renderer stage `lib/asciidoctor/latexmath/rendering/pdf_to_png_renderer.rb` depends: T025.
- [ ] T028 Processors (block & inline) `lib/asciidoctor/latexmath/processors/block_processor.rb`, `lib/asciidoctor/latexmath/processors/inline_macro_processor.rb` depends: T021,T022,T023,T024,T025–T027,T020.
- [ ] T029 Extension wiring & registration update `lib/asciidoctor-latexmath.rb` depends: T028.

## Phase 3.5: Behavior Completion & Edge Cases
- [ ] T030 Implement cache hit/miss + store logic (DiskCache + CacheKey integration) depends: T023,T017,T029.
- [ ] T031 Implement atomic write & concurrency lock behavior depends: T030.
- [ ] T032 Implement conflict detection raising `TargetConflictError` depends: T020,T028,T030.
- [ ] T033 Implement nocache + keep-artifacts flows depends: T028,T030.
- [ ] T034 Implement timeout enforcement & process kill depends: T025–T027.
- [ ] T035 Implement security restrictions (no shell-escape, sanitized args) depends: T025–T027.
- [ ] T036 Implement attribute precedence & alias normalization logic (make T005 red→green) depends: T021,T028.

## Phase 3.6: Polish & Performance
- [ ] T037 [P] Performance smoke spec `spec/performance/render_perf_spec.rb` (skipped if tools missing) depends: T034.
- [ ] T038 [P] Statistics logging spec `spec/integration/statistics_spec.rb` depends: T030,T033. Validate MIN format (FR-022, FR-035): single line `latexmath stats: renders=R cache_hits=H avg_render_ms=X avg_hit_ms=Y`; no extra fields; quiet suppresses; repeated invocations not duplicated; avg rounding; hit=0 case.
- [ ] T039 Update README attributes table & usage examples depends: T036.
- [ ] T040 Update DESIGN.md removing BlockMacro references depends: T039.
- [ ] T041 Add examples: `examples/block_svg.adoc`, `examples/png_cached.adoc`, `examples/inline_mix.adoc` depends: T029,T033.
- [ ] T042 Add CHANGELOG entry & set version 0.1.0 depends: T039–T041.
- [ ] T043 Add release rake tasks & gem build verification depends: T042.
- [ ] T044 [P] Add determinism spec `spec/integration/determinism_spec.rb` (repeat run identical checksum) depends: T030.
- [ ] T045 Final verification checklist task (run full suite twice, capture timings) depends: T037–T044.

## Dependencies (Summary)
T002 → T001
T003,T004 → T001
T005–T012 → T002
T013–T020 → T005–T012 (all tests authored) & T002
T021 → T013,T014
T022 → T018
T023 → T015,T016,T017
T024 → T015,T019
T025 → T024,T022
T026,T027 → T025
T028 → T021,T022,T023,T024,T025,T026,T027,T020
T029 → T028
T030 → T023,T017,T029
T031 → T030
T032 → T020,T028,T030
T033 → T028,T030
T034 → T025,T026,T027
T035 → T025,T026,T027
T036 → T021,T028
T037 → T034
T038 → T030,T033
T039 → T036
T040 → T039
T041 → T029,T033
T042 → T039,T040,T041
T043 → T042
T044 → T030
T045 → T037,T038,T042,T043,T044

## Parallel Execution Examples
Example Group A (Contracts): T005 T006 T007
Example Group B (Integration Specs): T008 T009 T010 T011 T012
Example Group C (Entity Stubs): T013 T014 T015 T016 T017 T018 T019 T020
Example Group D (Renderer Stages): T026 T027
Example Group E (Performance & Stats): T037 T038 T044

## Validation Checklist
- [ ] All contract files mapped to tests (renderer_pipeline, cache_key, processors → T005–T007)
- [ ] All 8 entities have model stub tasks (T013–T020)
- [ ] All user stories & acceptance scenarios mapped to integration specs (Primary + 4 scenarios → T008–T012)
- [ ] Tests precede implementation (T005–T012 before T013+)
- [ ] No [P] tasks share a file path
- [ ] External tool detection & timeout tasks present (T022, T034)
- [ ] Security restrictions task present (T035)
- [ ] Lint/style task present (T003)
- [ ] Determinism & performance tasks present (T037, T044)
- [ ] Documentation & release tasks present (T039–T043)
- [ ] Stats MIN format enforced (T038; FR-022/FR-035)
- [ ] Aruba sandbox isolation validated (T008–T012; FR-041)

## Notes
- Each task should result in at least one commit referencing TID (e.g., "T021: implement attribute resolver precedence chain").
- Keep failing specs minimal initially; expand after core green to avoid over-specifying early.
- Use pending blocks (`pending "..."`) where detailed behavior depends on later tasks to avoid brittle premature assertions.
- Integration specs (T008–T012) must use Aruba for filesystem & env isolation (FR-041). Do NOT rely on user HOME or global cache location.
- Statistics spec (T038) treats output format as immutable contract; any new field requires new FR & version bump.
- Future performance hard thresholds (FR-042) can extend T037 or add a new task rather than altering T038.

---
Based on Constitution v2.0.0 – see `.specify/memory/constitution.md`.

