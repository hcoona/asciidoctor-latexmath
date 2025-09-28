# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "tmpdir"
require "fileutils"
require "open3"
require "shellwords"
require "digest"
require "pathname"
require "json"
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
      CACHE_VERSION = 1
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
        @cache_enabled = cache_enabled?
        @cache_dir = resolve_cache_dir if @cache_enabled
      end

      def render(equation:, display:, inline: false, id: nil, asciidoc_source: nil, source_location: nil)
        basename = sanitize_basename(id) || auto_basename(equation)
        inline_embed = inline && @inline_attribute
        signature = cache_signature(
          equation: equation,
          display: display,
          inline: inline,
          inline_embed: inline_embed
        )
        equation_digest = Digest::SHA256.hexdigest(equation)

        if @cache_enabled
          if (cached = load_cached_render(basename, signature, equation_digest, inline_embed))
            copy_cached_artifacts(signature, basename) if @keep_artifacts
            return cached
          end
        end

        result = nil
        Dir.mktmpdir("asciidoctor-latexmath-") do |dir|
          tex_path = File.join(dir, "#{basename}.tex")
          pdf_path = File.join(dir, "#{basename}.pdf")

          latex_source = build_document(equation, display)
          File.write(tex_path, latex_source)
          begin
            run_pdflatex(
              tex_path,
              dir,
              latex_source: latex_source,
              asciidoc_source: asciidoc_source,
              source_location: source_location
            )

            unless File.exist?(pdf_path)
              raise RenderingError, "pdflatex did not produce #{basename}.pdf"
            end
          rescue RenderingError
            copy_artifacts(dir, basename)
            raise
          end

          result = case @format
          when :pdf
            handle_pdf(pdf_path, dir, basename, inline_embed)
          when :svg
            handle_svg(pdf_path, dir, basename, inline_embed)
          when :png
            handle_png(pdf_path, dir, basename, inline_embed)
          else
            raise RenderingError, "Unsupported format: #{@format}"
          end

          if @cache_enabled && result
            persist_cached_render(signature, equation_digest, inline_embed, result, dir, basename)
          end
        end
        result
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
          .sub("%<PREAMBLE>") { @preamble ? "\n#{@preamble}\n" : "" }
          .sub("%<BODY>") { body }
      end

      def run_pdflatex(tex_path, dir, latex_source:, asciidoc_source: nil, source_location: nil)
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
        latex_source ||= File.read(tex_path, mode: "r:UTF-8")
        message_parts = [e.message.rstrip]

        message_parts << "LaTeX source (#{tex_path}):\n#{latex_source}"

        if asciidoc_source
          location_hint = format_source_location(source_location)
          header = "Asciidoc source#{location_hint}:"
          message_parts << "#{header}\n#{asciidoc_source}"
        end

        raise RenderingError, message_parts.join("\n\n")
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

      def cache_enabled?
        value = @document.attr("latexmath-cache")
        return true if value.nil?
        !%w[false off no 0].include?(value.to_s.downcase)
      end

      def resolve_cache_dir
        attr = @document.attr("latexmath-cache-dir")
        docdir = @document.attr("docdir")
        if attr && !attr.to_s.strip.empty?
          @document.normalize_system_path(attr, docdir)
        else
          base_attr = @document.attr("outdir") || docdir || Dir.pwd
          base = @document.normalize_system_path(base_attr, docdir)
          File.join(base, ".asciidoctor", "latexmath")
        end
      rescue
        File.join(Dir.pwd, ".asciidoctor", "latexmath")
      end

      def cache_signature(equation:, display:, inline:, inline_embed:)
        components = [
          @format,
          equation,
          display,
          inline,
          inline_embed,
          @preamble.to_s,
          @ppi,
          @pdf_engine,
          @pdf2svg,
          @png_tool
        ]
        Digest::SHA256.hexdigest(components.join("\u0000"))
      end

      def cache_entry_dir(basename, signature)
        File.join(@cache_dir, basename, signature)
      end

      def cache_metadata_path(basename, signature)
        File.join(cache_entry_dir(basename, signature), "metadata.json")
      end

      def load_cached_render(basename, signature, equation_digest, inline_embed)
        return unless @cache_dir
        metadata_path = cache_metadata_path(basename, signature)
        return unless File.file?(metadata_path)

        metadata = JSON.parse(File.read(metadata_path), symbolize_names: true)
        return unless metadata[:version] == CACHE_VERSION
        return unless metadata[:signature] == signature
        return unless metadata[:source_digest] == equation_digest
        return unless metadata[:inline_embed] == inline_embed

        data_path = metadata[:data_path]
        return unless data_path

        data_file = File.join(cache_entry_dir(basename, signature), data_path)
        return unless File.file?(data_file)

        data = File.binread(data_file)
        if (encoding = metadata[:encoding])
          begin
            data.force_encoding(Encoding.find(encoding))
          rescue
            data.force_encoding(Encoding::BINARY)
          end
        end

        RenderResult.new(
          format: metadata[:format]&.to_sym,
          data: data,
          extension: metadata[:extension],
          width: metadata[:width],
          height: metadata[:height],
          inline_markup: metadata[:inline_markup],
          basename: basename
        )
      rescue
        nil
      end

      def persist_cached_render(signature, equation_digest, inline_embed, result, dir, basename)
        return unless @cache_dir

        entry_dir = cache_entry_dir(basename, signature)
        FileUtils.rm_rf(entry_dir)
        FileUtils.mkdir_p(entry_dir)

        data_filename = if result.extension
          "result.#{result.extension}"
        else
          "result.bin"
        end

        if result.data
          File.binwrite(File.join(entry_dir, data_filename), result.data)
        else
          data_filename = nil
        end

        metadata = {
          version: CACHE_VERSION,
          signature: signature,
          format: result.format.to_s,
          extension: result.extension,
          width: result.width && result.width.to_f,
          height: result.height && result.height.to_f,
          inline_embed: inline_embed,
          encoding: result.data&.encoding&.name,
          data_path: data_filename,
          source_digest: equation_digest,
          inline_markup: result.inline_markup
        }

        artifacts = store_cache_artifacts(entry_dir, dir, basename)
        metadata[:artifacts] = artifacts unless artifacts.empty?
        metadata.delete(:data_path) unless data_filename

        File.write(cache_metadata_path(basename, signature), JSON.pretty_generate(stringify_keys(metadata)))
      rescue
        nil
      end

      def store_cache_artifacts(entry_dir, dir, basename)
        return [] unless @keep_artifacts

        artifacts = Dir.glob(File.join(dir, "#{basename}.*"))
        return [] if artifacts.empty?

        target_dir = File.join(entry_dir, "artifacts")
        FileUtils.mkdir_p(target_dir)

        artifacts.map do |path|
          filename = File.basename(path)
          FileUtils.cp(path, File.join(target_dir, filename))
          filename
        end
      end

      def copy_cached_artifacts(signature, basename)
        return unless @cache_dir

        artifacts_dir = File.join(cache_entry_dir(basename, signature), "artifacts")
        return unless Dir.exist?(artifacts_dir)

        copy_artifacts(artifacts_dir, basename)
      end

      def stringify_keys(hash)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value
        end
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

      def format_source_location(source_location)
        return "" unless source_location

        file = if source_location.respond_to?(:file)
          source_location.file
        elsif source_location.respond_to?(:path)
          source_location.path
        elsif source_location.respond_to?(:filename)
          source_location.filename
        end

        line = if source_location.respond_to?(:lineno)
          source_location.lineno
        end

        parts = []
        parts << file if file && !file.to_s.empty?
        parts << line if line
        parts.empty? ? "" : " (#{parts.join(":")})"
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
