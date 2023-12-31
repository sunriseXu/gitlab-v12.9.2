<script>
import { mapActions } from 'vuex';
import { GlDropdown, GlDropdownItem, GlLoadingIcon } from '@gitlab/ui';
import { getIssueStatusFromLicenseStatus } from 'ee/vue_shared/license_management/store/utils';
import { s__ } from '~/locale';
import Icon from '~/vue_shared/components/icon.vue';
import IssueStatusIcon from '~/reports/components/issue_status_icon.vue';

import { LICENSE_APPROVAL_STATUS, LICENSE_APPROVAL_ACTION } from '../constants';
import { LICENSE_MANAGEMENT } from 'ee/vue_shared/license_management/store/constants';

const visibleClass = 'visible';
const invisibleClass = 'invisible';

export default {
  name: 'AdminLicenseManagementRow',
  components: {
    GlDropdown,
    GlDropdownItem,
    GlLoadingIcon,
    Icon,
    IssueStatusIcon,
  },
  props: {
    license: {
      type: Object,
      required: true,
      validator: license =>
        Boolean(license.name) &&
        Object.values(LICENSE_APPROVAL_STATUS).includes(license.approvalStatus),
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  LICENSE_APPROVAL_STATUS,
  LICENSE_APPROVAL_ACTION,
  [LICENSE_APPROVAL_ACTION.ALLOW]: s__('LicenseCompliance|Allow'),
  [LICENSE_APPROVAL_ACTION.DENY]: s__('LicenseCompliance|Deny'),
  [LICENSE_APPROVAL_STATUS.ALLOWED]: s__('LicenseCompliance|Allowed'),
  [LICENSE_APPROVAL_STATUS.DENIED]: s__('LicenseCompliance|Denied'),
  computed: {
    approveIconClass() {
      return this.license.approvalStatus === LICENSE_APPROVAL_STATUS.ALLOWED
        ? visibleClass
        : invisibleClass;
    },
    blacklistIconClass() {
      return this.license.approvalStatus === LICENSE_APPROVAL_STATUS.DENIED
        ? visibleClass
        : invisibleClass;
    },
    status() {
      return getIssueStatusFromLicenseStatus(this.license.approvalStatus);
    },
    dropdownText() {
      return this.$options[this.license.approvalStatus];
    },
  },
  methods: {
    ...mapActions(LICENSE_MANAGEMENT, ['setLicenseInModal', 'allowLicense', 'denyLicense']),
  },
};
</script>
<template>
  <div data-qa-selector="admin_license_compliance_row">
    <issue-status-icon :status="status" class="float-left append-right-default" />
    <span class="js-license-name" data-qa-selector="license_name_content">{{ license.name }}</span>
    <div class="float-right">
      <div class="d-flex">
        <gl-loading-icon v-if="loading" class="js-loading-icon d-flex align-items-center mr-2" />
        <gl-dropdown
          :text="dropdownText"
          :disabled="loading"
          toggle-class="d-flex justify-content-between align-items-center"
          right
        >
          <gl-dropdown-item @click="allowLicense(license)">
            <icon :class="approveIconClass" name="mobile-issue-close" />
            {{ $options[$options.LICENSE_APPROVAL_ACTION.ALLOW] }}
          </gl-dropdown-item>
          <gl-dropdown-item @click="denyLicense(license)">
            <icon :class="blacklistIconClass" name="mobile-issue-close" />
            {{ $options[$options.LICENSE_APPROVAL_ACTION.DENY] }}
          </gl-dropdown-item>
        </gl-dropdown>
        <button
          :disabled="loading"
          class="btn btn-blank js-remove-button"
          type="button"
          data-toggle="modal"
          data-target="#modal-license-delete-confirmation"
          @click="setLicenseInModal(license)"
        >
          <icon name="remove" />
        </button>
      </div>
    </div>
  </div>
</template>
