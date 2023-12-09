import Vue from 'vue';
import Vuex from 'vuex';

import listModule from './modules/list';
import { licenseManagementModule } from 'ee/vue_shared/license_management/store/index';
import { LICENSE_LIST } from './constants';
import { LICENSE_MANAGEMENT } from 'ee/vue_shared/license_management/store/constants';

Vue.use(Vuex);

export default () =>
  new Vuex.Store({
    modules: {
      [LICENSE_LIST]: listModule(),
      [LICENSE_MANAGEMENT]: licenseManagementModule(),
    },
  });
