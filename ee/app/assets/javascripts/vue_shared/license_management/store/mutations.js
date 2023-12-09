import * as types from './mutation_types';
import { normalizeLicense } from './utils';

export default {
  [types.SET_LICENSE_IN_MODAL](state, license) {
    Object.assign(state, {
      currentLicenseInModal: license,
    });
  },
  [types.RESET_LICENSE_IN_MODAL](state) {
    Object.assign(state, {
      currentLicenseInModal: null,
    });
  },
  [types.SET_API_SETTINGS](state, data) {
    Object.assign(state, data);
  },
  [types.SET_IS_ADMIN](state, data) {
    Object.assign(state, {
      isAdmin: data,
    });
  },
  [types.RECEIVE_MANAGED_LICENSES_SUCCESS](state, licenses = []) {
    const managedLicenses = licenses.map(normalizeLicense).reverse();

    Object.assign(state, {
      managedLicenses,
      isLoadingManagedLicenses: false,
      loadManagedLicensesError: false,
    });
  },
  [types.RECEIVE_MANAGED_LICENSES_ERROR](state, error) {
    Object.assign(state, {
      managedLicenses: [],
      isLoadingManagedLicenses: false,
      loadManagedLicensesError: error,
    });
  },
  [types.REQUEST_MANAGED_LICENSES](state) {
    Object.assign(state, {
      isLoadingManagedLicenses: true,
    });
  },

  [types.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS](state, { newLicenses, existingLicenses }) {
    Object.assign(state, {
      newLicenses,
      existingLicenses,
      isLoadingLicenseReport: false,
      loadLicenseReportError: false,
    });
  },
  [types.RECEIVE_PARSED_LICENSE_REPORT_ERROR](state, error) {
    Object.assign(state, {
      isLoadingLicenseReport: false,
      loadLicenseReportError: error,
    });
  },
  [types.REQUEST_PARSED_LICENSE_REPORT](state) {
    Object.assign(state, {
      isLoadingLicenseReport: true,
    });
  },

  [types.RECEIVE_DELETE_LICENSE](state) {
    Object.assign(state, {
      isDeleting: false,
      currentLicenseInModal: null,
    });
  },
  [types.RECEIVE_DELETE_LICENSE_ERROR](state) {
    Object.assign(state, {
      isDeleting: false,
      currentLicenseInModal: null,
    });
  },
  [types.REQUEST_DELETE_LICENSE](state) {
    Object.assign(state, {
      isDeleting: true,
    });
  },
  [types.REQUEST_SET_LICENSE_APPROVAL](state) {
    Object.assign(state, {
      isSaving: true,
    });
  },
  [types.RECEIVE_SET_LICENSE_APPROVAL](state) {
    Object.assign(state, {
      isSaving: false,
      currentLicenseInModal: null,
    });
  },
  [types.RECEIVE_SET_LICENSE_APPROVAL_ERROR](state) {
    Object.assign(state, {
      isSaving: false,
      currentLicenseInModal: null,
    });
  },
  [types.ADD_PENDING_LICENSE](state, id) {
    state.pendingLicenses.push(id);
  },
  [types.REMOVE_PENDING_LICENSE](state, id) {
    state.pendingLicenses = state.pendingLicenses.filter(pendingLicense => pendingLicense !== id);
  },
};
