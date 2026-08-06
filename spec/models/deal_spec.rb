# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Deal do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stages) { pipeline.stages.ordered.to_a }
  let(:entry_stage) { stages[0] }
  let(:active_stage) { stages[1] }
  let(:done_stage) { stages[2] }
  let(:closed_stage) { stages[3] }
  let(:contact) { create(:contact, account: account) }

  def build_deal(stage: nil, **attrs)
    create(:deal, account: account, pipeline: pipeline, stage: stage || entry_stage, contact: contact, **attrs)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:stage) }
    it { is_expected.to belong_to(:contact) }
    it { is_expected.to belong_to(:assignee).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }

    it 'rejects a negative value' do
      expect(build_deal.tap { |deal| deal.value = -1 }).not_to be_valid
    end

    it 'rejects a stage from another pipeline' do
      other_stage = create(:stage, pipeline: create(:pipeline, account: account))
      deal = build_deal
      deal.stage = other_stage
      deal.pipeline = pipeline

      expect(deal).not_to be_valid
    end
  end

  describe 'status derived from stage_type' do
    it 'marks the deal as won when moved to a done stage' do
      deal = build_deal
      deal.update!(stage: done_stage)

      expect(deal.reload).to have_attributes(status: 'won')
      expect(deal.won_at).to be_present
    end

    it 'marks the deal as lost when moved to a closed stage' do
      deal = build_deal
      deal.update!(stage: closed_stage)

      expect(deal.reload).to have_attributes(status: 'lost')
      expect(deal.lost_at).to be_present
    end

    it 'reopens the deal when moved back to an active stage' do
      deal = build_deal(stage: done_stage)
      deal.update!(stage: active_stage)

      expect(deal.reload).to have_attributes(status: 'open', won_at: nil, lost_at: nil)
    end
  end

  describe '#move_to_stage!' do
    it 'dispatches deal.stage_changed exactly once' do
      deal = build_deal
      events = []
      allow(Rails.configuration.dispatcher).to receive(:dispatch) { |name, *| events << name }

      deal.move_to_stage!(active_stage)

      expect(events.count('deal.stage_changed')).to eq(1)
    end

    it 'refreshes last_activity_at' do
      deal = build_deal
      deal.update_columns(last_activity_at: 5.days.ago)

      expect { deal.move_to_stage!(active_stage) }
        .to(change { deal.reload.last_activity_at })
    end
  end

  describe '#rotting?' do
    it 'is false when the stage has no rotting_days' do
      stage = create(:stage, pipeline: pipeline, rotting_days: nil)
      expect(build_deal(stage: stage, last_activity_at: 1.year.ago)).not_to be_rotting
    end

    it 'is true past the stage threshold' do
      stage = create(:stage, pipeline: pipeline, rotting_days: 3)
      expect(build_deal(stage: stage, last_activity_at: 10.days.ago)).to be_rotting
    end

    it 'is false within the threshold' do
      stage = create(:stage, pipeline: pipeline, rotting_days: 30)
      expect(build_deal(stage: stage, last_activity_at: 2.days.ago)).not_to be_rotting
    end
  end

  describe '#cached_label_list_array' do
    it 'reads the labels from the cache column' do
      deal = build_deal
      deal.update!(label_list: %w[urgente vip])

      expect(deal.reload.cached_label_list_array).to contain_exactly('urgente', 'vip')
    end

    it 'returns an empty array when there are no labels' do
      expect(build_deal.cached_label_list_array).to eq([])
    end
  end

  describe 'update event payload' do
    # previous_changes carrega o BigDecimal de `value`, que o Sidekiq recusa.
    it 'serialises changed attributes to native JSON types' do
      deal = build_deal(value: 100)
      payload = nil
      allow(Rails.configuration.dispatcher).to receive(:dispatch) do |name, _ts, data|
        payload = data if name == 'deal.updated'
      end

      deal.update!(value: 250)

      expect(payload[:changed_attributes]['value'].map(&:class)).not_to include(BigDecimal)
    end
  end
end
