import $ from 'jquery';
import projectNew from '~/projects/project_new';

const bindEvents = () => {
  const $newProjectForm = $('#new_project');
  const $useCustomTemplateBtn = $('.custom-template-button > input');
  const $projectFieldsForm = $('.project-fields-form');
  const $selectedIcon = $('.selected-icon');
  const $selectedTemplateText = $('.selected-template');
  const $templateProjectNameInput = $('#template-project-name #project_path');
  const $changeTemplateBtn = $('.change-template');
  const $projectTemplateButtons = $('.project-templates-buttons');
  const $projectFieldsFormInput = $('.project-fields-form input#project_use_custom_template');
  const $subgroupWithTemplatesIdInput = $('.js-project-group-with-project-templates-id');
  const $namespaceSelect = $projectFieldsForm.find('.js-select-namespace');
  let hasUserDefinedProjectName = false;

  if ($newProjectForm.length !== 1 || $useCustomTemplateBtn.length === 0) {
    return;
  }

  function enableCustomTemplate() {
    $projectFieldsFormInput.val(true);
  }

  function disableCustomTemplate() {
    $projectFieldsFormInput.val(false);
  }

  function hideNonRootParentPathOptions() {
    const rootParent = `/${
      $namespaceSelect
        .find('option:selected')
        .data('show-path')
        .split('/')[1]
    }`;

    $namespaceSelect
      .find('option')
      .filter(function doesNotMatchParent() {
        return !$(this)
          .data('show-path')
          .includes(rootParent);
      })
      .addClass('hidden');
  }

  function hideOptionlessOptgroups() {
    $namespaceSelect
      .find('optgroup')
      .filter(function noVisibleOptions() {
        return !$(this).find('option:not(.hidden)').length;
      })
      .addClass('hidden');
  }

  function chooseTemplate() {
    const subgroupId = $(this).data('subgroup-id');
    const templateName = $(this).data('template-name');

    if (subgroupId) {
      $subgroupWithTemplatesIdInput.val(subgroupId);
      $namespaceSelect.val(subgroupId).trigger('change');

      hideNonRootParentPathOptions();

      hideOptionlessOptgroups();
    }

    $projectTemplateButtons.addClass('hidden');
    $projectFieldsForm.addClass('selected');
    $selectedIcon.empty();

    $selectedTemplateText.text(templateName);

    $(this)
      .parents('.template-option')
      .find('.avatar')
      .clone()
      .addClass('d-block')
      .removeClass('s40')
      .appendTo($selectedIcon);

    $templateProjectNameInput.focus();
    enableCustomTemplate();

    const $activeTabProjectName = $('.tab-pane.active #project_name');
    const $activeTabProjectPath = $('.tab-pane.active #project_path');
    $activeTabProjectName.focus();
    $activeTabProjectName.on('keyup', () => {
      projectNew.onProjectNameChange($activeTabProjectName, $activeTabProjectPath);
      hasUserDefinedProjectName = $activeTabProjectName.val().trim().length > 0;
    });
    $activeTabProjectPath.on('keyup', () =>
      projectNew.onProjectPathChange(
        $activeTabProjectName,
        $activeTabProjectPath,
        hasUserDefinedProjectName,
      ),
    );

    $projectFieldsForm
      .find('.js-select-namespace')
      .first()
      .val(subgroupId);
  }

  $useCustomTemplateBtn.on('change', chooseTemplate);

  $changeTemplateBtn.on('click', () => {
    $projectTemplateButtons.removeClass('hidden');
    $useCustomTemplateBtn.prop('checked', false);
    $namespaceSelect
      .val($namespaceSelect.find('option[data-options-parent="users"]').val())
      .trigger('change');
    $namespaceSelect.find('option, optgroup').removeClass('hidden');
    disableCustomTemplate();
  });

  $(document).on('click', '.js-template-group-options', function toggleExpandedClass() {
    $(this).toggleClass('expanded');
  });
};

export default () => {
  const $navElement = $('.js-custom-instance-project-templates-nav-link');
  const $tabContent = $('.js-custom-instance-project-templates-tab-content');
  const $groupNavElement = $('.js-custom-group-project-templates-nav-link');
  const $groupTabContent = $('.js-custom-group-project-templates-tab-content');

  $tabContent.on('ajax:success', bindEvents);
  $groupTabContent.on('ajax:success', bindEvents);

  $navElement.one('click', () => {
    // eslint-disable-next-line no-jquery/no-ajax
    $.get($tabContent.data('initialTemplates'));
  });

  $groupNavElement.one('click', () => {
    // eslint-disable-next-line no-jquery/no-ajax
    $.get($groupTabContent.data('initialTemplates'));
  });

  bindEvents();
};
