/* global axios */
import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  get(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);
    if (params.stageId) queryParams.append('stage_id', params.stageId);
    if (params.status) queryParams.append('status', params.status);
    if (params.assigneeId) queryParams.append('assignee_id', params.assigneeId);
    if (params.contactId) queryParams.append('contact_id', params.contactId);
    if (params.page) queryParams.append('page', params.page);

    const queryString = queryParams.toString();
    return axios.get(`${this.url}${queryString ? `?${queryString}` : ''}`);
  }

  show(dealId) {
    return axios.get(`${this.url}/${dealId}`);
  }

  create(data) {
    return axios.post(this.url, { deal: data });
  }

  update(dealId, data) {
    return axios.patch(`${this.url}/${dealId}`, { deal: data });
  }

  delete(dealId) {
    return axios.delete(`${this.url}/${dealId}`);
  }

  move(dealId, stageId, position = null) {
    const payload = { stage_id: stageId };
    if (position !== null) payload.position = position;
    return axios.patch(`${this.url}/${dealId}/move`, payload);
  }

  assign(dealId, assigneeId) {
    return axios.patch(`${this.url}/${dealId}/assign`, {
      assignee_id: assigneeId,
    });
  }

  win(dealId) {
    return axios.patch(`${this.url}/${dealId}/win`);
  }

  lose(dealId, lostReason) {
    return axios.patch(`${this.url}/${dealId}/lose`, {
      lost_reason: lostReason,
    });
  }

  // Activities
  getActivities(dealId) {
    return axios.get(`${this.url}/${dealId}/activities`);
  }

  createActivity(dealId, data) {
    return axios.post(`${this.url}/${dealId}/activities`, {
      deal_activity: data,
    });
  }

  updateActivity(dealId, activityId, data) {
    return axios.patch(`${this.url}/${dealId}/activities/${activityId}`, {
      deal_activity: data,
    });
  }

  deleteActivity(dealId, activityId) {
    return axios.delete(`${this.url}/${dealId}/activities/${activityId}`);
  }

  completeActivity(dealId, activityId) {
    return axios.patch(
      `${this.url}/${dealId}/activities/${activityId}/complete`
    );
  }

  // Conversations
  getConversations(dealId) {
    return axios.get(`${this.url}/${dealId}/conversations`);
  }

  linkConversation(dealId, conversationDisplayId) {
    return axios.post(`${this.url}/${dealId}/conversations`, {
      conversation_id: conversationDisplayId,
    });
  }

  unlinkConversation(dealId, conversationDealId) {
    return axios.delete(
      `${this.url}/${dealId}/conversations/${conversationDealId}`
    );
  }
}

export default new DealsAPI();
