# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::PathLocksFinder do
  let(:project) { create :project }
  let(:user) { create :user }
  let(:finder) { described_class.new(project) }

  it "returns correct lock information" do
    lock1 = create :path_lock, project: project, path: 'app'
    lock2 = create :path_lock, project: project, path: 'lib/gitlab/repo.rb'

    expect(finder.find('app')).to eq(lock1)
    expect(finder.find('app/models/project.rb')).to eq(lock1)
    expect(finder.find('lib')).to be_falsey
    expect(finder.find('lib/gitlab/repo.rb')).to eq(lock2)
  end
end
