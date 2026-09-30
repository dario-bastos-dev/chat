require 'rails_helper'

describe DataImport::ContactManager do
  subject(:manager) { described_class.new(account) }

  let(:account) { create(:account) }

  # The params below have the shape DataImportJob hands over: a CSV row with indifferent access.
  describe 'social profiles' do
    it 'stores the networks of a new contact as social profiles, not as custom attributes' do
      row = { 'email' => 'ana@example.com', 'instagram' => 'ana.ig', 'linkedin' => 'ana-li' }
      contact = manager.build_contact(row.with_indifferent_access).tap(&:save!)

      contact.reload
      expect(contact.additional_attributes['social_profiles']).to eq('instagram' => 'ana.ig', 'linkedin' => 'ana-li')
      expect(contact.custom_attributes.keys).not_to include('instagram', 'linkedin')
    end

    it 'keeps the networks an existing contact already had when the file brings others' do
      create(:contact, account: account, email: 'ana@example.com',
                       additional_attributes: { 'social_profiles' => { 'facebook' => 'ana.fb' } })

      contact = manager.build_contact({ 'email' => 'ana@example.com', 'instagram' => 'ana.ig' }.with_indifferent_access).tap(&:save!)

      expect(contact.reload.additional_attributes['social_profiles']).to eq('facebook' => 'ana.fb', 'instagram' => 'ana.ig')
    end

    it 'replaces a network the file brings again' do
      create(:contact, account: account, email: 'ana@example.com',
                       additional_attributes: { 'social_profiles' => { 'instagram' => 'old.ig' } })

      contact = manager.build_contact({ 'email' => 'ana@example.com', 'instagram' => 'new.ig' }.with_indifferent_access).tap(&:save!)

      expect(contact.reload.additional_attributes['social_profiles']).to eq('instagram' => 'new.ig')
    end
  end
end
