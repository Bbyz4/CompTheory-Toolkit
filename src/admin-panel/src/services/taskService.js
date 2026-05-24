import { request } from './apiClient';

const TASK_TYPE = 'MODEL_CONSTRUCTION';

const mapTask = (task) => ({
  id: task.id,
  title: task.title,
  slug: task.slug,
  description: task.description,
  shortDescription: task.short_description,
  config: task.config ?? {},
  status: task.status,
  visibility: task.visibility,
  createdAt: task.created_at,
  updatedAt: task.updated_at,
  publishedAt: task.published_at,
  difficulty: task.difficulty,
  type: task.type,
  authorId: task.author_id,
});

const shortDescription = (description) => {
  const trimmed = description.trim();

  if (!trimmed) {
    return null;
  }

  return trimmed.slice(0, 140);
};

export const getTasks = async () => {
  const payload = await request('/tasks');
  return (payload?.tasks ?? []).map(mapTask);
};

export const getTaskTypeTemplate = async (taskType = TASK_TYPE) => {
  return request(`/task-types/${taskType}/config-template`);
};

const buildTaskPayload = ({
  title,
  slug,
  description,
  shortDescription: nextShortDescription,
  type = TASK_TYPE,
  difficulty = 0,
  config,
  status = 'PUBLISHED',
  visibility = 'PUBLIC',
}) => ({
  title,
  slug: slug?.trim() ? slug.trim() : null,
  description,
  short_description: nextShortDescription ?? shortDescription(description),
  type,
  difficulty,
  config,
  status,
  visibility,
});

export const createTask = async (task) => {
  const payload = await request('/tasks', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(buildTaskPayload(task)),
  });

  return mapTask(payload.task);
};

export const updateTask = async (taskId, task) => {
  const payload = await request(`/tasks/${taskId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(buildTaskPayload(task)),
  });

  return mapTask(payload.task);
};
