# frozen_string_literal: true

require "spec_helper"

describe "Admin views license" do
  let_it_be(:admin) { create(:admin) }

  before do
    stub_feature_flags(licenses_app: false)
    sign_in(admin)
  end

  context "when license is valid" do
    before do
      visit(admin_license_path)
    end

    it "shows license" do
      expect(page).to have_content("Your license is valid")

      page.within(".license-panel") do
        expect(page).to have_content("Unlimited")
      end
    end
  end

  context "when license is trial" do
    let_it_be(:license) { create(:license, trial: true) }

    before do
      visit(admin_license_path)
    end

    it "shows expiration duration with license type" do
      page.within(".js-license-info-panel") do
        expect(page).to have_content("Expires: Free trial will expire in")
      end
    end

    context "when license is expired" do
      let_it_be(:license) { create(:license, trial: true, expired: true) }

      it "does not mention blocking of changes" do
        page.within(".gitlab-ee-license-banner") do
          expect(page).to have_content("Your trial license expired on")
                     .and have_no_content("Pushing code and creation of issues and merge requests has been disabled")
        end
      end
    end
  end

  context "when license is regular" do
    let_it_be(:license) { create(:license) }

    before do
      visit(admin_license_path)
    end

    it "shows only expiration duration" do
      expect(page).to have_content(license.licensee.each_value.first)

      page.within(".js-license-info-panel") do
        expect(page).not_to have_content("Expires: Free trial will expire in")
      end
    end

    context "when license expired" do
      let_it_be(:license) { build(:license, data: build(:gitlab_license, expires_at: Date.yesterday).export).save(validate: false) }

      it { expect(page).to have_content("Your license expired") }

      context "when license blocks changes" do
        let_it_be(:license) { build(:license, data: build(:gitlab_license, expires_at: Date.yesterday, block_changes_at: Date.today).export).save(validate: false) }

        it { expect(page).to have_content "Pushing code and creation of issues and merge requests has been disabled." }
      end
    end

    context "when viewing license history" do
      let_it_be(:license) { create(:license) }

      it "shows licensee" do
        license_history = page.find("#license_history")

        License.previous.each do |license|
          expect(license_history).to have_content(license.licensee.each_value.first)
        end
      end
    end
  end

  context "with limited users" do
    let_it_be(:license) { create(:license, data: build(:gitlab_license, restrictions: { active_user_count: 2000 }).export) }

    before do
      visit(admin_license_path)
    end

    it "shows panel counts" do
      page.within(".license-panel") do
        expect(page).to have_content("2,000")
      end
    end
  end
end
