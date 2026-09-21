/* global axios */
import ApiClient from './ApiClient';

const toQuery = ({ from, to, pipelineId, groupBy }) => ({
  from,
  to,
  pipeline_id: pipelineId,
  group_by: groupBy,
});

class CrmReportsAPI extends ApiClient {
  constructor() {
    super('crm/reports', { accountScoped: true });
  }

  /**
   * Todas as seções do relatório de um funil, calculadas com os mesmos filtros.
   * @param {Object} params
   * @param {number} params.from - Início do período (unix)
   * @param {number} params.to - Fim do período (unix)
   * @param {number} params.pipelineId - Funil (obrigatório)
   * @param {string} params.groupBy - day | week | month | year
   */
  getOverview(params) {
    return axios.get(`${this.url}/overview`, { params: toQuery(params) });
  }

  downloadReport(params) {
    return axios.get(`${this.url}/download`, {
      params: toQuery(params),
      responseType: 'blob',
    });
  }
}

export default new CrmReportsAPI();
