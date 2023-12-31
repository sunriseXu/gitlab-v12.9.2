import MockAdapter from 'axios-mock-adapter';

import GroupMemberStore from 'ee/group_member_contributions/store/group_member_store';
import defaultColumns from 'ee/group_member_contributions/constants';
import axios from '~/lib/utils/axios_utils';

import { rawMembers, contributionsPath } from '../mock_data';

describe('GroupMemberStore', () => {
  let store;

  beforeEach(() => {
    store = new GroupMemberStore(contributionsPath);
  });

  describe('setColumns', () => {
    beforeEach(() => {
      store.setColumns(defaultColumns);
    });

    it('sets columns to store state', () => {
      expect(store.state.columns).toBe(defaultColumns);
    });

    it('initializes sortOrders on store state', () => {
      Object.keys(store.state.sortOrders).forEach(column => {
        expect(store.state.sortOrders[column]).toBe(1);
      });
    });
  });

  describe('setMembers', () => {
    it('sets members to store state', () => {
      store.setMembers(rawMembers);

      expect(store.state.members.length).toBe(rawMembers.length);
    });
  });

  describe('sortMembers', () => {
    it('sorts members list based on provided column name', () => {
      store.setColumns(defaultColumns);
      store.setMembers(rawMembers);

      let [firstMember] = store.state.members;

      expect(firstMember.fullname).toBe('Administrator');

      store.sortMembers('fullname');
      [firstMember] = store.state.members;

      expect(firstMember.fullname).toBe('Terrell Graham');
    });
  });

  describe('fetchContributedMembers', () => {
    let mock;

    beforeEach(() => {
      mock = new MockAdapter(axios);
      setFixtures('<div class="flash-container"></div>');
    });

    afterEach(() => {
      mock.restore();
    });

    it('calls service.getContributedMembers and sets response to the store on success', done => {
      mock.onGet(contributionsPath).reply(200, rawMembers);
      spyOn(store, 'setColumns');
      spyOn(store, 'setMembers');

      store
        .fetchContributedMembers()
        .then(() => {
          expect(store.isLoading).toBe(false);
          expect(store.setColumns).toHaveBeenCalledWith(jasmine.any(Object));
          expect(store.setMembers).toHaveBeenCalledWith(rawMembers);
          done();
        })
        .catch(done.fail);

      expect(store.isLoading).toBe(true);
    });

    it('calls service.getContributedMembers and sets `isLoading` to false and shows flash message if request failed', done => {
      mock.onGet(contributionsPath).reply(500, {});

      store
        .fetchContributedMembers()
        .then(() => done.fail('Expected error to be thrown!'))
        .catch(e => {
          expect(e.message).toBe('Request failed with status code 500');
          expect(store.isLoading).toBe(false);
          expect(document.querySelector('.flash-text').innerText.trim()).toBe(
            'Something went wrong while fetching group member contributions',
          );
        })
        .then(done)
        .catch(done.fail);

      expect(store.isLoading).toBe(true);
    });
  });
});
