# frozen_string_literal: true

FactoryBot.define do
  factory :status_page_setting, class: 'StatusPageSetting' do
    project
    aws_s3_bucket_name { 'bucket-name' }
    aws_region { 'ap-southeast-2' }
    aws_access_key { FFaker::String.from_regexp(StatusPageSetting::AWS_ACCESS_KEY_REGEXP) }
    aws_secret_key { FFaker::String.from_regexp(StatusPageSetting::AWS_SECRET_KEY_REGEXP) }
    enabled { false }

    trait :enabled do
      enabled { true }
    end
  end
end
