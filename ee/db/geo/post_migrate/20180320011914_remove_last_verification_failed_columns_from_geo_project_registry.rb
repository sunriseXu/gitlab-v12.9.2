class RemoveLastVerificationFailedColumnsFromGeoProjectRegistry < ActiveRecord::Migration[4.2]
  DOWNTIME = false

  def up
    remove_column :project_registry, :last_repository_verification_failed
    remove_column :project_registry, :last_wiki_verification_failed
  end

  def down
    add_column :project_registry, :last_repository_verification_failed, :boolean, default: false, null: false # rubocop:disable Migration/AddColumn
    add_column :project_registry, :last_wiki_verification_failed, :boolean, default: false, null: false # rubocop:disable Migration/AddColumn
  end
end
