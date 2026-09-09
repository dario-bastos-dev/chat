import enInboxMgmt from 'dashboard/i18n/locale/en/inboxMgmt.json';
import ptBrInboxMgmt from 'dashboard/i18n/locale/pt_BR/inboxMgmt.json';

const settingsOf = messages =>
  messages.INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS;

describe('Evolution GO group toggle copy', () => {
  it.each([
    ['en', enInboxMgmt],
    ['pt_BR', ptBrInboxMgmt],
  ])('describes the groups toggle in %s', (_locale, messages) => {
    const groups = settingsOf(messages).GROUPS_ENABLED;

    expect(groups.TITLE).toBeTruthy();
    expect(groups.DESC).toBeTruthy();
  });

  it('does not leave the pt_BR copy as a copy of the english one', () => {
    expect(settingsOf(ptBrInboxMgmt).GROUPS_ENABLED.TITLE).not.toBe(
      settingsOf(enInboxMgmt).GROUPS_ENABLED.TITLE
    );
  });
});
