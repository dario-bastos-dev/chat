import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
const PipelineSettings = () => import('./PipelineSettings.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/settings/pipelines'),
    component: PipelineSettings,
    name: 'pipelines_settings_index',
    meta: {
      permissions: ['administrator'],
    },
  },
];
