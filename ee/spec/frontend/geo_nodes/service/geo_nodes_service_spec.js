import GeoNodesService from 'ee/geo_nodes/service/geo_nodes_service';
import axios from '~/lib/utils/axios_utils';

import { NODE_DETAILS_PATH } from '../mock_data';

jest.mock('axios');

describe('GeoNodesService', () => {
  let service;

  beforeEach(() => {
    service = new GeoNodesService(NODE_DETAILS_PATH);
  });

  describe('getGeoNodes', () => {
    it('returns axios instance for Geo nodes path', () => {
      service.getGeoNodes();

      expect(axios.get).toHaveBeenCalledWith(service.geoNodesPath);
    });
  });

  describe('getGeoNodeDetails', () => {
    it('returns axios instance for Geo node details path', () => {
      service.getGeoNodeDetails(2);

      expect(axios.get).toHaveBeenCalled();
    });
  });
});
