# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "fileutils"
require "json"
require "digest"
require "time"

module Asciidoctor
  module Latexmath
    module Cache
      class DiskCache
        METADATA_FILENAME = "metadata.json"
        ARTIFACT_FILENAME = "artifact"

        def initialize(root)
          @root = root
          FileUtils.mkdir_p(@root)
        end

        def fetch(key_digest)
          entry_dir = entry_dir(key_digest)
          metadata_path = File.join(entry_dir, METADATA_FILENAME)
          artifact_path = File.join(entry_dir, ARTIFACT_FILENAME)
          return nil unless File.exist?(metadata_path) && File.exist?(artifact_path)

          metadata = JSON.parse(File.read(metadata_path))
          CacheEntry.new(
            final_path: artifact_path,
            format: metadata["format"],
            content_hash: metadata["content_hash"],
            preamble_hash: metadata["preamble_hash"],
            engine: metadata["engine"],
            ppi: metadata["ppi"],
            entry_type: metadata["entry_type"],
            created_at: Time.parse(metadata["created_at"]),
            checksum: metadata["checksum"],
            size_bytes: metadata["size_bytes"]
          )
        rescue JSON::ParserError, Errno::ENOENT
          nil
        end

        def store(key_digest, cache_entry, source_path)
          entry_dir = entry_dir(key_digest)
          FileUtils.mkdir_p(entry_dir)
          artifact_path = File.join(entry_dir, ARTIFACT_FILENAME)
          temp_artifact = artifact_path + ".tmp"

          FileUtils.cp(source_path, temp_artifact)
          FileUtils.mv(temp_artifact, artifact_path)

          metadata_path = File.join(entry_dir, METADATA_FILENAME)
          temp_metadata = metadata_path + ".tmp"
          metadata = {
            "format" => cache_entry.format,
            "content_hash" => cache_entry.content_hash,
            "preamble_hash" => cache_entry.preamble_hash,
            "engine" => cache_entry.engine,
            "ppi" => cache_entry.ppi,
            "entry_type" => cache_entry.entry_type,
            "created_at" => cache_entry.created_at.utc.iso8601,
            "checksum" => cache_entry.checksum,
            "size_bytes" => cache_entry.size_bytes
          }
          File.write(temp_metadata, JSON.pretty_generate(metadata))
          FileUtils.mv(temp_metadata, metadata_path)
        end

        def with_lock(key_digest)
          lock_path = File.join(root, "#{key_digest}.lock")
          FileUtils.mkdir_p(File.dirname(lock_path))
          File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |file|
            file.flock(File::LOCK_EX)
            yield
          ensure
            file.flock(File::LOCK_UN)
          end
        end

        private

        attr_reader :root

        def entry_dir(key_digest)
          File.join(root, key_digest)
        end
      end
    end
  end
end
