import { shouldGroupWithNext } from '../messageGrouping.js';

const message = (overrides = {}) => ({
  senderId: 7,
  messageType: 0,
  createdAt: 1700000000,
  ...overrides,
});

describe('shouldGroupWithNext', () => {
  it('groups two messages the same sender wrote in the same minute', () => {
    const list = [message(), message()];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(true);
  });

  it('never groups the last message', () => {
    expect(shouldGroupWithNext(message(), undefined)).toBe(false);
  });

  it('does not group messages from different senders', () => {
    const list = [message(), message({ senderId: 8 })];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(false);
  });

  it('does not group messages a minute apart', () => {
    const list = [message(), message({ createdAt: 1700000000 + 60 })];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(false);
  });

  it('does not group when the next message failed to send', () => {
    const list = [message(), message({ status: 'failed' })];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(false);
  });

  it('keeps two participants of a group apart even though the chat is one contact', () => {
    const list = [
      message({
        contentAttributes: { groupParticipant: { jid: 'alex@s.whatsapp.net' } },
      }),
      message({
        contentAttributes: {
          groupParticipant: { jid: 'bruna@s.whatsapp.net' },
        },
      }),
    ];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(false);
  });

  it('still groups consecutive messages from the same participant', () => {
    const list = [
      message({
        contentAttributes: { groupParticipant: { jid: 'alex@s.whatsapp.net' } },
      }),
      message({
        contentAttributes: { groupParticipant: { jid: 'alex@s.whatsapp.net' } },
      }),
    ];

    expect(shouldGroupWithNext(list[0], list[1])).toBe(true);
  });
});
