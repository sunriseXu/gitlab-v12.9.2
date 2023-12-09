import MockAdapter from 'axios-mock-adapter';
import Api from 'ee/api';
import * as cycleAnalyticsConstants from 'ee/analytics/cycle_analytics/constants';
import axios from '~/lib/utils/axios_utils';
import * as analyticsMockData from 'ee_jest/analytics/cycle_analytics/mock_data';

describe('Api', () => {
  const dummyApiVersion = 'v3000';
  const dummyUrlRoot = '/gitlab';
  const dummyGon = {
    api_version: dummyApiVersion,
    relative_url_root: dummyUrlRoot,
  };
  const mockEpics = [
    {
      id: 1,
      iid: 10,
      group_id: 2,
      title: 'foo',
    },
    {
      id: 2,
      iid: 11,
      group_id: 2,
      title: 'bar',
    },
  ];

  let originalGon;
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    originalGon = window.gon;
    window.gon = Object.assign({}, dummyGon);
  });

  afterEach(() => {
    mock.restore();
    window.gon = originalGon;
  });

  describe('ldapGroups', () => {
    it('calls callback on completion', done => {
      const query = 'query';
      const provider = 'provider';
      const callback = jasmine.createSpy();
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ldap/${provider}/groups.json`;

      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.ldapGroups(query, provider, callback)
        .then(response => {
          expect(callback).toHaveBeenCalledWith(response);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('createChildEpic', () => {
    it('calls `axios.post` using params `groupId`, `parentEpicIid` and title', done => {
      const groupId = 'gitlab-org';
      const parentEpicIid = 1;
      const title = 'Sample epic';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics/${parentEpicIid}/epics`;
      const expectedRes = {
        title,
        id: 20,
        iid: 5,
      };

      mock.onPost(expectedUrl).reply(200, expectedRes);

      Api.createChildEpic({ groupId, parentEpicIid, title })
        .then(({ data }) => {
          expect(data.title).toBe(expectedRes.title);
          expect(data.id).toBe(expectedRes.id);
          expect(data.iid).toBe(expectedRes.iid);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('groupEpics', () => {
    it('calls `axios.get` using param `groupId`', done => {
      const groupId = 2;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics`;

      mock
        .onGet(expectedUrl, {
          params: {
            include_ancestor_groups: false,
            include_descendant_groups: true,
          },
        })
        .reply(200, mockEpics);

      Api.groupEpics({ groupId })
        .then(({ data }) => {
          data.forEach((epic, index) => {
            expect(epic.id).toBe(mockEpics[index].id);
            expect(epic.iid).toBe(mockEpics[index].iid);
            expect(epic.group_id).toBe(mockEpics[index].group_id);
            expect(epic.title).toBe(mockEpics[index].title);
          });
        })
        .then(done)
        .catch(done.fail);
    });

    it('calls `axios.get` using param `search` when it is provided', done => {
      const groupId = 2;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics`;

      mock
        .onGet(expectedUrl, {
          params: {
            include_ancestor_groups: false,
            include_descendant_groups: true,
            search: 'foo',
          },
        })
        .reply(200, mockEpics);

      Api.groupEpics({ groupId, search: 'foo' })
        .then(({ data }) => {
          data.forEach((epic, index) => {
            expect(epic.id).toBe(mockEpics[index].id);
            expect(epic.iid).toBe(mockEpics[index].iid);
            expect(epic.group_id).toBe(mockEpics[index].group_id);
            expect(epic.title).toBe(mockEpics[index].title);
          });
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('addEpicIssue', () => {
    it('calls `axios.post` using params `groupId`, `epicIid` and `issueId`', done => {
      const groupId = 2;
      const mockIssue = {
        id: 20,
      };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics/${mockEpics[0].iid}/issues/${mockIssue.id}`;
      const expectedRes = {
        id: 30,
        epic: mockEpics[0],
        issue: mockIssue,
      };

      mock.onPost(expectedUrl).reply(200, expectedRes);

      Api.addEpicIssue({ groupId, epicIid: mockEpics[0].iid, issueId: mockIssue.id })
        .then(({ data }) => {
          expect(data.id).toBe(expectedRes.id);
          expect(data.epic).toEqual(expect.objectContaining({ ...expectedRes.epic }));
          expect(data.issue).toEqual(expect.objectContaining({ ...expectedRes.issue }));
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('removeEpicIssue', () => {
    it('calls `axios.delete` using params `groupId`, `epicIid` and `epicIssueId`', done => {
      const groupId = 2;
      const mockIssue = {
        id: 20,
        epic_issue_id: 40,
      };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics/${mockEpics[0].iid}/issues/${mockIssue.epic_issue_id}`;
      const expectedRes = {
        id: 30,
        epic: mockEpics[0],
        issue: mockIssue,
      };

      mock.onDelete(expectedUrl).reply(200, expectedRes);

      Api.removeEpicIssue({
        groupId,
        epicIid: mockEpics[0].iid,
        epicIssueId: mockIssue.epic_issue_id,
      })
        .then(({ data }) => {
          expect(data.id).toBe(expectedRes.id);
          expect(data.epic).toEqual(expect.objectContaining({ ...expectedRes.epic }));
          expect(data.issue).toEqual(expect.objectContaining({ ...expectedRes.issue }));
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('packages', () => {
    const projectId = 'project_a';
    const packageId = 'package_b';
    const apiResponse = [{ id: 1, name: 'foo' }];

    describe('groupPackages', () => {
      const groupId = 'group_a';

      it('fetch all group packages', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/packages`;
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.groupPackages(groupId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, {});
        });
      });
    });

    describe('projectPackages', () => {
      it('fetch all project packages', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/packages`;
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.projectPackages(projectId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, {});
        });
      });
    });

    describe('buildProjectPackageUrl', () => {
      it('returns the right url', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/packages/${packageId}`;
        const url = Api.buildProjectPackageUrl(projectId, packageId);
        expect(url).toEqual(expectedUrl);
      });
    });

    describe('projectPackage', () => {
      it('fetch package details', () => {
        const expectedUrl = `foo`;
        jest.spyOn(Api, 'buildProjectPackageUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.projectPackage(projectId, packageId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl);
        });
      });
    });

    describe('deleteProjectPackage', () => {
      it('delete a package', () => {
        const expectedUrl = `foo`;

        jest.spyOn(Api, 'buildProjectPackageUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'delete');
        mock.onDelete(expectedUrl).replyOnce(200, true);

        return Api.deleteProjectPackage(projectId, packageId).then(({ data }) => {
          expect(data).toEqual(true);
          expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
        });
      });
    });
  });

  describe('Cycle analytics', () => {
    const groupId = 'counting-54321';
    const createdBefore = '2019-11-18';
    const createdAfter = '2019-08-18';
    const stageId = 'thursday';
    const defaultParams = {
      group_id: groupId,
      created_after: createdAfter,
      created_before: createdBefore,
    };

    const expectRequestWithCorrectParameters = (responseObj, { params, expectedUrl, response }) => {
      const {
        data,
        config: { params: reqParams, url },
      } = responseObj;
      expect(data).toEqual(response);
      expect(reqParams).toEqual(params);
      expect(url).toEqual(expectedUrl);
    };

    describe('cycleAnalyticsTasksByType', () => {
      it('fetches tasks by type data', done => {
        const tasksByTypeResponse = [
          {
            label: {
              id: 9,
              title: 'Thursday',
              color: '#7F8C8D',
              description: 'What are you waiting for?',
              group_id: 2,
              project_id: null,
              template: false,
              text_color: '#FFFFFF',
              created_at: '2019-08-20T05:22:49.046Z',
              updated_at: '2019-08-20T05:22:49.046Z',
            },
            series: [['2019-11-03', 5]],
          },
        ];
        const labelIds = [10, 9, 8, 7];
        const params = {
          ...defaultParams,
          project_ids: null,
          subject: cycleAnalyticsConstants.TASKS_BY_TYPE_SUBJECT_ISSUE,
          label_ids: labelIds,
        };
        const expectedUrl = analyticsMockData.endpoints.tasksByTypeData;
        mock.onGet(expectedUrl).reply(200, tasksByTypeResponse);

        Api.cycleAnalyticsTasksByType(params)
          .then(({ data, config: { params: reqParams } }) => {
            expect(data).toEqual(tasksByTypeResponse);
            expect(reqParams).toEqual(params);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsTopLabels', () => {
      it('fetches top group level labels', done => {
        const response = [];
        const labelIds = [10, 9, 8, 7];
        const params = {
          ...defaultParams,
          project_ids: null,
          subject: cycleAnalyticsConstants.TASKS_BY_TYPE_SUBJECT_ISSUE,
          label_ids: labelIds,
        };

        const expectedUrl = analyticsMockData.endpoints.tasksByTypeTopLabelsData;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsTopLabels(params)
          .then(({ data, config: { url, params: reqParams } }) => {
            expect(data).toEqual(response);
            expect(url).toMatch(expectedUrl);
            expect(reqParams).toEqual(params);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsSummaryData', () => {
      it('fetches value stream analytics summary data', done => {
        const response = [{ value: 0, title: 'New Issues' }, { value: 0, title: 'Deploys' }];
        const params = {
          ...defaultParams,
        };

        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/summary`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsSummaryData(params)
          .then(responseObj =>
            expectRequestWithCorrectParameters(responseObj, {
              response,
              params,
              expectedUrl,
            }),
          )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsGroupStagesAndEvents', () => {
      it('fetches custom stage events and all stages', done => {
        const response = { events: [], stages: [] };
        const params = {
          group_id: groupId,
          'cycle_analytics[created_after]': createdAfter,
          'cycle_analytics[created_before]': createdBefore,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsGroupStagesAndEvents(groupId, params)
          .then(responseObj =>
            expectRequestWithCorrectParameters(responseObj, {
              response,
              params,
              expectedUrl,
            }),
          )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsStageEvents', () => {
      it('fetches stage events', done => {
        const response = { events: [] };
        const params = {
          ...defaultParams,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages/${stageId}/records`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsStageEvents(groupId, stageId, params)
          .then(responseObj =>
            expectRequestWithCorrectParameters(responseObj, {
              response,
              params,
              expectedUrl,
            }),
          )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsStageMedian', () => {
      it('fetches stage events', done => {
        const response = { value: '5 days ago' };
        const params = {
          ...defaultParams,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages/${stageId}/median`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsStageMedian(groupId, stageId, params)
          .then(responseObj =>
            expectRequestWithCorrectParameters(responseObj, {
              response,
              params,
              expectedUrl,
            }),
          )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsCreateStage', () => {
      it('submit the custom stage data', done => {
        const response = {};
        const customStage = {
          name: 'cool-stage',
          start_event_identifier: 'issue_created',
          start_event_label_id: null,
          end_event_identifier: 'issue_closed',
          end_event_label_id: null,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages`;
        mock.onPost(expectedUrl).reply(200, response);

        Api.cycleAnalyticsCreateStage(groupId, customStage)
          .then(({ data, config: { params: reqParams, data: reqData, url } }) => {
            expect(data).toEqual(response);
            expect(reqParams).toEqual({ group_id: groupId });
            expect(JSON.parse(reqData)).toMatchObject(customStage);
            expect(url).toEqual(expectedUrl);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsUpdateStage', () => {
      it('updates the stage data', done => {
        const response = { id: stageId, custom: false, hidden: true, name: 'nice-stage' };
        const stageData = {
          name: 'nice-stage',
          hidden: true,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages/${stageId}`;
        mock.onPut(expectedUrl).reply(200, response);

        Api.cycleAnalyticsUpdateStage(stageId, groupId, stageData)
          .then(({ data, config: { params: reqParams, data: reqData, url } }) => {
            expect(data).toEqual(response);
            expect(reqParams).toEqual({ group_id: groupId });
            expect(JSON.parse(reqData)).toMatchObject(stageData);
            expect(url).toEqual(expectedUrl);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsRemoveStage', () => {
      it('deletes the specified data', done => {
        const response = { id: stageId, hidden: true, custom: true };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages/${stageId}`;
        mock.onDelete(expectedUrl).reply(200, response);

        Api.cycleAnalyticsRemoveStage(stageId, groupId)
          .then(({ data, config: { params: reqParams, url } }) => {
            expect(data).toEqual(response);
            expect(reqParams).toEqual({ group_id: groupId });

            expect(url).toEqual(expectedUrl);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsDurationChart', () => {
      it('fetches stage duration data', done => {
        const response = [];
        const params = {
          ...defaultParams,
        };
        const expectedUrl = `${dummyUrlRoot}/-/analytics/value_stream_analytics/stages/thursday/duration_chart`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsDurationChart(stageId, params)
          .then(responseObj =>
            expectRequestWithCorrectParameters(responseObj, {
              response,
              params,
              expectedUrl,
            }),
          )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('cycleAnalyticsGroupLabels', () => {
      it('fetches group level labels', done => {
        const response = [];
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/labels`;
        mock.onGet(expectedUrl).reply(200, response);

        Api.cycleAnalyticsGroupLabels(groupId)
          .then(({ data, config: { url } }) => {
            expect(data).toEqual(response);
            expect(url).toEqual(expectedUrl);
          })
          .then(done)
          .catch(done.fail);
      });
    });
  });

  describe('GeoReplicable', () => {
    let expectedUrl;
    let apiResponse;
    let mockParams;
    let mockReplicableType;

    beforeEach(() => {
      mockReplicableType = 'designs';
      expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/geo_replication/${mockReplicableType}`;
    });

    describe('getGeoReplicableItems', () => {
      it('fetches replicableItems based on replicableType', () => {
        apiResponse = [{ id: 1, name: 'foo' }, { id: 2, name: 'bar' }];
        mockParams = { page: 1 };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.getGeoReplicableItems(mockReplicableType, mockParams).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: mockParams });
        });
      });
    });

    describe('initiateAllGeoReplicableSyncs', () => {
      it('POSTs with correct action', () => {
        apiResponse = [{ status: 'ok' }];
        mockParams = {};

        const mockAction = 'reverify';

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'post');
        mock.onPost(`${expectedUrl}/${mockAction}`).replyOnce(201, apiResponse);

        return Api.initiateAllGeoReplicableSyncs(mockReplicableType, mockAction).then(
          ({ data }) => {
            expect(data).toEqual(apiResponse);
            expect(axios.post).toHaveBeenCalledWith(`${expectedUrl}/${mockAction}`, mockParams);
          },
        );
      });
    });

    describe('initiateGeoReplicableSync', () => {
      it('PUTs with correct action and projectId', () => {
        apiResponse = [{ status: 'ok' }];
        mockParams = {};

        const mockAction = 'reverify';
        const mockProjectId = 1;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'put');
        mock.onPut(`${expectedUrl}/${mockProjectId}/${mockAction}`).replyOnce(201, apiResponse);

        return Api.initiateGeoReplicableSync(mockReplicableType, {
          projectId: mockProjectId,
          action: mockAction,
        }).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.put).toHaveBeenCalledWith(
            `${expectedUrl}/${mockProjectId}/${mockAction}`,
            mockParams,
          );
        });
      });
    });
  });

  describe('changeVulnerabilityState', () => {
    it.each`
      id    | action
      ${5}  | ${'dismiss'}
      ${7}  | ${'confirm'}
      ${38} | ${'resolve'}
    `('POSTS to correct endpoint ($id, $action)', ({ id, action }) => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/vulnerabilities/${id}/${action}`;
      const expectedResponse = { id, action, test: 'test' };

      mock.onPost(expectedUrl).replyOnce(200, expectedResponse);

      return Api.changeVulnerabilityState(id, action).then(({ data }) => {
        expect(mock.history.post).toContainEqual(expect.objectContaining({ url: expectedUrl }));
        expect(data).toEqual(expectedResponse);
      });
    });
  });
});
