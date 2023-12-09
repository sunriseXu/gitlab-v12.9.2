# frozen_string_literal: true
class Packages::Package < ApplicationRecord
  include Sortable
  include Gitlab::SQL::Pattern

  belongs_to :project
  # package_files must be destroyed by ruby code in order to properly remove carrierwave uploads and update project statistics
  has_many :package_files, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent
  has_many :dependency_links, inverse_of: :package, class_name: 'Packages::DependencyLink'
  has_many :tags, inverse_of: :package, class_name: 'Packages::Tag'
  has_one :conan_metadatum, inverse_of: :package
  has_one :maven_metadatum, inverse_of: :package
  has_one :build_info, inverse_of: :package

  accepts_nested_attributes_for :conan_metadatum
  accepts_nested_attributes_for :maven_metadatum

  delegate :recipe, :recipe_path, to: :conan_metadatum, prefix: :conan

  validates :project, presence: true

  validates :name,
    presence: true,
    format: { with: Gitlab::Regex.package_name_regex }

  validates :name,
    uniqueness: { scope: %i[project_id version package_type] }, unless: :conan?

  validate :valid_conan_package_recipe, if: :conan?
  validate :valid_npm_package_name, if: :npm?
  validate :package_already_taken, if: :npm?
  validates :version, format: { with: Gitlab::Regex.semver_regex }, if: :npm?

  enum package_type: { maven: 1, npm: 2, conan: 3, nuget: 4 }

  scope :with_name, ->(name) { where(name: name) }
  scope :with_name_like, ->(name) { where(arel_table[:name].matches(name)) }
  scope :search_by_name, ->(query) { fuzzy_search(query, [:name], use_minimum_char_limit: false) }
  scope :with_version, ->(version) { where(version: version) }
  scope :without_version_like, -> (version) { where.not(arel_table[:version].matches(version)) }
  scope :with_package_type, ->(package_type) { where(package_type: package_type) }

  scope :with_conan_channel, ->(package_channel) do
    joins(:conan_metadatum).where(packages_conan_metadata: { package_channel: package_channel })
  end
  scope :with_conan_username, ->(package_username) do
    joins(:conan_metadatum).where(packages_conan_metadata: { package_username: package_username })
  end

  scope :without_nuget_temporary_name, -> { where.not(name: Packages::Nuget::CreatePackageService::TEMPORARY_PACKAGE_NAME) }

  scope :has_version, -> { where.not(version: nil) }
  scope :processed, -> do
    where.not(package_type: :nuget).or(
      where.not(name: Packages::Nuget::CreatePackageService::TEMPORARY_PACKAGE_NAME)
    )
  end
  scope :preload_files, -> { preload(:package_files) }
  scope :last_of_each_version, -> { where(id: all.select('MAX(id) AS id').group(:version)) }
  scope :limit_recent, ->(limit) { order_created_desc.limit(limit) }
  scope :select_distinct_name, -> { select(:name).distinct }

  # Sorting
  scope :order_created, -> { reorder('created_at ASC') }
  scope :order_created_desc, -> { reorder('created_at DESC') }
  scope :order_name, -> { reorder('name ASC') }
  scope :order_name_desc, -> { reorder('name DESC') }
  scope :order_version, -> { reorder('version ASC') }
  scope :order_version_desc, -> { reorder('version DESC') }
  scope :order_type, -> { reorder('package_type ASC') }
  scope :order_type_desc, -> { reorder('package_type DESC') }
  scope :order_project_name, -> { joins(:project).reorder('projects.name ASC') }
  scope :order_project_name_desc, -> { joins(:project).reorder('projects.name DESC') }
  scope :order_project_path, -> { joins(:project).reorder('projects.path ASC, id ASC') }
  scope :order_project_path_desc, -> { joins(:project).reorder('projects.path DESC, id DESC') }

  def self.for_projects(projects)
    return none unless projects.any?

    where(project_id: projects)
  end

  def self.only_maven_packages_with_path(path)
    joins(:maven_metadatum).where(packages_maven_metadata: { path: path })
  end

  def self.by_name_and_file_name(name, file_name)
    with_name(name)
      .joins(:package_files)
      .where(packages_package_files: { file_name: file_name }).last!
  end

  def self.pluck_names
    pluck(:name)
  end

  def self.pluck_versions
    pluck(:version)
  end

  def self.sort_by_attribute(method)
    case method.to_s
    when 'created_asc' then order_created
    when 'created_at_asc' then order_created
    when 'name_asc' then order_name
    when 'name_desc' then order_name_desc
    when 'version_asc' then order_version
    when 'version_desc' then order_version_desc
    when 'type_asc' then order_type
    when 'type_desc' then order_type_desc
    when 'project_name_asc' then order_project_name
    when 'project_name_desc' then order_project_name_desc
    when 'project_path_asc' then order_project_path
    when 'project_path_desc' then order_project_path_desc
    else
      order_created_desc
    end
  end

  private

  def valid_conan_package_recipe
    recipe_exists = project.packages
                           .conan
                           .includes(:conan_metadatum)
                           .with_name(name)
                           .with_version(version)
                           .with_conan_channel(conan_metadatum.package_channel)
                           .with_conan_username(conan_metadatum.package_username)
                           .id_not_in(id)
                           .exists?

    errors.add(:base, _('Package recipe already exists')) if recipe_exists
  end

  def valid_npm_package_name
    return unless project&.root_namespace

    unless name =~ %r{\A@#{project.root_namespace.path}/[^/]+\z}
      errors.add(:name, 'is not valid')
    end
  end

  def package_already_taken
    return unless project

    if project.package_already_taken?(name)
      errors.add(:base, _('Package already exists'))
    end
  end
end
