# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

module Asciidoctor
  module Latexmath
    class LatexmathError < StandardError; end

    class UnsupportedFormatError < LatexmathError; end

    class MissingToolError < LatexmathError
      attr_reader :tool

      def initialize(tool, message = nil)
        @tool = tool
        super(message || "Missing required tool: #{tool}")
      end
    end

    class InvalidAttributeError < LatexmathError; end

    class TargetConflictError < LatexmathError; end

    class RenderTimeoutError < LatexmathError; end

    class StageFailureError < LatexmathError; end

    module ErrorHandling
      class Policy
        attr_reader :mode

        def initialize(mode)
          @mode = mode
        end

        def abort?
          mode == :abort
        end

        def log?
          mode == :log
        end

        alias_method :abort, :abort?
        alias_method :log, :log?
      end

      SUPPORTED_POLICIES = {
        abort: Policy.new(:abort),
        log: Policy.new(:log)
      }.freeze

      def self.policy(name)
        SUPPORTED_POLICIES.fetch(name.to_sym) do
          raise ArgumentError, "Unknown on-error policy: #{name}"
        end
      end

      module Placeholder
        HTML_HEADER = %(<pre class="highlight latexmath-error" role="note" data-latex-error="1">)
        HTML_FOOTER = "</pre>"

        def self.render(message:, command:, stdout:, stderr:, source:, latex_source:)
          body = [
            "Error: #{message}",
            "Command: #{command}",
            "Stdout: #{present_or_placeholder(stdout)}",
            "Stderr: #{present_or_placeholder(stderr)}",
            "Source (AsciiDoc): #{source}",
            "Source (LaTeX): #{latex_source}"
          ].join("\n")

          <<~HTML.rstrip
            #{HTML_HEADER}
            #{escape_html(body)}
            #{HTML_FOOTER}
          HTML
        end

        def self.present_or_placeholder(value)
          return "<empty>" if value.nil? || value.to_s.empty?

          value
        end

        def self.escape_html(text)
          text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
        end
        private_class_method :escape_html, :present_or_placeholder
      end
    end
  end
end
