/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class LabelsAPI extends CacheEnabledApiClient {
  constructor() {
    super('labels', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'label';
  }

  importTable(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new LabelsAPI();
