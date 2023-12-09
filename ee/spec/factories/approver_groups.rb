# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :approver_group do
    target factory: :merge_request
    group
  end
end
