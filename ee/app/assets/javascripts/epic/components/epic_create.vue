<script>
import { mapState, mapActions } from 'vuex';
import { GlButton } from '@gitlab/ui';

import { __ } from '~/locale';
import LoadingButton from '~/vue_shared/components/loading_button.vue';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';

export default {
  components: {
    GlButton,
    LoadingButton,
  },
  directives: {
    autofocusonshow,
  },
  props: {
    alignRight: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['newEpicTitle', 'epicCreateInProgress']),
    buttonLabel() {
      return this.epicCreateInProgress ? __('Creating epic') : __('Create epic');
    },
    isEpicCreateDisabled() {
      return !this.newEpicTitle.length;
    },
    epicTitle: {
      set(value) {
        this.setEpicCreateTitle({
          newEpicTitle: value,
        });
      },
      get() {
        return this.newEpicTitle;
      },
    },
  },
  methods: {
    ...mapActions(['setEpicCreateTitle', 'createEpic']),
  },
};
</script>

<template>
  <div class="dropdown epic-create-dropdown">
    <gl-button variant="success" class="qa-new-epic-button" data-toggle="dropdown">
      {{ __('New epic') }}
    </gl-button>
    <div :class="{ 'dropdown-menu-right': alignRight }" class="dropdown-menu">
      <input
        ref="epicTitleInput"
        v-model="epicTitle"
        v-autofocusonshow
        :disabled="epicCreateInProgress"
        :placeholder="__('Title')"
        type="text"
        class="form-control"
        data-qa-selector="epic_title_field"
        @keyup.enter.exact="createEpic"
      />
      <loading-button
        :disabled="isEpicCreateDisabled"
        :loading="epicCreateInProgress"
        :label="buttonLabel"
        container-class="btn btn-success btn-inverted prepend-top-10 qa-create-epic-button"
        @click.stop="createEpic"
      />
    </div>
  </div>
</template>
