/* global axios */
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true });
  }

  getForConversation(conversationId) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`
    );
  }

  createForConversation(conversationId, data) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`,
      data
    );
  }

  updateForConversation(conversationId, id, data) {
    return axios.patch(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${id}`,
      data
    );
  }

  deleteForConversation(conversationId, id) {
    return axios.delete(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${id}`
    );
  }
}

export default new ScheduledMessagesAPI();
