// Maps a template as Meta returns it back into the shape TemplateForm edits.
// This is the inverse of the payload the form builds when creating one.

export const VARIABLE_PATTERN = /\{\{\s*([A-Za-z0-9_]+)\s*\}\}/g;

export const extractVariables = text => [
  ...new Set([...(text || '').matchAll(VARIABLE_PATTERN)].map(match => match[1])),
];

const findComponent = (components, type) =>
  (components || []).find(
    component => component.type?.toUpperCase() === type
  ) || null;

// Positional examples arrive as [[ "a", "b" ]] and named ones as
// [{ param_name, example }]; both collapse to a flat list ordered like the text.
const readExamples = (component, namedKey, positionalKey, text) => {
  const named = component?.example?.[namedKey];
  if (Array.isArray(named)) {
    const byName = new Map(named.map(item => [item.param_name, item.example]));
    return extractVariables(text).map(variable => byName.get(variable) ?? '');
  }

  const positional = component?.example?.[positionalKey];
  if (!Array.isArray(positional)) return [];

  // body_text nests one sample set per variable group; header_text does not.
  const values = Array.isArray(positional[0]) ? positional[0] : positional;
  return values.map(value => value ?? '');
};

const readButtons = components => {
  const buttons = findComponent(components, 'BUTTONS')?.buttons || [];
  return buttons.map(button => ({
    type: button.type?.toUpperCase() || 'QUICK_REPLY',
    text: button.text || '',
    // Meta returns the copy code sample under `example`; the form keeps it as
    // `code` so it does not clash with the URL button's array of samples.
    code: button.example || '',
    url: button.url || '',
    phone_number: button.phone_number || '',
  }));
};

export const templateToForm = template => {
  const components = template?.components || [];
  const header = findComponent(components, 'HEADER');
  const body = findComponent(components, 'BODY');
  const footer = findComponent(components, 'FOOTER');
  const headerFormat = header?.format?.toUpperCase() || 'TEXT';
  const isMediaHeader = headerFormat !== 'TEXT';

  return {
    name: template?.name || '',
    category: template?.category?.toUpperCase() || 'MARKETING',
    language: template?.language || 'pt_BR',
    headerFormat: header ? headerFormat : 'TEXT',
    headerText: isMediaHeader ? '' : header?.text || '',
    headerExamples: isMediaHeader
      ? []
      : readExamples(
          header,
          'header_text_named_params',
          'header_text',
          header?.text
        ),
    // The stored handle is not returned by Meta, so an edit keeps the existing
    // media unless the author uploads a new file.
    mediaHandle: '',
    mediaBlobId: '',
    mediaFileName: '',
    bodyText: body?.text || '',
    bodyExamples: readExamples(
      body,
      'body_text_named_params',
      'body_text',
      body?.text
    ),
    footerText: footer?.text || '',
    buttons: readButtons(components),
  };
};
