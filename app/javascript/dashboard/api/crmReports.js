/* global axios */
import ApiClient from './ApiClient';

class CrmReportsAPI extends ApiClient {
  constructor() {
    super('crm/reports', { accountScoped: true });
  }

  /**
   * Get CRM summary metrics
   * @param {Object} params - Query parameters
   * @param {number} params.from - Start date timestamp
   * @param {number} params.to - End date timestamp
   * @param {number} params.pipelineId - Optional pipeline filter
   */
  getSummary(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/summary${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get deals by stage (funnel data)
   * @param {Object} params - Query parameters
   */
  getFunnel(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/funnel${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get deals over time chart data
   * @param {Object} params - Query parameters
   */
  getDealsOverTime(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);
    if (params.groupBy) queryParams.append('group_by', params.groupBy);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/deals_over_time${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get won/lost deals metrics
   * @param {Object} params - Query parameters
   */
  getWonLostMetrics(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/won_lost${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get agent performance metrics
   * @param {Object} params - Query parameters
   */
  getAgentPerformance(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/agent_performance${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get average deal cycle time
   * @param {Object} params - Query parameters
   */
  getCycleTime(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/cycle_time${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Get top deals
   * @param {Object} params - Query parameters
   */
  getTopDeals(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);
    if (params.limit) queryParams.append('limit', params.limit);
    if (params.status) queryParams.append('status', params.status);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/top_deals${queryString ? `?${queryString}` : ''}`
    );
  }

  /**
   * Download CRM report as CSV
   * @param {Object} params - Query parameters
   */
  downloadReport(params = {}) {
    const queryParams = new URLSearchParams();

    if (params.from) queryParams.append('from', params.from);
    if (params.to) queryParams.append('to', params.to);
    if (params.pipelineId) queryParams.append('pipeline_id', params.pipelineId);
    if (params.reportType) queryParams.append('report_type', params.reportType);

    const queryString = queryParams.toString();
    return axios.get(
      `${this.url}/download${queryString ? `?${queryString}` : ''}`,
      {
        responseType: 'blob',
      }
    );
  }
}

export default new CrmReportsAPI();
