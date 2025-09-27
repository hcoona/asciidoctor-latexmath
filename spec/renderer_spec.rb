# frozen_string_literal: true

require "rspec"
require "asciidoctor"
require_relative "../lib/asciidoctor-latexmath/renderer"

RSpec.describe Asciidoctor::Latexmath::Renderer do
  let(:document) do
    instance_double(Asciidoctor::Document).tap do |doc|
      allow(doc).to receive(:attr?).and_return(false)
      allow(doc).to receive(:attr).and_return(nil)
      allow(doc).to receive(:normalize_system_path) { |path, *_| path }
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
end
