# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "tmpdir"
require "fileutils"
require "open3"
require "shellwords"
require "digest/md5"
require "pathname"
require "asciidoctor"

module Asciidoctor
  module Latexmath
    class RenderingError < StandardError; end

    RenderResult = Struct.new(
      :format,
      :data,
      :extension,
      :width,
      :height,
      :inline_markup,
      :basename,
      keyword_init: true
    )

    class Renderer
      DEFAULT_FORMAT = :svg
      LATEX_TEMPLATE = <<~'LATEX'
        \documentclass[preview,border=2bp]{standalone}
        \usepackage{amsmath}
        \usepackage{amssymb}
        %<PREAMBLE>
        \begin{document}
        %<BODY>
        \end{document}
      LATEX

      def initialize(document)
        @document = document
        @format = resolve_format
        @inline_attribute = document.attr? "latexmath-inline"
        @ppi = resolve_ppi
        @keep_artifacts = truthy_attr?("latexmath-keep-artifacts")
        @pdf_engine = resolve_command(document.attr("pdflatex") || "pdflatex")
        @pdf2svg = resolve_command(document.attr("latexmath-pdf2svg") || "pdf2svg") if @format == :svg || @inline_attribute
        @png_tool = resolve_png_tool if @format == :png
        @preamble = document.attr("latexmath-preamble")
      end

      def render(equation:, display:, inline: false, id: nil)
        basename = sanitize_basename(id) || auto_basename(equation)
        inline_embed = inline && @inline_attribute

        Dir.mktmpdir("asciidoctor-latexmath-") do |dir|
          tex_path = File.join(dir, "#{basename}.tex")
          pdf_path = File.join(dir, "#{basename}.pdf")

          File.write(tex_path, build_document(equation, display))
          run_pdflatex(tex_path, dir)

          unless File.exist?(pdf_path)
            raise RenderingError, "pdflatex did not produce #{basename}.pdf"
          end

          case @format
          when :pdf
            handle_pdf(pdf_path, dir, basename, inline_embed)
          when :svg
            handle_svg(pdf_path, dir, basename, inline_embed)
          when :png
            handle_png(pdf_path, dir, basename, inline_embed)
          else
            raise RenderingError, "Unsupported format: #{@format}"
          end
        end
      end

      private

      def resolve_format
        raw = (@document.attr("latexmath-format") || DEFAULT_FORMAT).to_s.strip
        raw = DEFAULT_FORMAT if raw.empty?
        fmt = raw.downcase.to_sym
        return fmt if %i[pdf svg png].include?(fmt)

        warn %(Unknown latexmath-format '#{raw}', falling back to #{DEFAULT_FORMAT})
        DEFAULT_FORMAT
      end

      def resolve_ppi
        value = (@document.attr("latexmath-ppi") || "300").to_f
        value.positive? ? value : 300.0
      end

      def resolve_png_tool
        tool = @document.attr("latexmath-png-tool")
        candidates = [tool, "magick", "convert", "pdftoppm"]
        candidates.compact.each do |candidate|
          resolved = resolve_command(candidate, silent: true)
          return resolved if resolved
        end

        raise RenderingError, "No PNG conversion tool found; set latexmath-png-tool to a valid command (magick, convert, or pdftoppm)."
      end

      def build_document(equation, display)
        body = if latex_environment?(equation)
          equation
        elsif display
          "\\[#{equation}\\]"
        else
          "\\(#{equation}\\)"
        end

        LATEX_TEMPLATE
          .sub("%<PREAMBLE>", (@preamble ? "\n#{@preamble}\n" : ""))
          .sub("%<BODY>", body)
      end

      def run_pdflatex(tex_path, dir)
        command = [
          @pdf_engine,
          "-interaction=nonstopmode",
          "-halt-on-error",
          "-file-line-error",
          "-output-directory",
          dir,
          tex_path
        ]

        execute(command, work_dir: dir)
      rescue RenderingError => e
        latex_source = File.read(tex_path, mode: "r:UTF-8")
        message = <<~MSG
          #{e.message.rstrip}

          LaTeX source (#{tex_path}):
          #{latex_source}
        MSG
        raise RenderingError, message
      end

      def handle_pdf(pdf_path, dir, basename, inline_embed)
        copy_artifacts(dir, basename)
        warn "latexmath-inline is ignored for pdf format." if inline_embed
        RenderResult.new(format: :pdf, data: File.read(pdf_path, mode: "rb"), extension: "pdf", basename: basename)
      end

      def handle_svg(pdf_path, dir, basename, inline_embed)
        svg_path = File.join(dir, "#{basename}.svg")
        execute([@pdf2svg, pdf_path, svg_path], work_dir: dir)
        svg_data = sanitize_svg(File.read(svg_path))
        width, height = svg_dimensions(svg_data)
        copy_artifacts(dir, basename)

        if inline_embed
          inline_markup = %(<span class="latexmath-inline">#{svg_data}</span>)
          RenderResult.new(format: :svg, inline_markup: inline_markup, width: width, height: height, data: svg_data, extension: "svg", basename: basename)
        else
          RenderResult.new(format: :svg, data: File.read(svg_path, mode: "rb"), width: width, height: height, extension: "svg", basename: basename)
        end
      end

      def handle_png(pdf_path, dir, basename, inline_embed)
        png_path = File.join(dir, "#{basename}.png")
        convert_pdf_to_png(pdf_path, png_path)
        png_data = File.read(png_path, mode: "rb")
        width, height = png_dimensions(png_path)
        copy_artifacts(dir, basename)

        if inline_embed
          encoded = [png_data].pack("m0")
          inline_markup = %(<span class="latexmath-inline"><img src="data:image/png;base64,#{encoded}" alt="latexmath"/></span>)
          RenderResult.new(format: :png, inline_markup: inline_markup, width: width, height: height, data: png_data, extension: "png", basename: basename)
        else
          RenderResult.new(format: :png, data: png_data, width: width, height: height, extension: "png", basename: basename)
        end
      end

      def convert_pdf_to_png(pdf_path, png_path)
        if File.basename(@png_tool) == "pdftoppm"
          base = png_path.sub(/\.png\z/, "")
          command = [@png_tool, "-png", "-r", @ppi.to_i.to_s, pdf_path, base]
          execute(command, work_dir: File.dirname(pdf_path))
          generated = Dir["#{base}*.png"].first
          raise RenderingError, "pdftoppm did not produce a PNG file" unless generated
          FileUtils.mv(generated, png_path)
        else
          density = @ppi.to_i
          command = [@png_tool, "-density", density.to_s, pdf_path, "-quality", "100", png_path]
          execute(command, work_dir: File.dirname(pdf_path))
        end
      end

      def svg_dimensions(svg_data)
        if (match = svg_data.match(/viewBox="\s*0\s+0\s+([0-9.]+)\s+([0-9.]+)/))
          [match[1].to_f, match[2].to_f]
        elsif (match = svg_data.match(/width="([0-9.]+)(px)?"\s+height="([0-9.]+)(px)?"/))
          [match[1].to_f, match[3].to_f]
        end
      end

      def png_dimensions(png_path)
        IO.popen(["identify", "-format", "%w %h", png_path]) do |io|
          output = io.read
          return output.split.map!(&:to_i) if output
        end
      rescue Errno::ENOENT
        nil
      end

      def execute(command, work_dir: nil)
        stdout_str, stderr_str, status = Open3.capture3(*command, chdir: work_dir)
        return if status.success?

        raise RenderingError, <<~MSG
          Command failed: #{Shellwords.join(command)}
          stdout: #{stdout_str}
          stderr: #{stderr_str}
        MSG
      end

      def sanitize_svg(svg_data)
        svg_data.sub(/\A<\?xml.*?\?>\s*/m, "").sub(/<!DOCTYPE.*?>\s*/m, "")
      end

      def copy_artifacts(dir, basename)
        return unless @keep_artifacts

        out_dir = artifacts_output_dir
        FileUtils.mkdir_p(out_dir)
        Dir.glob(File.join(dir, "#{basename}.*")).each do |path|
          FileUtils.cp(path, File.join(out_dir, File.basename(path)))
        end
      end

      def artifacts_output_dir
        attr = @document.attr("latexmath-artifacts-dir")
        if attr && !attr.strip.empty?
          @document.normalize_system_path(attr, @document.attr("docdir"))
        else
          @document.attr("imagesoutdir") || @document.attr("docdir")
        end
      end

      def auto_basename(equation)
        "latexmath-#{Digest::MD5.hexdigest(equation)}"
      end

      def sanitize_basename(id)
        return unless id
        id.to_s.gsub(/[^a-zA-Z0-9_.-]/, "-")
      end

      def resolve_command(cmd, silent: false)
        return cmd if Pathname.new(cmd).absolute? && File.executable?(cmd)

        resolved = which(cmd)
        return resolved if resolved

        return nil if silent

        raise RenderingError, "Command '#{cmd}' could not be found in PATH"
      end

      def which(cmd)
        path_ext = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |path|
          path_ext.each do |ext|
            candidate = File.join(path, "#{cmd}#{ext}")
            return candidate if File.executable?(candidate) && !File.directory?(candidate)
          end
        end
        nil
      end

      def truthy_attr?(name)
        value = @document.attr(name)
        case value
        when nil
          false
        when true
          true
        else
          !%w[false off no 0].include?(value.to_s.downcase)
        end
      end

      def latex_environment?(equation)
        equation.match?(/\\begin\s*\{[^}]+\}/) && equation.match?(/\\end\s*\{[^}]+\}/)
      end
    end
  end
end
