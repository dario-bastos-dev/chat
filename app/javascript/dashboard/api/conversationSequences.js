/* global axios */

import ApiClient from './ApiClient';

class ConversationSequencesAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  getEndpoint(conversationId) {
    return `${this.baseUrl()}/conversations/${conversationId}/conversation_sequences`;
  }

  getSequences(conversationId) {
    return axios.get(this.getEndpoint(conversationId));
  }

  attach(conversationId, messageSequenceId) {
    return axios.post(this.getEndpoint(conversationId), {
      message_sequence_id: messageSequenceId,
    });
  }

  detach(conversationId, conversationSequenceId) {
    return axios.delete(
      `${this.getEndpoint(conversationId)}/${conversationSequenceId}`
    );
  }
}

export default new ConversationSequencesAPI();
