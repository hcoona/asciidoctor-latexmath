# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "fileutils"

require_relative "renderer"
require_relative "tool_detector"

module Asciidoctor
  module Latexmath
    module Rendering
      class PdfToPngRenderer < Renderer
        def name
          "pdf_to_png"
        end

        def render(request, context)
          previous = context.respond_to?(:[]) ? context[:previous_output] : nil
          return previous if request.format != :png && !previous.nil?

          pdf_path = previous || pdf_path_for(request, context)
          return pdf_path unless request.format == :png

          context.fetch(:tool_detector).ensure_png_tool!

          artifact_dir = context.fetch(:artifact_dir)
          FileUtils.mkdir_p(artifact_dir)
          output_path = File.join(artifact_dir, "#{context.fetch(:artifact_basename)}.png")
          File.write(output_path, build_placeholder_png(request, pdf_path))
          output_path
        end

        private

        def pdf_path_for(request, context)
          File.join(context.fetch(:tmp_dir), "#{request.content_hash}.pdf")
        end

        def build_placeholder_png(request, pdf_path)
          "PNG placeholder for #{request.expression.content} generated from #{File.basename(pdf_path)}"
        end
      end
    end
  end
end
