/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class Inboxes extends CacheEnabledApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'inbox';
  }

  getCampaigns(inboxId) {
    return axios.get(`${this.url}/${inboxId}/campaigns`);
  }

  deleteInboxAvatar(inboxId) {
    return axios.delete(`${this.url}/${inboxId}/avatar`);
  }

  getAgentBot(inboxId) {
    return axios.get(`${this.url}/${inboxId}/agent_bot`);
  }

  setAgentBot(inboxId, botId) {
    return axios.post(`${this.url}/${inboxId}/set_agent_bot`, {
      agent_bot: botId,
    });
  }

  syncTemplates(inboxId) {
    return axios.post(`${this.url}/${inboxId}/sync_templates`);
  }

  getMessageTemplates(inboxId, params = {}, config = {}) {
    return axios.get(`${this.url}/${inboxId}/message_templates`, {
      ...config,
      params,
    });
  }

  updateWhatsappBusinessManagementToken(inboxId, businessManagementToken) {
    return axios.put(
      `${this.url}/${inboxId}/whatsapp_business_management_token`,
      {
        business_management_token: businessManagementToken,
      }
    );
  }

  getWhatsappProfile(inboxId) {
    return axios.get(`${this.url}/${inboxId}/whatsapp_profile`);
  }

  updateWhatsappProfile(inboxId, { profilePicture, websites = [], ...fields }) {
    const formData = new FormData();
    Object.entries(fields).forEach(([key, value]) => {
      formData.append(key, value ?? '');
    });
    // Meta clears the list when no website is sent, so an empty array
    // still needs one blank entry.
    if (websites.length) {
      websites.forEach(website => formData.append('websites[]', website));
    } else {
      formData.append('websites[]', '');
    }
    if (profilePicture) {
      formData.append('profile_picture', profilePicture);
    }
    return axios.post(
      `${this.url}/${inboxId}/update_whatsapp_profile`,
      formData
    );
  }

  createMessageTemplate(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/message_templates`, { template });
  }

  updateMessageTemplate(inboxId, name, language, template) {
    return axios.patch(`${this.url}/${inboxId}/message_templates/${name}`, {
      language,
      template,
    });
  }

  deleteMessageTemplate(inboxId, name) {
    return axios.delete(`${this.url}/${inboxId}/message_templates/${name}`);
  }

  uploadMessageTemplateMedia(inboxId, file, format) {
    const formData = new FormData();
    formData.append('file', file);
    // Not `format`: the API routes default it to 'json' and route defaults win
    // over the body, so the header format would never reach the controller.
    formData.append('header_format', format);
    return axios.post(
      `${this.url}/${inboxId}/message_templates/media`,
      formData
    );
  }

  // Evolution API methods
  getEvolutionQRCode(inboxId, params = {}) {
    return axios.get(`${this.url}/${inboxId}/evolution_qrcode`, { params });
  }

  getEvolutionStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/evolution_status`);
  }

  createEvolutionInstance(inboxId) {
    return axios.post(`${this.url}/${inboxId}/evolution_create_instance`);
  }

  disconnectEvolution(inboxId) {
    return axios.post(`${this.url}/${inboxId}/evolution_disconnect`);
  }

  // Evolution GO API methods
  getEvolutionGoQRCode(inboxId) {
    return axios.get(`${this.url}/${inboxId}/evolution_go_qrcode`);
  }

  getEvolutionGoPairingCode(inboxId, params = {}) {
    return axios.get(`${this.url}/${inboxId}/evolution_go_pairing`, { params });
  }

  getEvolutionGoStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/evolution_go_status`);
  }

  createEvolutionGoInstance(inboxId) {
    return axios.post(`${this.url}/${inboxId}/evolution_go_create_instance`);
  }

  disconnectEvolutionGo(inboxId) {
    return axios.post(`${this.url}/${inboxId}/evolution_go_disconnect`);
  }

  getEvolutionGoSettings(inboxId) {
    return axios.get(`${this.url}/${inboxId}/evolution_go_settings`);
  }

  createCSATTemplate(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template`, {
      template,
    });
  }

  getCSATTemplateStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/csat_template`);
  }

  analyzeCSATTemplateUtility(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template/analyze`, {
      template,
    });
  }

  resetSecret(inboxId) {
    return axios.post(`${this.url}/${inboxId}/reset_secret`);
  }

  enableWhatsappCalling(inboxId) {
    return axios.post(`${this.url}/${inboxId}/enable_whatsapp_calling`);
  }

  disableWhatsappCalling(inboxId) {
    return axios.post(`${this.url}/${inboxId}/disable_whatsapp_calling`);
  }

  setInboundCalls(inboxId, enabled) {
    return axios.post(`${this.url}/${inboxId}/set_inbound_calls`, {
      inbound_calls_enabled: enabled,
    });
  }
}

export default new Inboxes();
