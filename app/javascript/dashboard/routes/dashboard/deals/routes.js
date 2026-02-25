import { frontendURL } from '../../../helper/URLHelper';

const DealsIndex = () => import('./Index.vue');
const DealsKanban = () => import('./Kanban.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/deals'),
    name: 'deals_index',
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
    component: DealsIndex,
  },
  {
    path: frontendURL('accounts/:accountId/deals/:pipelineId'),
    name: 'deals_kanban',
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
    component: DealsKanban,
  },
];
