import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

import SettingsContent from '../Wrapper.vue';
import SettingsWrapper from '../SettingsWrapper.vue';
import MessageSequences from './Index.vue';
import SequenceEditor from './SequenceEditor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/message-sequences'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'message_sequences_wrapper',
          component: MessageSequences,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/message-sequences'),
      component: SettingsContent,
      props: () => ({
        headerTitle: 'MESSAGE_SEQUENCES.HEADER',
        icon: 'list-ordered',
        showBackButton: true,
      }),
      children: [
        {
          path: ':sequenceId/edit',
          name: 'message_sequences_edit',
          component: SequenceEditor,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
        {
          path: 'new',
          name: 'message_sequences_new',
          component: SequenceEditor,
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
        },
      ],
    },
  ],
};
