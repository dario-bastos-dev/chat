import { processVariable, buildWhatsAppProcessedParams } from '@chatwoot/utils';

// Constants and pure template helpers are shared with the mobile app via
// @chatwoot/utils so the logic lives in one place.
export {
  MEDIA_FORMATS,
  COMPONENT_TYPES,
  findComponentByType,
  processVariable,
  renderTemplatePreview,
} from '@chatwoot/utils';

export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';

export const allKeysRequired = value => {
  const keys = Object.keys(value);
  return keys.every(key => value[key]);
};

export const replaceTemplateVariables = (templateText, processedParams) => {
  return templateText.replace(/{{([^}]+)}}/g, (match, variable) => {
    const variableKey = processVariable(variable);
    return processedParams.body?.[variableKey] || `{{${variable}}}`;
  });
};

// The media-header flag is derived from the template inside the shared helper;
// the second argument is kept for backwards-compatible call sites.
export const buildTemplateParameters = template =>
  buildWhatsAppProcessedParams(template);

/**
 * Overlays previously saved variable values on a fresh parameter skeleton.
 *
 * Used when reopening something that already stores filled variables — an
 * automation rule, a sequence step. The skeleton defines which variables exist,
 * so a template edited at Meta drops the values of variables it no longer has
 * instead of carrying them around.
 *
 * @param {Object} skeleton - buildTemplateParameters result for this template.
 * @param {Object} savedParams - Values persisted earlier, in the same shape.
 * @returns {Object} Skeleton with saved values applied where the key survives.
 */
export const mergeTemplateParameters = (skeleton, savedParams) => {
  // A template with no parseable components yields no skeleton; walking it
  // would throw and take the parser down, so it is handed back untouched.
  if (!skeleton || typeof skeleton !== 'object') return skeleton;
  if (!savedParams || typeof savedParams !== 'object') return skeleton;

  return Object.fromEntries(
    Object.entries(skeleton).map(([section, value]) => {
      const saved = savedParams[section];

      if (Array.isArray(value)) {
        return [
          section,
          value.map((item, index) => ({ ...item, ...(saved?.[index] || {}) })),
        ];
      }

      if (value && typeof value === 'object') {
        const merged = { ...value };
        Object.keys(merged).forEach(key => {
          if (saved?.[key]) merged[key] = saved[key];
        });
        return [section, merged];
      }

      return [section, saved ?? value];
    })
  );
};
