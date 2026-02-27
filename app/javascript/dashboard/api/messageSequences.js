import ApiClient from './ApiClient';

class MessageSequencesAPI extends ApiClient {
  constructor() {
    super('message_sequences', { accountScoped: true });
  }

  create(data) {
    if (data instanceof FormData) {
      return axios.post(this.url, data, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
    }
    return axios.post(this.url, data);
  }

  update(id, data) {
    if (data instanceof FormData) {
      return axios.patch(`${this.url}/${id}`, data, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
    }
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export default new MessageSequencesAPI();
