# frozen_string_literal: true

require "spec_helper"

describe License do
  let(:gl_license)  { build(:gitlab_license) }
  let(:license)     { build(:license, data: gl_license.export) }

  describe "Validation" do
    describe "Valid license" do
      context "when the license is provided" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when no license is provided" do
        before do
          license.data = nil
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end
    end

    describe '#check_users_limit' do
      using RSpec::Parameterized::TableSyntax

      before do
        create(:group_member, :guest)
        create(:group_member, :reporter)
        create(:license, plan: plan)
      end

      let(:users_count) { nil }
      let(:new_license) do
        gl_license = build(:gitlab_license, restrictions: { plan: plan, active_user_count: users_count, previous_user_count: 1 })
        build(:license, data: gl_license.export)
      end

      where(:gl_plan, :valid) do
        ::License::STARTER_PLAN  | false
        ::License::PREMIUM_PLAN  | false
        ::License::ULTIMATE_PLAN | true
      end

      with_them do
        let(:plan) { gl_plan }

        context 'when license has restricted users' do
          let(:users_count) { 1 }

          it { expect(new_license.valid?).to eq(valid) }
        end

        context 'when license has unlimited users' do
          let(:users_count) { nil }

          it 'is always valid' do
            expect(new_license.valid?).to eq(true)
          end
        end
      end
    end

    describe "Historical active user count" do
      let(:active_user_count) { User.active.count + 10 }
      let(:date)              { described_class.current.starts_at }
      let!(:historical_data)  { HistoricalData.create!(date: date, active_user_count: active_user_count) }

      context "when there is no active user count restriction" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context 'without historical data' do
        before do
          create_list(:user, 2)

          gl_license.restrictions = {
            previous_user_count: 1,
            active_user_count: User.active.count - 1
          }

          HistoricalData.delete_all
        end

        context 'with previous_user_count and active users above of license limit' do
          it 'is invalid' do
            expect(license).to be_invalid
          end

          it 'shows the proper error message' do
            license.valid?

            error_msg = "This GitLab installation currently has 2 active users, exceeding this license's limit of 1 by 1 user. " \
                        "Please upload a license for at least 2 users or contact sales at renewals@gitlab.com"

            expect(license.errors[:base].first).to eq(error_msg)
          end
        end
      end

      context "when the active user count restriction is exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count - 1 }
        end

        context "when the license started" do
          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "after the license started" do
          let(:date) { Date.today }

          it "is valid" do
            expect(license).to be_valid
          end
        end

        context "in the year before the license started" do
          let(:date) { described_class.current.starts_at - 6.months }

          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "earlier than a year before the license started" do
          let(:date) { described_class.current.starts_at - 2.years }

          it "is valid" do
            expect(license).to be_valid
          end
        end
      end

      context "when the active user count restriction is not exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count + 1 }
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the active user count is met exactly" do
        it "is valid" do
          active_user_count = 100
          gl_license.restrictions = { active_user_count: active_user_count }

          expect(license).to be_valid
        end
      end

      context 'with true-up info' do
        context 'when quantity is ok' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 10)
          end

          it 'is valid' do
            expect(license).to be_valid
          end

          context 'but active users exceeds restricted user count' do
            it 'is invalid' do
              create_list(:user, 6)

              expect(license).not_to be_valid
            end
          end
        end

        context 'when quantity is wrong' do
          it 'is invalid' do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 8)

            expect(license).not_to be_valid
          end
        end

        context 'when previous user count is not present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 7)
          end

          it 'uses current active user count to calculate the expected true-up' do
            create_list(:user, 3)

            expect(license).to be_valid
          end

          context 'with wrong true-up quantity' do
            it 'is invalid' do
              create_list(:user, 2)

              expect(license).not_to be_valid
            end
          end
        end

        context 'when previous user count is present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 6, previous_user_count: 4)
          end

          it 'uses it to calculate the expected true-up' do
            expect(license).to be_valid
          end
        end
      end
    end

    describe "Not expired" do
      context "when the license doesn't expire" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the license has expired" do
        before do
          gl_license.expires_at = Date.yesterday
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end

      context "when the license has yet to expire" do
        before do
          gl_license.expires_at = Date.tomorrow
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end
    end

    describe 'downgrade' do
      context 'when more users were added in previous period' do
        before do
          HistoricalData.create!(date: 6.months.ago, active_user_count: 15)

          set_restrictions(restricted_user_count: 5, previous_user_count: 10)
        end

        it 'is invalid without a true-up' do
          expect(license).not_to be_valid
        end
      end

      context 'when no users were added in the previous period' do
        before do
          HistoricalData.create!(date: 6.months.ago, active_user_count: 15)

          set_restrictions(restricted_user_count: 10, previous_user_count: 15)
        end

        it 'is valid' do
          expect(license).to be_valid
        end
      end
    end
  end

  describe "Class methods" do
    let!(:license) { described_class.last }

    before do
      described_class.reset_current
      allow(described_class).to receive(:last).and_return(license)
    end

    describe '.features_for_plan' do
      it 'returns features for starter plan' do
        expect(described_class.features_for_plan('starter'))
          .to include(:multiple_issue_assignees)
      end

      it 'returns features for premium plan' do
        expect(described_class.features_for_plan('premium'))
          .to include(:multiple_issue_assignees, :deploy_board, :file_locks)
      end

      it 'returns features for early adopter plan' do
        expect(described_class.features_for_plan('premium'))
          .to include(:deploy_board, :file_locks)
      end

      it 'returns empty array if no features for given plan' do
        expect(described_class.features_for_plan('bronze')).to eq([])
      end
    end

    describe '.plan_includes_feature?' do
      let(:feature) { :deploy_board }

      subject { described_class.plan_includes_feature?(plan, feature) }

      context 'when addon included' do
        let(:plan) { 'premium' }

        it 'returns true' do
          is_expected.to eq(true)
        end
      end

      context 'when addon not included' do
        let(:plan) { 'starter' }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when plan is not set' do
        let(:plan) { nil }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when feature does not exists' do
        let(:plan) { 'premium' }
        let(:feature) { nil }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end
    end

    describe ".current" do
      context 'when licenses table does not exist' do
        before do
          allow(described_class).to receive(:table_exists?).and_return(false)
        end

        it 'returns nil' do
          expect(described_class.current).to be_nil
        end
      end

      context "when there is no license" do
        let!(:license) { nil }

        it "returns nil" do
          expect(described_class.current).to be_nil
        end
      end

      context "when the license is invalid" do
        before do
          allow(license).to receive(:valid?).and_return(false)
        end

        it "returns nil" do
          expect(described_class.current).to be_nil
        end
      end

      context "when the license is valid" do
        it "returns the license" do
          expect(described_class.current).to be_present
        end
      end
    end

    describe ".block_changes?" do
      context "when there is no current license" do
        before do
          allow(described_class).to receive(:current).and_return(nil)
        end

        it "returns false" do
          expect(described_class.block_changes?).to be_falsey
        end
      end

      context 'with an expired trial license' do
        let!(:license) { create(:license, trial: true) }

        it 'returns false' do
          expect(described_class.block_changes?).to be_falsey
        end
      end

      context 'with an expired normal license' do
        let!(:license) { create(:license, expired: true) }

        it 'returns true' do
          expect(described_class.block_changes?).to eq(true)
        end
      end

      context "when the current license is set to block changes" do
        before do
          allow(license).to receive(:block_changes?).and_return(true)
        end

        it "returns true" do
          expect(described_class.block_changes?).to be_truthy
        end
      end

      context "when the current license doesn't block changes" do
        it "returns false" do
          expect(described_class.block_changes?).to be_falsey
        end
      end
    end

    describe '.global_feature?' do
      subject { described_class.global_feature?(feature) }

      context 'when it is a global feature' do
        let(:feature) { :geo }

        it { is_expected.to be(true) }
      end

      context 'when it is not a global feature' do
        let(:feature) { :sast }

        it { is_expected.to be(false) }
      end
    end
  end

  describe "#md5" do
    it "returns the same MD5 for licenses with carriage returns and those without" do
      other_license = build(:license, data: license.data.gsub("\n", "\r\n"))

      expect(other_license.md5).to eq(license.md5)
    end

    it "returns the same MD5 for licenses with trailing newlines and those without" do
      other_license = build(:license, data: license.data.chomp)

      expect(other_license.md5).to eq(license.md5)
    end

    it "returns the same MD5 for licenses with multiple trailing newlines and those with a single trailing newline" do
      other_license = build(:license, data: "#{license.data}\n\n\n")

      expect(other_license.md5).to eq(license.md5)
    end
  end

  describe "#license" do
    context "when no data is provided" do
      before do
        license.data = nil
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when corrupt license data is provided" do
      before do
        license.data = "whatever"
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when valid license data is provided" do
      it "returns the license" do
        expect(license.license).not_to be_nil
      end
    end
  end

  describe 'reading add-ons' do
    describe '#plan' do
      let(:gl_license) { build(:gitlab_license, restrictions: restrictions.merge(add_ons: {})) }
      let(:license)    { build(:license, data: gl_license.export) }

      subject { license.plan }

      [
        { restrictions: {},                  plan: License::STARTER_PLAN },
        { restrictions: { plan: nil },       plan: License::STARTER_PLAN },
        { restrictions: { plan: '' },        plan: License::STARTER_PLAN },
        { restrictions: { plan: 'unknown' }, plan: 'unknown' }
      ].each do |spec|
        context spec.inspect do
          let(:restrictions) { spec[:restrictions] }

          it { is_expected.to eq(spec[:plan]) }
        end
      end
    end

    describe '#features_from_add_ons' do
      context 'without add-ons' do
        it 'returns an empty array' do
          license = build_license_with_add_ons({}, plan: 'unknown')

          expect(license.features_from_add_ons).to eq([])
        end
      end

      context 'with add-ons' do
        it 'returns all available add-ons' do
          license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 1, 'GitLab_FileLocks' => 2 })

          expect(license.features_from_add_ons).to match_array([:deploy_board, :file_locks])
        end
      end

      context 'with nil add-ons' do
        it 'returns an empty array' do
          license = build_license_with_add_ons({ 'GitLab_DeployBoard' => nil, 'GitLab_FileLocks' => nil })

          expect(license.features_from_add_ons).to eq([])
        end
      end
    end

    describe '#feature_available?' do
      it 'returns true if add-on exists and have a quantity greater than 0' do
        license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 1 })

        expect(license.feature_available?(:deploy_board)).to eq(true)
      end

      it 'returns true if the feature is included in the plan do' do
        license = build_license_with_add_ons({}, plan: License::PREMIUM_PLAN)

        expect(license.feature_available?(:auditor_user)).to eq(true)
      end

      it 'returns false if add-on exists but have a quantity of 0' do
        license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 0 })

        expect(license.feature_available?(:deploy_board)).to eq(false)
      end

      it 'returns false if add-on does not exists' do
        license = build_license_with_add_ons({})

        expect(license.feature_available?(:deploy_board)).to eq(false)
        expect(license.feature_available?(:auditor_user)).to eq(false)
      end

      context 'with an expired trial license' do
        let(:license) { create(:license, trial: true, expired: true) }

        before(:all) do
          described_class.destroy_all # rubocop: disable DestroyAll
        end

        ::License::EES_FEATURES.each do |feature|
          it "returns false for #{feature}" do
            expect(license.feature_available?(feature)).to eq(false)
          end
        end
      end

      context 'when feature is disabled by a feature flag' do
        it 'returns false' do
          feature = license.features.first
          stub_feature_flags(feature => false)

          expect(license.features).not_to receive(:include?)

          expect(license.feature_available?(feature)).to eq(false)
        end
      end

      context 'when feature is enabled by a feature flag' do
        it 'returns true' do
          feature = license.features.first
          stub_feature_flags(feature => true)

          expect(license.feature_available?(feature)).to eq(true)
        end
      end
    end

    def build_license_with_add_ons(add_ons, plan: nil)
      gl_license = build(:gitlab_license, restrictions: { add_ons: add_ons, plan: plan })
      build(:license, data: gl_license.export)
    end
  end

  describe '#overage' do
    it 'returns 0 if restricted_user_count is nil' do
      allow(license).to receive(:restricted_user_count) { nil }

      expect(license.overage).to eq(0)
    end

    it 'returns the difference between user_count and restricted_user_count' do
      allow(license).to receive(:restricted_user_count) { 10 }

      expect(license.overage(14)).to eq(4)
    end

    it 'returns the difference using current_active_users_count as user_count if no user_count argument provided' do
      allow(license).to receive(:current_active_users_count) { 110 }
      allow(license).to receive(:restricted_user_count) { 100 }

      expect(license.overage).to eq(10)
    end

    it 'returns 0 if the difference is a negative number' do
      allow(license).to receive(:restricted_user_count) { 2 }

      expect(license.overage(1)).to eq(0)
    end
  end

  describe '#maximum_user_count' do
    using RSpec::Parameterized::TableSyntax

    subject { license.maximum_user_count }

    where(:current_active_users_count, :historical_max, :expected) do
      100 | 50  | 100
      50  | 100 | 100
      50  | 50  | 50
    end

    with_them do
      before do
        allow(license).to receive(:current_active_users_count) { current_active_users_count }
        allow(license).to receive(:historical_max) { historical_max }
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe 'Trial Licenses' do
    before do
      ApplicationSetting.create_from_defaults
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    end

    describe 'Update trial setting' do
      context 'when the license is not trial' do
        before do
          gl_license.restrictions = { trial: false }
          gl_license.expires_at = Date.tomorrow
        end

        it 'returns nil' do
          updated = license.update_trial_setting
          expect(updated).to be_nil
          expect(ApplicationSetting.current.license_trial_ends_on).to be_nil
        end
      end

      context 'when the license is the very first trial' do
        let(:tomorrow) { Date.tomorrow }

        before do
          gl_license.restrictions = { trial: true }
          gl_license.expires_at = tomorrow
        end

        it 'is eligible for trial' do
          expect(described_class.eligible_for_trial?).to be_truthy
        end

        it 'updates the trial setting' do
          updated = license.update_trial_setting

          expect(updated).to be_truthy
          expect(described_class.eligible_for_trial?).to be_falsey
          expect(ApplicationSetting.current.license_trial_ends_on).to eq(tomorrow)
        end
      end

      context 'when the license is a repeated trial' do
        let(:yesterday) { Date.yesterday }

        before do
          gl_license.restrictions = { trial: true }
          gl_license.expires_at = Date.tomorrow
          ApplicationSetting.current.update license_trial_ends_on: yesterday
        end

        it 'does not update existing trial setting' do
          updated = license.update_trial_setting
          expect(updated).to be_falsey
          expect(ApplicationSetting.current.license_trial_ends_on).to eq(yesterday)
        end

        it 'is not eligible for trial' do
          expect(described_class.eligible_for_trial?).to be_falsey
        end
      end
    end
  end

  describe '#promo_feature_available?' do
    subject { described_class.promo_feature_available?(feature) }

    shared_examples 'CI CD trial features' do |status|
      before do
        stub_feature_flags(free_period_for_pull_mirroring: status)
      end

      License::ANY_PLAN_FEATURES.each do |feature_name|
        context "with #{feature_name}" do
          let(:feature) { feature_name }

          it { is_expected.to eq(status) }
        end
      end
    end

    context 'with free_period_for_pull_mirroring enabled' do
      it_behaves_like 'CI CD trial features', true
    end

    context 'with free_period_for_pull_mirroring disabled' do
      it_behaves_like 'CI CD trial features', false
    end
  end

  def set_restrictions(opts)
    gl_license.restrictions = {
      active_user_count: opts[:restricted_user_count],
      previous_user_count: opts[:previous_user_count],
      trueup_quantity: opts[:trueup_quantity],
      trueup_from: (Date.today - 1.year).to_s,
      trueup_to: Date.today.to_s
    }
  end
end
