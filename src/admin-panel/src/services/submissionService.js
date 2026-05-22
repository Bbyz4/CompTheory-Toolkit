import { request } from './apiClient';

const mapSubmission = (submission) => ({
  id: submission.id,
  taskId: submission.task_id,
  userId: submission.user_id,
  verdict: submission.verdict,
  createdAt: submission.created_at,
  judgedAt: submission.judged_at,
});

export const getSubmissions = async () => {
  const payload = await request('/submissions');
  return (payload?.submissions ?? []).map(mapSubmission);
};
