
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
离线（本地 LaTeX 工具链）渲染 `latexmath` 块与内联宏表达式为 `svg|pdf|png`，提供与 `asciidoctor-diagram` 风格一致的属性/缓存/目录/冲突处理语义，仅维持 Processor Duo（Block + InlineMacro），实现确定性缓存键（内容哈希 + 配置 + 工具版本 + 引擎 + preamble 哈希 + 版本），在失败策略(`on-error`)与统计输出(单行 MIN 格式)下保持可预测、可追踪、可重复构建。所有模糊点已通过 Clarifications 解决；无剩余 NEEDS CLARIFICATION。

## Technical Context
**Language/Version**: Ruby 3.1–3.3 (tested matrix)
**Primary Dependencies**: asciidoctor (~>2.0), standardrb, rspec, aruba (integration sandbox), external CLI tools (`pdflatex|xelatex|lualatex|tectonic`, `dvisvgm|pdf2svg`, `pdftoppm|magick|gs`).
**Storage**: 本地文件系统（缓存与产物目录），无数据库。
**Testing**: RSpec（单元/契约/集成/性能），Aruba（文件系统隔离），Pending 性能基准脚本。
**Target Platform**: Linux / macOS（初始），Windows 后续评估。
**Project Type**: 单库（Ruby gem + Asciidoctor extension）。
**Performance Goals**: 冷启动简单公式 (≤120 chars) SVG p95 < ~3000ms（软目标），缓存命中平均 <5ms 附加开销，后续基准固化硬阈值 (FR-042)。
**Constraints**: 纯离线、无网络依赖；禁止 TreeProcessor & BlockMacro；确定性缓存、可重复构建、超时强制 120s 默认。
**Scale/Scope**: 支撑 ≥5k 公式线性扩展；无内建上限；内存与状态按表达式流式处理。
**Outstanding Clarifications**: None (全部已解决)。

## Constitution Check
*Initial + Post-Design Review (all pass)*

| Principle | Verification | Status | Notes |
|-----------|--------------|--------|-------|
| P1 Processor Duo Only | 仅列出 Block + InlineMacro，任务 T028 明确不注册 BlockMacro；计划/契约无 TreeProcessor | PASS | DESIGN.md 后续更新去除旧引用 (T040) |
| P2 Interface-First TDD | contracts/ 已包含 renderer_pipeline, cache_key, processors；tasks.md Phase 3.2 全部先写测试 | PASS | 无实现代码先行任务 |
| P3 Diagram Parity | research.md 含属性对照表；差异（无 BlockMacro, `ppi` 术语）已记录 | PASS | 差异有意识且文档化 |
| P4 Quality & Toolchain | Tasks T003 (standardrb), T004 (CI), T022/T034 (tool detect/timeout), T035 (security) | PASS | 覆盖 lint/CI/安全/超时 |
| P5 Determinism & Security | cache key 合成列于 contracts/cache_key.md；原子写 + 锁 (T030–T031)；无 shell-escape (T035) | PASS | 统计与错误占位不污染缓存 |

Complexity Deviations: None (表格留空)。

ios/ or android/
## Project Structure

### Documentation (feature specs directory)
```
specs/001-asciidoctor-latexmath-asciidoctor/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── renderer_pipeline.md
│   ├── cache_key.md
│   └── processors.md
├── tasks.md
└── (future) performance-baseline.md (FR-042 follow-up)
```

### Source (Ruby Gem)
```
lib/
├── asciidoctor-latexmath.rb          # Extension entry, registration, version
├── asciidoctor/latexmath/
│   ├── version.rb
│   ├── math_expression.rb
│   ├── render_request.rb
│   ├── attribute_resolver.rb
│   ├── support/
│   │   └── conflict_registry.rb
│   ├── cache/
│   │   ├── cache_key.rb
│   │   ├── cache_entry.rb
│   │   └── disk_cache.rb
│   └── rendering/
│       ├── pipeline_signature.rb
│       ├── pipeline.rb
│       ├── renderer.rb
│       ├── pdflatex_renderer.rb
│       ├── pdf_to_svg_renderer.rb
│       ├── pdf_to_png_renderer.rb
│       └── tool_detector.rb
└── asciidoctor/latexmath/processors/
      ├── block_processor.rb
      └── inline_macro_processor.rb

spec/
├── processors/
├── rendering/
├── cache/
├── integration/
├── performance/
└── support/
```

**Structure Decision**: 单项目 Ruby gem 布局（无前后端分离）；符合 Constitution P1–P5，最大程度保持简单与易测试性。

## Phase 0: Outline & Research (DONE)
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

## Phase 1: Design & Contracts (DONE)
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

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

## Phase 2: Task Planning Approach (DONE)
tasks.md 已生成并包含 45 个分阶段任务，覆盖：
- 合同测试 (T005–T007)
- 集成（用户故事 & 场景）测试 (T008–T012)
- 模型 / 核心实体桩 (T013–T020)
- 渲染器 & 处理器实现序列 (T021–T029)
- 缓存/并发/冲突/超时/安全 (T030–T036)
- 性能、统计、文档、发布、确定性验证 (T037–T045)

任务标注 [P] 的代表可并行（文件互不冲突），执行顺序保持红→绿（TDD）与依赖拓扑。

## Phase 3+: Future Implementation
后续将按 tasks.md 顺序执行（严格先测试后实现），并在性能基准产出后回补 FR-042 硬阈值（若需）。

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
**Phase Status**:
- [x] Phase 0: Research complete
- [x] Phase 1: Design complete
- [x] Phase 2: Task planning complete (tasks.md present)
- [ ] Phase 3: Tasks generated & executed
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (None)

---
*Based on Constitution v2.0.0 - See `.specify/memory/constitution.md`*
