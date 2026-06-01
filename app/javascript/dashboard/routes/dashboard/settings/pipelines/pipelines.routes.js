import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SettingsWrapper from '../SettingsWrapper.vue';
const PipelineSettings = () => import('./PipelineSettings.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/settings/pipelines'),
    component: SettingsWrapper,
    children: [
      {
        path: '',
        name: 'pipelines_settings_index',
        component: PipelineSettings,
        meta: {
          permissions: ['administrator'],
        },
      },
    ],
  },
];
