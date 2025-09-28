# frozen_string_literal: true

require "rspec"
require "asciidoctor"
require "tmpdir"
require "fileutils"
require_relative "../lib/asciidoctor-latexmath/renderer"

RSpec.describe Asciidoctor::Latexmath::Renderer do
  let(:attributes) { {} }

  let(:document) do
    instance_double(Asciidoctor::Document).tap do |doc|
      allow(doc).to receive(:attr?) { |name| !!attributes[name.to_s] }
      allow(doc).to receive(:attr) { |name| attributes[name.to_s] }
      allow(doc).to receive(:normalize_system_path) do |path, base = nil|
        if base
          File.expand_path(path.to_s, base)
        else
          File.expand_path(path.to_s)
        end
      end
    end
  end

  before do
    allow_any_instance_of(described_class).to receive(:resolve_command) do |_instance, cmd, **_|
      cmd
    end
    allow_any_instance_of(described_class).to receive(:resolve_png_tool).and_return("magick")
  end

  subject(:renderer) { described_class.new(document) }

  describe "#build_document" do
    it "wraps simple display equations with display math delimiters" do
      latex_document = renderer.send(:build_document, "a^2+b^2=c^2", true)
      expect(latex_document).to include("\\[a^2+b^2=c^2\\]")
    end

    it "wraps simple inline equations with inline math delimiters" do
      latex_document = renderer.send(:build_document, "a^2+b^2=c^2", false)
      expect(latex_document).to include("\\(a^2+b^2=c^2\\)")
    end

    it "does not wrap equations already containing latex environments when display" do
      equation = <<~LATEX.strip
        \\begin{gather*}
          \\alpha_a :: F a \\to G a \\\\
          \\alpha_b :: F b \\to G b
        \\end{gather*}
      LATEX

      latex_document = renderer.send(:build_document, equation, true)

      expect(latex_document).to include("\\begin{gather*}")
      expect(latex_document).not_to include("\\[")
    end

    it "does not wrap equations already containing latex environments when inline" do
      equation = <<~LATEX.strip
        \\begin{aligned}
          x &= y + 1 \\\\
          y &= z
        \\end{aligned}
      LATEX

      latex_document = renderer.send(:build_document, equation, false)

      expect(latex_document).to include("\\begin{aligned}")
      expect(latex_document).not_to include("\\(")
    end

    it "preserves double backslashes within latex environments" do
      equation = <<~LATEX.strip
        \\begin{gather*}
        a \\to \\mathbf{C}(L a, b) \\\\
        a \\to \\mathbf{D}(a, R b)
        \\end{gather*}
      LATEX

      latex_document = renderer.send(:build_document, equation, true)

      expected_line = <<~'LINE'
        a \to \mathbf{C}(L a, b) \\
      LINE
      expect(latex_document).to include(expected_line)
      expect(latex_document).to include("a \\to \\mathbf{D}(a, R b)")
    end
  end

  describe "caching" do
    let(:workspace_dir) { Dir.mktmpdir("latexmath-spec-") }

    before do
      attributes["docdir"] = workspace_dir
      attributes["outdir"] = workspace_dir
    end

    after do
      FileUtils.remove_entry(workspace_dir) if File.exist?(workspace_dir)
    end

    it "reuses cached svg renderings for repeated equations" do
      allow(renderer).to receive(:run_pdflatex) do |tex_path, dir, **_opts|
        pdf_path = File.join(dir, "#{File.basename(tex_path, ".tex")}.pdf")
        File.write(pdf_path, "%PDF-1.4\n%stub")
      end

      call_count = 0
      allow(renderer).to receive(:handle_svg) do |_pdf_path, _dir, basename, inline_embed|
        call_count += 1
        expect(inline_embed).to eq(false)
        Asciidoctor::Latexmath::RenderResult.new(
          format: :svg,
          data: "<svg>cached</svg>",
          extension: "svg",
          width: 120.0,
          height: 45.0,
          basename: basename
        )
      end

      first = renderer.render(equation: "a^2+b^2=c^2", display: false, inline: false)
      second = renderer.render(equation: "a^2+b^2=c^2", display: false, inline: false)

      expect(call_count).to eq(1)
      expect(renderer).to have_received(:run_pdflatex).once
      expect(second.data).to eq(first.data)
      expect(second.width).to eq(first.width)
      expect(second.height).to eq(first.height)
    end

    it "caches inline svg renderings when latexmath-inline is enabled" do
      attributes["latexmath-inline"] = true
      allow(renderer).to receive(:run_pdflatex) do |tex_path, dir, **_opts|
        pdf_path = File.join(dir, "#{File.basename(tex_path, ".tex")}.pdf")
        File.write(pdf_path, "%PDF-1.4\n%stub")
      end

      handle_calls = 0
      inline_markup = %(<span class="latexmath-inline">inline</span>)

      allow(renderer).to receive(:handle_svg) do |_pdf_path, _dir, basename, inline_embed|
        handle_calls += 1
        expect(inline_embed).to eq(true)
        Asciidoctor::Latexmath::RenderResult.new(
          format: :svg,
          data: "<svg>inline</svg>",
          inline_markup: inline_markup,
          extension: "svg",
          width: 80.0,
          height: 30.0,
          basename: basename
        )
      end

      first = renderer.render(equation: "f(x)=x^2", display: false, inline: true)
      second = renderer.render(equation: "f(x)=x^2", display: false, inline: true)

      expect(handle_calls).to eq(1)
      expect(renderer).to have_received(:run_pdflatex).once
      expect(second.inline_markup).to eq(first.inline_markup)
      expect(second.data).to eq(first.data)
    ensure
      attributes.delete("latexmath-inline")
    end
  end
end
