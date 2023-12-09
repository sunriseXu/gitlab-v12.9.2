import SidebarMediator from 'ee/sidebar/sidebar_mediator';
import CESidebarMediator from '~/sidebar/sidebar_mediator';
import CESidebarStore from '~/sidebar/stores/sidebar_store';
import SidebarService from '~/sidebar/services/sidebar_service';
import Mock from './ee_mock_data';
import waitForPromises from 'spec/helpers/wait_for_promises';

describe('EE Sidebar mediator', () => {
  let mediator;

  beforeEach(() => {
    mediator = new SidebarMediator(Mock.mediator);
  });

  afterEach(() => {
    SidebarService.singleton = null;
    CESidebarStore.singleton = null;
    CESidebarMediator.singleton = null;
  });

  it('processes fetched data', () => {
    const mockData =
      Mock.responseMap.GET['/gitlab-org/gitlab-shell/issues/5.json?serializer=sidebar'];
    const mockGraphQlData = Mock.graphQlResponseData;
    mediator.processFetchedData(mockData, mockGraphQlData);

    expect(mediator.store.weight).toBe(mockData.weight);
    expect(mediator.store.status).toBe(mockGraphQlData.project.issue.healthStatus);
  });

  it('updates status when updateStatus is called', () => {
    const healthStatus = 'onTrack';

    spyOn(mediator.service, 'updateWithGraphQl').and.returnValue(
      Promise.resolve({
        data: {
          updateIssue: {
            issue: {
              healthStatus,
            },
          },
        },
      }),
    );

    expect(mediator.store.status).toBe('');

    mediator.updateStatus(healthStatus);

    return waitForPromises().then(() => {
      expect(mediator.store.status).toBe(healthStatus);
    });
  });
});
