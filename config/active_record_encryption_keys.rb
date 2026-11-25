# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'fileutils'
require 'json'
require 'securerandom'

# Generates the Active Record encryption keys once and persists them in a file, so a
# self-hosted install does not need the keys configured by hand.
#
# Opt-in: only runs when ACTIVE_RECORD_ENCRYPTION_KEYS_FILE points to a path on a
# persistent volume shared by the web and worker processes. It stays off during the
# image build (assets:precompile) so keys are never baked into a shared image.
# Keys set explicitly in the environment always take precedence over the file.
#
# Losing or regenerating this file makes every value encrypted with it unreadable.
module ActiveRecordEncryptionKeys
  ENV_KEYS = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ].freeze

  def self.load!
    path = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEYS_FILE', '')
    return if path.empty?
    return if ENV_KEYS.any? { |key| !ENV.fetch(key, '').empty? }

    create_file(path) unless File.exist?(path)

    keys = JSON.parse(File.read(path))
    ENV_KEYS.each do |key|
      ENV[key] = keys.fetch(key)
    end
  end

  # The web and worker processes can boot at the same time on a fresh install. Each one
  # writes its own temporary file and links it into place; File.link fails when the
  # target already exists, so only the first process wins and the others read its keys.
  def self.create_file(path)
    FileUtils.mkdir_p(File.dirname(path))
    temp_path = "#{path}.#{Process.pid}.tmp"
    keys = ENV_KEYS.index_with { SecureRandom.hex(32) }
    File.write(temp_path, JSON.pretty_generate(keys), perm: 0o600)

    begin
      File.link(temp_path, path)
      warn "Generated Active Record encryption keys at #{path}. Back up this file: losing it makes encrypted data unreadable."
    rescue Errno::EEXIST
      # Another process created the file first; its keys are used.
    ensure
      File.delete(temp_path)
    end
  end
end
