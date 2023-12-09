# frozen_string_literal: true

require 'spec_helper'

describe HistoricalData do
  before do
    (1..12).each do |i|
      described_class.create!(date: Date.new(2014, i, 1), active_user_count: i * 100)
    end
  end

  describe ".during" do
    it "returns the historical data during the specified period" do
      expect(described_class.during(Date.new(2014, 1, 1)..Date.new(2014, 12, 31)).average(:active_user_count)).to eq(650)
    end
  end

  describe ".up_until" do
    it "returns the historical data up until the specified date" do
      expect(described_class.up_until(Date.new(2014, 6, 1)).average(:active_user_count)).to eq(350)
    end
  end

  describe ".at" do
    it "returns the historical data at the specified date" do
      expect(described_class.at(Date.new(2014, 8, 1)).active_user_count).to eq(800)
    end
  end

  describe ".track!" do
    before do
      allow(User).to receive(:active).and_return([1, 2, 3, 4, 5])
    end

    it "creates a new historical data record" do
      described_class.track!

      data = described_class.last
      expect(data.date).to eq(Date.today)
      expect(data.active_user_count).to eq(5)
    end
  end

  describe '.max_historical_user_count' do
    context 'with multiple historical data points for the current license' do
      before do
        (1..3).each do |i|
          described_class.create!(date: Time.now - i.days, active_user_count: i * 100)
        end
      end

      it 'returns max user count for the past year' do
        expect(described_class.max_historical_user_count).to eq(300)
      end
    end

    context 'using parameters' do
      let!(:license) do
        create(
          :license,
          starts_at: Date.new(2014, 1, 1),
          expires_at: Date.new(2014, 12, 1)
        )
      end

      it 'returns max user count for the given license' do
        expect(described_class.max_historical_user_count(license: license)).to eq(1200)
      end

      it 'returns max user count for the time range' do
        from = Date.new(2014, 6, 1)
        to = Date.new(2014, 9, 1)

        expect(described_class.max_historical_user_count(from: from, to: to)).to eq(900)
      end
    end

    context 'with different plans' do
      using RSpec::Parameterized::TableSyntax

      before do
        create(:group_member, :guest)
        create(:group_member, :reporter)
        create(:license, plan: plan)

        described_class.track!
      end

      where(:gl_plan, :expected_count) do
        ::License::STARTER_PLAN  | 2
        ::License::PREMIUM_PLAN  | 2
        ::License::ULTIMATE_PLAN | 1
      end

      with_them do
        let(:plan) { gl_plan }

        it 'does not count guest users' do
          expect(described_class.max_historical_user_count).to eq(expected_count)
        end
      end
    end

    context 'with data outside of the license period' do
      let!(:license) { create(:license) }

      context 'with stats before the license period' do
        before do
          described_class.create!(date: license.starts_at.ago(2.days), active_user_count: 10)
        end

        it 'ignore those records' do
          expect(described_class.max_historical_user_count).to eq(0)
        end
      end

      context 'with stats after the license period' do
        before do
          described_class.create!(date: license.expires_at.in(2.days), active_user_count: 10)
        end

        it 'ignore those records' do
          expect(described_class.max_historical_user_count).to eq(0)
        end
      end

      context 'with stats inside license period' do
        before do
          described_class.create!(date: license.starts_at.in(2.days), active_user_count: 10)
          described_class.create!(date: license.starts_at.in(5.days), active_user_count: 15)
        end

        it 'returns max value for active_user_count' do
          expect(described_class.max_historical_user_count).to eq(15)
        end
      end
    end
  end
end
