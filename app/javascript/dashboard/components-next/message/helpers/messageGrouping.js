import { MESSAGE_TYPES } from '../constants.js';

/**
 * Determines if a message should be grouped with the next message
 * @param {Object} current - Current message
 * @param {Object} next - Next message, absent at a campaign entry or the end
 * @returns {Boolean} - Whether the message should be grouped with next
 */
export const shouldGroupWithNext = (current, next) => {
  if (!next || next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  const hasSameSender = nextSenderId === currentSenderId;

  const nextMessageType = next.messageType;
  const currentMessageType = current.messageType;

  const areBothTemplates =
    nextMessageType === MESSAGE_TYPES.TEMPLATE &&
    currentMessageType === MESSAGE_TYPES.TEMPLATE;

  if (!hasSameSender || areBothTemplates) return false;

  if (currentMessageType !== nextMessageType) return false;

  // Every message of a group chat shares one sender, the group itself, so the participant is the
  // only thing that tells two people apart. Without this they would merge into a single block.
  if (
    next.contentAttributes?.groupParticipant?.jid !==
    current.contentAttributes?.groupParticipant?.jid
  ) {
    return false;
  }

  // Check if messages are in the same minute by rounding down to nearest minute
  return Math.floor(next.createdAt / 60) === Math.floor(current.createdAt / 60);
};
