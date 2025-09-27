# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require_relative "asciidoctor-latexmath/version"
require_relative "asciidoctor-latexmath/treeprocessor"

Asciidoctor::Extensions.register do
  treeprocessor Asciidoctor::Latexmath::Treeprocessor
end
