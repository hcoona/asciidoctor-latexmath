# frozen_string_literal: true

# SPDX-FileCopyrightText: 2025 Shuai Zhang
#
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception

require "rake/clean"

CLEAN.include("sample.html", "generated_images")

if File.exist?("asciidoctor-latexmath.gemspec")
  begin
    require "bundler/gem_tasks"
  rescue LoadError
    warn <<~MSG
      Bundler is required to build gem packages.
      Install it with: gem install bundler
    MSG
  end
else
  warn "Skipping Bundler gem tasks because asciidoctor-latexmath.gemspec is missing."
end

def bundler_available?
  return true if ENV["BUNDLE_GEMFILE"]

  @bundler_available ||= begin
    system("bundle", "exec", "ruby", "-v", out: File::NULL, err: File::NULL)
  rescue Errno::ENOENT
    false
  end
end

SAMPLE_RENDER_CMD = if bundler_available?
  "bundle exec asciidoctor -r ./lib/asciidoctor-latexmath.rb sample.adoc"
else
  "asciidoctor -r ./lib/asciidoctor-latexmath.rb sample.adoc"
end

desc "Render sample.adoc with the local extension"
task :sample do
  sh SAMPLE_RENDER_CMD
end

task default: :sample
