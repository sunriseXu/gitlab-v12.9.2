import { groupByDateRanges } from './utils';
import { UNSCANNED_PROJECTS_DATE_RANGES } from '../../constants';

export const untestedProjects = ({ projects }) =>
  projects.filter(({ securityTestsUnconfigured }) => securityTestsUnconfigured === true);

export const untestedProjectsCount = (state, getters) => getters.untestedProjects.length;

export const outdatedProjects = ({ projects }) =>
  groupByDateRanges({
    ranges: UNSCANNED_PROJECTS_DATE_RANGES,
    dateFn: x => x.securityTestsLastSuccessfulRun,
    projects,
  });

export const outdatedProjectsCount = (state, getters) =>
  getters.outdatedProjects.reduce((count, currentGroup) => count + currentGroup.projects.length, 0);

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
