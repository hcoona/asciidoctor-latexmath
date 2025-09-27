# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "asciidoctor/extensions"
require "fileutils"
require "pathname"
require "cgi"
require_relative "renderer"

module Asciidoctor
  module Latexmath
    class Treeprocessor < Asciidoctor::Extensions::Treeprocessor
      LINE_FEED = %(
)
      STEM_INLINE_MACRO_RX = /\\?(stem|latexmath):([a-z,]*)\[(.*?[^\\])\]/m

      def process(document)
        return unless needs_processing?(document)

        renderer = Renderer.new(document)
        image_output_dir, image_target_dir = image_output_and_target_dir(document)
        context = {renderer: renderer, image_output_dir: image_output_dir, image_target_dir: image_target_dir}

        (document.find_by(context: :stem, traverse_documents: true) || []).dup.each do |stem|
          handle_stem_block(stem, context)
        end

        (document.find_by(traverse_documents: true) { |node| prose_candidate?(node) } || []).each do |prose|
          handle_prose_block(prose, context)
        end

        (document.find_by(content: :section) || []).each do |section|
          handle_section_title(section, context)
        end

        document.remove_attr "stem"
        begin
          (document.instance_variable_get :@header_attributes)&.delete("stem")
        rescue
          nil
        end

        nil
      end

      private

      def needs_processing?(document)
        stem_nodes = document.find_by(context: :stem, traverse_documents: true) || []
        return true if stem_nodes.any? { |stem| latexmath_node?(stem) }

        if (stem_attr = default_stem_style(document))
          return true if stem_attr == "latexmath"
        end

        inline_candidates = document.find_by(traverse_documents: true) { |node| prose_candidate?(node) } || []
        inline_candidates.any? { |node| contains_inline_stem?(node) }
      end

      def handle_stem_block(stem, context)
        return unless latexmath_node?(stem)

        content = extract_block_content(stem)
        result = render_equation(
          content,
          display: true,
          inline: false,
          id: stem.id,
          context: context,
          asciidoc_source: stem.source,
          source_location: stem.source_location
        )
        return unless result

        parent = stem.parent
        target, width, height = store_result(result, context)
        return unless target

        alt_text = stem.attr "alt", ((stem.context == :stem) ? stem.source : stem.content).to_s
        attrs = {
          "target" => target,
          "alt" => alt_text,
          "align" => "center"
        }
        if result.format == :png && width && height
          attrs["width"] = width.to_i
          attrs["height"] = height.to_i
        end

        replacement = create_image_block parent, attrs
        replacement.id = stem.id if stem.id
        if (title = stem.attributes["title"])
          replacement.title = title
        end
        index = parent.blocks.index(stem)
        parent.blocks[index] = replacement if index
      rescue RenderingError => e
        insert_block_error(stem, e)
      end

      def handle_prose_block(prose, context)
        use_text_property = %i[list_item table_cell].include?(prose.context)
        text = if use_text_property
          prose.instance_variable_get(:@text)
        else
          (prose.lines || []) * LINE_FEED
        end

        updated_text, modified = inline_replace(text, prose, prose.document, context)
        return unless modified

        if use_text_property
          prose.text = updated_text
        else
          prose.lines = updated_text.split(LINE_FEED)
        end
      end

      def handle_section_title(section, context)
        text = section.instance_variable_get(:@title)
        updated_text, modified = inline_replace(text, section, section.document, context)
        section.title = updated_text if modified
      end

      def latexmath_node?(node)
        style = node.style
        if style
          style_name = style.to_s
          return true if %w[latexmath tex].include?(style_name)
        end

        default_style = default_stem_style(node.document)
        default_style == "latexmath"
      end

      def default_stem_style(document)
        stem_attr = document.attr("stem")
        return unless stem_attr
        value = stem_attr.to_s.split(",").map(&:strip).find { |val| val == "latexmath" || val == "tex" }
        (value == "tex") ? "latexmath" : value
      end

      def extract_block_content(stem)
        case stem.context
        when :stem
          stem.content
        else
          stem.source
        end
      end

      def render_equation(content, display:, inline:, context:, id: nil, asciidoc_source: nil, source_location: nil)
        context[:renderer].render(
          equation: normalize_equation(content),
          display: display,
          inline: inline,
          id: id,
          asciidoc_source: asciidoc_source,
          source_location: source_location
        )
      end

      def normalize_equation(content)
        content.strip
      end

      def store_result(result, context)
        return [nil, nil, nil] unless result.data

        image_output_dir = context[:image_output_dir]
        image_target_dir = context[:image_target_dir]

        FileUtils.mkdir_p(image_output_dir) unless File.directory?(image_output_dir)
        filename = "#{result.basename}.#{result.extension}"
        output_path = ::File.join(image_output_dir, filename)
        ::File.binwrite(output_path, result.data)

        target = if image_target_dir == "."
          filename
        else
          ::File.join(image_target_dir, filename)
        end

        [target, result.width, result.height]
      end

      def inline_replace(text, node, document, context)
        return [text, false] unless text && !text.empty?

        modified = false
        default_style = default_stem_style(document) || "latexmath"

        new_text = text.gsub(STEM_INLINE_MACRO_RX) do
          match = Regexp.last_match
          escaped = match[0].start_with?("\\")
          if escaped
            match[0][1..]
          else
            macro = match[1]
            subs = match[2]
            equation = match[3].rstrip
            next "" if equation.empty?

            style = (macro == "stem") ? default_style : "latexmath"
            if style == "latexmath"
              inline_subs = (subs.nil? || subs.empty?) ? [] : node.resolve_pass_subs(subs)
              equation = node.apply_subs(equation, inline_subs) unless inline_subs.empty?
              begin
                result = render_equation(
                  equation,
                  display: false,
                  inline: true,
                  context: context,
                  asciidoc_source: match[0],
                  source_location: node.source_location
                )
              rescue RenderingError => e
                location = node.source_location
                log_rendering_error(e, location)
                ensure_macros_substitution(node)
                modified = true
                next inline_error_markup(e, location)
              end
              next match[0] unless result

              modified = true

              if result.inline_markup
                ensure_macros_substitution(node)
                %(pass:[#{result.inline_markup}])
              else
                target, width, height = store_result(result, context)
                next match[0] unless target
                attrs = []
                attrs << %(width=#{width.to_i}) if width
                attrs << %(height=#{height.to_i}) if height
                attr_text = attrs.join(",")
                ensure_macros_substitution(node)
                %(image:#{target}[#{attr_text}])
              end
            else
              match[0]
            end
          end
        end

        [new_text, modified]
      end

      def prose_candidate?(node)
        (node.content_model == :simple && node.subs.include?(:macros)) || %i[list_item table_cell].include?(node.context)
      end

      def contains_inline_stem?(node)
        text = if node.context == :list_item || node.context == :table_cell
          node.instance_variable_get(:@text)
        else
          (node.lines || []) * LINE_FEED
        end
        text && text =~ STEM_INLINE_MACRO_RX
      end

      def ensure_macros_substitution(node)
        return unless node.respond_to?(:subs)

        subs = node.subs
        if subs.nil?
          node.instance_variable_set(:@subs, [:macros])
        elsif subs.include?(:macros)
          # already enabled
        else
          updated = subs.dup
          updated << :macros
          node.instance_variable_set(:@subs, updated)
        end
      end

      def image_output_and_target_dir(doc)
        output_dir = doc.attr("imagesoutdir")
        if output_dir
          if doc.attr("imagesdir").nil_or_empty?
            target_dir = output_dir
          else
            abs_imagesdir = ::Pathname.new doc.normalize_system_path(doc.attr("imagesdir"))
            abs_outdir = ::Pathname.new doc.normalize_system_path(output_dir)
            target_dir = abs_outdir.relative_path_from(abs_imagesdir).to_s
          end
        else
          output_dir = doc.attr("imagesdir") || "."
          target_dir = "."
        end

        output_dir = doc.normalize_system_path(output_dir, doc.attr("docdir"))
        [output_dir, target_dir]
      end

      def insert_block_error(stem, error)
    log_rendering_error(error, stem.source_location)
    parent = stem.parent
    return unless parent

    text = block_error_text(error, stem.source_location)
        replacement = Asciidoctor::Block.new(parent, :listing, source: text)
        replacement.add_role("latexmath-error") if replacement.respond_to?(:add_role)
        replacement.id = stem.id if stem.id
        if (title = stem.attributes["title"])
          replacement.title = title
        end

        index = parent.blocks.index(stem)
        if index
          parent.blocks[index] = replacement
        else
          parent.blocks << replacement
        end
      end

      def block_error_text(error, source_location)
        location_hint = format_error_location(source_location)
        header = if location_hint.empty?
          "Failed to render latexmath"
        else
          "Failed to render latexmath#{location_hint}"
        end
        header = "#{header}:"
        message = error.message.to_s.rstrip
        message.empty? ? header : "#{header}\n#{message}"
      end

      def inline_error_markup(error, source_location = nil)
        location_hint = format_error_location(source_location)
        prefix = "Failed to render latexmath"
        prefix += location_hint unless location_hint.empty?
        message = "#{prefix}: #{error.message}".strip
        escaped = CGI.escapeHTML(message)
        escaped = escaped.gsub(/\r?\n/, "<br>")
        "+++<span class=\"latexmath-error\"><code>#{escaped}</code></span>+++"
      end

      def log_rendering_error(error, source_location)
        location_hint = format_error_location(source_location)
        first_line = error.message.to_s.lines.first&.strip || error.message.to_s
        warn %(asciidoctor-latexmath: #{first_line}#{location_hint})
      end

      def format_error_location(source_location)
        return "" unless source_location

        file = if source_location.respond_to?(:file)
          source_location.file
        elsif source_location.respond_to?(:path)
          source_location.path
        elsif source_location.respond_to?(:filename)
          source_location.filename
        end

        line = source_location.respond_to?(:lineno) ? source_location.lineno : nil

        parts = []
        parts << file if file && !file.to_s.empty?
        parts << line if line
        parts.empty? ? "" : " (#{parts.join(':')})"
      end
    end
  end
end
