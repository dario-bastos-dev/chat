import conversationRoutes from '../conversation.routes';
import { routeIsAccessibleFor } from 'dashboard/helper/routeHelpers';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions';

vi.mock('dashboard/store', () => ({ default: { getters: {} } }));
vi.mock('../ConversationView.vue', () => ({ default: {} }));

// defaultRedirectPage sends every one of these permissions to the conversation dashboard, so a route that
// rejects one of them makes the router redirect to itself forever and the app stays on a blank screen.
describe('conversation routes', () => {
  describe.each(conversationRoutes.routes.map(route => [route.name, route]))(
    '%s',
    (_name, route) => {
      it.each([...ROLES, ...CONVERSATION_PERMISSIONS])(
        'is accessible with %s',
        permission => {
          expect(routeIsAccessibleFor(route, [permission])).toBe(true);
        }
      );
    }
  );
});
