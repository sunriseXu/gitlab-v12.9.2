# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['Requirement'] do
  fields = %i[id iid title state project author created_at updated_at user_permissions]

  it { expect(described_class).to expose_permissions_using(Types::PermissionTypes::Requirement) }

  it { expect(described_class.graphql_name).to eq('Requirement') }

  it { expect(described_class).to require_graphql_authorizations(:read_requirement) }

  it { expect(described_class).to have_graphql_fields(fields) }
end
