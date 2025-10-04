# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require_relative "../errors"

module Asciidoctor
  module Latexmath
    module Support
      class ConflictRegistry
        def initialize
          @entries = {}
        end

        def register!(basename, signature, location)
          record = entries[basename]
          if record
            unless record[:signature] == signature
              raise TargetConflictError, "Target '#{basename}' already used at #{record[:location]}"
            end
          else
            entries[basename] = {signature: signature, location: location}
          end
        end

        private

        attr_reader :entries
      end
    end
  end
end
