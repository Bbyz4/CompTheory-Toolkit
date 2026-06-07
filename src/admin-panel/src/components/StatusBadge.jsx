const statusTone = (value = '') => {
  const normalized = String(value).toLowerCase();

  if (
    ['accepted', 'published', 'public', 'active', 'verified', 'admin', 'yes'].includes(
      normalized,
    )
  ) {
    return 'success';
  }

  if (['pending', 'draft', 'unlisted'].includes(normalized)) {
    return 'warning';
  }

  if (
    ['rejected', 'invalid_format', 'internal_error', 'archived', 'private', 'banned', 'no'].includes(
      normalized,
    )
  ) {
    return 'danger';
  }

  if (['user', 'model_construction'].includes(normalized)) {
    return 'info';
  }

  return 'neutral';
};

const labelFor = (value) =>
  String(value ?? 'N/A')
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());

const StatusBadge = ({ value, tone }) => (
  <span className={`status-badge is-${tone ?? statusTone(value)}`}>
    {labelFor(value)}
  </span>
);

export default StatusBadge;
