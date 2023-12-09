import 'select2/select2';
import $ from 'jquery';
import { s__ } from '~/locale';
import Api from '~/api';

const onLimitCheckboxChange = (checked, $limitByNamespaces, $limitByProjects) => {
  $limitByNamespaces.find('.select2').select2('data', null);
  $limitByNamespaces.find('.select2').select2('data', null);
  $limitByNamespaces.toggleClass('hidden', !checked);
  $limitByProjects.toggleClass('hidden', !checked);
};

const getDropdownConfig = (placeholder, apiPath, textProp) => ({
  placeholder,
  multiple: true,
  initSelection($el, callback) {
    callback($el.data('selected'));
  },
  ajax: {
    url: Api.buildUrl(apiPath),
    dataType: 'JSON',
    quietMillis: 250,
    data(search) {
      return {
        search,
      };
    },
    results(data) {
      return {
        results: data.map(entity => ({
          id: entity.id,
          text: entity[textProp],
        })),
      };
    },
  },
});

document.addEventListener('DOMContentLoaded', () => {
  const $container = $('#js-elasticsearch-settings');

  $container
    .find('.js-limit-checkbox')
    .on('change', e =>
      onLimitCheckboxChange(
        e.currentTarget.checked,
        $container.find('.js-limit-namespaces'),
        $container.find('.js-limit-projects'),
      ),
    );

  $container
    .find('.js-elasticsearch-namespaces')
    .select2(
      getDropdownConfig(
        s__('Elastic|None. Select namespaces to index.'),
        Api.namespacesPath,
        'full_path',
      ),
    );

  $container
    .find('.js-elasticsearch-projects')
    .select2(
      getDropdownConfig(
        s__('Elastic|None. Select projects to index.'),
        Api.projectsPath,
        'name_with_namespace',
      ),
    );
});
