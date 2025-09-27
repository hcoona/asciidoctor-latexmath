# asciidoctor-latexmath

Offline `latexmath` rendering for Asciidoctor documents powered by your local LaTeX toolchain.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Output Formats](#output-formats)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Document Attributes](#document-attributes)
- [Why asciidoctor-latexmath?](#why-asciidoctor-latexmath)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

## Overview

`asciidoctor-latexmath` is an Asciidoctor extension that renders `latexmath` blocks and inline macros into static images. It leverages the LaTeX toolchain already installed on your system so you can produce consistent formulas in environments where MathJax or similar browser-side renderers are not an option.

## Features

- **Offline-first rendering** – no external services or JavaScript runtime required.
- **LaTeX fidelity** – relies on the same `pdflatex`, `xelatex`, or `lualatex` tooling used for high-quality print workflows.
- **Multiple output formats** – generate PDF, SVG, or PNG assets to match your target backend.
- **Drop-in integration** – register the extension once and keep authoring with the familiar `latexmath` syntax.

## How It Works

1. The extension intercepts `latexmath` blocks and inline macros during the Asciidoctor conversion pipeline.
2. The captured TeX snippet is compiled with your preferred LaTeX engine (`pdflatex`, `xelatex`, `lualatex`, or `tectonic`) into a minimal standalone document.
3. The resulting PDF is post-processed into the requested target format (PDF/SVG/PNG).
4. The rendered asset is embedded back into the document output so it behaves like any other image.

All processing happens locally, which keeps your documentation builds reproducible and secure.

## Output Formats

| Format | Description | Typical Use Cases |
| ------ | ----------- | ----------------- |
| `pdf`  | Keeps the raw LaTeX PDF output for backends that accept vector PDFs. | Asciidoctor PDF, print-ready workflows |
| `svg`  | Converts the PDF to scalable vector graphics. | Responsive HTML output, retina displays |
| `png`  | Rasterizes the PDF into a bitmap image. | Legacy HTML pipelines, slide decks |

## Prerequisites

Make sure the following tools are available on your system `PATH` before enabling the extension:

- **Ruby 3.3+** and **Asciidoctor 2.0+**
- A LaTeX engine such as **`pdflatex`**, **`xelatex`**, **`lualatex`**, or **`tectonic`** (provided by TeX Live, MiKTeX, MacTeX, etc.)
- Optional: **`dvisvgm`** for SVG conversion and **ImageMagick** or **ghostscript** for PNG conversion
- Computer Modern fonts (usually bundled with the TeX distribution)

You can verify `pdflatex` availability with:

```bash
pdflatex --version
```

Swap in another engine if that is your default workflow—for example, `xelatex --version` or `tectonic --help`.

## Installation

### Using RubyGems

```bash
gem install asciidoctor-latexmath
```

### Using Bundler

```ruby
gem 'asciidoctor-latexmath'
```

Run `bundle install` to make the extension available to your project.

### From Source

Clone this repository and point Asciidoctor at the local checkout:

```bash
git clone https://github.com/your-org/asciidoctor-latexmath.git
cd asciidoctor-latexmath
bundle install
```

Then require the extension via a relative path (see [Quick Start](#quick-start)).

## Quick Start

Render a document with offline `latexmath` support:

```bash
asciidoctor -r asciidoctor-latexmath -a latexmath-format=svg sample.adoc
```

Select a different engine by providing the `pdflatex` attribute at runtime. For example, to build with `tectonic`:

```bash
asciidoctor -r asciidoctor-latexmath -a pdflatex=tectonic -a latexmath-format=svg sample.adoc
```

During development, load the registration file directly from your working tree:

```bash
asciidoctor -r ./lib/asciidoctor-latexmath.rb -a latexmath-format=svg sample.adoc
```

Sample AsciiDoc snippet:

```adoc
The famous mass-energy equivalence equation is shown below.

[latexmath]
+++
E = mc^2
+++

Einstein also described spacetime curvature with the inline latexmath:[E_{\mu\nu} = 8 \pi T_{\mu\nu}] variant.
```

The extension replaces both expressions with rendered images that match the format specified in `latexmath-format`.

## Document Attributes

| Attribute | Description | Values | Default |
| --------- | ----------- | ------ | ------- |
| `stem` | Enables global stem support. Set to `latexmath` (or `tex`) to make bare `stem:[...]` invocations render through this extension. | `latexmath`, `tex`, etc. | *(not set)* |
| `latexmath-format` | Desired output format for generated assets. | `pdf`, `svg`, `png` | `svg` |
| `latexmath-inline` | Embed inline formulas directly into the HTML output instead of linking to image files. Works with `svg` (inline markup) and `png` (data URI). | `true`, `false` | `false` |
| `latexmath-ppi` | Pixels per inch for PNG rasterization. Ignored for `pdf`/`svg`. | Any positive number | `300` |
| `latexmath-preamble` | Extra LaTeX preamble inserted before `\begin{document}`. Useful for additional packages or macro definitions. | LaTeX snippet | *(empty)* |
| `pdflatex` | Command used to compile the temporary LaTeX document. | `pdflatex`, `xelatex`, `lualatex`, `tectonic`, absolute path | `pdflatex` |
| `latexmath-pdf2svg` | Converter used when `latexmath-format=svg`. Override if your toolchain provides an alternative. | `pdf2svg`, absolute path | `pdf2svg` |
| `latexmath-png-tool` | Converter used when `latexmath-format=png`. The extension auto-detects `magick`, `convert`, or `pdftoppm`; set this attribute to force a specific command. | Command name or path | *(auto)* |
| `latexmath-keep-artifacts` | Preserve the generated `.tex`, `.log`, and intermediate PDF files for inspection. | `true`, `false` | `false` |
| `latexmath-artifacts-dir` | Destination directory for kept artifacts when `latexmath-keep-artifacts=true`. Relative paths are resolved from the document directory. | Path | `imagesoutdir` (or document directory) |

All generated images follow Asciidoctor's standard image directory rules. Set `imagesoutdir` to control where files are written on disk and `imagesdir` to influence how they are referenced from the rendered document. Inline math inside literal table cells is also supported—the extension adds macro substitutions automatically so the rendered `<span class="image">…</span>` markup appears inside the literal block.

Set attributes via the CLI or document header, for example: `-a latexmath-format=png`.

## Why asciidoctor-latexmath?

| Feature | asciidoctor-latexmath | asciidoctor-mathematical |
| ------- | --------------------- | ------------------------- |
| Input types | `latexmath` only | `latexmath` and `stem` |
| Rendering backend | Local LaTeX engine (`pdflatex`/`xelatex`/`lualatex`/`tectonic`) | Native Mathematical library |
| Output formats | PDF, SVG, PNG | PNG (default) / SVG |
| External dependencies | Leverages standard LaTeX installation | Requires the Mathematical gem and Cairo stack |

Choose `asciidoctor-latexmath` when you already depend on a LaTeX distribution and want fully offline builds with minimal additional dependencies.

## Troubleshooting

- **LaTeX engine not found** – install a LaTeX distribution (TeX Live, MiKTeX, MacTeX, or Tectonic) and ensure the binaries are on your `PATH`.
- **Blank or clipped formulas** – enable `-a latexmath-keep-artifacts=true` and inspect the generated `.log` file for LaTeX errors.
- **Missing glyphs** – install Computer Modern or other math-capable fonts that ship with TeX Live/MacTeX.
- **Slow builds** – consider caching the generated assets or pre-rendering formulas as part of your CI pipeline.

## Contributing

Bug reports, feature requests, and patches are welcome. Please open an issue describing the use case before submitting large changes. If you plan to contribute code, follow the established Ruby style guidelines and add documentation or samples for new behaviors.

## Author

Created and maintained by Shuai Zhang.

## License

Licensed under the **LGPL-3.0-or-later WITH LGPL-3.0-linking-exception**. See `LICENSE` for the full text.
