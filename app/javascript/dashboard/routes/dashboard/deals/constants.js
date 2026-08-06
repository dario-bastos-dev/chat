/**
 * Etapas propostas ao criar um funil. Espelha Pipelines::CreateDefaultService
 * no backend, que é quem monta o funil das contas novas — se um lado mudar, o
 * outro precisa acompanhar.
 *
 * Estava duplicado quatro vezes entre Index.vue e PipelineSettings.vue.
 */
export const DEFAULT_STAGE_TEMPLATE = [
  {
    name: 'Pendente',
    color: '#3b82f6',
    stage_type: 'not_started',
    position: 1,
    win_probability: 10,
  },
  {
    name: 'Aberto',
    color: '#eab308',
    stage_type: 'active',
    position: 2,
    win_probability: 50,
  },
  {
    name: 'Ganho',
    color: '#22c55e',
    stage_type: 'done',
    position: 3,
    win_probability: 100,
  },
  {
    name: 'Perdido',
    color: '#ef4444',
    stage_type: 'closed',
    position: 4,
    win_probability: 0,
  },
];

/** Ordem lógica das etapas, usada para ordenar antes de salvar. */
export const STAGE_TYPE_ORDER = {
  not_started: 0,
  active: 1,
  done: 2,
  closed: 3,
};

/** Cor padrão por tipo de etapa, para etapas criadas sem cor definida. */
export const STAGE_TYPE_COLORS = {
  not_started: '#3b82f6',
  active: '#eab308',
  done: '#22c55e',
  closed: '#ef4444',
};

export const buildDefaultPipeline = (isDefault = false) => ({
  name: '',
  is_default: isDefault,
  stages: DEFAULT_STAGE_TEMPLATE.map(stage => ({ ...stage })),
  lost_reasons: [],
  visibility: 'public',
  allowed_team_ids: [],
});
