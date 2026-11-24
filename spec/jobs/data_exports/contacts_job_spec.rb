require 'rails_helper'

RSpec.describe DataExports::ContactsJob do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:options) { {} }
  let(:data_export) { DataExports::CreationService.new(account: account, initiated_by: admin, options: options).perform }

  it 'owns its file, escapes formulas, and finishes with actual progress', :aggregate_failures do
    create(:contact, account: account, name: '=1+1', email: 'person@example.com')
    create(:contact, email: 'another-account@example.com')
    described_class.perform_now(data_export, data_export.active_run_id)
    expect(data_export.reload).to be_completed
    expect(data_export.processed_records).to eq(1)
    expect(data_export.total_records).to eq(1)
    contents = data_export.export_file.download
    expect(contents).to start_with("\uFEFF".b)
    expect(contents).to include("'=1+1")
    expect(contents).not_to include('another-account@example.com')
    expect(account.contacts_export).not_to be_attached
    expect { described_class.perform_now(data_export, data_export.active_run_id) }.not_to change(ActiveStorage::Blob, :count)
  end

  context 'with a label selection' do
    let(:options) { { label: 'vip', column_names: %w[email labels] } }

    it 'preserves the selected scope and column order' do
      create(:label, account: account, title: 'vip')
      contact = create(:contact, account: account, email: 'selected@example.com')
      contact.update!(label_list: ['vip'])
      create(:contact, account: account, email: 'excluded@example.com')
      described_class.perform_now(data_export, data_export.active_run_id)
      expect(data_export.export_file.download).to include('email,labels', 'selected@example.com,vip')
      expect(data_export.export_file.download).not_to include('excluded@example.com')
    end
  end

  it 'does not publish a file after the requesting user loses permission' do
    data_export
    account.account_users.find_by!(user: admin).update!(role: :agent)
    described_class.perform_now(data_export, data_export.active_run_id)
    expect(data_export.reload).to be_failed
    expect(data_export.export_file).not_to be_attached
  end

  it 'explains permission loss during generation without publishing a file' do
    create(:contact, account: account, email: 'person@example.com')
    job = described_class.new
    allow(job).to receive(:write_batch).and_wrap_original do |method, *args|
      method.call(*args)
      account.account_users.find_by!(user: admin).update!(role: :agent)
    end

    expect { job.perform(data_export, data_export.active_run_id) }.to raise_error(Pundit::NotAuthorizedError)
    expect(data_export.reload).to be_failed
    expect(data_export.error_message).to eq('The requesting user no longer has export access.')
    expect(data_export.export_file).not_to be_attached
  end

  it 'explains permission loss during upload and purges the unpublished file' do
    data_export
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_wrap_original do |method, **args|
      blob = method.call(**args)
      account.account_users.find_by!(user: admin).update!(role: :agent)
      blob
    end

    expect { described_class.perform_now(data_export, data_export.active_run_id) }.to raise_error(Pundit::NotAuthorizedError)
    expect(data_export.reload).to be_failed
    expect(data_export.error_message).to eq('The requesting user no longer has export access.')
    expect(data_export.export_file).not_to be_attached
    expect(ActiveStorage::PurgeJob).to have_been_enqueued
  end

  it 'keeps retry advice for an unexpected export failure' do
    job = described_class.new
    allow(job).to receive(:write_csv).and_raise(IOError, 'Storage unavailable')

    expect { job.perform(data_export, data_export.active_run_id) }.to raise_error(IOError)
    expect(data_export.reload).to be_failed
    expect(data_export.error_message).to eq('The export could not finish. Run the export again to retry.')
    expect(data_export.export_file).not_to be_attached
  end

  it 'ignores jobs from an obsolete run' do
    expect { described_class.perform_now(data_export, 'stale') }.not_to(change { data_export.reload.status })
    expect(data_export.export_file).not_to be_attached
  end

  it 'finishes an empty selection with a header-only file' do
    described_class.perform_now(data_export, data_export.active_run_id)
    expect(data_export.reload).to be_completed
    expect(data_export.total_records).to eq(0)
    expect(data_export.export_file.download.lines.size).to eq(1)
  end

  context 'with contact custom attributes' do
    before do
      create(:custom_attribute_definition, account: account, attribute_model: :contact_attribute, attribute_key: 'plan')
      create(:custom_attribute_definition, account: account, attribute_model: :conversation_attribute, attribute_key: 'channel_source')
    end

    it 'exports them by default alongside the city and company name' do
      create(:contact, account: account, email: 'person@example.com', custom_attributes: { 'plan' => 'gold' },
                       additional_attributes: { 'city' => 'Curitiba', 'company_name' => 'Acme' })
      described_class.perform_now(data_export, data_export.active_run_id)

      rows = CSV.parse(data_export.export_file.download.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF"), headers: true)
      expect(rows.headers).to include('plan', 'city', 'company_name')
      expect(rows.headers).not_to include('channel_source')
      expect(rows.first.to_h).to include('plan' => 'gold', 'city' => 'Curitiba', 'company_name' => 'Acme')
    end
  end

  context 'with a timezone' do
    let(:options) { { column_names: %w[email created_at], timezone: 'America/Sao_Paulo' } }

    it 'writes timestamps in that timezone' do
      create(:contact, account: account, email: 'person@example.com', created_at: Time.utc(2026, 1, 10, 2, 30))
      described_class.perform_now(data_export, data_export.active_run_id)

      expect(data_export.export_file.download).to include('person@example.com,2026-01-09 23:30:00 -0300')
    end
  end

  it 'rejects an unknown timezone before creating an export' do
    expect do
      DataExports::CreationService.new(account: account, initiated_by: admin, options: { timezone: 'Mars/Olympus' }).perform
    end.to raise_error(ArgumentError)
    expect(account.data_exports).to be_empty
  end

  it 'rejects unsupported columns before creating an export' do
    expect do
      DataExports::CreationService.new(account: account, initiated_by: admin, options: { column_names: ['destroy!'] }).perform
    end.to raise_error(ArgumentError, 'Unsupported export columns.')
    expect(account.data_exports).to be_empty
  end
end
