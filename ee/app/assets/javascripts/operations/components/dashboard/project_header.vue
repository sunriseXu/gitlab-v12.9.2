<script>
import { GlButton, GlLink, GlTooltipDirective } from '@gitlab/ui';
import Icon from '~/vue_shared/components/icon.vue';
import ProjectAvatar from '~/vue_shared/components/project_avatar/default.vue';
import { __ } from '~/locale';

export default {
  components: {
    Icon,
    ProjectAvatar,
    GlButton,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    project: {
      type: Object,
      required: true,
    },
    hasPipelineFailed: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasErrors: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    title() {
      return __('Remove card');
    },
    headerClasses() {
      return {
        'dashboard-card-header-warning': this.hasErrors,
        'dashboard-card-header-failed': this.hasPipelineFailed,
        'bg-light': !this.hasErrors && !this.hasPipelineFailed,
      };
    },
  },
  methods: {
    onRemove() {
      this.$emit('remove', this.project.remove_path);
    },
  },
};
</script>

<template>
  <div :class="headerClasses" class="card-header border-0 py-2 d-flex align-items-center">
    <project-avatar :project="project" :size="24" class="flex-shrink-0 border rounded" />
    <div class="flex-grow-1 block-truncated">
      <gl-link
        v-gl-tooltip
        class="js-project-link cgray"
        :href="project.web_url"
        :title="project.name_with_namespace"
      >
        <span class="js-project-namespace">{{ project.namespace.name }} /</span>
        <span class="js-project-name bold"> {{ project.name }}</span>
      </gl-link>
    </div>
    <gl-button
      v-gl-tooltip
      class="js-remove-button bg-transparent border-0 p-0 text-secondary"
      :title="title"
      @click="onRemove"
    >
      <icon name="remove" />
    </gl-button>
  </div>
</template>
