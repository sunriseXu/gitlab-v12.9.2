<script>
import { uniqueId } from 'underscore';
import { GlSkeletonLoader } from '@gitlab/ui';

import Icon from '~/vue_shared/components/icon.vue';

import accordionEventBus from './accordion_event_bus';

const accordionItemUniqueId = name => uniqueId(`gl-accordion-item-${name}-`);

export default {
  components: {
    GlSkeletonLoader,
    Icon,
  },
  props: {
    accordionId: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    maxHeight: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isExpanded: false,
    };
  },
  computed: {
    contentStyles() {
      return {
        maxHeight: this.maxHeight,
        overflow: 'auto',
      };
    },
    isDisabled() {
      return this.disabled || !this.hasContent;
    },
    hasContent() {
      return this.$scopedSlots.default !== undefined;
    },
  },
  created() {
    this.buttonId = accordionItemUniqueId('trigger');
    this.contentContainerId = accordionItemUniqueId('content-container');
    // create a unique event name so multiple accordion instances don't close each other items
    this.closeOtherItemsEvent = `${this.accordionId}.closeOtherAccordionItems`;

    accordionEventBus.$on(this.closeOtherItemsEvent, this.onCloseOtherAccordionItems);
  },
  destroyed() {
    accordionEventBus.$off(this.closeOtherItemsEvent);
  },
  methods: {
    onCloseOtherAccordionItems(trigger) {
      if (trigger !== this) {
        this.collapse();
      }
    },
    handleClick() {
      if (this.isExpanded) {
        this.collapse();
      } else {
        this.expand();
      }
      accordionEventBus.$emit(this.closeOtherItemsEvent, this);
    },
    expand() {
      this.isExpanded = true;
    },
    collapse() {
      this.isExpanded = false;
    },
  },
};
</script>

<template>
  <li class="list-group-item p-0">
    <template v-if="!isLoading">
      <div class="d-flex align-items-stretch">
        <button
          :id="buttonId"
          ref="expansionTrigger"
          type="button"
          :disabled="isDisabled"
          :aria-expanded="isExpanded"
          :aria-controls="contentContainerId"
          class="btn-transparent border-0 rounded-0 w-100 p-0 text-left"
          :class="{ 'cursor-default': isDisabled }"
          @click="handleClick"
        >
          <div
            class="d-flex align-items-center p-2"
            :class="{ 'list-group-item-action': !isDisabled }"
          >
            <icon
              :size="16"
              class="mr-2 gl-text-gray-900"
              :name="isExpanded ? 'angle-down' : 'angle-right'"
            />
            <span
              ><slot name="title" :is-expanded="isExpanded" :is-disabled="isDisabled"></slot
            ></span>
          </div>
        </button>
      </div>
      <div
        v-show="isExpanded"
        :id="contentContainerId"
        ref="contentContainer"
        :aria-labelledby="buttonId"
        role="region"
      >
        <slot name="subTitle"></slot>
        <div ref="content" :style="contentStyles"><slot name="default"></slot></div>
      </div>
    </template>
    <div v-else ref="loadingIndicator" class="d-flex p-2">
      <div class="h-32-px">
        <gl-skeleton-loader :height="32">
          <rect width="12" height="16" rx="4" x="0" y="8" />
          <circle cx="37" cy="15" r="15" />
          <rect width="20" height="16" rx="4" x="63" y="8" />
        </gl-skeleton-loader>
      </div>
    </div>
  </li>
</template>
