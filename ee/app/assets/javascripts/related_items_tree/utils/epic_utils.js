import { PathIdSeparator } from 'ee/related_issues/constants';
import createGqClient, { fetchPolicies } from '~/lib/graphql';

import { ChildType } from '../constants';

export const gqClient = createGqClient(
  {},
  {
    fetchPolicy: fetchPolicies.NO_CACHE,
  },
);

/**
 * Returns a numeric representation of item
 * order in an array.
 *
 * This method is to be used as comparison
 * function for Array.sort
 *
 * @param {Object} childA
 * @param {Object} childB
 */
export const sortChildren = (childA, childB) => childA.relativePosition - childB.relativePosition;

/**
 * Returns a numeric representation of item, by state,
 * opened items first, closed items last
 * Used to sort epics and issues
 *
 * This method is to be used as comparison
 * function for Array.sort
 *
 * @param {Array} items
 */
const stateOrder = ['opened', 'closed'];
export const sortByState = (a, b) => stateOrder.indexOf(a.state) - stateOrder.indexOf(b.state);

/**
 * Returns sorted array, using sortChildren and sortByState
 * Used to sort epics and issues
 *
 * @param {Array} items
 */
export const applySorts = array => array.sort(sortChildren).sort(sortByState);

/**
 * Returns formatted child item to include additional
 * flags and properties to use while rendering tree.
 * @param {Object} item
 */
export const formatChildItem = item =>
  Object.assign({}, item, {
    pathIdSeparator: PathIdSeparator[item.type],
  });

/**
 * Returns formatted array of Epics that doesn't contain
 * `edges`->`node` nesting
 *
 * @param {Array} children
 */
export const extractChildEpics = children =>
  children.edges.map(({ node, epicNode = node }) =>
    formatChildItem({
      ...epicNode,
      fullPath: epicNode.group.fullPath,
      type: ChildType.Epic,
    }),
  );

/**
 * Returns formatted array of Assignees that doesn't contain
 * `edges`->`node` nesting
 *
 * @param {Array} assignees
 */
export const extractIssueAssignees = assignees =>
  assignees.edges.map(assigneeNode => ({
    ...assigneeNode.node,
  }));

/**
 * Returns formatted array of Issues that doesn't contain
 * `edges`->`node` nesting
 *
 * @param {Array} issues
 */
export const extractChildIssues = issues =>
  issues.edges.map(({ node, issueNode = node }) =>
    formatChildItem({
      ...issueNode,
      type: ChildType.Issue,
      assignees: extractIssueAssignees(issueNode.assignees),
    }),
  );

/**
 * Parses Graph query response and updates
 * children array to include issues within it
 * and then sorts everything based on `relativePosition`
 * and state
 *
 * @param {Object} responseRoot
 */
export const processQueryResponse = ({ epic }) =>
  applySorts([...extractChildEpics(epic.children), ...extractChildIssues(epic.issues)]);
