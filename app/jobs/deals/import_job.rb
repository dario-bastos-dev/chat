# frozen_string_literal: true

# Import de negocios via CSV. Espelha o DataImportJob de contatos: separa
# aceitos de rejeitados, grava os rejeitados num CSV anexo com a coluna de erro,
# e conclui o DataImport com os contadores.
class Deals::ImportJob < ApplicationJob
  queue_as :low

  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  def perform(data_import)
    @data_import = data_import
    @manager = DataImport::DealManager.new(@data_import.account)

    return fail_import!(I18n.t('errors.deals.import.no_pipeline')) unless @manager.usable?

    process
  rescue CSV::MalformedCSVError
    fail_import!(I18n.t('errors.deals.import.malformed'))
  end

  private

  def process
    @data_import.update!(status: :processing)
    accepted, rejected = build_rows

    accepted.each(&:save)
    @data_import.update!(
      status: :completed,
      processed_records: accepted.count(&:persisted?),
      total_records: accepted.size + rejected.size
    )
    attach_failed_records(rejected)
  end

  def build_rows
    accepted = []
    rejected = []

    with_import_file do |file|
      csv_reader(file).each do |row|
        deal = @manager.build_deal(row.to_h.with_indifferent_access)
        if deal.valid?
          accepted << deal
        else
          rejected << row.to_h.merge('errors' => deal.errors.full_messages.join(', '))
        end
      end
    end

    [accepted, rejected]
  end

  def attach_failed_records(rejected)
    return if rejected.blank?

    csv_data = CSV.generate do |csv|
      csv << rejected.first.keys
      rejected.each { |row| csv << row.values }
    end

    @data_import.failed_records.attach(
      io: StringIO.new(csv_data),
      filename: "#{Time.zone.today.strftime('%Y%m%d')}_deals_rejeitados.csv",
      content_type: 'text/csv'
    )
  end

  def fail_import!(message)
    @data_import.update!(status: :failed, processing_errors: message)
  end

  def csv_reader(file)
    file.rewind
    raw = file.read.force_encoding('UTF-8')
    clean = raw.valid_encoding? ? raw : raw.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')

    CSV.new(StringIO.new(clean), headers: true, header_converters: ->(h) { h.to_s.strip.downcase })
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      file.binmode
      yield file
    end
  end
end
