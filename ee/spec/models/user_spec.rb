# frozen_string_literal: true

require 'spec_helper'

describe User do
  subject(:user) { described_class.new }

  describe 'user creation' do
    describe 'with defaults' do
      it "applies defaults to user" do
        expect(user.group_view).to eq('details')
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:shared_runners_minutes_limit).to(:namespace) }
    it { is_expected.to delegate_method(:shared_runners_minutes_limit=).to(:namespace).with_arguments(133) }
  end

  describe 'associations' do
    subject { build(:user) }

    it { is_expected.to have_many(:reviews) }
    it { is_expected.to have_many(:vulnerability_feedback) }
    it { is_expected.to have_many(:path_locks).dependent(:destroy) }
    it { is_expected.to have_many(:users_security_dashboard_projects) }
    it { is_expected.to have_many(:security_dashboard_projects) }
  end

  describe 'nested attributes' do
    it { is_expected.to respond_to(:namespace_attributes=) }
  end

  describe 'validations' do
    it 'does not allow a user to be both an auditor and an admin' do
      user = build(:user, :admin, :auditor)

      expect(user).to be_invalid
    end
  end

  describe "scopes" do
    describe ".non_ldap" do
      it "retuns non-ldap user" do
        described_class.delete_all
        create(:user)
        ldap_user = create(:omniauth_user, provider: "ldapmain")
        create(:omniauth_user, provider: "gitlub")

        users = described_class.non_ldap

        expect(users.count).to eq(2)
        expect(users.detect { |user| user.username == ldap_user.username }).to be_nil
      end
    end

    describe '.excluding_guests' do
      let!(:user_without_membership) { create(:user).id }
      let!(:project_guest_user)      { create(:project_member, :guest).user_id }
      let!(:project_reporter_user)   { create(:project_member, :reporter).user_id }
      let!(:group_guest_user)        { create(:group_member, :guest).user_id }
      let!(:group_reporter_user)     { create(:group_member, :reporter).user_id }

      it 'exclude users with a Guest role in a Project/Group' do
        user_ids = described_class.excluding_guests.pluck(:id)

        expect(user_ids).to include(project_reporter_user)
        expect(user_ids).to include(group_reporter_user)

        expect(user_ids).not_to include(user_without_membership)
        expect(user_ids).not_to include(project_guest_user)
        expect(user_ids).not_to include(group_guest_user)
      end
    end

    describe 'with_invalid_expires_at_tokens' do
      it 'only includes users with invalid tokens' do
        valid_pat = create(:personal_access_token, expires_at: 7.days.from_now)
        invalid_pat1 = create(:personal_access_token, expires_at: nil)
        invalid_pat2 = create(:personal_access_token, expires_at: 20.days.from_now)

        users_with_invalid_tokens = described_class.with_invalid_expires_at_tokens(15.days.from_now)

        expect(users_with_invalid_tokens).to contain_exactly(invalid_pat1.user, invalid_pat2.user)
        expect(users_with_invalid_tokens).not_to include valid_pat.user
      end
    end

    describe '.active_without_ghosts' do
      let_it_be(:user1) { create(:user, :external) }
      let_it_be(:user2) { create(:user, state: 'blocked') }
      let_it_be(:user3) { create(:user, ghost: true) }
      let_it_be(:user4) { create(:user, bot_type: 'support_bot') }
      let_it_be(:user5) { create(:user, state: 'blocked', bot_type: 'support_bot') }

      it 'returns all active users including active bots but ghost users' do
        expect(described_class.active_without_ghosts).to match_array([user1, user4])
      end
    end
  end

  describe '.find_by_smartcard_identity' do
    let!(:user) { create(:user) }
    let!(:smartcard_identity) { create(:smartcard_identity, user: user) }

    it 'returns the user' do
      expect(described_class.find_by_smartcard_identity(smartcard_identity.subject,
                                             smartcard_identity.issuer))
        .to eq(user)
    end
  end

  describe 'the GitLab_Auditor_User add-on' do
    context 'creating an auditor user' do
      it "does not allow creating an auditor user if the addon isn't enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user, :auditor)).to be_invalid
      end

      it "does not allow creating an auditor user if no license is present" do
        allow(License).to receive(:current).and_return nil

        expect(build(:user, :auditor)).to be_invalid
      end

      it "allows creating an auditor user if the addon is enabled" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user, :auditor)).to be_valid
      end

      it "allows creating a regular user if the addon isn't enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user)).to be_valid
      end
    end

    describe '#auditor?' do
      it "returns true for an auditor user if the addon is enabled" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user, :auditor)).to be_auditor
      end

      it "returns false for an auditor user if the addon is not enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user, :auditor)).not_to be_auditor
      end

      it "returns false for an auditor user if a license is not present" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user, :auditor)).not_to be_auditor
      end

      it "returns false for a non-auditor user even if the addon is present" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user)).not_to be_auditor
      end
    end
  end

  describe '#access_level=' do
    let(:user) { build(:user) }

    before do
      # `auditor?` returns true only when the user is an auditor _and_ the auditor license
      # add-on is present. We aren't testing this here, so we can assume that the add-on exists.
      stub_licensed_features(auditor_user: true)
    end

    it "does not set 'auditor' for an invalid access level" do
      user.access_level = :invalid_access_level

      expect(user.auditor).to be false
    end

    it "does not set 'auditor' for admin level" do
      user.access_level = :admin

      expect(user.auditor).to be false
    end

    it "assigns the 'auditor' access level" do
      user.access_level = :auditor

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end

    it "assigns the 'auditor' access level" do
      user.access_level = :regular

      expect(user.access_level).to eq(:regular)
      expect(user.admin).to be false
      expect(user.auditor).to be false
    end

    it "clears the 'admin' access level when a user is made an auditor" do
      user.access_level = :admin
      user.access_level = :auditor

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end

    it "clears the 'auditor' access level when a user is made an admin" do
      user.access_level = :auditor
      user.access_level = :admin

      expect(user.access_level).to eq(:admin)
      expect(user.admin).to be true
      expect(user.auditor).to be false
    end

    it "doesn't clear existing 'auditor' access levels when an invalid access level is passed in" do
      user.access_level = :auditor
      user.access_level = :invalid_access_level

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end
  end

  describe '#can_read_all_resources?' do
    it 'returns true for auditor user' do
      user = build(:user, :auditor)

      expect(user.can_read_all_resources?).to be_truthy
    end
  end

  describe '#forget_me!' do
    subject { create(:user, remember_created_at: Time.now) }

    it 'clears remember_created_at' do
      subject.forget_me!

      expect(subject.reload.remember_created_at).to be_nil
    end

    it 'does not clear remember_created_at when in a GitLab read-only instance' do
      allow(Gitlab::Database).to receive(:read_only?) { true }

      expect { subject.forget_me! }.not_to change(subject, :remember_created_at)
    end
  end

  describe '#remember_me!' do
    subject { create(:user, remember_created_at: nil) }

    it 'updates remember_created_at' do
      subject.remember_me!

      expect(subject.reload.remember_created_at).not_to be_nil
    end

    it 'does not update remember_created_at when in a Geo read-only instance' do
      allow(Gitlab::Database).to receive(:read_only?) { true }

      expect { subject.remember_me! }.not_to change(subject, :remember_created_at)
    end
  end

  describe '#email_opted_in_source' do
    context 'for GitLab.com' do
      let(:user) { build(:user, email_opted_in_source_id: 1) }

      it 'returns GitLab.com' do
        expect(user.email_opted_in_source).to eq('GitLab.com')
      end
    end

    context 'for nil source id' do
      let(:user) { build(:user, email_opted_in_source_id: nil) }

      it 'returns blank' do
        expect(user.email_opted_in_source).to be_blank
      end
    end

    context 'for non-existent source id' do
      let(:user) { build(:user, email_opted_in_source_id: 2) }

      it 'returns blank' do
        expect(user.email_opted_in_source).to be_blank
      end
    end
  end

  describe '#available_custom_project_templates' do
    let(:user) { create(:user) }

    it 'returns an empty relation if group is not set' do
      expect(user.available_custom_project_templates.empty?).to be_truthy
    end

    context 'when group with custom project templates is set' do
      let(:group) { create(:group) }

      before do
        stub_ee_application_setting(custom_project_templates_group_id: group.id)
      end

      it 'returns an empty relation if group has no available project templates' do
        expect(group.projects.empty?).to be true
        expect(user.available_custom_project_templates.empty?).to be true
      end

      context 'when group has custom project templates' do
        let!(:private_project) { create :project, :private, namespace: group, name: 'private_project' }
        let!(:internal_project) { create :project, :internal, namespace: group, name: 'internal_project' }
        let!(:public_project) { create :project, :public, namespace: group, name: 'public_project' }
        let!(:public_project_two) { create :project, :public, namespace: group, name: 'public_project_second' }

        it 'returns public projects' do
          expect(user.available_custom_project_templates).to include public_project
        end

        context 'returns private projects if user' do
          it 'is a member of the project' do
            expect(user.available_custom_project_templates).not_to include private_project

            private_project.add_developer(user)

            expect(user.available_custom_project_templates).to include private_project
          end

          it 'is a member of the group' do
            expect(user.available_custom_project_templates).not_to include private_project

            group.add_developer(user)

            expect(user.available_custom_project_templates).to include private_project
          end
        end

        it 'returns internal projects' do
          expect(user.available_custom_project_templates).to include internal_project
        end

        it 'allows to search available project templates by name' do
          projects = user.available_custom_project_templates(search: 'publi')

          expect(projects.count).to eq 2
          expect(projects.first).to eq public_project
        end

        it 'filters by project ID' do
          projects = user.available_custom_project_templates(project_id: public_project.id)

          expect(projects.count).to eq 1
          expect(projects).to match_array([public_project])

          projects = user.available_custom_project_templates(project_id: [public_project.id, public_project_two.id])

          expect(projects.count).to eq 2
          expect(projects).to match_array([public_project, public_project_two])
        end

        it 'does not return inaccessible projects' do
          projects = user.available_custom_project_templates(project_id: private_project.id)

          expect(projects.count).to eq 0
        end
      end
    end
  end

  describe '#available_subgroups_with_custom_project_templates' do
    let(:user) { create(:user) }

    context 'without Groups with custom project templates' do
      before do
        group = create(:group)

        group.add_maintainer(user)
      end

      it 'returns an empty collection' do
        expect(user.available_subgroups_with_custom_project_templates).to be_empty
      end
    end

    context 'with Groups with custom project templates' do
      let!(:group_1) { create(:group, name: 'group-1') }
      let!(:group_2) { create(:group, name: 'group-2') }
      let!(:group_3) { create(:group, name: 'group-3') }

      let!(:subgroup_1) { create(:group, parent: group_1, name: 'subgroup-1') }
      let!(:subgroup_2) { create(:group, parent: group_2, name: 'subgroup-2') }
      let!(:subgroup_3) { create(:group, parent: group_3, name: 'subgroup-3') }

      before do
        group_1.update!(custom_project_templates_group_id: subgroup_1.id)
        group_2.update!(custom_project_templates_group_id: subgroup_2.id)
        group_3.update!(custom_project_templates_group_id: subgroup_3.id)

        create(:project, namespace: subgroup_1)
        create(:project, namespace: subgroup_2)
      end

      context 'when the access level of the user is below the required one' do
        before do
          group_1.add_reporter(user)
        end

        it 'returns an empty collection' do
          expect(user.available_subgroups_with_custom_project_templates).to be_empty
        end
      end

      context 'when the access level of the user is the correct' do
        before do
          group_1.add_developer(user)
          group_2.add_maintainer(user)
          group_3.add_developer(user)
        end

        context 'when a Group ID is passed' do
          it 'returns a single Group' do
            groups = user.available_subgroups_with_custom_project_templates(group_1.id)

            expect(groups.size).to eq(1)
            expect(groups.first.name).to eq('subgroup-1')
          end
        end

        context 'when a Group ID is not passed' do
          it 'returns all available Groups' do
            groups = user.available_subgroups_with_custom_project_templates

            expect(groups.size).to eq(2)
            expect(groups.map(&:name)).to include('subgroup-1', 'subgroup-2')
          end

          it 'excludes Groups with the configured setting but without projects' do
            groups = user.available_subgroups_with_custom_project_templates

            expect(groups.map(&:name)).not_to include('subgroup-3')
          end
        end

        context 'when namespace plan is checked' do
          before do
            create(:gitlab_subscription, namespace: group_1, hosted_plan: create(:bronze_plan))
            create(:gitlab_subscription, namespace: group_2, hosted_plan: create(:gold_plan))
            allow(Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?) { true }
          end

          it 'returns groups on gold or silver plans' do
            Timecop.freeze(GroupsWithTemplatesFinder::CUT_OFF_DATE + 1.day) do
              groups = user.available_subgroups_with_custom_project_templates

              expect(groups.size).to eq(1)
              expect(groups.map(&:name)).to include('subgroup-2')
            end
          end
        end
      end
    end
  end

  describe '#roadmap_layout' do
    context 'not set' do
      subject { build(:user, roadmap_layout: nil) }

      it 'returns default value' do
        expect(subject.roadmap_layout).to eq(EE::User::DEFAULT_ROADMAP_LAYOUT)
      end
    end

    context 'set' do
      subject { build(:user, roadmap_layout: 'quarters') }

      it 'returns set value' do
        expect(subject.roadmap_layout).to eq('quarters')
      end
    end
  end

  describe '#group_sso?' do
    subject(:user) { create(:user) }

    it 'is false without a saml_provider' do
      expect(subject.group_sso?(nil)).to be_falsey
      expect(subject.group_sso?(create(:group))).to be_falsey
    end

    context 'with linked identity' do
      let!(:identity) { create(:group_saml_identity, user: user) }
      let(:saml_provider) { identity.saml_provider }
      let(:group) { saml_provider.group }

      context 'without preloading' do
        it 'returns true' do
          expect(subject.group_sso?(group)).to be_truthy
        end

        it 'does not cause ActiveRecord to loop through identites' do
          create(:group_saml_identity, user: user)

          expect(Identity).not_to receive(:instantiate)

          subject.group_sso?(group)
        end
      end

      context 'when identities and saml_providers pre-loaded' do
        before do
          ActiveRecord::Associations::Preloader.new.preload(subject, group_saml_identities: :saml_provider)
        end

        it 'returns true' do
          expect(subject.group_sso?(group)).to be_truthy
        end

        it 'does not trigger additional database queries' do
          expect { subject.group_sso?(group) }.not_to exceed_query_limit(0)
        end
      end
    end
  end

  describe '#group_managed_account?' do
    subject { user.group_managed_account? }

    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it { is_expected.to eq true }
    end

    context 'when user has no linked managing group' do
      it { is_expected.to eq false }
    end
  end

  describe '#password_required?' do
    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it 'does not require password to be present' do
        expect(user).not_to validate_presence_of(:password)
        expect(user).not_to validate_presence_of(:password_confirmation)
      end
    end
  end

  describe '#allow_password_authentication_for_web?' do
    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it 'is false' do
        expect(user.allow_password_authentication_for_web?).to eq false
      end
    end
  end

  describe '#allow_password_authentication_for_git?' do
    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it 'is false' do
        expect(user.allow_password_authentication_for_git?).to eq false
      end
    end
  end

  describe '#using_license_seat?' do
    let(:user) { create(:user) }

    context 'when user is inactive' do
      before do
        user.block
      end

      it 'returns false' do
        expect(user.using_license_seat?).to eq false
      end
    end

    context 'when user is active' do
      context 'when user is internal' do
        using RSpec::Parameterized::TableSyntax

        where(:bot_type) do
          User.bot_types.keys
        end

        with_them do
          context 'when user is a bot' do
            let(:user) { create(:user, bot_type: bot_type) }

            it 'returns false' do
              expect(user.using_license_seat?).to eq false
            end
          end
        end

        context 'when user is a ghost' do
          let(:user) { create(:user, ghost: true) }

          it 'returns false' do
            expect(user.using_license_seat?).to eq false
          end
        end
      end

      context 'when user is not internal' do
        context 'when license is nil (core/free/default)' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'returns false if license is nil (core/free/default)' do
            expect(user.using_license_seat?).to eq false
          end
        end

        context 'user is guest' do
          let(:project_guest_user) { create(:project_member, :guest).user }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(project_guest_user.using_license_seat?).to eq false
          end

          it 'returns true if license is not ultimate and not nil' do
            create(:license, plan: License::STARTER_PLAN)

            expect(project_guest_user.using_license_seat?).to eq true
          end
        end

        context 'user is admin without projects' do
          let(:user) { create(:user, admin: true) }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(user.using_license_seat?).to eq false
          end

          it 'returns true if license is not ultimate and not nil' do
            create(:license, plan: License::STARTER_PLAN)

            expect(user.using_license_seat?).to eq true
          end
        end
      end
    end
  end

  describe '#using_gitlab_com_seat?' do
    let(:user) { create(:user) }
    let(:namespace) { create(:group) }

    subject { user.using_gitlab_com_seat?(namespace) }

    context 'when Gitlab.com? is false' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when user is not active' do
      let(:user) { create(:user, :blocked) }

      it { is_expected.to be_falsey }
    end

    context 'when Gitlab.com? is true' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      context 'when namespace is nil' do
        let(:namespace) { nil }

        it { is_expected.to be_falsey }
      end

      context 'when namespace is on a free plan' do
        it { is_expected.to be_falsey }
      end

      context 'when namespace is on a gold plan' do
        before do
          create(:gitlab_subscription, namespace: namespace.root_ancestor, hosted_plan: create(:gold_plan))
        end

        context 'user is a guest' do
          before do
            namespace.add_guest(user)
          end

          it { is_expected.to be_falsey }
        end

        context 'user is not a guest' do
          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end

        context 'when user is within project' do
          let(:group) { create(:group) }
          let(:namespace) { create(:project, namespace: group) }

          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end

        context 'when user is within subgroup' do
          let(:group) { create(:group) }
          let(:namespace) { create(:group, parent: group) }

          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end
      end

      context 'when namespace is on a plan that is not free or gold' do
        before do
          create(:gitlab_subscription, namespace: namespace, hosted_plan: create(:silver_plan))
        end

        context 'user is a guest' do
          before do
            namespace.add_guest(user)
          end

          it { is_expected.to be_truthy }
        end

        context 'user is not a guest' do
          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '.username_suggestion' do
    context 'namespace with input name does not exist' do
      let(:name) { 'Arthur Morgan' }

      it 'returns the parameterized name' do
        username = described_class.username_suggestion(name)

        expect(username).to eq('arthur_morgan')
      end
    end

    context 'namespace with input name exists' do
      let(:name) { 'Disney' }

      before do
        create(:user, name: 'disney')
      end

      it 'returns the parameterized name with a suffix' do
        username = described_class.username_suggestion(name)

        expect(username).to eq('disney1')
      end
    end

    context 'namespace with input name and suffix exists' do
      let(:name) { 'Disney' }

      before do
        create(:user, name: 'disney')
        create(:user, name: 'disney1')
      end

      it 'loops through parameterized name with suffixes, until it finds one that does not exist' do
        username = described_class.username_suggestion(name)

        expect(username).to eq('disney2')
      end
    end

    context 'when max attempts for suggestion is exceeded' do
      let(:name) { 'Disney' }
      let(:max_attempts) { described_class::MAX_USERNAME_SUGGESTION_ATTEMPTS }

      before do
        allow(::Namespace).to receive(:find_by_path_or_name).with("disney").and_return(true)
        max_attempts.times { |count| allow(::Namespace).to receive(:find_by_path_or_name).with("disney#{count}").and_return(true) }
      end

      it 'returns an empty response' do
        username = described_class.username_suggestion(name)

        expect(username).to eq('')
      end
    end
  end

  describe '#ab_feature_enabled?' do
    let(:experiment_user) { create(:user) }
    let(:new_user) { create(:user) }
    let(:new_fresh_user) { create(:user) }
    let(:control_user) { create(:user) }
    let(:users_of_different_groups) { [experiment_user, new_user, new_fresh_user, control_user] }

    before do
      create(:user_preference, user: experiment_user, feature_filter_type: UserPreference::FEATURE_FILTER_EXPERIMENT)
      create(:user_preference, user: new_user, feature_filter_type: UserPreference::FEATURE_FILTER_UNKNOWN)
      create(:user_preference, user: new_fresh_user, feature_filter_type: nil)
      create(:user_preference, user: control_user, feature_filter_type: UserPreference::FEATURE_FILTER_CONTROL)
    end

    context 'when not on Gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it 'returns false' do
        users_of_different_groups.each do |user|
          expect(user.ab_feature_enabled?(:discover_security, percentage: 100)).to eq(false)
        end
      end
    end

    context 'when on Gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      context 'when on a secondary Geo' do
        before do
          allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
        end

        it 'returns false' do
          users_of_different_groups.each do |user|
            expect(user.ab_feature_enabled?(:discover_security, percentage: 100)).to eq(false)
          end
        end
      end

      context 'when not on a secondary Geo' do
        before do
          allow(Gitlab::Geo).to receive(:secondary?).and_return(false)
        end

        context 'for any feature except discover_security' do
          it 'raises runtime error' do
            users_of_different_groups.each do |user|
              expect do
                user.ab_feature_enabled?(:any_other_feature, percentage: 100)
              end.to raise_error(RuntimeError, 'Currently only discover_security feature is supported')
            end
          end
        end

        context 'when discover_security feature flag is disabled' do
          before do
            stub_feature_flags(discover_security: false)
          end

          it 'returns false' do
            users_of_different_groups.each do |user|
              expect(user.ab_feature_enabled?(:discover_security, percentage: 100)).to eq(false)
            end
          end
        end

        context 'when discover_security feature flag is enabled' do
          it 'returns false when in control group' do
            expect(control_user.ab_feature_enabled?(:discover_security, percentage: 100)).to eq(false)
          end

          it 'returns true for experiment group' do
            expect(experiment_user.ab_feature_enabled?(:discover_security, percentage: 100)).to eq(true)
          end

          it 'assigns to control or experiment group when feature_filter_type is nil' do
            new_fresh_user.ab_feature_enabled?(:discover_security, percentage: 100)

            expect(new_fresh_user.user_preference.feature_filter_type).not_to eq(UserPreference::FEATURE_FILTER_UNKNOWN)
          end

          it 'assigns to control or experiment group when feature_filter_type is zero' do
            new_user.ab_feature_enabled?(:discover_security, percentage: 100)

            expect(new_user.user_preference.feature_filter_type).not_to eq(UserPreference::FEATURE_FILTER_UNKNOWN)
          end

          it 'returns false for zero percentage' do
            expect(experiment_user.ab_feature_enabled?(:discover_security, percentage: 0)).to eq(false)
          end

          it 'returns false when no percentage is provided' do
            expect(experiment_user.ab_feature_enabled?(:discover_security)).to eq(false)
          end

          it 'returns true when 100% control percentage is provided' do
            Feature.get(:discover_security_control).enable_percentage_of_time(100)

            expect(experiment_user.ab_feature_enabled?(:discover_security)).to eq(true)
            expect(experiment_user.user_preference.feature_filter_type).to eq(UserPreference::FEATURE_FILTER_EXPERIMENT)
          end
        end
      end
    end
  end

  describe '#managed_free_namespaces' do
    let_it_be(:user) { create(:user) }
    let_it_be(:licensed_group) { create(:group, plan: :bronze_plan) }
    let_it_be(:free_group_z) { create(:group, plan: :default_plan, name: 'Z') }
    let_it_be(:free_group_a) { create(:group, plan: :default_plan, name: 'A') }

    subject { user.managed_free_namespaces }

    context 'user with no groups' do
      it { is_expected.to eq [] }
    end

    context 'owner of a licensed group' do
      before do
        licensed_group.add_owner(user)
      end

      it { is_expected.not_to include licensed_group }
    end

    context 'guest of a free group' do
      before do
        free_group_a.add_guest(user)
      end

      it { is_expected.not_to include free_group_a }
    end

    context 'developer of a free group' do
      before do
        free_group_a.add_developer(user)
      end

      it { is_expected.not_to include free_group_a }
    end

    context 'maintainer of a free group' do
      before do
        free_group_a.add_maintainer(user)
      end

      it { is_expected.to include free_group_a }
    end

    context 'owner of 2 free groups' do
      before do
        free_group_a.add_owner(user)
        free_group_z.add_owner(user)
      end

      it { is_expected.to eq [free_group_a, free_group_z] }
    end
  end
end
