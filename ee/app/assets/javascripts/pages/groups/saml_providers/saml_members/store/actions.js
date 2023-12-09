import { __ } from '~/locale';
import Api from '~/api';
import createFlash from '~/flash';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import * as types from './mutation_types';

export function fetchPage({ commit, state }, newPage) {
  return Api.groupMembers(state.groupId, {
    with_saml_identity: 'true',
    page: newPage || state.pageInfo.page,
    per_page: state.pageInfo.perPage,
  })
    .then(response => {
      const { headers, data } = response;
      const pageInfo = parseIntPagination(normalizeHeaders(headers));
      commit(types.RECEIVE_SAML_MEMBERS_SUCCESS, {
        members: data.map(({ group_saml_identity: identity, ...item }) => ({
          ...item,
          identity: identity ? identity.extern_uid : null,
        })),
        pageInfo,
      });
    })
    .catch(() => {
      createFlash(__('An error occurred while loading group members.'));
    });
}
// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
