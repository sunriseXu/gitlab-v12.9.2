# frozen_string_literal: true

module EE
  module MirrorHelper
    def render_mirror_failed_message(raw_message:)
      mirror_last_update_at = @project.import_state.last_update_at
      message = "The repository failed to update #{time_ago_with_tooltip(mirror_last_update_at)}.".html_safe

      return message if raw_message

      message = icon('warning triangle') + ' ' + message

      if can?(current_user, :admin_project, @project)
        link_to message, project_mirror_path(@project)
      else
        message
      end
    end

    def branch_diverged_tooltip_message
      message = [s_('Branches|The branch could not be updated automatically because it has diverged from its upstream counterpart.')]

      if can?(current_user, :push_code, @project)
        message << '<br>'
        message << s_("Branches|To discard the local changes and overwrite the branch with the upstream version, delete it here and choose 'Update Now' above.")
      end

      message.join
    end

    def options_for_mirror_user
      options_from_collection_for_select(default_mirror_users, :id, :name, @project.mirror_user_id || current_user.id)
    end

    def mirrored_repositories_count(project = @project)
      count = project.mirror == true ? 1 : 0
      count + @project.remote_mirrors.to_a.count { |mirror| mirror.enabled }
    end

    def mirror_lfs_sync_message
      docs_link_url = help_page_path('workflow/lfs/manage_large_binaries_with_git_lfs')
      docs_link_start = '<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe % { url: docs_link_url }

      _('Git LFS objects will be synced in pull mirrors if LFS is %{docs_link_start}enabled for the project%{docs_link_end}. They will <strong>not</strong> be synced in push mirrors.').html_safe % { docs_link_start: docs_link_start, docs_link_end: '</a>'.html_safe }
    end
  end
end
