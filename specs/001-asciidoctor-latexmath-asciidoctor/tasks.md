# Phase 2 Task Plan – asciidoctor-latexmath

NOTE: Generated early per user instruction (plan.prompt override) although template normally defers until /tasks command.

## Legend
[P] = Potentially parallel (order independent once predecessors done)
[TDD] = Test-first task (write failing spec)
[DOC] = Documentation related
[REF] = Refactor / internal quality
[SEC] = Security / safety

## Ordering (High-Level)
1. Environment & scaffolding
2. Interface & attribute contract specs (tests) [TDD]
3. Core infrastructure (cache, tool detection) with specs
4. Rendering pipeline skeleton → concrete stages
5. Error handling & edge cases
6. Documentation & examples
7. Final consistency & release prep

## Task List
1. [TDD] Add spec helper baseline & RSpec configuration (spec/spec_helper.rb) referencing Constitution v2.0.0.
2. [TDD][P2] Write failing spec: attribute precedence (block vs doc vs default) – block overrides doc.
3. [TDD] Failing spec: inline attribute precedence & parsing of `format=png, ppi=200`.
4. [TDD] Failing spec: deprecated alias `cache-dir` logged once & normalized.
5. [TDD] Failing spec: cache key changes when preamble changes.
6. [TDD] Failing spec: cache key unchanged when format=svg and only PPI differs.
7. [TDD] Failing spec: PPI out of range raises InvalidAttributeError.
8. [TDD] Failing spec: conflict registry rejects differing content same explicit basename.
9. [TDD] Failing spec: conflict registry allows identical signature duplicate.
10. [TDD] Failing spec: missing required tool (dvisvgm for svg) errors early before rendering.
11. [TDD] Failing spec: timeout triggers RenderTimeoutError and kills child process (mocked slow command).
12. [TDD] Failing spec: nocache skips cache fetch & store.
13. [TDD] Failing spec: keep-artifacts retains .tex & .log in artifacts dir.
14. [TDD] Failing spec: atomic write concurrency (simulate parallel threads) results in single artifact.
15. [TDD] Failing spec: signature includes tool versions (changing version invalidates hit).
16. [TDD] Failing spec: explicit engine override per element.
17. [TDD] Failing spec: unsupported format produces supported list message.
18. [CODE] Implement module skeleton: `lib/asciidoctor-latexmath.rb` register processors (Block + Inline only) – empty bodies.
19. [CODE] Implement attribute normalization & validation module (no rendering yet).
20. [CODE] Implement ConflictRegistry with in-memory map + thread safety (Mutex).
21. [CODE] Implement CacheKey class + DiskCache (fetch/store/with_lock) with atomic rename.
22. [CODE] Implement ToolDetector: detect & capture versions for engines & converters.
23. [CODE] Implement Renderer interfaces + Pipeline orchestrator (no actual system calls yet, return stub files).
24. [REF] Integrate logging helper (levels info/debug/warn/error) with structured messages.
25. [CODE][SEC] Implement PdflatexRenderer stage (generate temp .tex; run command; capture logs; honor timeout).
26. [CODE] Implement PdfToSvgRenderer variants (dvisvgm or explicit pdf2svg) with selection logic.
27. [CODE] Implement PdfToPngRenderer variants (pdftoppm/magick/gs) with PPI handling.
28. [CODE] Wire pipeline builder: choose stages based on format & overrides; compute pipeline signature.
29. [CODE] Implement caching wrapper: compute key, fetch, store on miss.
30. [CODE] Implement processors: build RenderRequest, interact with cache/pipeline, create AST nodes.
31. [TDD] Add determinism spec: identical content + attributes yields identical file checksum.
32. [TDD] Add performance smoke spec (skipped in CI if tools missing) ensure average cold render < target threshold (configurable) for simple formula.
33. [TDD] Add statistics spec: counts (rendered, cache hits) increment correctly.
34. [REF] Remove any temporary stub code & verify all earlier failing specs now pass.
35. [DOC] Update DESIGN.md removing BlockMacro references; sync with Constitution P1.
36. [DOC] Update README attribute table to align with AsciidoctorLatexmathAttributes.md (no block macro column).
37. [DOC] Add examples directory with sample `block-svg.adoc`, `block-png.adoc`, `inline-mixed.adoc`.
38. [DOC] Update quickstart.md if adjustments from implementation.
39. [CODE][SEC] Add input sanitation guard tests for command arg list (no injection of `;` etc.).
40. [CODE] Implement one-time deprecation log for `cache-dir` alias.
41. [TDD] Add test ensuring BlockMacro form `latexmath::[]` stays untouched + warning emitted.
42. [REF] StandardRB / lint setup; apply formatting.
43. [RELEASE] Add CHANGELOG entry, bump version (0.1.0), record constitution version & principles satisfied.
44. [RELEASE] Tag & build gem (manual step outside automated tests).

## Parallelization Notes
- Tasks 2–17 are spec authoring; can be parallelized by developer roles but must all be red before implementation tasks 18+.
- Tasks 25–27 can proceed after 23; 28–30 depend on 25–27.

## Traceability
| Task Range | Spec FR / Principle |
|------------|---------------------|
| 2–4 | FR-001, FR-006, P2 |
| 5–7 | FR-011, FR-018, P5 |
| 8–9 | FR-040 |
| 10 | FR-004 |
| 11 | FR-023/034 |
| 12 | FR-015 |
| 13 | FR-021 |
| 14 | FR-013 |
| 15 | FR-011 |
| 16 | FR-003 |
| 17 | FR-019 |
| 21 | FR-011/013/037 |
| 22 | FR-020 |
| 25–27 | FR-002/003/020 |
| 31 | P5 determinism |
| 33 | FR-022/035 |
| 41 | P1 enforcement |

## Completion Criteria
- All TDD tasks green.
- Lint passes (StandardRB).
- README & DESIGN updated & consistent.
- Cache determinism proven (rerun determinism spec twice).
- Tool absence scenario verified (intentional PATH manipulation in spec).

