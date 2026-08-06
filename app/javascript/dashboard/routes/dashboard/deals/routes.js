import { frontendURL } from '../../../helper/URLHelper';
import { DEAL_PERMISSIONS } from 'dashboard/constants/permissions.js';

const DealsIndex = () => import('./Index.vue');
const DealsKanban = () => import('./Kanban.vue');

const meta = {
  permissions: ['administrator', 'agent', ...DEAL_PERMISSIONS],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/deals'),
    name: 'deals_index',
    meta,
    component: DealsIndex,
  },
  {
    path: frontendURL('accounts/:accountId/deals/:pipelineId'),
    name: 'deals_kanban',
    meta,
    component: DealsKanban,
  },
];
