import { request } from './apiClient';

const TASK_TYPE = 'MODEL_CONSTRUCTION';

const mapTask = (task) => ({
  id: task.id,
  title: task.title,
  slug: task.slug,
  description: task.description,
  shortDescription: task.short_description,
  status: task.status,
  visibility: task.visibility,
  createdAt: task.created_at,
  updatedAt: task.updated_at,
  publishedAt: task.published_at,
  difficulty: task.difficulty,
  type: task.type,
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

export const createTask = async ({ title, description }) => {
  const templatePayload = await request(
    `/task-types/${TASK_TYPE}/config-template`,
  );

  const payload = await request('/tasks', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      title,
      description,
      short_description: shortDescription(description),
      type: TASK_TYPE,
      difficulty: 0,
      config: templatePayload?.config_template ?? {},
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
    }),
  });

  return mapTask(payload.task);
};
