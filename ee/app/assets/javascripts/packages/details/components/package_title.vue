<script>
import { mapState, mapGetters } from 'vuex';
import { GlIcon, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import PackageTags from '../../shared/components/package_tags.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import timeagoMixin from '~/vue_shared/mixins/timeago';

export default {
  name: 'PackageTitle',
  components: {
    GlIcon,
    GlSprintf,
    PackageTags,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  computed: {
    ...mapState(['packageEntity', 'packageFiles']),
    ...mapGetters(['packageTypeDisplay']),
    hasTagsToDisplay() {
      return Boolean(this.packageEntity.tags && this.packageEntity.tags.length);
    },
    totalSize() {
      return numberToHumanSize(this.packageFiles.reduce((acc, p) => acc + p.size, 0));
    },
  },
};
</script>

<template>
  <div class="flex-column">
    <h1 class="gl-font-size-20 prepend-top-8 append-bottom-4">{{ packageEntity.name }}</h1>

    <div class="d-flex align-items-center text-secondary">
      <gl-icon name="eye" class="append-right-8" />
      <gl-sprintf message="v%{version} published %{timeAgo}">
        <template #version>
          {{ packageEntity.version }}
        </template>

        <template #timeAgo>
          <span v-gl-tooltip :title="tooltipTitle(packageEntity.created_at)">
            &nbsp;{{ timeFormatted(packageEntity.created_at) }}
          </span>
        </template>
      </gl-sprintf>
    </div>

    <div class="d-flex flex-wrap align-items-center append-bottom-8">
      <div v-if="packageTypeDisplay" class="d-flex align-items-center append-right-default">
        <gl-icon name="package" class="text-secondary append-right-8" />
        <span ref="package-type" class="font-weight-bold">{{ packageTypeDisplay }}</span>
      </div>

      <div v-if="hasTagsToDisplay" class="d-flex align-items-center append-right-default">
        <package-tags :tag-display-limit="1" :tags="packageEntity.tags" />
      </div>

      <div class="d-flex align-items-center append-right-default">
        <gl-icon name="disk" class="text-secondary append-right-8" />
        <span ref="package-size" class="font-weight-bold">{{ totalSize }}</span>
      </div>
    </div>
  </div>
</template>
