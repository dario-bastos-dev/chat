/* global axios */
import ApiClient from './ApiClient';

class BulkActionsAPI extends ApiClient {
  constructor() {
    super('bulk_actions', { accountScoped: true });
  }

  redistributionPreview({ ids, teamId }) {
    return axios.post(`${this.url}/redistribution_preview`, {
      ids,
      team_id: teamId,
    });
  }
}

export default new BulkActionsAPI();
