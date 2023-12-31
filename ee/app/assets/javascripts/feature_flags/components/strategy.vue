<script>
import {
  GlFormSelect,
  GlFormInput,
  GlFormTextarea,
  GlFormGroup,
  GlToken,
  GlButton,
  GlIcon,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import {
  PERCENT_ROLLOUT_GROUP_ID,
  ROLLOUT_STRATEGY_ALL_USERS,
  ROLLOUT_STRATEGY_PERCENT_ROLLOUT,
  ROLLOUT_STRATEGY_USER_ID,
} from '../constants';

import NewEnvironmentsDropdown from './new_environments_dropdown.vue';

export default {
  components: {
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlFormSelect,
    GlToken,
    GlButton,
    GlIcon,
    NewEnvironmentsDropdown,
  },
  model: {
    prop: 'strategy',
    event: 'change',
  },
  props: {
    strategy: {
      type: Object,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
    endpoint: {
      type: String,
      required: false,
      default: '',
    },
    canDelete: {
      type: Boolean,
      required: true,
    },
  },
  ROLLOUT_STRATEGY_ALL_USERS,
  ROLLOUT_STRATEGY_PERCENT_ROLLOUT,
  ROLLOUT_STRATEGY_USER_ID,

  translations: {
    allEnvironments: __('All environments'),
    environmentsLabel: __('Environments'),
    removeLabel: s__('FeatureFlag|Delete strategy'),
    rolloutPercentageDescription: __('Enter a whole number between 0 and 100'),
    rolloutPercentageInvalid: s__(
      'FeatureFlags|Percent rollout must be a whole number between 0 and 100',
    ),
    rolloutPercentageLabel: s__('FeatureFlag|Percentage'),
    rolloutUserIdsDescription: __('Enter one or more user ID separated by commas'),
    rolloutUserIdsLabel: s__('FeatureFlag|User IDs'),
    strategyTypeDescription: __('Select strategy activation method'),
    strategyTypeLabel: s__('FeatureFlag|Type'),
  },

  data() {
    return {
      environments: this.strategy.scopes || [],
      formStrategy: { ...this.strategy },
      formPercentage:
        this.strategy.name === ROLLOUT_STRATEGY_PERCENT_ROLLOUT
          ? this.strategy.parameters.percentage
          : '',
      formUserIds:
        this.strategy.name === ROLLOUT_STRATEGY_USER_ID ? this.strategy.parameters.userIds : '',
      strategies: [
        {
          value: ROLLOUT_STRATEGY_ALL_USERS,
          text: __('All users'),
        },
        {
          value: ROLLOUT_STRATEGY_PERCENT_ROLLOUT,
          text: __('Percent rollout (logged in users)'),
        },
        {
          value: ROLLOUT_STRATEGY_USER_ID,
          text: __('User IDs'),
        },
      ],
    };
  },
  computed: {
    strategyTypeId() {
      return `strategy-type-${this.index}`;
    },
    strategyPercentageId() {
      return `strategy-percentage-${this.index}`;
    },
    strategyUserIdsId() {
      return `strategy-user-ids-${this.index}`;
    },
    environmentsDropdownId() {
      return `environments-dropdown-${this.index}`;
    },
    isPercentRollout() {
      return this.isStrategyType(ROLLOUT_STRATEGY_PERCENT_ROLLOUT);
    },
    isUserWithId() {
      return this.isStrategyType(ROLLOUT_STRATEGY_USER_ID);
    },
    hasNoDefinedEnvironments() {
      return this.environments.length === 0;
    },
  },
  methods: {
    addEnvironment(environment) {
      this.environments.push(environment);
      this.onStrategyChange();
    },
    onStrategyChange() {
      const parameters = {};
      switch (this.formStrategy.name) {
        case ROLLOUT_STRATEGY_PERCENT_ROLLOUT:
          parameters.percentage = this.formPercentage;
          parameters.groupId = PERCENT_ROLLOUT_GROUP_ID;
          break;
        case ROLLOUT_STRATEGY_USER_ID:
          parameters.userIds = this.formUserIds;
          break;
        default:
          break;
      }
      this.$emit('change', {
        ...this.formStrategy,
        parameters,
        scopes: this.environments,
      });
    },
    removeScope(environment) {
      this.environments = this.environments.filter(e => e !== environment);
      this.onStrategyChange();
    },
    isStrategyType(type) {
      return this.formStrategy.name === type;
    },
  },
};
</script>
<template>
  <div>
    <div class="flex flex-column flex-md-row flex-md-wrap">
      <div class="mr-5">
        <gl-form-group
          :label="$options.translations.strategyTypeLabel"
          :description="$options.translations.strategyTypeDescription"
          :label-for="strategyTypeId"
        >
          <gl-form-select
            :id="strategyTypeId"
            v-model="formStrategy.name"
            :options="strategies"
            @change="onStrategyChange"
          />
        </gl-form-group>
      </div>

      <div>
        <gl-form-group
          v-if="isPercentRollout"
          :label="$options.translations.rolloutPercentageLabel"
          :description="$options.translations.rolloutPercentageDescription"
          :label-for="strategyPercentageId"
          :invalid-feedback="$options.translations.rolloutPercentageInvalid"
        >
          <div class="flex align-items-center">
            <gl-form-input
              :id="strategyPercentageId"
              v-model="formPercentage"
              class="rollout-percentage text-right w-3rem"
              type="number"
              @input="onStrategyChange"
            />
            <span class="ml-1">%</span>
          </div>
        </gl-form-group>

        <gl-form-group
          v-if="isUserWithId"
          :label="$options.translations.rolloutUserIdsLabel"
          :description="$options.translations.rolloutUserIdsDescription"
          :label-for="strategyUserIdsId"
        >
          <gl-form-textarea
            :id="strategyUserIdsId"
            v-model="formUserIds"
            @input="onStrategyChange"
          />
        </gl-form-group>
      </div>

      <div class="align-self-end align-self-md-stretch order-first offset-md-0 order-md-0 ml-auto">
        <gl-button v-if="canDelete" variant="danger">
          <span class="d-md-none">
            {{ $options.translations.removeLabel }}
          </span>
          <gl-icon class="d-none d-md-inline-flex" name="remove" />
        </gl-button>
      </div>
    </div>
    <div class="flex flex-column">
      <label :for="environmentsDropdownId">{{ $options.translations.environmentsLabel }}</label>
      <div class="flex flex-column flex-md-row align-items-start align-items-md-center">
        <new-environments-dropdown
          :id="environmentsDropdownId"
          :endpoint="endpoint"
          class="mr-2"
          @add="addEnvironment"
        />
        <span v-if="hasNoDefinedEnvironments" class="text-secondary mt-2 mt-md-0 ml-md-3">
          {{ $options.translations.allEnvironments }}
        </span>
        <div v-else class="flex align-items-center">
          <gl-token
            v-for="environment in environments"
            :key="environment"
            class="mt-2 mr-2 mt-md-0 mr-md-0 ml-md-2 rounded-pill"
            @close="removeScope(environment)"
          >
            {{ environment }}
          </gl-token>
        </div>
      </div>
    </div>
  </div>
</template>
