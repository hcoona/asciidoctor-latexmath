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
      class PdfToSvgRenderer < Renderer
        def name
          "pdf_to_svg"
        end

        def render(request, context)
          previous = context.respond_to?(:[]) ? context[:previous_output] : nil
          pdf_path = previous || pdf_path_for(request, context)
          return pdf_path unless request.format == :svg

          context.fetch(:tool_detector).ensure_svg_tool!

          artifact_dir = context.fetch(:artifact_dir)
          FileUtils.mkdir_p(artifact_dir)
          output_path = File.join(artifact_dir, "#{context.fetch(:artifact_basename)}.svg")
          File.write(output_path, build_placeholder_svg(request, pdf_path))
          output_path
        end

        private

        def pdf_path_for(request, context)
          File.join(context.fetch(:tmp_dir), "#{request.content_hash}.pdf")
        end

        def build_placeholder_svg(request, pdf_path)
          <<~SVG
            <svg xmlns="http://www.w3.org/2000/svg">
              <text>SVG placeholder for #{request.expression.content} (#{request.engine}) from #{File.basename(pdf_path)}</text>
            </svg>
          SVG
        end
      end
    end
  end
end
