/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(pipelineId) {
    return axios.get(`${this.url}/${pipelineId}`);
  }

  // Payload inicial do Kanban: primeiras N oportunidades de cada etapa e o
  // total real da coluna.
  board(pipelineId, filters = {}) {
    return axios.get(`${this.url}/${pipelineId}/board`, { params: filters });
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(pipelineId, data) {
    return axios.patch(`${this.url}/${pipelineId}`, data);
  }

  delete(pipelineId) {
    return axios.delete(`${this.url}/${pipelineId}`);
  }

  // Stages
  getStages(pipelineId) {
    return axios.get(`${this.url}/${pipelineId}/stages`);
  }

  createStage(pipelineId, data) {
    return axios.post(`${this.url}/${pipelineId}/stages`, data);
  }

  updateStage(pipelineId, stageId, data) {
    return axios.patch(`${this.url}/${pipelineId}/stages/${stageId}`, data);
  }

  deleteStage(pipelineId, stageId) {
    return axios.delete(`${this.url}/${pipelineId}/stages/${stageId}`);
  }

  reorderStages(pipelineId, stageIds) {
    return axios.put(`${this.url}/${pipelineId}/stages/reorder`, {
      stage_ids: stageIds,
    });
  }
}

export default new PipelinesAPI();
