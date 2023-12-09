import { createLocalVue, mount } from '@vue/test-utils';
import $ from 'jquery';
import Api from 'ee/api';
import ApproversSelect from 'ee/approvals/components/approvers_select.vue';
import { TYPE_USER, TYPE_GROUP } from 'ee/approvals/constants';
import { TEST_HOST } from 'spec/test_constants';

const DEBOUNCE_TIME = 250;
const TEST_PROJECT_ID = '17';
const TEST_GROUP_AVATAR = `${TEST_HOST}/group-avatar.png`;
const TEST_USER_AVATAR = `${TEST_HOST}/user-avatar.png`;
const TEST_GROUPS = [
  { id: 1, full_name: 'GitLab Org', full_path: 'gitlab/org', avatar_url: null },
  {
    id: 2,
    full_name: 'Lorem Ipsum',
    full_path: 'lorem-ipsum',
    avatar_url: TEST_GROUP_AVATAR,
  },
];
const TEST_USERS = [
  { id: 1, name: 'Dolar', username: 'dolar', avatar_url: TEST_USER_AVATAR },
  { id: 3, name: 'Sit', username: 'sit', avatar_url: TEST_USER_AVATAR },
];

const localVue = createLocalVue();

const waitForEvent = ($input, event) => new Promise(resolve => $input.one(event, resolve));
const parseAvatar = element => (element.classList.contains('identicon') ? null : element.src);
const select2Container = () => document.querySelector('.select2-container');
const select2DropdownOptions = () => document.querySelectorAll('#select2-drop .user-result');
const select2DropdownItems = () =>
  Array.prototype.map.call(select2DropdownOptions(), element => {
    const isGroup = element.classList.contains('group-result');
    const avatar = parseAvatar(element.querySelector('.avatar'));

    return isGroup
      ? {
          avatar_url: avatar,
          full_name: element.querySelector('.group-name').textContent,
          full_path: element.querySelector('.group-path').textContent,
        }
      : {
          avatar_url: avatar,
          name: element.querySelector('.user-name').textContent,
          username: element.querySelector('.user-username').textContent,
        };
  });

describe('Approvals ApproversSelect', () => {
  let wrapper;
  let $input;

  const factory = (options = {}) => {
    const propsData = {
      projectId: TEST_PROJECT_ID,
      ...options.propsData,
    };

    wrapper = mount(localVue.extend(ApproversSelect), {
      ...options,
      propsData,
      localVue,
      attachToDocument: true,
    });

    $input = $(wrapper.vm.$refs.input);
  };
  const search = (term = '') => {
    $input.select2('search', term);
    jasmine.clock().tick(DEBOUNCE_TIME);
  };

  beforeEach(() => {
    jasmine.clock().install();
    spyOn(Api, 'groups').and.returnValue(Promise.resolve(TEST_GROUPS));
    spyOn(Api, 'projectUsers').and.returnValue(Promise.resolve(TEST_USERS));
  });

  afterEach(() => {
    jasmine.clock().uninstall();
    wrapper.destroy();
  });

  it('renders select2 input', () => {
    expect(select2Container()).toBe(null);

    factory();

    expect(select2Container()).not.toBe(null);
  });

  it('queries and displays groups and users', done => {
    factory();

    const expected = TEST_GROUPS.concat(TEST_USERS)
      .map(({ id, ...obj }) => obj)
      .map(({ username, ...obj }) => (!username ? obj : { ...obj, username: `@${username}` }));

    waitForEvent($input, 'select2-loaded')
      .then(() => {
        const items = select2DropdownItems();

        expect(items).toEqual(expected);
      })
      .then(done)
      .catch(done.fail);

    search();
  });

  describe('with search term', () => {
    const term = 'lorem';

    beforeEach(done => {
      factory();

      waitForEvent($input, 'select2-loaded')
        .then(done)
        .catch(done.fail);

      search(term);
    });

    it('fetches all available groups', () => {
      expect(Api.groups).toHaveBeenCalledWith(term, { skip_groups: [], all_available: true });
    });

    it('fetches users', () => {
      expect(Api.projectUsers).toHaveBeenCalledWith(TEST_PROJECT_ID, term, {
        skip_users: [],
      });
    });
  });

  describe('with empty seach term and skips', () => {
    const skipGroupIds = [7, 8];
    const skipUserIds = [9, 10];

    beforeEach(done => {
      factory({
        propsData: {
          skipGroupIds,
          skipUserIds,
        },
      });

      waitForEvent($input, 'select2-loaded')
        .then(done)
        .catch(done.fail);

      search();
    });

    it('skips groups and does not fetch all available', () => {
      expect(Api.groups).toHaveBeenCalledWith('', {
        skip_groups: skipGroupIds,
        all_available: false,
      });
    });

    it('skips users', () => {
      expect(Api.projectUsers).toHaveBeenCalledWith(TEST_PROJECT_ID, '', {
        skip_users: skipUserIds,
      });
    });
  });

  it('emits input when data changes', done => {
    factory();

    const expectedFinal = [
      { ...TEST_USERS[0], type: TYPE_USER },
      { ...TEST_GROUPS[0], type: TYPE_GROUP },
    ];
    const expected = expectedFinal.map((x, idx) => ({
      name: 'input',
      args: [expectedFinal.slice(0, idx + 1)],
    }));

    waitForEvent($input, 'select2-loaded')
      .then(() => {
        const options = select2DropdownOptions();
        $(options[TEST_GROUPS.length]).trigger('mouseup');
        $(options[0]).trigger('mouseup');
      })
      .then(done)
      .catch(done.fail);

    waitForEvent($input, 'change')
      .then(() => {
        expect(wrapper.emittedByOrder()).toEqual(expected);
      })
      .then(done)
      .catch(done.fail);

    search();
  });
});
