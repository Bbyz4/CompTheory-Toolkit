import { taskTypeOptions, taskTypePanels } from './taskTypePanels';

export const defaultTaskType = taskTypeOptions[0]?.value ?? 'MODEL_CONSTRUCTION';

export const statusOptions = [
  { value: 'DRAFT', label: 'Draft' },
  { value: 'PUBLISHED', label: 'Published' },
  { value: 'ARCHIVED', label: 'Archived' },
];

export const visibilityOptions = [
  { value: 'PRIVATE', label: 'Private' },
  { value: 'UNLISTED', label: 'Unlisted' },
  { value: 'PUBLIC', label: 'Public' },
];

export const createEmptyFormState = (taskType, template) => {
  const taskPanel = taskTypePanels[taskType];

  return {
    id: null,
    title: '',
    slug: '',
    description: '',
    difficulty: 0,
    status: 'DRAFT',
    visibility: 'PRIVATE',
    type: taskType,
    config: taskPanel.createInitialConfig(template?.config_template ?? {}),
  };
};

export const normalizeTaskToFormState = (task) => {
  const taskPanel = taskTypePanels[task.type] ?? taskTypePanels[defaultTaskType];

  return {
    id: task.id,
    title: task.title ?? '',
    slug: task.slug ?? '',
    description: task.description ?? '',
    difficulty: Number(task.difficulty ?? 0),
    status: task.status ?? 'DRAFT',
    visibility: task.visibility ?? 'PRIVATE',
    type: task.type ?? defaultTaskType,
    config: taskPanel.normalizeConfig(task.config ?? {}),
  };
};
