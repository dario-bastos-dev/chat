import { compareDeals } from '../dealSort';

describe('compareDeals', () => {
  const older = { id: 1, created_at: '2026-09-01T10:00:00.000Z' };
  const newer = { id: 2, created_at: '2026-09-10T10:00:00.000Z' };

  it('puts the newest deal first for created_at_desc', () => {
    expect([older, newer].sort(compareDeals('created_at_desc'))).toEqual([
      newer,
      older,
    ]);
  });

  it('puts the oldest deal first for created_at_asc', () => {
    expect([newer, older].sort(compareDeals('created_at_asc'))).toEqual([
      older,
      newer,
    ]);
  });

  // Mesmo desempate do Deal::SORT_ORDERS: sem ele, o card movido cairia num
  // lugar diferente do que o servidor devolve no proximo refetch.
  it('breaks a created_at tie by id, descending, for created_at_desc', () => {
    const lowerId = { id: 3, created_at: '2026-09-05T10:00:00.000Z' };
    const higherId = { id: 7, created_at: '2026-09-05T10:00:00.000Z' };

    expect([lowerId, higherId].sort(compareDeals('created_at_desc'))).toEqual([
      higherId,
      lowerId,
    ]);
  });

  it('breaks a created_at tie by id, ascending, for created_at_asc', () => {
    const lowerId = { id: 3, created_at: '2026-09-05T10:00:00.000Z' };
    const higherId = { id: 7, created_at: '2026-09-05T10:00:00.000Z' };

    expect([higherId, lowerId].sort(compareDeals('created_at_asc'))).toEqual([
      lowerId,
      higherId,
    ]);
  });
});
