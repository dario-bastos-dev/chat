/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  getCampaignHistory(conversationId, { before, signal } = {}) {
    return axios.get(`${this.url}/${conversationId}/campaign_history`, {
      params: { before },
      signal,
    });
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  exportConversations(queryPayload) {
    return axios.post(`${this.url}/export`, queryPayload);
  }

  getSuggestions(conversationID, type) {
    return axios.get(`${this.url}/${conversationID}/suggestions/${type}`);
  }

  getUnreadCounts() {
    return axios.get(`${this.url}/unread_counts`);
  }

  getSidebarCounts() {
    return axios.get(`${this.url}/sidebar_counts`);
  }
}

export default new ConversationApi();
