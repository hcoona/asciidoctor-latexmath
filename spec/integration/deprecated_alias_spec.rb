# frozen_string_literal: true

require "asciidoctor-latexmath"

class CapturingLogger
  attr_reader :messages

  def initialize
    @messages = []
  end

  def add(severity, message = nil, progname = nil)
    content = message
    content = yield if message.nil? && block_given?
    @messages << [severity, content]
  end

  def warn(message = nil, &block)
    add(:warn, message, &block)
  end

  def info(message = nil, &block)
    add(:info, message, &block)
  end

  def debug(message = nil, &block)
    add(:debug, message, &block)
  end

  def error(message = nil, &block)
    add(:error, message, &block)
  end
end

RSpec.describe "Deprecated alias handling" do
  it "logs a single info message when cache-dir alias is used" do
    logger = CapturingLogger.new
    Asciidoctor::LoggerManager.logger = logger

    within_tmpdir do |dir|
      Dir.chdir(dir) do
        source = <<~ADOC
          [latexmath, cache-dir=legacy]
          ++++
          x
          ++++
        ADOC

        convert_with_extension(source, attributes: {"imagesdir" => "images"})
      end
    end

    messages = logger.messages.select { |(_, msg)| msg.include?("cache-dir is deprecated") }
    expect(messages.size).to eq(1)
  ensure
    Asciidoctor::LoggerManager.logger = nil
  end
end
