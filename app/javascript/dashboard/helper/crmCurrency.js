/**
 * Formatação dos valores de negócio. A moeda é uma só por conta, guardada em
 * `account.settings.crm_currency` — por isso ela é sempre passada de fora, e
 * nunca inferida do negócio.
 */
export const DEFAULT_CRM_CURRENCY = 'BRL';

export const formatDealValue = (value, currency = DEFAULT_CRM_CURRENCY) => {
  const amount = Number(value ?? 0);
  if (Number.isNaN(amount)) return '';

  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || DEFAULT_CRM_CURRENCY,
    maximumFractionDigits: 2,
  }).format(amount);
};

/**
 * Versão compacta para os cabeçalhos de coluna do Kanban, onde não há espaço
 * para o valor por extenso (ex.: R$ 1,2 mil).
 */
export const formatDealValueCompact = (
  value,
  currency = DEFAULT_CRM_CURRENCY
) => {
  const amount = Number(value ?? 0);
  if (Number.isNaN(amount)) return '';

  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || DEFAULT_CRM_CURRENCY,
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(amount);
};
