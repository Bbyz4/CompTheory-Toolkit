export const MODEL_CONSTRUCTION_TASK_TYPE = 'MODEL_CONSTRUCTION';

const normalizeTests = (tests) => {
  if (!Array.isArray(tests)) {
    return [];
  }

  return tests
    .filter((value) => typeof value === 'string')
    .map((value) => value);
};

export const normalizeModelConstructionConfig = (config = {}) => {
  const requiredModelType =
    typeof config?.requiredModelType === 'string' &&
    config.requiredModelType.trim()
      ? config.requiredModelType
      : 'NFA';
  const graderKind =
    config?.grader?.kind === 'explicit-tests' ? 'explicit-tests' : 'mock';

  if (graderKind === 'explicit-tests') {
    return {
      requiredModelType,
      grader: {
        kind: 'explicit-tests',
        tests: normalizeTests(config?.grader?.tests),
      },
    };
  }

  return {
    requiredModelType,
    grader: {
      kind: 'mock',
    },
  };
};

export const createModelConstructionConfig = (template) =>
  normalizeModelConstructionConfig(template);
