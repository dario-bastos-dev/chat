# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Deals::Finder do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stage) { pipeline.stages.ordered.first }
  let(:other_stage) { pipeline.stages.ordered.second }
  let(:contact) { create(:contact, account: account, name: 'Maria Fernanda') }

  let!(:cheap) do
    create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact,
                  title: 'Contrato pequeno', value: 100)
  end
  let!(:pricey) do
    create(:deal, account: account, pipeline: pipeline, stage: other_stage, contact: contact,
                  title: 'Contrato grande', value: 5000)
  end

  def find(params)
    described_class.new(scope: Deal.where(account_id: account.id), params: params).perform
  end

  it 'returns everything when no filter is given' do
    expect(find({})).to contain_exactly(cheap, pricey)
  end

  it 'filters by stage' do
    expect(find(stage_id: stage.id)).to contain_exactly(cheap)
  end

  it 'searches by deal title' do
    expect(find(q: 'pequeno')).to contain_exactly(cheap)
  end

  it 'searches by contact name' do
    expect(find(q: 'Maria')).to contain_exactly(cheap, pricey)
  end

  it 'filters by label' do
    cheap.update!(label_list: ['urgente'])
    expect(find(label: 'urgente')).to contain_exactly(cheap)
  end

  it 'filters by custom field, case insensitively' do
    pricey.update!(custom_attributes: { 'origem' => 'Instagram' })
    expect(find(custom_field_key: 'origem', custom_field_value: 'insta')).to contain_exactly(pricey)
  end

  it 'filters by minimum value' do
    expect(find(min_value: 1000)).to contain_exactly(pricey)
  end

  it 'filters by maximum value' do
    expect(find(max_value: 1000)).to contain_exactly(cheap)
  end

  it 'combines filters' do
    expect(find(q: 'Contrato', min_value: 1000, stage_id: other_stage.id)).to contain_exactly(pricey)
  end

  it 'never widens the scope it was given' do
    other_account_deal = create(:deal)
    expect(find({})).not_to include(other_account_deal)
  end
end
