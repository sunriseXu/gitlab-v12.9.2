import { SEVERITY_LEVELS, REPORT_TYPES, BASE_FILTERS } from './constants';
import { s__ } from '~/locale';

const optionsObjectToArray = obj => Object.entries(obj).map(([id, name]) => ({ id, name }));

export default () => ({
  filters: [
    {
      name: s__('SecurityDashboard|Severity'),
      id: 'severity',
      options: [BASE_FILTERS.severity, ...optionsObjectToArray(SEVERITY_LEVELS)],
      hidden: false,
      selection: new Set([BASE_FILTERS.severity.id]),
    },
    {
      name: s__('SecurityDashboard|Report type'),
      id: 'report_type',
      options: [BASE_FILTERS.report_type, ...optionsObjectToArray(REPORT_TYPES)],
      hidden: false,
      selection: new Set([BASE_FILTERS.report_type.id]),
    },
    {
      name: s__('SecurityDashboard|Project'),
      id: 'project_id',
      options: [BASE_FILTERS.project_id],
      hidden: false,
      selection: new Set([BASE_FILTERS.project_id.id]),
    },
  ],
  hideDismissed: true,
});
