# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pipeline do
  let(:account) { create(:account) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'rejects an unknown visibility' do
      expect(build(:pipeline, account: account, visibility: 'secret')).not_to be_valid
    end
  end

  describe 'default pipeline' do
    # A conta ja nasce com um funil padrao, criado no after_create_commit.
    it 'is created together with the account' do
      expect(account.pipelines.count).to eq(1)
      expect(account.pipelines.first).to be_is_default
    end

    it 'keeps a single default per account' do
      second = create(:pipeline, account: account, is_default: true)

      expect(account.pipelines.where(is_default: true)).to contain_exactly(second)
    end

    it 'promotes the remaining pipeline when none is marked as default' do
      pipeline = create(:pipeline, account: account, is_default: false)
      account.pipelines.where.not(id: pipeline.id).update_all(is_default: false)
      pipeline.save!

      expect(pipeline.reload).to be_is_default
    end
  end

  describe 'destroying a pipeline with deals' do
    it 'migrates the deals to another pipeline instead of losing them' do
      source = create(:pipeline, :with_stages, account: account)
      target = account.pipelines.find_by(is_default: true)
      create(:stage, pipeline: target, stage_type: 'not_started', position: 20)
      deal = create(:deal, account: account, pipeline: source, stage: source.stages.ordered.first,
                           contact: create(:contact, account: account))

      source.destroy

      expect(deal.reload.pipeline_id).to eq(target.id)
    end
  end

  describe 'default stages' do
    it 'creates the four stage types in order' do
      stages = account.pipelines.first.stages.ordered

      expect(stages.pluck(:stage_type)).to eq(%w[not_started active done closed])
      expect(stages.pluck(:color)).to all(be_present)
    end
  end
end
