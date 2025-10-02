# Feature Specification: Asciidoctor Latexmath Offline Rendering Extension

**Feature Branch**: `001-asciidoctor-latexmath-asciidoctor`
**Created**: 2025-10-02
**Status**: Draft
**Input**: User description: "开发 asciidoctor-latexmath 插件: 作为 Asciidoctor extension 处理 latexmath 内联宏、块宏与块, 使用本地 LaTeX 工具链离线渲染为 PDF/SVG/PNG 并嵌入输出, 支持通过文档和块级 AsciiDoc attributes 配置格式、缓存、工具链选择 (pdflatex/xelatex/lualatex/tectonic)、preamble、PNG 工具 (pdftoppm/magick/gs)、SVG 工具 (dvisvgm/pdf2svg)、DPI、缓存目录、保留产物、禁用缓存、内联 data URI, 保持行为与 asciidoctor-diagram 一致, 不使用 TreeProcessor 与 Mathematical gem, 保证可重复构建、确定性缓存、TDD 工作流、语义化版本控制、安全 & 超时机制。"

## Execution Flow (main)
```
1. Parse user description from Input
   → If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   → Identify: actors, actions, data, constraints
3. For each unclear aspect:
   → Mark with [NEEDS CLARIFICATION: specific question]
4. Fill User Scenarios & Testing section
   → If no clear user flow: ERROR "Cannot determine user scenarios"
5. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
6. Identify Key Entities (if data involved)
7. Run Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Spec has uncertainties"
   → If implementation details found: ERROR "Remove tech details"
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

### Section Requirements
- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation
When creating this spec from a user prompt:
1. **Mark all ambiguities**: Use [NEEDS CLARIFICATION: specific question] for any assumption you'd need to make
2. **Don't guess**: If the prompt doesn't specify something (e.g., "login system" without auth method), mark it
3. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
4. **Common underspecified areas**:
   - User types and permissions
   - Data retention/deletion policies
   - Performance targets and scale
   - Error handling behaviors
   - Integration requirements
   - Security/compliance needs

---

## Clarifications

### Session 2025-10-02
- Q: FR-033 v1 是否需要插件自带的独立 data URI 开关 / 默认是否启用内联? → A: 不提供独立开关；v1 仅继承 Asciidoctor 全局 `:data-uri:` 行为，不自行生成 `data:` URL；当检测到 `data-uri` 属性时仅改用产物绝对路径（与 `asciidoctor-diagram` 一致），未来可扩展细粒度策略。
- Q: 超时属性命名与单位选哪种方案? → A: 采用文档级 `:latexmath-timeout:` （正整数秒），元素级 `timeout=` 覆写；不支持毫秒与多属性回退。
- Q: 统计禁用设计（FR-035）采用哪种方案? → A: 通过日志级别控制统计输出；不引入专有属性；降低日志级别（quiet）即抑制统计。
- Q: 是否支持 `latexmath::[]` 块宏语法? → A: 不支持；范围限定为 `[latexmath]` 块与 `latexmath:[...]` 内联宏两种入口。

## User Scenarios & Testing *(mandatory)*

### Primary User Story
作为技术写作者 / CI 构建系统, 我希望在离线或受限网络环境中把文档中所有 `latexmath` 数学公式（块、块宏、内联）一次性渲染为所需的矢量或位图资源 (SVG / PDF / PNG), 并在重复构建时复用缓存, 以保证输出质量、构建速度和可重复性。

### Acceptance Scenarios
1. **Given** 文档设置 `:stem: latexmath` 且默认 `:latexmath-format: svg`, **When** 运行文档转换, **Then** 每个 `latexmath` 块 / 内联公式被渲染为单个 SVG 文件并写入 `imagesoutdir`, 文档中对应位置引用这些 SVG, 重复运行构建时同一内容不重新调用外部工具 (缓存命中统计≥1)。
2. **Given** 用户请求 `:latexmath-format: svg` 但系统缺少 `dvisvgm` 与 `pdf2svg`, **When** 执行构建, **Then** 构建失败并输出清晰错误: 缺失的命令列表、建议安装方式、指向禁用或切换格式的提示, 不产生半成品文件。
3. **Given** 用户在块级添加 `[%nocache]` 与 `format=png, ppi=200`, **When** 构建两次, **Then** 该块两次都重新渲染且生成 PNG (200 PPI) 文件名保持一致, 其它未加 `%nocache` 的表达式复用缓存。
4. **Given** 并行构建 (两个独立进程) 渲染同一公式文本, **When** 同时启动, **Then** 结果只有一个缓存条目被写入 (无损坏 / 无临时文件泄漏) 且两个进程均成功引用该产物。

### Edge Cases
- 请求不支持的格式 (如 `format=gif`) → 明确错误并列出受支持集合。
- 指定工具不存在或无执行权限。
- `latexmath-preamble` 含非法 LaTeX 指令导致编译失败。
- 大型公式 (>10KB 源) 或深度递归宏。
- `latexmath-cache=false` 与 元素 `%nocache` 混合使用。
- 同一文档中混合 `svg` 与 `png` 输出需求。
- 超时：外部工具长时间挂起。
- Windows / Linux 路径差异 (相对路径解析)。
- 内联公式选择 data URI (未来扩展) 与默认文件引用并存。

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: MUST 支持两种入口语法：`[latexmath]` 块 与 `latexmath:[...]` 内联宏（包含文档属性与元素属性覆写）；MUST NOT 支持 `latexmath::[]` 块宏形式。
- **FR-002**: MUST 依据文档或元素属性渲染为 `svg|pdf|png` 三种格式之一；默认 `svg`。
- **FR-003**: MUST 允许用户通过属性选择编译引擎 (pdflatex/xelatex/lualatex/tectonic)。
- **FR-004**: MUST 在缺少所需工具链时以可操作错误终止，列出缺失命令与建议解决方式。
- **FR-005**: MUST 在同一内容+配置组合下重复构建时命中缓存且不重复调用外部命令（命中率可统计）。
- **FR-006**: MUST 支持块级/内联 `format=`、`ppi=`、`pdflatex=`、`pdf2svg=`、`png-tool=`、`preamble=`、`cache=`、`cache-dir=`、`artifacts-dir=` 覆写。
- **FR-007**: MUST 支持元素选项 `%nocache` 与 `keep-artifacts`，准确控制该元素缓存与产物保留。
- **FR-008**: MUST 生成的输出文件置于 `imagesoutdir`（若未设置则退回 `imagesdir` 再退回文档目录）。
- **FR-009**: MUST 对块首个位置属性解释为目标基名，第二个位置属性可解释为格式（与 asciidoctor-diagram 中块行为一致）；不适用块宏语法。
- **FR-010**: MUST 为未指定目标名的表达式生成稳定且基于内容哈希的文件基名，避免冲突。
- **FR-011**: MUST 缓存键包含：内容哈希、最终格式、引擎类型、preamble 哈希、工具版本签名、PPI、入口类型（块/内联）、扩展版本。
- **FR-012**: MUST 在任何引起缓存键组成部分变化时强制重新渲染。
- **FR-013**: MUST 在并行运行中防止竞争条件（无局部半写文件；写操作原子）。
- **FR-014**: MUST 在渲染失败时（非 0 退出码）输出：执行命令、退出码、日志文件路径、建议下一步。
- **FR-015**: MUST 支持用户关闭缓存（文档级或元素级），关闭后不读取也不写入缓存。
- **FR-016**: MUST 允许 `latexmath-preamble` 追加多行文本；空值不产生额外空行副作用。
- **FR-017**: MUST 默认禁止潜在危险的外部命令执行（无显式允许时不启用 shell escape）。
- **FR-018**: MUST 为 PNG 输出应用 PPI（≥72 且 ≤600）范围校验; 超出时报错。
- **FR-019**: MUST 对不支持的格式、属性值、工具名给出枚举提示信息。
- **FR-020**: MUST 在首次加载时检测可用工具并缓存结果，避免重复探测影响性能。
- **FR-021**: MUST 在启用 `keep-artifacts` 时保留 `.tex`、`.log`、中间 PDF 至指定 artifacts 目录。
- **FR-022**: MUST 可统计（可选日志级别）渲染次数、缓存命中次数、平均渲染耗时。
- **FR-023**: MUST 在超时（默认 120s）后终止外部进程并报告超时（含建议调高/简化公式）。
- **FR-024**: MUST 对内联公式输出参考（文件或未来 data URI）；默认文件引用。
- **FR-025**: MUST 不使用 TreeProcessor 或依赖 Mathematical；若检测到冲突（同时启用 mathematical）提示优先级与迁移。
- **FR-026**: MUST 遵循宪章 TDD：拒绝在无对应失败测试前合入新行为（通过 CI Gate 控制）。
- **FR-027**: MUST 文档化所有支持属性（README/Attributes 表格同步）。
- **FR-028**: MUST 允许在同一文档中混用不同输出格式；彼此缓存隔离。
- **FR-029**: MUST 正确处理含 Unicode 字符（通过非 ASCII 公式用例验证）。
- **FR-030**: SHOULD 在工具缺失时建议替代（如缺少 `dvisvgm` → 提示使用 `pdf2svg` 或更换目标格式）。
- **FR-031**: SHOULD 在启动时输出一次工具签名摘要（可禁用）。
- **FR-032**: SHOULD 为重复出现的大型公式记录单独耗时便于性能诊断。
- **FR-033**: SHOULD（未来扩展）支持独立于全局 `:data-uri:` 的细粒度内联策略；v1 不提供专有 data URI 开关，仅继承 Asciidoctor 核心 `:data-uri:` 行为并通过绝对路径辅助核心内联。
- **FR-034**: SHOULD 允许用户自定义渲染超时：文档级属性 `:latexmath-timeout:` （正整数秒，默认 120），元素级属性 `timeout=` 可覆写当前表达式；非法或非正整数值应报错并回退默认。
- **FR-035**: SHOULD 统计输出仅随日志级别（info 及以上）显示；不提供文档/元素级属性；当日志级别 quiet 或低于 info 不输出统计；需测试日志级别切换的可控性。


### Key Entities *(include if feature involves data)*
- **Math Expression**: 用户在文档中的原始 LaTeX 公式文本（块/宏/内联）。
- **Rendering Request**: 一次独立渲染操作的抽象，绑定表达式、格式、工具链选择与归一化属性集合。
- **Output Artifact**: 最终产物文件 (svg/pdf/png) 及可选调试文件集合。
- **Cache Entry**: 由缓存键映射到产物路径与元数据（命中次数、生成时间、工具签名摘要）。
- **Toolchain Configuration**: 用户声明的引擎与转换工具组合；决定管线步骤。
- **Statistics Record**: 可选聚合指标（渲染次数、平均耗时、命中率）。

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] Written for non-technical stakeholders
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous
- [ ] Success criteria are measurable
- [ ] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [ ] User description parsed
- [ ] Key concepts extracted
- [ ] Ambiguities marked
- [ ] User scenarios defined
- [ ] Requirements generated
- [ ] Entities identified
- [ ] Review checklist passed

---

*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
