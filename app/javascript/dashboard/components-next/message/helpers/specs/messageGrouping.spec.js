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

    expect(shouldGroupWithNext(0, list)).toBe(true);
  });

  it('never groups the last message', () => {
    expect(shouldGroupWithNext(0, [message()])).toBe(false);
  });

  it('does not group messages from different senders', () => {
    const list = [message(), message({ senderId: 8 })];

    expect(shouldGroupWithNext(0, list)).toBe(false);
  });

  it('does not group messages a minute apart', () => {
    const list = [message(), message({ createdAt: 1700000000 + 60 })];

    expect(shouldGroupWithNext(0, list)).toBe(false);
  });

  it('does not group when the next message failed to send', () => {
    const list = [message(), message({ status: 'failed' })];

    expect(shouldGroupWithNext(0, list)).toBe(false);
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

    expect(shouldGroupWithNext(0, list)).toBe(false);
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

    expect(shouldGroupWithNext(0, list)).toBe(true);
  });
});
