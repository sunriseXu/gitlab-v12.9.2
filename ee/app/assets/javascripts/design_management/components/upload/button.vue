<script>
import { GlButton, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import { VALID_DESIGN_FILE_MIMETYPE } from '../../constants';

export default {
  components: {
    GlButton,
    GlLoadingIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isSaving: {
      type: Boolean,
      required: true,
    },
  },
  methods: {
    openFileUpload() {
      this.$refs.fileUpload.click();
    },
    onFileUploadChange(e) {
      this.$emit('upload', e.target.files);
    },
  },
  VALID_DESIGN_FILE_MIMETYPE,
};
</script>

<template>
  <div>
    <gl-button
      v-gl-tooltip.hover
      :title="
        s__(
          'DesignManagement|Adding a design with the same filename replaces the file in a new version.',
        )
      "
      :disabled="isSaving"
      variant="success"
      @click="openFileUpload"
    >
      {{ s__('DesignManagement|Add designs') }}
      <gl-loading-icon v-if="isSaving" inline class="ml-1" />
    </gl-button>

    <input
      ref="fileUpload"
      type="file"
      name="design_file"
      :accept="$options.VALID_DESIGN_FILE_MIMETYPE.mimetype"
      class="hide"
      multiple
      @change="onFileUploadChange"
    />
  </div>
</template>
