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
- Q: 渲染时对 LaTeX 源（公式正文与 `preamble`）的信任级别是哪种? → A: 完全可信（受控仓库作者）；禁用 shell-escape，额外沙箱/FS 隔离不在 v1 范围。
- Q: 默认缓存目录策略? → A: 与 asciidoctor-diagram 逻辑对齐（名称替换为 latexmath）：优先元素 `cachedir=`，否则文档级 `:latexmath-cachedir:`，否则回退 `<outdir>/.asciidoctor/latexmath`；不使用 imagesdir；示例：`-D build/out` 时默认为 `build/out/.asciidoctor/latexmath`。
- Q: 并行渲染/调度策略? → A: 不内建并行（单进程串行，Option E）；v1 仅保障跨进程并发安全（多 Asciidoctor 进程指向同一缓存目录）；预留未来扩展 `:latexmath-jobs:`（Option D 风格）但当前未实现。
- Q: 缓存回收 / 老化策略? → A: 无自动回收（Option A）；v1 不进行大小/TTL 扫描，不输出阈值告警；完全由用户手动删除；未来如引入策略将新增独立属性并保持向后兼容。
- Q: 显式目标基名冲突策略? → A: 检测差异并报错（Option B）；同名且内容/配置哈希不同立即构建失败，提示首次定义位置与冲突条目；哈希相同则复用不重复写。
- Q: 未指定目标名时自动生成文件基名采用何种稳定方案? → A: 使用前缀 `lm-` + 正规化内容 SHA256 哈希前 16 个十六进制字符 (共 19 字符)，长度与可读性平衡并提供 64bit 熵；与缓存键独立，冲突极低（<1e-11 级别针对 ≤5k 公式）。
 - Q: 正规化内容算法选哪种策略以计算文件基名与 content_hash? → A: 采用 Option E（仅去 UTF-8 BOM，保留原始所有空白、制表符、行结尾 CRLF/LF 原样），不裁剪首尾，不折叠内部空白；跨平台行结尾差异将导致不同哈希，视为可接受的构建环境差异；理由：最大限度保持 LaTeX 敏感空白（对某些宏可能影响）与调试可追溯性。
 - Q: 性能指标阈值是否在 v1 规格中量化? → A: 选 Option E（暂不固化具体数值）；定义“性能可接受”= 简单公式（≤120 字符，无自定义 preamble）冷启动渲染不会显著拖慢 CI（经验目标 p95 < 3s，如超过需在后续基准后回补强制阈值条目）。
 - Q: 集成 / CLI 层测试的文件系统隔离策略? → A: 使用 Aruba (RSpec) 沙箱，每个示例独立临时目录与隔离环境变量，避免状态泄漏并便于命令行行为回归测试。
 - Q: 统计输出格式策略? → A: 选 MIN：当日志级别≥info 且至少处理 1 个表达式，在渲染会话结束时输出单行纯文本：`latexmath stats: renders=<int> cache_hits=<int> avg_render_ms=<int> avg_hit_ms=<int>`；字段顺序与名称稳定且永不新增额外键；`avg_render_ms` 为所有实际执行渲染（非缓存命中）耗时的算术平均（四舍五入到整数 ms），`avg_hit_ms` 为所有命中耗时平均（若无命中则为 0）；quiet 或低于 info 不输出；禁止在同一会话重复输出多行统计。
- Q: v1 HTML 可访问性文本策略（渲染产物标签）采用哪种方案? → A: 选 Option D：alt=原始 LaTeX（逐字），并在标签上添加 `role="math"` 与 `data-latex-original` 属性以利辅助技术与后续增强（无截断策略；与内容哈希逻辑独立）。
- Q: 典型与需支撑的最大公式数量规模假设? → A: 选 Option E：不设上限；需可流式处理任意规模（IO/缓存驱动）并保持近线性扩展，不强制内存常驻全部表达式。
- Q: 单个公式渲染失败（编译/工具错误）时文档处理策略? → A: 可配置：文档/元素属性 `latexmath-on-error`（或 `on-error=`）取值 `log|abort`；默认 `log`（继续其它公式并插入占位，整体构建成功）；`abort` 表示 fail-fast（立即终止整体失败）。块级属性覆写文档级；不支持自动重试；未识别值时报错并回落默认 `log`。

- Q: 失败占位（on-error=log）HTML 呈现策略? → A: 使用 `<pre class="highlight latexmath-error">`；内部顺序包含：1) 简短错误描述 2) 执行命令 3) stdout 4) stderr 5) 原始 AsciiDoc 文本 6) 生成的 LaTeX 源；该占位不缓存、不写入统计 renders、仅在策略=log 且单表达式失败时生成；保留换行与缩进供诊断；不截断（未来如需截断将引入独立属性并保持向后兼容）。

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
- **FR-006**: MUST 支持块级/内联 `format=`、`ppi=`、`pdflatex=`、`pdf2svg=`、`png-tool=`、`preamble=`、`cache=`、`cachedir=`、`artifacts-dir=` 覆写；`cache-dir=` 早期草案命名弃用（可作为别名接受但不在文档公开）。
- **FR-007**: MUST 支持元素选项 `%nocache` 与 `keep-artifacts`，准确控制该元素缓存与产物保留。
- **FR-008**: MUST 生成的输出文件置于 `imagesoutdir`（若未设置则退回 `imagesdir` 再退回文档目录）。
- **FR-009**: MUST 对块首个位置属性解释为目标基名，第二个位置属性可解释为格式（与 asciidoctor-diagram 中块行为一致）；不适用块宏语法。
- **FR-010**: MUST 为未指定目标名的表达式生成稳定且基于内容哈希的文件基名：算法 = 取得“正规化内容” (Normalization-E)：仅移除 UTF-8 BOM；其余字节序列（含制表符、CRLF 或混合行结尾、行尾空白、前后导空白）全部保留原样；计算 SHA256，对其十六进制串取前 16 个字符，加前缀 `lm-` 得基名（例：`lm-a1b2c3d4e5f6a7b8`）。文件扩展名由最终格式决定；用户显式提供基名时跳过此规则。若该 16 字符截断产生与不同内容/配置的另一表达式基名冲突（极低概率），在写入阶段检测：追加 `-1`,`-2` 递增直到不冲突，并记录单次 WARN；递增后基名不再回溯修改缓存键（缓存键使用完整 SHA256）。
- **FR-011**: MUST 缓存键包含：内容哈希（同 FR-010 Normalization-E）、最终格式、引擎类型、preamble 哈希、工具版本签名、PPI、入口类型（块/内联）、扩展版本。
- **FR-012**: MUST 在任何引起缓存键组成部分变化时强制重新渲染。
- **FR-013**: MUST 在并行运行（多进程）中防止竞争条件：采用内容哈希命名 + 先写入临时文件（同目录 `<name>.tmp-<pid>`）后原子重命名；目标文件已存在即视为成功并跳过；需避免半写文件、脏读；可选基于锁文件 `<hash>.lock`（获取失败时指数退避重试 ≤ 5 次）。
- **FR-014**: MUST 在渲染失败时（非 0 退出码）输出：执行命令、退出码、日志文件路径、建议下一步。
   - NOTE: 与 FR-045 协同；当当前作用域（元素→文档）解析 `on-error=abort` 时触发 fail-fast；否则记录错误并生成占位（见 FR-045）。
- **FR-015**: MUST 支持用户关闭缓存（文档级或元素级），关闭后不读取也不写入缓存。
- **FR-016**: MUST 允许 `latexmath-preamble` 追加多行文本；空值不产生额外空行副作用。
- **FR-017**: MUST 默认禁止潜在危险的外部命令执行（无显式允许时不启用 shell escape）。
- **FR-018**: MUST 为 PNG 输出应用 PPI（≥72 且 ≤600）范围校验; 超出时报错。
- **FR-019**: MUST 对不支持的格式、属性值、工具名给出枚举提示信息。
- **FR-020**: MUST 在首次加载时检测可用工具并缓存结果，避免重复探测影响性能。
- **FR-021**: MUST 在启用 `keep-artifacts` 时保留 `.tex`、`.log`、中间 PDF 至指定 artifacts 目录。
- **FR-022**: MUST 可统计（可选日志级别）渲染次数、缓存命中次数、平均渲染耗时。统计输出契约 (MIN)：当日志级别≥info 且本次会话 renders+cache_hits>0 时仅输出 1 行：`latexmath stats: renders=<int> cache_hits=<int> avg_render_ms=<int> avg_hit_ms=<int>`；四字段与顺序固定；`avg_render_ms`、`avg_hit_ms` 为四舍五入整数毫秒；无命中时 `avg_hit_ms=0`；不得添加新字段；低于 info 不输出；多次调用扩展（多文档）可各自输出一行。
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
- **FR-035**: SHOULD 统计输出仅随日志级别（info 及以上）显示；不提供文档/元素级属性；当日志级别 quiet 或低于 info 不输出统计；需测试日志级别切换的可控性。禁止在单文档渲染生命周期内输出多于一行统计；若 renders=0 可完全省略。
- **FR-036**: MUST 采用“受控仓库作者完全可信”信任模型：假设公式与 preamble 来自可信源；实现禁用 shell-escape（见 FR-017）但不增加额外沙箱/文件系统隔离；多租/不可信输入强化措施（隔离目录、内存/CPU 限额）列为未来范围外。
- **FR-037**: MUST 缓存目录解析顺序：1) 元素属性 `cachedir=` 明确指定（相对路径基于文档 outdir 解析）；2) 文档属性 `:latexmath-cachedir:`；3) 默认 `<outdir>/.asciidoctor/latexmath`；其中 `outdir` 由 Asciidoctor 决议（命令行 `-D` / 文档属性 / 执行工作目录）。若路径不存在需在渲染前创建；不得回退至 imagesdir。应允许旧别名 `cache-dir=` / `:latexmath-cache-dir:` 但发出一次去precation 日志（info 级）。
- **FR-038**: MUST 不内建并行渲染调度（单进程串行队列）；跨进程并发仅依赖 FR-013 原子写保障；预留文档属性 `:latexmath-jobs:`（保留字，当前解析后记录 Warning 并忽略）以便未来扩展为可配置并行度（默认 cores）。
- **FR-039**: MUST 不实施任何自动缓存逐出/清理：不基于大小、文件数或 TTL 扫描删除；插件不对缓存目录做周期遍历。用户如需清理，需手动删除目录（安全：再生成时按键重建）。未来策略（大小 / TTL / LRU）将通过新属性显式启用，保持默认行为不变。
- **FR-040**: MUST 当两个以上表达式（内容或配置不同 → 缓存键不同）显式请求相同目标基名 + 相同格式时：在首次检测到第二个冲突时抛出可操作错误，列出：目标名、原始定义（行/块标识）、新定义摘要（前 80 字符哈希前缀）、建议（移除显式目标名或改名）。若缓存键相同（完全同一内容与配置）则视为幂等：不重写文件亦不警告。检测需在写入前完成（结合 FR-013 原子策略）。
 - **FR-041**: MUST 集成与端到端命令行测试使用 Aruba（或功能等价沙箱）确保：每测试示例独立临时工作目录、环境变量清理、无跨示例残留文件；测试可通过 helper 提供对渲染产物与日志的断言；不得依赖真实用户 HOME / 全局缓存副作用。
 - **FR-042**: SHOULD 在首次实现后生成一份性能基准（≥30 个简单公式批量：SVG 冷/热 + PNG）并记录：冷启动 p50/p95、缓存命中追加开销、平均渲染耗时；若 SVG 冷 p95 > 3000ms 或 PNG 冷 p95 > 3500ms 则需在后续迭代将明确量化阈值添加为 MUST（更新本 spec 与 README）。当前版本不锁定硬阈值（见 Clarifications）。
- **FR-043**: MUST 生成 HTML 时，对由扩展替换的数学公式引用（`<img>` 或等效占位）添加可访问性元数据：`alt` 属性内容 = 原始 LaTeX 源（逐字保留，不截断，不做命令剥离）；附加 `role="math"` 与 `data-latex-original`（同 alt 内容）属性；若用户已手动提供 `alt` 元素属性（块/内联属性）则优先用户值且仍附加 `role` 与 `data-latex-original`（不覆盖用户 alt）。该行为适用于三种输出格式 (svg/pdf/png)；与缓存 / 基名 / 哈希策略无副作用；测试应验证：存在 alt、role、data-latex-original 且三者一致（当未用户覆写）。
- **FR-044**: MUST 不对文档中数学公式总数施加内建上限；应可在公式数量无限增长（例如 ≥10k）时维持近线性总耗时增长，并避免除缓存与统计所需外的 O(n) 级内存累积（处理单个表达式后释放中间状态）；失败公式的错误处理策略另行定义（见后续 Clarifications）。性能基准场景需包含 ≥5k 简单公式批量以验证无指数退化。
- **FR-045**: MUST 提供失败策略属性：文档级 `:latexmath-on-error:`，元素级 `on-error=`；允许值 `log` 与 `abort`；默认 `log`。`abort` → 在首次失败立即终止转换并返回错误；`log` → 记录错误（与 FR-014 输出一致）并在输出中插入结构化占位（见 FR-046），继续处理剩余表达式，最终构建成功且统计中不计入成功渲染次数（renders 不含失败项）。非法值时报错并回退默认 `log`。缓存不记录失败产物。
 - **FR-046**: MUST 当失败策略=log 且单表达式渲染失败时插入 `<pre class="highlight latexmath-error" role="note" data-latex-error="1">` 占位，内部文本段落按顺序包含：
    1. `Error:` + 简短错误描述（单行）
    2. `Command:` + 完整执行命令字符串
    3. `Stdout:` 原样（空则写 `<empty>`）
    4. `Stderr:` 原样（空则写 `<empty>`）
    5. `Source (AsciiDoc):` 原始表达式（如为块包含多行）
    6. `Source (LaTeX):` 生成的 `.tex` 文件主内容（preamble + 公式）
   分节之间以单个空行分隔；仅进行 HTML 必要转义（`&`, `<`, `>` 等）；不额外截断；不写入缓存；不计入成功渲染统计；未来若需截断/精简将通过新增属性控制并保持向后兼容。


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
