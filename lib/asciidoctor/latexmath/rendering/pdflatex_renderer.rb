# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "fileutils"

require_relative "renderer"

module Asciidoctor
  module Latexmath
    module Rendering
      class PdflatexRenderer < Renderer
        def name
          "pdflatex"
        end

        def render(request, context)
          tmp_dir = context.fetch(:tmp_dir)
          FileUtils.mkdir_p(tmp_dir)

          pdf_path = pdf_path_for(request, context)
          File.write(pdf_path, build_placeholder_pdf(request))

          pdf_path
        end

        private

        def pdf_path_for(request, context)
          File.join(context.fetch(:tmp_dir), "#{request.content_hash}.pdf")
        end

        def build_placeholder_pdf(request)
          "PDF placeholder for #{request.expression.content} using #{request.engine}"
        end
      end
    end
  end
end
