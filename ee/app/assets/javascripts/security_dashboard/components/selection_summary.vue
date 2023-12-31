<script>
import { __, n__ } from '~/locale';
import { mapActions, mapGetters } from 'vuex';
import { GlButton, GlFormSelect } from '@gitlab/ui';

const REASON_NONE = __('[No reason]');
const REASON_WONT_FIX = __("Won't fix / Accept risk");
const REASON_FALSE_POSITIVE = __('False positive');

export default {
  name: 'SelectionSummary',
  components: {
    GlButton,
    GlFormSelect,
  },
  data: () => ({
    dismissalReason: null,
  }),
  computed: {
    ...mapGetters('vulnerabilities', ['selectedVulnerabilitiesCount']),
    canDismissVulnerability() {
      return this.dismissalReason && this.selectedVulnerabilitiesCount > 0;
    },
    message() {
      return n__(
        'Dismiss %d selected vulnerability as',
        'Dismiss %d selected vulnerabilities as',
        this.selectedVulnerabilitiesCount,
      );
    },
  },
  methods: {
    ...mapActions('vulnerabilities', ['dismissSelectedVulnerabilities']),
    handleDismiss() {
      if (!this.canDismissVulnerability) {
        return;
      }

      if (this.dismissalReason === REASON_NONE) {
        this.dismissSelectedVulnerabilities();
      } else {
        this.dismissSelectedVulnerabilities({ comment: this.dismissalReason });
      }
    },
  },
  dismissalReasons: [
    { value: null, text: __('Select a reason') },
    REASON_FALSE_POSITIVE,
    REASON_WONT_FIX,
    REASON_NONE,
  ],
};
</script>

<template>
  <div class="card">
    <form class="card-body d-flex align-items-center" @submit.prevent="handleDismiss">
      <span>{{ message }}</span>
      <gl-form-select
        v-model="dismissalReason"
        class="mx-3 w-auto"
        :options="$options.dismissalReasons"
      />
      <gl-button type="submit" variant="close" :disabled="!canDismissVulnerability">{{
        __('Dismiss Selected')
      }}</gl-button>
    </form>
  </div>
</template>
