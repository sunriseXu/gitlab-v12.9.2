# frozen_string_literal: true

module DesignManagement
  class Design < ApplicationRecord
    include Importable
    include Noteable
    include Gitlab::FileTypeDetection
    include Gitlab::Utils::StrongMemoize
    include Referable
    include Mentionable

    belongs_to :project, inverse_of: :designs
    belongs_to :issue

    has_many :actions
    has_many :versions, through: :actions, class_name: 'DesignManagement::Version', inverse_of: :designs
    # This is a polymorphic association, so we can't count on FK's to delete the
    # data
    has_many :notes, as: :noteable, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
    has_many :user_mentions, class_name: "DesignUserMention", dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent

    validates :project, :filename, presence: true
    validates :issue, presence: true, unless: :importing?
    validates :filename, uniqueness: { scope: :issue_id }
    validate :validate_file_is_image

    alias_attribute :title, :filename

    # Pre-fetching scope to include the data necessary to construct a
    # reference using `to_reference`.
    scope :for_reference, -> { includes(issue: [{ project: [:route, :namespace] }]) }

    # Find designs visible at the given version
    #
    # @param version [nil, DesignManagement::Version]:
    #   the version at which the designs must be visible
    #   Passing `nil` is the same as passing the most current version
    #
    # Restricts to designs
    # - created at least *before* the given version
    # - not deleted as of the given version.
    #
    # As a query, we ascertain this by finding the last event prior to
    # (or equal to) the cut-off, and seeing whether that version was a deletion.
    scope :visible_at_version, -> (version) do
      deletion = ::DesignManagement::Action.events[:deletion]
      designs = arel_table
      actions = ::DesignManagement::Action
        .most_recent.up_to_version(version)
        .arel.as('most_recent_actions')

      join = designs.join(actions)
        .on(actions[:design_id].eq(designs[:id]))

      joins(join.join_sources).where(actions[:event].not_eq(deletion)).order(:id)
    end

    scope :with_filename, -> (filenames) { where(filename: filenames) }
    scope :on_issue, ->(issue) { where(issue_id: issue) }

    # Scope called by our REST API to avoid N+1 problems
    scope :with_api_entity_associations, -> { preload(:issue) }

    # A design is current if the most recent event is not a deletion
    scope :current, -> { visible_at_version(nil) }

    def status
      if new_design?
        :new
      elsif deleted?
        :deleted
      else
        :current
      end
    end

    def deleted?
      most_recent_action&.deletion?
    end

    # A design is visible_in? a version if:
    #   * it was created before that version
    #   * the most recent action before the version was not a deletion
    def visible_in?(version)
      map = strong_memoize(:visible_in) do
        Hash.new do |h, k|
          h[k] = self.class.visible_at_version(k).where(id: id).exists?
        end
      end

      map[version]
    end

    def most_recent_action
      strong_memoize(:most_recent_action) { actions.ordered.last }
    end

    # A reference for a design is the issue reference, indexed by the filename
    # with an optional infix when full.
    #
    # e.g.
    #   #123[homescreen.png]
    #   other-project#72[sidebar.jpg]
    #   #38/designs[transition.gif]
    #   #12["filename with [] in it.jpg"]
    def to_reference(from = nil, full: false)
      infix = full ? '/designs' : ''
      totally_simple = %r{ \A #{self.class.simple_file_name} \z }x
      safe_name = if totally_simple.match?(filename)
                    filename
                  elsif filename =~ /[<>]/
                    %Q{base64:#{Base64.strict_encode64(filename)}}
                  else
                    escaped = filename.gsub(%r{[\\"]}) { |x| "\\#{x}" }
                    %Q{"#{escaped}"}
                  end

      "#{issue.to_reference(from, full: full)}#{infix}[#{safe_name}]"
    end

    def self.reference_pattern
      @reference_pattern ||= begin
        # Filenames can be escaped with double quotes to name filenames
        # that include square brackets, or other special characters
        %r{
          #{Issue.reference_pattern}
          (\/designs)?
          \[
            (?<design> #{simple_file_name} | #{quoted_file_name} | #{base_64_encoded_name})
          \]
        }x
      end
    end

    def self.simple_file_name
      %r{
          (?<simple_file_name>
           ( \w | [_:,'-] | \. | \s )+
           \.
           \w+
          )
      }x
    end

    def self.base_64_encoded_name
      %r{
          base64:
          (?<base_64_encoded_name>
           [A-Za-z0-9+\n]+
           =?
          )
      }x
    end

    def self.quoted_file_name
      %r{
          "
          (?<escaped_filename>
            (\\ \\ | \\ " | [^"\\])+
          )
          "
      }x
    end

    def self.link_reference_pattern
      @link_reference_pattern ||= begin
        exts = SAFE_IMAGE_EXT + DANGEROUS_IMAGE_EXT
        path_segment = %r{issues/#{Gitlab::Regex.issue}/designs}
        filename_pattern = %r{(?<simple_file_name>[a-z0-9_=-]+\.(#{exts.join('|')}))}i

        super(path_segment, filename_pattern)
      end
    end

    def to_ability_name
      'design'
    end

    def description
      ''
    end

    def new_design?
      strong_memoize(:new_design) { actions.none? }
    end

    def full_path
      @full_path ||= File.join(DesignManagement.designs_directory, "issue-#{issue.iid}", filename)
    end

    def diff_refs
      strong_memoize(:diff_refs) { head_version&.diff_refs }
    end

    def clear_version_cache
      [versions, actions].each(&:reset)
      %i[new_design diff_refs head_sha visible_in most_recent_action].each do |key|
        clear_memoization(key)
      end
    end

    def repository
      project.design_repository
    end

    def user_notes_count
      user_notes_count_service.count
    end

    def after_note_changed(note)
      user_notes_count_service.delete_cache unless note.system?
    end
    alias_method :after_note_created,   :after_note_changed
    alias_method :after_note_destroyed, :after_note_changed

    private

    def head_version
      strong_memoize(:head_sha) { versions.ordered.first }
    end

    def allow_dangerous_images?
      Feature.enabled?(:design_management_allow_dangerous_images, project)
    end

    def valid_file_extensions
      allow_dangerous_images? ? (SAFE_IMAGE_EXT + DANGEROUS_IMAGE_EXT) : SAFE_IMAGE_EXT
    end

    def validate_file_is_image
      unless image? || (dangerous_image? && allow_dangerous_images?)
        message = _('does not have a supported extension. Only %{extension_list} are supported') % {
          extension_list: valid_file_extensions.to_sentence
        }
        errors.add(:filename, message)
      end
    end

    def user_notes_count_service
      strong_memoize(:user_notes_count_service) do
        ::DesignManagement::DesignUserNotesCountService.new(self) # rubocop: disable CodeReuse/ServiceClass
      end
    end
  end
end
