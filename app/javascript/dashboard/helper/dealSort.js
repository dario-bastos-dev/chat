/**
 * Ordem dos cards dentro de uma etapa do Kanban. Espelha Deal::SORT_ORDERS no
 * backend, inclusive o desempate por id, para que um card reposicionado no
 * front caia no mesmo lugar em que o servidor o devolveria.
 */
export const DEFAULT_DEAL_SORT = 'created_at_desc';

export const compareDeals = sortBy => {
  const direction = sortBy === 'created_at_asc' ? 1 : -1;
  return (a, b) =>
    direction *
    (new Date(a.created_at) - new Date(b.created_at) || a.id - b.id);
};
