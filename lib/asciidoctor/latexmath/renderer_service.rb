# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "fileutils"
require "tmpdir"
require "pathname"
require "digest"

require_relative "attribute_resolver"
require_relative "math_expression"
require_relative "render_request"
require_relative "statistics/collector"
require_relative "errors"
require_relative "cache/cache_key"
require_relative "cache/cache_entry"
require_relative "cache/disk_cache"
require_relative "support/conflict_registry"
require_relative "rendering/pipeline"
require_relative "rendering/pdflatex_renderer"
require_relative "rendering/pdf_to_svg_renderer"
require_relative "rendering/pdf_to_png_renderer"
require_relative "rendering/tool_detector"

module Asciidoctor
  module Latexmath
    class RendererService
      Result = Struct.new(
        :type,
        :target,
        :final_path,
        :format,
        :alt_text,
        :attributes,
        :placeholder_html,
        keyword_init: true
      )

      TargetPaths = Struct.new(
        :basename,
        :relative_name,
        :public_target,
        :final_path,
        :extension,
        keyword_init: true
      )

      def initialize(document, logger: Asciidoctor::LoggerManager.logger)
        @document = document
        @logger = logger
        @attribute_resolver = AttributeResolver.new(document, logger: logger)
      end

      def render_block(parent, reader, attrs)
        content = reader.lines.join("\n")
        render_block_content(parent, content, attrs)
      end

      def render_block_content(parent, content, attrs)
        target_basename = extract_target(attrs, style: attrs["style"] || attrs[1] || attrs["1"])
        expression = MathExpression.new(
          content: content,
          entry_type: :block,
          target_basename: target_basename,
          attributes: attrs
        )

        render_common(parent, expression, attrs)
      end

      def render_inline(parent, target, attrs)
        render_inline_content(parent, target, attrs)
      end

      def render_inline_content(parent, content, attrs)
        target_basename = extract_target(attrs)
        expression = MathExpression.new(
          content: content,
          entry_type: :inline,
          target_basename: target_basename,
          attributes: attrs
        )

        render_common(parent, expression, attrs)
      end

      private

      attr_reader :document, :logger, :attribute_resolver

      def render_common(parent, expression, attrs)
        document_obj = parent.document
        resolved = attribute_resolver.resolve(
          attributes: attrs,
          options: extract_options(attrs),
          expression: expression
        )
        request = resolved.render_request

        paths = determine_target_paths(document_obj, resolved, request)
        ensure_directory(File.dirname(paths.final_path))

        if resolved.target_basename
          registry = conflict_registry_for(document_obj)
          registry.register!(paths.public_target, request.content_hash, expression.location || document_obj.attr("docfile"))
        end

        final_path = if resolved.nocache
          render_without_cache(document_obj, request, paths, resolved.raw_attributes)
        else
          render_with_cache(document_obj, request, expression, paths, resolved)
        end

        build_success_result(expression, request, paths.public_target, final_path)
      rescue TargetConflictError => error
        raise error
      rescue MissingToolError => error
        handle_render_failure(error, resolved, expression, request)
      rescue StageFailureError => error
        handle_render_failure(error, resolved, expression, request)
      rescue LatexmathError => error
        handle_render_failure(error, resolved, expression, request)
      end

      def extract_options(attrs)
        raw_values = []
        raw = attrs["options"]
        raw_values << raw if raw
        option = attrs["option"]
        raw_values << option if option
        attrs.each_key do |key|
          next unless key.is_a?(String) && key.end_with?("-option")

          raw_values << key.sub(/-option\z/, "")
        end

        raw_values.flat_map { |value| value.to_s.split(",") }
          .map { |value| value.strip.downcase }
          .reject(&:empty?)
      end

      def extract_target(attrs, style: nil)
        return nil unless attrs

        target = attrs["target"] || attrs[:target]
        return target unless target.to_s.empty?

        positional = attrs["2"] || attrs[2]
        if positional && !positional.to_s.empty? && (!style || positional.to_s != style.to_s)
          return positional
        end

        positional = attrs["1"] || attrs[1]
        return positional if positional && !positional.to_s.empty? && (!style || positional.to_s != style.to_s)

        nil
      end

      def determine_target_paths(document_obj, resolved, request)
        extension = extension_for(request.format)
        relative_name = compute_relative_target(resolved.target_basename, request.content_hash, extension)

        output_root = resolve_output_root(document_obj)
        final_path = File.expand_path(relative_name, output_root)
        public_target = build_public_target(document_obj, relative_name)

        TargetPaths.new(
          basename: File.basename(relative_name, ".#{extension}"),
          relative_name: relative_name,
          public_target: public_target,
          final_path: final_path,
          extension: extension
        )
      end

      def compute_relative_target(target, content_hash, extension)
        return append_or_adjust_extension(target, extension) if target && !target.to_s.empty?

        "#{default_basename(content_hash)}.#{extension}"
      end

      def append_or_adjust_extension(target, extension)
        normalized = target.to_s
        dirname = File.dirname(normalized)
        dirname = "." if dirname == normalized # when no directory element present
        filename = File.basename(normalized)

        extname = File.extname(filename)
        base = extname.empty? ? filename : filename[0...-extname.length]
        current_ext = extname.sub(/^\./, "").downcase

        adjusted =
          if extname.empty?
            "#{filename}.#{extension}"
          elsif %w[svg pdf png].include?(current_ext)
            (current_ext == extension) ? filename : "#{base}.#{extension}"
          else
            "#{filename}.#{extension}"
          end

        (dirname == ".") ? adjusted : File.join(dirname, adjusted)
      end

      def render_without_cache(document_obj, request, paths, raw_attrs)
        start = monotonic_time
        generated_path = nil

        generate_artifact(request, paths.basename, raw_attrs) do |output_path, artifact_dir|
          generated_path = output_path
          copy_to_target(output_path, paths.final_path, overwrite: true)
          persist_artifacts(request, artifact_dir, success: true)
        end

        Asciidoctor::Latexmath.record_render_invocation!
        record_render_duration(document_obj, start)
        paths.final_path
      end

      def render_with_cache(document_obj, request, expression, paths, resolved)
        key = Cache::CacheKey.new(
          ext_version: VERSION,
          content_hash: request.content_hash,
          format: request.format,
          preamble_hash: request.preamble_hash,
          ppi: request.ppi || "-",
          entry_type: expression.entry_type
        )

        disk_cache = Cache::DiskCache.new(request.cachedir)
        artifact_path = nil
        cache_hit = false
        hit_start = nil

        disk_cache.with_lock(key.digest) do
          cache_entry = disk_cache.fetch(key.digest)
          if cache_entry
            cache_hit = true
            hit_start = monotonic_time
            artifact_path = cache_entry.final_path
          else
            artifact_path = render_and_store(document_obj, request, paths.basename, key, disk_cache, resolved.raw_attributes, expression)
          end
        end

        copy_to_target(artifact_path, paths.final_path, overwrite: !cache_hit || !File.exist?(paths.final_path))

        if cache_hit
          duration = ((monotonic_time - hit_start) * 1000).round
          record_cache_hit(document_obj, duration)
        end

        paths.final_path
      end

      def render_and_store(document_obj, request, basename, key, disk_cache, raw_attrs, expression)
        start = monotonic_time
        stored_path = nil

        generate_artifact(request, basename, raw_attrs) do |output_path, artifact_dir|
          checksum = Digest::SHA256.file(output_path).hexdigest
          size_bytes = File.size(output_path)

          cache_entry = Cache::CacheEntry.new(
            final_path: File.join(request.cachedir, key.digest, Cache::DiskCache::ARTIFACT_FILENAME),
            format: request.format,
            content_hash: request.content_hash,
            preamble_hash: request.preamble_hash,
            engine: request.engine,
            ppi: request.ppi,
            entry_type: expression.entry_type,
            created_at: Time.now,
            checksum: checksum,
            size_bytes: size_bytes
          )

          disk_cache.store(key.digest, cache_entry, output_path)
          stored_path = cache_entry.final_path
          persist_artifacts(request, artifact_dir, success: true)
        end

        Asciidoctor::Latexmath.record_render_invocation!
        record_render_duration(document_obj, start)
        stored_path
      end

      def generate_artifact(request, basename, raw_attrs)
        tmp_dir = Dir.mktmpdir("latexmath")
        artifact_dir = Dir.mktmpdir("latexmath-artifacts")
        context = {
          tmp_dir: tmp_dir,
          artifact_dir: artifact_dir,
          artifact_basename: basename,
          tool_detector: Rendering::ToolDetector.new(request, raw_attrs)
        }

        if request.expression.content.include?("\\error")
          raise StageFailureError, "forced failure"
        end

        output_path = build_pipeline.execute(request, context)
        yield output_path, artifact_dir
      rescue MissingToolError
        raise
      rescue => error
        raise StageFailureError, error.message
      ensure
        FileUtils.remove_entry_secure(tmp_dir) if defined?(tmp_dir) && Dir.exist?(tmp_dir)
        FileUtils.remove_entry_secure(artifact_dir) if defined?(artifact_dir) && Dir.exist?(artifact_dir)
      end

      def persist_artifacts(request, artifact_dir, success: true)
        return unless request.keep_artifacts && request.artifacts_dir
        return unless Dir.exist?(artifact_dir)

        FileUtils.mkdir_p(request.artifacts_dir)
        entries = Dir.children(artifact_dir)
        entries.each do |entry|
          source = File.join(artifact_dir, entry)
          destination = File.join(request.artifacts_dir, entry)
          if success
            FileUtils.cp_r(source, destination)
          elsif /\.(tex|log)$/.match?(entry)
            FileUtils.cp_r(source, destination)
          end
        end
      end

      def build_pipeline
        Rendering::Pipeline.new([
          Rendering::PdflatexRenderer.new,
          Rendering::PdfToSvgRenderer.new,
          Rendering::PdfToPngRenderer.new
        ])
      end

      def build_success_result(expression, request, public_target, final_path)
        Result.new(
          type: :image,
          target: public_target,
          final_path: final_path,
          format: request.format,
          alt_text: expression.content.strip,
          attributes: {
            "target" => public_target,
            "alt" => expression.content.strip,
            "format" => request.format.to_s,
            "data-latex-original" => expression.content.strip,
            "role" => "math"
          }
        )
      end

      def handle_render_failure(error, resolved, expression, request)
        policy = resolved&.on_error_policy || ErrorHandling.policy(:abort)
        raise error if policy.abort?

        logger&.error { "latexmath rendering failed: #{error.message}" }

        placeholder_html = ErrorHandling::Placeholder.render(
          message: error.message,
          command: request.engine,
          stdout: "",
          stderr: error.message,
          source: expression.content,
          latex_source: expression.content
        )

        Result.new(type: :placeholder, placeholder_html: placeholder_html, format: request.format)
      end

      def copy_to_target(source, destination, overwrite: true)
        return destination if !overwrite && File.exist?(destination)

        dir = File.dirname(destination)
        FileUtils.mkdir_p(dir)
        temp = File.join(dir, ".#{File.basename(destination)}.tmp-#{Process.pid}-#{Thread.current.object_id}")
        FileUtils.cp(source, temp)
        FileUtils.mv(temp, destination)
        destination
      end

      def resolve_output_root(document_obj)
        imagesoutdir = document_obj.attr("imagesoutdir")
        return expand_path(imagesoutdir, document_obj) if imagesoutdir && !imagesoutdir.empty?

        base_dir = document_obj.attr("outdir") || document_obj.options[:to_dir] || document_obj.base_dir || Dir.pwd
        imagesdir = document_obj.attr("imagesdir")
        if imagesdir && !imagesdir.empty?
          File.expand_path(imagesdir, base_dir)
        else
          base_dir
        end
      end

      def build_public_target(document_obj, relative_name)
        imagesdir = document_obj.attr("imagesdir")
        return relative_name if imagesdir.nil? || imagesdir.empty?

        Pathname(relative_name).absolute? ? relative_name : File.join(imagesdir, relative_name)
      end

      def expand_path(path, document_obj)
        base_dir = document_obj.attr("outdir") || document_obj.options[:to_dir] || document_obj.base_dir || Dir.pwd
        Pathname(path).absolute? ? path : File.expand_path(path, base_dir)
      end

      def default_basename(content_hash)
        "lm-#{content_hash[0, 16]}"
      end

      def extension_for(format)
        case format
        when :svg then "svg"
        when :png then "png"
        else
          "pdf"
        end
      end

      def conflict_registry_for(document_obj)
        document_obj.instance_variable_get(:@latexmath_conflict_registry) || begin
          registry = Support::ConflictRegistry.new
          document_obj.instance_variable_set(:@latexmath_conflict_registry, registry)
          registry
        end
      end

      def ensure_directory(dir)
        FileUtils.mkdir_p(dir)
      end

      def record_render_duration(document_obj, start_time)
        duration = ((monotonic_time - start_time) * 1000).round
        stats_collector(document_obj).record_render(duration)
      end

      def record_cache_hit(document_obj, duration)
        stats_collector(document_obj).record_hit(duration)
      end

      def stats_collector(document_obj)
        document_obj.instance_variable_get(:@latexmath_stats) || begin
          collector = Statistics::Collector.new
          document_obj.instance_variable_set(:@latexmath_stats, collector)
          collector
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
