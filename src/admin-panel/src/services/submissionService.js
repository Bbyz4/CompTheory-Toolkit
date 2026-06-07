import { request } from './apiClient';

const mapSubmission = (submission) => ({
  id: submission.id,
  taskId: submission.task_id,
  userId: submission.user_id,
  data: submission.data ?? {},
  verdict: submission.verdict,
  runData: submission.run_data,
  createdAt: submission.created_at,
  judgedAt: submission.judged_at,
});

export const getSubmissions = async () => {
  const payload = await request('/submissions');
  return (payload?.submissions ?? []).map(mapSubmission);
};

export const getSubmission = async (submissionId) => {
  const payload = await request(`/submissions/${submissionId}`);
  return mapSubmission(payload.submission);
};
