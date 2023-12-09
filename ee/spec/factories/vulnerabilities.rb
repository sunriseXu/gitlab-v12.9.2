# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability do
    project
    author
    title { generate(:title) }
    title_html { "<h2>#{title}</h2>" }
    severity { :high }
    confidence { :medium }
    report_type { :sast }

    trait :detected do
      state { Vulnerability.states[:detected] }
    end

    trait :resolved do
      state { Vulnerability.states[:resolved] }
      resolved_at { Time.current }
    end

    trait :dismissed do
      state { Vulnerability.states[:dismissed] }
      dismissed_at { Time.current }
    end

    trait :confirmed do
      state { Vulnerability.states[:confirmed] }
      confirmed_at { Time.current }
    end

    ::Vulnerabilities::Occurrence::SEVERITY_LEVELS.keys.each do |severity_level|
      trait severity_level do
        severity { severity_level }
      end
    end

    ::Vulnerabilities::Occurrence::REPORT_TYPES.keys.each do |report_type|
      trait report_type do
        report_type { report_type }
      end
    end

    trait :with_findings do
      after(:build) do |vulnerability|
        vulnerability.findings = build_list(
          :vulnerabilities_occurrence,
          2,
          vulnerability: vulnerability,
          report_type: vulnerability.report_type,
          project: vulnerability.project)
      end
    end

    trait :with_issue_links do
      after(:create) do |vulnerability|
        create_list(:issue, 2).each do |issue|
          create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue)
        end
      end
    end
  end
end
