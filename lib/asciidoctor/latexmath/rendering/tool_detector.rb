# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "asciidoctor"

require_relative "toolchain_record"
require_relative "../../latexmath/errors"

module Asciidoctor
  module Latexmath
    module Rendering
      class ToolDetector
        SVG_PRIORITY = %i[dvisvgm pdf2svg].freeze
        PNG_PRIORITY = %i[pdftoppm magick gs].freeze

        def initialize(request, raw_attributes)
          @request = request
          @raw_attributes = raw_attributes || {}
        end

        def ensure_svg_tool!
          return nil unless request.format == :svg

          record = detect_svg_tool
          return record if record.available

          message = <<~MSG.strip
            Required SVG conversion tool not available. Tried: #{svg_candidates.join(", ")}. Configure :latexmath-pdf2svg: with an executable path or install one of the supported tools.
          MSG
          raise MissingToolError.new(record.id, message)
        end

        def ensure_png_tool!
          return nil unless request.format == :png

          record = detect_png_tool
          return record if record.available

          message = <<~MSG.strip
            Required PNG conversion tool not available. Tried: #{png_candidates.join(", ")}. Configure :latexmath-png-tool: with an executable path or install one of the supported tools.
          MSG
          raise MissingToolError.new(record.id, message)
        end

        private

        attr_reader :request
        attr_reader :raw_attributes

        def detect_svg_tool
          if (explicit = explicit_svg_path)
            id = infer_identifier(request.tool_overrides[:svg] || :pdf2svg, SVG_PRIORITY)
            available = executable_file?(explicit)
            return ToolchainRecord.new(id: id, available: available, path: explicit)
          end

          override = request.tool_overrides[:svg]
          record = resolve_override(override, SVG_PRIORITY)
          return record if record

          detect_with_priority(SVG_PRIORITY)
        end

        def detect_png_tool
          if (explicit = explicit_png_path)
            id = infer_identifier(request.tool_overrides[:png] || :pdftoppm, PNG_PRIORITY)
            available = executable_file?(explicit)
            return ToolchainRecord.new(id: id, available: available, path: explicit)
          end

          override = request.tool_overrides[:png]
          record = resolve_override(override, PNG_PRIORITY)
          return record if record

          detect_with_priority(PNG_PRIORITY)
        end

        def detect_with_priority(priority)
          priority.each do |candidate|
            record = memoized_lookup(candidate)
            return record if record.available
          end

          memoized_lookup(priority.first)
        end

        def resolve_override(value, priority)
          return nil if value.nil? || value.to_s.strip.empty?

          candidate = value.to_s.strip
          id = infer_identifier(candidate, priority)

          if File.exist?(candidate)
            available = File.executable?(candidate)
            return ToolchainRecord.new(id: id, available: available, path: candidate)
          end

          record = memoized_lookup(id, candidate)
          return record if record.available

          ToolchainRecord.new(id: id, available: false, path: candidate)
        end

        def infer_identifier(candidate, priority)
          symbol = candidate.respond_to?(:to_sym) ? candidate.to_sym : candidate
          normalized = symbol.to_s.downcase
          explicit = normalized.gsub(/[^a-z0-9]+/, "_").to_sym
          return explicit if priority.include?(explicit)

          if File.exist?(candidate)
            basename = File.basename(candidate)
            inferred = basename.downcase.gsub(/[^a-z0-9]+/, "_").to_sym
            return inferred if priority.include?(inferred)
            return inferred
          end

          explicit
        end

        def memoized_lookup(identifier, override_command = nil)
          command = override_command || identifier.to_s
          self.class.lookup(identifier, command) do
            path = find_executable(command)
            if override_command
              ToolchainRecord.new(id: identifier, available: !path.nil?, path: path)
            else
              ToolchainRecord.new(id: identifier, available: true, path: path || command)
            end
          end
        end

        def find_executable(command)
          return command if executable_file?(command)

          path_extensions = if Gem.win_platform?
            ENV.fetch("PATHEXT", ".COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC").split(";")
          else
            [""]
          end

          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
            path_extensions.each do |ext|
              candidate = File.join(dir, ext.empty? ? command : "#{command}#{ext}")
              return candidate if executable_file?(candidate)
            end
          end

          nil
        end

        def executable_file?(path)
          File.exist?(path) && File.executable?(path) && !File.directory?(path)
        end

        def explicit_svg_path
          override = request.tool_overrides[:svg_path]
          return override if override && !override.to_s.strip.empty?

          extract_path("latexmath-pdf2svg")
        end

        def explicit_png_path
          override = request.tool_overrides[:png_path]
          return override if override && !override.to_s.strip.empty?

          extract_path("latexmath-pdftoppm")
        end

        def extract_path(key)
          value = raw_attributes[key]
          return nil if value.nil?

          stripped = value.to_s.strip
          stripped.empty? ? nil : stripped
        end

        def svg_candidates
          override = request.tool_overrides[:svg]
          return [override.to_s.strip].reject(&:empty?) unless override.nil? || override.to_s.strip.empty?

          SVG_PRIORITY.map(&:to_s)
        end

        def png_candidates
          override = request.tool_overrides[:png]
          return [override.to_s.strip].reject(&:empty?) unless override.nil? || override.to_s.strip.empty?

          PNG_PRIORITY.map(&:to_s)
        end

        class << self
          def lookup(identifier, command)
            @cache ||= {}
            key = [identifier, command]
            cached = @cache[key]
            return cached if cached

            record = yield
            @cache[key] = record
            record
          end

          def reset!
            @cache = {}
          end
        end
      end
    end
  end
end
