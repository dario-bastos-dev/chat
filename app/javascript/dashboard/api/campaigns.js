/* global axios */

import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  getAudienceEstimate({ inboxId, targetType, labelIds }) {
    return this.axios.post(`${this.url}/audience_estimate`, {
      inbox_id: inboxId,
      target_type: targetType,
      label_ids: labelIds,
    });
  }

  analyticsMetrics(id) {
    return axios.get(`${this.url}/${id}/analytics/metrics`);
  }

  analyticsContacts(id, { status, page } = {}) {
    return axios.get(`${this.url}/${id}/analytics/contacts`, {
      params: { status, page },
    });
  }
}

export default new CampaignsAPI();
