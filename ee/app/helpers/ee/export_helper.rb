# frozen_string_literal: true

module EE
  module ExportHelper
    extend ::Gitlab::Utils::Override

    override :project_export_descriptions
    def project_export_descriptions
      super + [_('Design Management files and data')]
    end
  end
end
