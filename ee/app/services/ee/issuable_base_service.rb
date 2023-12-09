# frozen_string_literal: true

module EE
  module IssuableBaseService
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    attr_reader :label_ids_ordered_by_selection

    private

    override :filter_params
    def filter_params(issuable)
      can_admin_issuable = can_admin_issuable?(issuable)

      unless can_admin_issuable && issuable.supports_weight?
        params.delete(:weight)
      end

      unless can_admin_issuable && issuable.supports_health_status?
        params.delete(:health_status)
      end

      super
    end

    override :filter_labels
    def filter_labels
      @label_ids_ordered_by_selection = params[:add_label_ids].to_a + params[:label_ids].to_a # rubocop:disable Gitlab/ModuleWithInstanceVariables

      super
    end

    def update_task_event?
      strong_memoize(:update_task_event) do
        params.key?(:update_task)
      end
    end

    override :process_label_ids
    def process_label_ids(attributes, existing_label_ids: nil, extra_label_ids: [])
      ids = super
      added_label_ids = ids - existing_label_ids.to_a

      filter_mutually_exclusive_labels(ids, added_label_ids)
    end

    def filter_mutually_exclusive_labels(ids, added_label_ids)
      return ids if added_label_ids.empty? || !parent.feature_available?(:scoped_labels)

      label_sets = ScopedLabelSet.from_label_ids(ids)

      label_sets.flat_map do |set|
        if set.valid? || !set.contains_any?(added_label_ids)
          set.label_ids
        else
          set.last_id_by_order(label_ids_ordered_by_selection)
        end
      end
    end
  end
end
