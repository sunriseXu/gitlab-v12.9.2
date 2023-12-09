import Vue from 'vue';
import MockAdapter from 'axios-mock-adapter';
import mrWidgetOptions from 'ee/vue_merge_request_widget/mr_widget_options.vue';
import MRWidgetStore from 'ee/vue_merge_request_widget/stores/mr_widget_store';
import filterByKey from 'ee/vue_shared/security_reports/store/utils/filter_by_key';
import mountComponent from 'spec/helpers/vue_mount_component_helper';
import { TEST_HOST } from 'spec/test_constants';

import mockData, {
  baseIssues,
  headIssues,
  basePerformance,
  headPerformance,
  parsedBaseIssues,
  parsedHeadIssues,
} from 'ee_spec/vue_mr_widget/mock_data';

import { SUCCESS } from '~/vue_merge_request_widget/components/deployment/constants';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';
import { MTWPS_MERGE_STRATEGY, MT_MERGE_STRATEGY } from '~/vue_merge_request_widget/constants';
import {
  sastDiffSuccessMock,
  dastDiffSuccessMock,
  containerScanningDiffSuccessMock,
  dependencyScanningDiffSuccessMock,
} from 'ee_spec/vue_shared/security_reports/mock_data';

const SAST_SELECTOR = '.js-sast-widget';
const DAST_SELECTOR = '.js-dast-widget';
const DEPENDENCY_SCANNING_SELECTOR = '.js-dependency-scanning-widget';
const CONTAINER_SCANNING_SELECTOR = '.js-container-scanning';

describe('ee merge request widget options', () => {
  let vm;
  let mock;
  let Component;

  function removeBreakLine(data) {
    return data
      .replace(/\r?\n|\r/g, '')
      .replace(/\s\s+/g, ' ')
      .trim();
  }

  beforeEach(() => {
    delete mrWidgetOptions.extends.el; // Prevent component mounting

    gon.features = { asyncMrWidget: true };

    Component = Vue.extend(mrWidgetOptions);
    mock = new MockAdapter(axios);

    mock.onGet(mockData.merge_request_widget_path).reply(() => [200, gl.mrWidgetData]);
    mock.onGet(mockData.merge_request_cached_widget_path).reply(() => [200, gl.mrWidgetData]);
  });

  afterEach(() => {
    vm.$destroy();
    mock.restore();
    gon.features = {};
  });

  const findSecurityWidget = () => vm.$el.querySelector('.js-security-widget');

  const VULNERABILITY_FEEDBACK_ENDPOINT = 'vulnerability_feedback_path';

  describe('SAST', () => {
    const SAST_DIFF_ENDPOINT = 'sast_diff_endpoint';

    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        enabled_reports: {
          sast: true,
        },
        sast_comparison_path: SAST_DIFF_ENDPOINT,
        vulnerability_feedback_path: VULNERABILITY_FEEDBACK_ENDPOINT,
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', () => {
        mock.onGet(SAST_DIFF_ENDPOINT).reply(200, sastDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        expect(
          findSecurityWidget()
            .querySelector(SAST_SELECTOR)
            .textContent.trim(),
        ).toContain('SAST is loading');
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet(SAST_DIFF_ENDPOINT).reply(200, sastDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${SAST_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ),
          ).toEqual('SAST detected 1 new, and 2 fixed vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with empty successful request', () => {
      beforeEach(() => {
        mock.onGet(SAST_DIFF_ENDPOINT).reply(200, { added: [], existing: [] });
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${SAST_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ).trim(),
          ).toEqual('SAST detected no vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onGet(SAST_DIFF_ENDPOINT).reply(500, {});
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(500, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(findSecurityWidget().querySelector(SAST_SELECTOR).textContent),
          ).toContain('SAST: Loading resulted in an error');
          done();
        }, 0);
      });
    });
  });

  describe('Dependency Scanning', () => {
    const DEPENDENCY_SCANNING_ENDPOINT = 'dependency_scanning_diff_endpoint';

    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        enabled_reports: {
          dependency_scanning: true,
        },
        dependency_scanning_comparison_path: DEPENDENCY_SCANNING_ENDPOINT,
        vulnerability_feedback_path: VULNERABILITY_FEEDBACK_ENDPOINT,
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', () => {
        mock.onGet(DEPENDENCY_SCANNING_ENDPOINT).reply(200, dependencyScanningDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        expect(
          removeBreakLine(
            findSecurityWidget().querySelector(DEPENDENCY_SCANNING_SELECTOR).textContent,
          ),
        ).toContain('Dependency scanning is loading');
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet(DEPENDENCY_SCANNING_ENDPOINT).reply(200, dependencyScanningDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${DEPENDENCY_SCANNING_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ),
          ).toEqual('Dependency scanning detected 2 new, and 1 fixed vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with full report and no added or fixed issues', () => {
      beforeEach(() => {
        mock.onGet(DEPENDENCY_SCANNING_ENDPOINT).reply(200, {
          added: [],
          fixed: [],
          existing: [{ title: 'Mock finding' }],
        });
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('renders no new vulnerabilities message', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${DEPENDENCY_SCANNING_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ),
          ).toEqual('Dependency scanning detected no new vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with empty successful request', () => {
      beforeEach(() => {
        mock.onGet(DEPENDENCY_SCANNING_ENDPOINT).reply(200, { added: [], fixed: [], existing: [] });
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${DEPENDENCY_SCANNING_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ),
          ).toEqual('Dependency scanning detected no vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onAny().reply(500);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(DEPENDENCY_SCANNING_SELECTOR).textContent,
            ),
          ).toContain('Dependency scanning: Loading resulted in an error');
          done();
        }, 0);
      });
    });
  });

  describe('code quality', () => {
    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        codeclimate: {},
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', done => {
        mock.onGet('head.json').reply(200, headIssues);
        mock.onGet('base.json').reply(200, baseIssues);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        vm.mr.codeclimate = {
          head_path: 'head.json',
          base_path: 'base.json',
        };

        vm.$nextTick(() => {
          expect(
            removeBreakLine(vm.$el.querySelector('.js-codequality-widget').textContent),
          ).toContain('Loading codeclimate report');

          done();
        });
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(200, headIssues);
        mock.onGet('base.json').reply(200, baseIssues);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.codeclimate = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.codeclimate = gl.mrWidgetData.codeclimate;

        // mock worker response
        spyOn(MRWidgetStore, 'doCodeClimateComparison').and.callFake(() =>
          Promise.resolve({
            newIssues: filterByKey(parsedHeadIssues, parsedBaseIssues, 'fingerprint'),
            resolvedIssues: filterByKey(parsedBaseIssues, parsedHeadIssues, 'fingerprint'),
          }),
        );
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
            ),
          ).toEqual('Code quality improved on 1 point and degraded on 1 point');
          done();
        }, 0);
      });

      describe('text connector', () => {
        it('should only render information about fixed issues', done => {
          setTimeout(() => {
            vm.mr.codeclimateMetrics.newIssues = [];

            Vue.nextTick(() => {
              expect(
                removeBreakLine(
                  vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
                ),
              ).toEqual('Code quality improved on 1 point');
              done();
            });
          }, 0);
        });

        it('should only render information about added issues', done => {
          setTimeout(() => {
            vm.mr.codeclimateMetrics.resolvedIssues = [];
            Vue.nextTick(() => {
              expect(
                removeBreakLine(
                  vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
                ),
              ).toEqual('Code quality degraded on 1 point');
              done();
            });
          }, 0);
        });
      });
    });

    describe('with empty successful request', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(200, []);
        mock.onGet('base.json').reply(200, []);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.codeclimate = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.codeclimate = gl.mrWidgetData.codeclimate;

        // mock worker response
        spyOn(MRWidgetStore, 'doCodeClimateComparison').and.callFake(() =>
          Promise.resolve({
            newIssues: filterByKey([], [], 'fingerprint'),
            resolvedIssues: filterByKey([], [], 'fingerprint'),
          }),
        );
      });

      afterEach(() => {
        mock.restore();
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
            ),
          ).toEqual('No changes to code quality');
          done();
        }, 0);
      });
    });

    describe('with a head_path but no base_path', () => {
      beforeEach(() => {
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.codeclimate = {
          head_path: 'head.json',
          base_path: null,
        };
        vm.mr.codeclimate = gl.mrWidgetData.codeclimate;
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
            ),
          ).toContain('Failed to load codeclimate report');
          done();
        }, 0);
      });

      it('should render a help icon with more information', done => {
        setTimeout(() => {
          expect(vm.$el.querySelector('.js-codequality-widget .btn-help')).not.toBeNull();
          expect(vm.codequalityPopover.title).toBe('Base pipeline codequality artifact not found');
          done();
        }, 0);
      });
    });

    describe('with codeclimate comparison worker rejection', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(200, headIssues);
        mock.onGet('base.json').reply(200, baseIssues);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.codeclimate = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.codeclimate = gl.mrWidgetData.codeclimate;

        // mock worker rejection
        spyOn(MRWidgetStore, 'doCodeClimateComparison').and.callFake(() => Promise.reject());
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
            ),
          ).toEqual('Failed to load codeclimate report');
          done();
        }, 0);
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(500, []);
        mock.onGet('base.json').reply(500, []);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.codeclimate = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.codeclimate = gl.mrWidgetData.codeclimate;
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-codequality-widget .js-code-text').textContent,
            ),
          ).toContain('Failed to load codeclimate report');
          done();
        }, 0);
      });
    });
  });

  describe('performance', () => {
    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        performance: {},
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', done => {
        mock.onGet('head.json').reply(200, headPerformance);
        mock.onGet('base.json').reply(200, basePerformance);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        vm.mr.performance = {
          head_path: 'head.json',
          base_path: 'base.json',
        };

        vm.$nextTick(() => {
          expect(
            removeBreakLine(vm.$el.querySelector('.js-performance-widget').textContent),
          ).toContain('Loading performance report');

          done();
        });
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(200, headPerformance);
        mock.onGet('base.json').reply(200, basePerformance);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.performance = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.performance = gl.mrWidgetData.performance;
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-performance-widget .js-code-text').textContent,
            ),
          ).toEqual('Performance metrics improved on 2 points and degraded on 1 point');
          done();
        }, 0);
      });

      describe('text connector', () => {
        it('should only render information about fixed issues', done => {
          setTimeout(() => {
            vm.mr.performanceMetrics.degraded = [];

            Vue.nextTick(() => {
              expect(
                removeBreakLine(
                  vm.$el.querySelector('.js-performance-widget .js-code-text').textContent,
                ),
              ).toEqual('Performance metrics improved on 2 points');
              done();
            });
          }, 0);
        });

        it('should only render information about added issues', done => {
          setTimeout(() => {
            vm.mr.performanceMetrics.improved = [];

            Vue.nextTick(() => {
              expect(
                removeBreakLine(
                  vm.$el.querySelector('.js-performance-widget .js-code-text').textContent,
                ),
              ).toEqual('Performance metrics degraded on 1 point');
              done();
            });
          }, 0);
        });
      });
    });

    describe('with empty successful request', () => {
      beforeEach(done => {
        mock.onGet('head.json').reply(200, []);
        mock.onGet('base.json').reply(200, []);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.performance = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.performance = gl.mrWidgetData.performance;

        // wait for network request from component watch update method
        setTimeout(done, 0);
      });

      it('should render provided data', () => {
        expect(
          removeBreakLine(vm.$el.querySelector('.js-performance-widget .js-code-text').textContent),
        ).toEqual('No changes to performance metrics');
      });

      it('does not show Expand button', () => {
        const expandButton = vm.$el.querySelector('.js-performance-widget .js-collapse-btn');

        expect(expandButton).toBeNull();
      });

      it('shows success icon', () => {
        expect(
          vm.$el.querySelector('.js-performance-widget .js-ci-status-icon-success'),
        ).not.toBeNull();
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onGet('head.json').reply(500, []);
        mock.onGet('base.json').reply(500, []);
        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        gl.mrWidgetData.performance = {
          head_path: 'head.json',
          base_path: 'base.json',
        };
        vm.mr.performance = gl.mrWidgetData.performance;
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              vm.$el.querySelector('.js-performance-widget .js-code-text').textContent,
            ),
          ).toContain('Failed to load performance report');
          done();
        }, 0);
      });
    });
  });

  describe('Container Scanning', () => {
    const CONTAINER_SCANNING_ENDPOINT = 'container_scanning';

    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        enabled_reports: {
          container_scanning: true,
        },
        container_scanning_comparison_path: CONTAINER_SCANNING_ENDPOINT,
        vulnerability_feedback_path: VULNERABILITY_FEEDBACK_ENDPOINT,
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', () => {
        mock.onGet(CONTAINER_SCANNING_ENDPOINT).reply(200, containerScanningDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        expect(
          removeBreakLine(
            findSecurityWidget().querySelector(CONTAINER_SCANNING_SELECTOR).textContent,
          ),
        ).toContain('Container scanning is loading');
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet(CONTAINER_SCANNING_ENDPOINT).reply(200, containerScanningDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            removeBreakLine(
              findSecurityWidget().querySelector(
                `${CONTAINER_SCANNING_SELECTOR} .report-block-list-issue-description`,
              ).textContent,
            ),
          ).toEqual('Container scanning detected 2 new, and 1 fixed vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onGet(CONTAINER_SCANNING_ENDPOINT).reply(500, {});
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(500, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            findSecurityWidget()
              .querySelector(CONTAINER_SCANNING_SELECTOR)
              .textContent.trim(),
          ).toContain('Container scanning: Loading resulted in an error');
          done();
        }, 0);
      });
    });
  });

  describe('DAST', () => {
    const DAST_ENDPOINT = 'dast_report';

    beforeEach(() => {
      gl.mrWidgetData = {
        ...mockData,
        enabled_reports: {
          dast: true,
        },
        dast_comparison_path: DAST_ENDPOINT,
        vulnerability_feedback_path: VULNERABILITY_FEEDBACK_ENDPOINT,
      };
    });

    describe('when it is loading', () => {
      it('should render loading indicator', () => {
        mock.onGet(DAST_ENDPOINT).reply(200, dastDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        expect(
          findSecurityWidget()
            .querySelector(DAST_SELECTOR)
            .textContent.trim(),
        ).toContain('DAST is loading');
      });
    });

    describe('with successful request', () => {
      beforeEach(() => {
        mock.onGet(DAST_ENDPOINT).reply(200, dastDiffSuccessMock);
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(200, []);

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render provided data', done => {
        setTimeout(() => {
          expect(
            findSecurityWidget()
              .querySelector(`${DAST_SELECTOR} .report-block-list-issue-description`)
              .textContent.trim(),
          ).toEqual('DAST detected 1 new, and 2 fixed vulnerabilities');
          done();
        }, 0);
      });
    });

    describe('with failed request', () => {
      beforeEach(() => {
        mock.onGet(DAST_ENDPOINT).reply(500, {});
        mock.onGet(VULNERABILITY_FEEDBACK_ENDPOINT).reply(500, {});

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });
      });

      it('should render error indicator', done => {
        setTimeout(() => {
          expect(
            findSecurityWidget()
              .querySelector(DAST_SELECTOR)
              .textContent.trim(),
          ).toContain('DAST: Loading resulted in an error');
          done();
        }, 0);
      });
    });
  });

  describe('license management report', () => {
    const licenseManagementApiUrl = `${TEST_HOST}/manage_license_api`;

    it('should be rendered if license management data is set', () => {
      gl.mrWidgetData = {
        ...mockData,
        enabled_reports: {
          license_management: true,
        },
        license_management: {
          managed_licenses_path: licenseManagementApiUrl,
          can_manage_licenses: false,
        },
      };

      vm = mountComponent(Component, { mrData: gl.mrWidgetData });

      expect(vm.$el.querySelector('.license-report-widget')).not.toBeNull();
    });

    it('should not be rendered if license management data is not set', () => {
      gl.mrWidgetData = {
        ...mockData,
        license_management: {},
      };

      vm = mountComponent(Component, { mrData: gl.mrWidgetData });

      expect(vm.$el.querySelector('.license-report-widget')).toBeNull();
    });
  });

  describe('computed', () => {
    describe('shouldRenderApprovals', () => {
      it('should return false when no approvals', () => {
        vm = mountComponent(Component, {
          mrData: {
            ...mockData,
            has_approvals_available: false,
          },
        });
        vm.mr.state = 'readyToMerge';

        expect(vm.shouldRenderApprovals).toBeFalsy();
      });

      it('should return false when in empty state', () => {
        vm = mountComponent(Component, {
          mrData: {
            ...mockData,
            has_approvals_available: true,
          },
        });
        vm.mr.state = 'nothingToMerge';

        expect(vm.shouldRenderApprovals).toBeFalsy();
      });

      it('should return true when requiring approvals and in non-empty state', () => {
        vm = mountComponent(Component, {
          mrData: {
            ...mockData,
            has_approvals_available: true,
          },
        });
        vm.mr.state = 'readyToMerge';

        expect(vm.shouldRenderApprovals).toBeTruthy();
      });
    });

    describe('shouldRenderMergeTrainHelperText', () => {
      it('should return true if MTWPS is available and the user has not yet pressed the MTWPS button', () => {
        vm = mountComponent(Component, {
          mrData: {
            ...mockData,
            available_auto_merge_strategies: [MTWPS_MERGE_STRATEGY],
            auto_merge_enabled: false,
          },
        });

        expect(vm.shouldRenderMergeTrainHelperText).toBe(true);
      });
    });
  });

  describe('rendering source branch removal status', () => {
    beforeEach(() => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
        },
      });
    });

    it('renders when user cannot remove branch and branch should be removed', done => {
      vm.mr.canRemoveSourceBranch = false;
      vm.mr.shouldRemoveSourceBranch = true;
      vm.mr.state = 'readyToMerge';

      vm.$nextTick(() => {
        const tooltip = vm.$el.querySelector('.fa-question-circle');

        expect(vm.$el.textContent).toContain('Deletes source branch');
        expect(tooltip.getAttribute('data-original-title')).toBe(
          'A user with write access to the source branch selected this option',
        );

        done();
      });
    });

    it('does not render in merged state', done => {
      vm.mr.canRemoveSourceBranch = false;
      vm.mr.shouldRemoveSourceBranch = true;
      vm.mr.state = 'merged';

      vm.$nextTick(() => {
        expect(vm.$el.textContent).toContain('The source branch has been deleted');
        expect(vm.$el.textContent).not.toContain('Removes source branch');

        done();
      });
    });
  });

  describe('rendering deployments', () => {
    const deploymentMockData = {
      id: 15,
      name: 'review/diplo',
      url: '/root/acets-review-apps/environments/15',
      stop_url: '/root/acets-review-apps/environments/15/stop',
      metrics_url: '/root/acets-review-apps/environments/15/deployments/1/metrics',
      metrics_monitoring_url: '/root/acets-review-apps/environments/15/metrics',
      external_url: 'http://diplo.',
      external_url_formatted: 'diplo.',
      deployed_at: '2017-03-22T22:44:42.258Z',
      deployed_at_formatted: 'Mar 22, 2017 10:44pm',
      status: SUCCESS,
    };

    beforeEach(done => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
        },
      });

      vm.mr.deployments.push(
        {
          ...deploymentMockData,
        },
        {
          ...deploymentMockData,
          id: deploymentMockData.id + 1,
        },
      );

      vm.$nextTick(done);
    });

    it('renders multiple deployments', () => {
      expect(vm.$el.querySelectorAll('.deploy-heading').length).toBe(2);
    });
  });

  describe('CI widget', () => {
    it('renders the branch in the pipeline widget', () => {
      const sourceBranchLink = '<a href="https://www.zelda.com/">Link</a>';
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          source_branch_with_namespace_link: sourceBranchLink,
        },
      });

      const ciWidget = vm.$el.querySelector('.mr-state-widget .label-branch');

      expect(ciWidget).toContainHtml(sourceBranchLink);
    });
  });

  describe('merge train helper text', () => {
    const getHelperTextElement = () => vm.$el.querySelector('.js-merge-train-helper-text');

    it('does not render the merge train helpe text if the MTWPS strategy is not available', () => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          available_auto_merge_strategies: [MT_MERGE_STRATEGY],
          pipeline: {
            ...mockData.pipeline,
            active: true,
          },
        },
      });

      const helperText = getHelperTextElement();

      expect(helperText).not.toExist();
    });

    it('renders the correct merge train helper text when there is an existing merge train', () => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          available_auto_merge_strategies: [MTWPS_MERGE_STRATEGY],
          merge_trains_count: 2,
          merge_train_when_pipeline_succeeds_docs_path: 'path/to/help',
          pipeline: {
            ...mockData.pipeline,
            id: 123,
            active: true,
          },
        },
      });

      const helperText = getHelperTextElement();

      expect(helperText).toExist();
      expect(helperText).toContainText(
        'This merge request will be added to the merge train when pipeline #123 succeeds.',
      );
    });

    it('renders the correct merge train helper text when there is no existing merge train', () => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          available_auto_merge_strategies: [MTWPS_MERGE_STRATEGY],
          merge_trains_count: 0,
          merge_train_when_pipeline_succeeds_docs_path: 'path/to/help',
          pipeline: {
            ...mockData.pipeline,
            id: 123,
            active: true,
          },
        },
      });

      const helperText = getHelperTextElement();

      expect(helperText).toExist();
      expect(helperText).toContainText(
        'This merge request will start a merge train when pipeline #123 succeeds.',
      );
    });

    it('renders the correct pipeline link inside the message', () => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          available_auto_merge_strategies: [MTWPS_MERGE_STRATEGY],
          merge_train_when_pipeline_succeeds_docs_path: 'path/to/help',
          pipeline: {
            ...mockData.pipeline,
            id: 123,
            path: 'path/to/pipeline',
            active: true,
          },
        },
      });

      const pipelineLink = getHelperTextElement().querySelector('.js-pipeline-link');

      expect(pipelineLink).toExist();
      expect(pipelineLink).toContainText('#123');
      expect(pipelineLink).toHaveAttr('href', 'path/to/pipeline');
    });

    it('renders the documentation link inside the message', () => {
      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          available_auto_merge_strategies: [MTWPS_MERGE_STRATEGY],
          merge_train_when_pipeline_succeeds_docs_path: 'path/to/help',
          pipeline: {
            ...mockData.pipeline,
            active: true,
          },
        },
      });

      const pipelineLink = getHelperTextElement().querySelector('.js-documentation-link');

      expect(pipelineLink).toExist();
      expect(pipelineLink).toContainText('More information');
      expect(pipelineLink).toHaveAttr('href', 'path/to/help');
    });
  });

  describe('data', () => {
    it('passes approval api paths to service', () => {
      const paths = {
        api_approvals_path: `${TEST_HOST}/api/approvals/path`,
        api_approval_settings_path: `${TEST_HOST}/api/approval/settings/path`,
        api_approve_path: `${TEST_HOST}/api/approve/path`,
        api_unapprove_path: `${TEST_HOST}/api/unapprove/path`,
      };

      vm = mountComponent(Component, {
        mrData: {
          ...mockData,
          ...paths,
        },
      });

      expect(vm.service).toEqual(jasmine.objectContaining(convertObjectPropsToCamelCase(paths)));
    });
  });

  describe('when no security reports are enabled', () => {
    const noSecurityReportsEnabledCases = [
      undefined,
      {},
      { foo: true },
      { license_management: true },
      {
        dast: false,
        sast: false,
        container_scanning: false,
        dependency_scanning: false,
      },
    ];

    noSecurityReportsEnabledCases.forEach(noSecurityReportsEnabled => {
      it('does not render the security reports widget', () => {
        gl.mrWidgetData = {
          ...mockData,
          enabled_reports: noSecurityReportsEnabled,
        };

        if (noSecurityReportsEnabled?.license_management) {
          // Provide license report config if it's going to be rendered
          gl.mrWidgetData.license_management = {
            managed_licenses_path: `${TEST_HOST}/manage_license_api`,
            can_manage_licenses: false,
          };
        }

        vm = mountComponent(Component, { mrData: gl.mrWidgetData });

        expect(findSecurityWidget()).toBe(null);
      });
    });
  });
});
