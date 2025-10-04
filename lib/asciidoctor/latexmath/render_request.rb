# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

module Asciidoctor
  module Latexmath
    class RenderRequest
      attr_reader :expression, :format, :engine, :preamble, :ppi, :timeout, :keep_artifacts,
        :nocache, :cachedir, :artifacts_dir, :tool_overrides, :content_hash, :preamble_hash

      def initialize(expression:, format:, engine:, preamble:, ppi:, timeout:, keep_artifacts:, nocache:, cachedir:, artifacts_dir:, tool_overrides:, content_hash:, preamble_hash:)
        @expression = expression
        @format = format
        @engine = engine
        @preamble = preamble
        @ppi = ppi
        @timeout = timeout
        @keep_artifacts = keep_artifacts
        @nocache = nocache
        @cachedir = cachedir
        @artifacts_dir = artifacts_dir
        @tool_overrides = tool_overrides
        @content_hash = content_hash
        @preamble_hash = preamble_hash
      end
    end
  end
end
