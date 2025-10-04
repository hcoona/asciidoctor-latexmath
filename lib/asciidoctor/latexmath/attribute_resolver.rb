# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "digest"
require "pathname"

require_relative "errors"
require_relative "render_request"

module Asciidoctor
  module Latexmath
    class AttributeResolver
      MIN_PPI = 72
      MAX_PPI = 600
      DEFAULT_PPI = 300
      DEFAULT_TIMEOUT = 120

      ResolvedAttributes = Struct.new(
        :render_request,
        :on_error_policy,
        :target_basename,
        :format,
        :nocache,
        :keep_artifacts,
        :raw_attributes,
        keyword_init: true
      )

      def initialize(document, logger: Asciidoctor::LoggerManager.logger)
        @document = document
        @logger = logger
      end

      def resolve(attributes:, options:, expression:)
        normalized = normalize_keys(attributes)
        normalized = apply_aliases(normalized)
        options = Array(options)

        format = infer_format(normalized)
        engine = infer_engine(normalized)
        ppi = infer_ppi(normalized, format)
        timeout = infer_timeout(normalized)
        nocache = infer_nocache(normalized, options)
        keep_artifacts = infer_keep_artifacts(normalized, options)
        cachedir = infer_cachedir(normalized) unless nocache
        artifacts_dir = infer_artifacts_dir(normalized, keep_artifacts, cachedir)
        preamble = infer_preamble(normalized)
        on_error_policy = infer_on_error(normalized)
        tool_overrides = infer_tool_overrides(normalized)

        normalized_content = normalize_text(expression.content.to_s)
        normalized_preamble = normalize_text(preamble)

        target_basename = determine_target_basename(normalized)

        render_request = RenderRequest.new(
          expression: expression,
          format: format,
          engine: engine,
          preamble: preamble,
          ppi: ppi,
          timeout: timeout,
          keep_artifacts: keep_artifacts,
          nocache: nocache,
          cachedir: cachedir,
          artifacts_dir: artifacts_dir,
          tool_overrides: tool_overrides,
          content_hash: Digest::SHA256.hexdigest(normalized_content),
          preamble_hash: Digest::SHA256.hexdigest(normalized_preamble)
        )

        ResolvedAttributes.new(
          render_request: render_request,
          on_error_policy: on_error_policy,
          target_basename: target_basename,
          format: format,
          nocache: nocache,
          keep_artifacts: keep_artifacts,
          raw_attributes: normalized
        )
      end

      private

      attr_reader :document, :logger

      def normalize_keys(attributes)
        attributes.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value
        end
      end

      def apply_aliases(attrs)
        if attrs.key?("cache-dir")
          log_cache_dir_alias_once(:element)
          attrs["cachedir"] = attrs.delete("cache-dir")
        end
        attrs
      end

      def determine_target_basename(attrs)
        explicit = attrs["target"]
        return explicit unless explicit.to_s.empty?

        positional = attrs["2"]
        style = attrs["style"]
        return positional if positional && !positional.to_s.empty? && positional != style

        positional = attrs["1"]
        return positional if positional && !positional.to_s.empty? && positional != style

        nil
      end

      def infer_format(attrs)
        value = attrs["format"] || document.attr("latexmath-format") || "svg"
        normalized = value.to_s.downcase.to_sym
        return normalized if %i[svg pdf png].include?(normalized)

        raise UnsupportedFormatError, "Unsupported format '#{value}'"
      end

      def infer_engine(attrs)
        (attrs["pdflatex"] || document.attr("latexmath-pdflatex") || document.attr("pdflatex") || "pdflatex").to_s.strip
      end

      def infer_preamble(attrs)
        override = attrs["preamble"]
        return override.to_s if override

        (document.attr("latexmath-preamble") || "").to_s
      end

      def infer_ppi(attrs, format)
        return nil unless format == :png

        value = attrs["ppi"] || document.attr("latexmath-ppi") || DEFAULT_PPI
        integer = Integer(value)
        unless integer.between?(MIN_PPI, MAX_PPI)
          raise InvalidAttributeError, "ppi #{integer} out of range (#{MIN_PPI}..#{MAX_PPI})"
        end
        integer
      rescue ArgumentError
        raise InvalidAttributeError, "ppi must be an integer"
      end

      def infer_timeout(attrs)
        value = attrs["timeout"] || document.attr("latexmath-timeout") || DEFAULT_TIMEOUT
        integer = Integer(value)
        raise InvalidAttributeError, "timeout must be positive" unless integer.positive?

        integer
      rescue ArgumentError
        raise InvalidAttributeError, "timeout must be an integer"
      end

      def infer_cachedir(attrs)
        explicit = attrs["cachedir"]
        doc_level = canonical_cachedir_attr

        return expand_path(explicit) if explicit
        return expand_path(doc_level) if doc_level

        base_dir = resolve_outdir
        File.expand_path(File.join(base_dir, ".asciidoctor", "latexmath"))
      end

      def infer_artifacts_dir(attrs, keep_artifacts, cachedir)
        return nil unless keep_artifacts

        explicit = attrs["artifacts-dir"] || attrs["artifactsdir"]
        doc_level = document&.attr("latexmath-artifacts-dir") || document&.attr("latexmath-artifactsdir")
        chosen = explicit || doc_level

        if chosen
          expand_path(chosen)
        elsif cachedir
          File.join(cachedir, "artifacts")
        end
      end

      def infer_tool_overrides(attrs)
        svg_tool = fetch_string(attrs, "latexmath-svg-tool") || document&.attr("latexmath-svg-tool")
        svg_path = fetch_string(attrs, "latexmath-pdf2svg") || document&.attr("latexmath-pdf2svg")
        png_tool = fetch_string(attrs, "latexmath-png-tool") || fetch_string(attrs, "png-tool") || document&.attr("latexmath-png-tool") || document&.attr("png-tool")
        png_path = fetch_string(attrs, "latexmath-pdftoppm") || document&.attr("latexmath-pdftoppm")
        engine_tool = fetch_string(attrs, "pdflatex") || document&.attr("latexmath-pdflatex")

        {
          svg: normalize_override(svg_tool),
          svg_path: normalize_override(svg_path),
          png: normalize_override(png_tool),
          png_path: normalize_override(png_path),
          engine: normalize_override(engine_tool)
        }
      end

      def infer_nocache(attrs, options)
        if attrs.key?("cache")
          parsed = parse_boolean(attrs["cache"])
          return !parsed unless parsed.nil?
        end

        if attrs.key?("nocache")
          parsed = parse_boolean(attrs["nocache"])
          return parsed unless parsed.nil?
        end

        return true if options.include?("nocache")

        doc_value = document && parse_boolean(document.attr("latexmath-cache"))
        return !doc_value unless doc_value.nil?

        false
      end

      def infer_keep_artifacts(attrs, options)
        if attrs.key?("keep-artifacts")
          parsed = parse_boolean(attrs["keep-artifacts"])
          return parsed unless parsed.nil?
        end

        return true if options.include?("keep-artifacts")

        doc_value = document && parse_boolean(document.attr("latexmath-keep-artifacts"))
        doc_value || false
      end

      def infer_on_error(attrs)
        policy_name = attrs["on-error"] || document.attr("latexmath-on-error") || :log
        ErrorHandling.policy(policy_name.to_sym)
      rescue ArgumentError
        logger&.warn { "latexmath: unknown on-error policy '#{policy_name}', falling back to log" }
        ErrorHandling.policy(:log)
      end

      def expand_path(path)
        return nil unless path

        base_dir = resolve_outdir
        Pathname(path).absolute? ? path : File.expand_path(path, base_dir)
      end

      def resolve_outdir
        document&.attr("outdir") || document&.options&.[](:to_dir) || document&.base_dir || document&.attr("docdir") || Dir.pwd
      end

      def canonical_cachedir_attr
        return nil unless document

        primary = document.attr("latexmath-cachedir")
        return primary if primary

        deprecated = document.attr("latexmath-cache-dir")
        if deprecated
          log_cache_dir_alias_once(:document)
          deprecated
        end
      end

      def log_cache_dir_alias_once(_scope)
        return unless document

        flag_name = "latexmath-deprecated-cache-dir-logged"
        return if parse_boolean(document.attr(flag_name))

        logger&.info { "latexmath: cache-dir is deprecated, use cachedir instead" }
        set_internal_document_attr(flag_name, true)
      end

      def fetch_string(attrs, key)
        value = attrs[key] || attrs[key.to_s]
        value = value.to_s if value
        (value && !value.strip.empty?) ? value.strip : nil
      end

      def normalize_override(value)
        return nil if value.nil?

        stripped = value.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def normalize_text(text)
        text.to_s.sub(/^\uFEFF/, "")
      end

      def parse_boolean(value)
        return value if value == true || value == false
        return nil if value.nil?

        string = value.to_s.strip
        normalized = string.downcase
        return true if string.empty?
        return true if %w[true yes on 1].include?(normalized)
        return false if %w[false no off 0].include?(normalized)

        nil
      end

      def set_internal_document_attr(name, value)
        normalized = normalize_attribute_value(value)
        if document.respond_to?(:set_attribute)
          document.set_attribute(name, normalized)
        elsif document.respond_to?(:set_attr)
          document.set_attr(name, normalized)
        elsif document.respond_to?(:attributes)
          document.attributes[name] = normalized
        end
      end

      def normalize_attribute_value(value)
        case value
        when true then "true"
        when false then "false"
        else
          value
        end
      end
    end
  end
end
