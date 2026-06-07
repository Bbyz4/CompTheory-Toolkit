import {
  ModelConstructionTaskTypePanel,
} from './modelConstructionTaskType';
import {
  createModelConstructionConfig,
  MODEL_CONSTRUCTION_TASK_TYPE,
  normalizeModelConstructionConfig,
} from './modelConstructionTaskConfig';

export const taskTypePanels = {
  [MODEL_CONSTRUCTION_TASK_TYPE]: {
    label: 'Model construction',
    createInitialConfig: createModelConstructionConfig,
    normalizeConfig: normalizeModelConstructionConfig,
    ConfigPanel: ModelConstructionTaskTypePanel,
  },
};

export const taskTypeOptions = Object.entries(taskTypePanels).map(
  ([value, panel]) => ({
    value,
    label: panel.label,
  }),
);
