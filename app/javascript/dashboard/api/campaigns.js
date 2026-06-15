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
}

export default new CampaignsAPI();
