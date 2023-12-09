# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::ApplicationContext do
  describe '#to_lazy_hash' do
    let(:user) { build(:user) }
    let(:project) { build(:project) }
    let(:namespace) { create(:group) }
    let(:subgroup) { create(:group, parent: namespace) }

    def result(context)
      context.to_lazy_hash.transform_values { |v| v.respond_to?(:call) ? v.call : v }
    end

    it 'correctly loads the expected values' do
      context = described_class.new(namespace: -> { subgroup })

      expect(result(context))
        .to include(root_namespace: namespace.full_path,
                    subscription_plan: 'free')
    end

    it 'falls back to a projects namespace plan when a project is passed but no namespace' do
      create(:gitlab_subscription, :silver, namespace: project.namespace)
      context = described_class.new(project: project)

      expect(result(context))
        .to include(project: project.full_path,
                    root_namespace: project.full_path_components.first,
                    subscription_plan: 'silver')
    end
  end

  context 'only include values for which an option was specified' do
    using RSpec::Parameterized::TableSyntax

    where(:provided_options, :expected_context_keys) do
      [:user, :namespace, :project] | [:user, :project, :root_namespace, :subscription_plan]
      [:user, :project]             | [:user, :project, :root_namespace, :subscription_plan]
      [:user, :namespace]           | [:user, :root_namespace, :subscription_plan]
      [:user]                       | [:user]
      [:caller_id]                  | [:caller_id]
      []                            | []
    end

    with_them do
      it do
        # Build a hash that has all `provided_options` as keys, and `nil` as value
        provided_values = provided_options.map { |key| [key, nil] }.to_h
        context = described_class.new(provided_values)

        expect(context.to_lazy_hash.keys).to contain_exactly(*expected_context_keys)
      end
    end
  end
end
