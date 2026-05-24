import {
  Alert,
  Box,
  Button,
  CircularProgress,
  MenuItem,
  Paper,
  TextField,
  Typography,
} from '@mui/material';
import React from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  createTask,
  getTaskTypeTemplate,
  getTasks,
  updateTask,
} from '../../services/taskService';
import {
  createEmptyFormState,
  defaultTaskType,
  normalizeTaskToFormState,
  statusOptions,
  visibilityOptions,
} from './taskFormState';
import { taskTypeOptions, taskTypePanels } from './taskTypePanels';

const actionButtonSx = {
  color: 'var(--text-h)',
  borderColor: 'var(--border)',
};

const primaryButtonSx = {
  backgroundColor: 'var(--accent-dark)',
  color: 'var(--accent-contrast)',
  border: '1px solid var(--border)',
  boxShadow: 'none',
  '&:hover': {
    backgroundColor: 'var(--accent)',
    boxShadow: 'none',
  },
};

const selectMenuProps = {
  MenuProps: {
    PaperProps: {
      sx: {
        backgroundColor: 'var(--box)',
        border: '1px solid var(--border)',
        boxShadow: 'none',
      },
    },
  },
};

const selectItemSx = {
  color: 'var(--text-h)',
  '&.Mui-selected': {
    backgroundColor: 'var(--box-light)',
  },
  '&.Mui-selected:hover': {
    backgroundColor: 'var(--box-light)',
  },
  '&:hover': {
    backgroundColor: 'var(--box-light)',
  },
};

const renderOptions = (options) =>
  options.map((option) => (
    <MenuItem key={option.value} value={option.value} sx={selectItemSx}>
      {option.label}
    </MenuItem>
  ));

const TaskEditor = () => {
  const { slug } = useParams();
  const navigate = useNavigate();
  const isEditing = Boolean(slug);
  const [templates, setTemplates] = React.useState({});
  const [loading, setLoading] = React.useState(true);
  const [submitting, setSubmitting] = React.useState(false);
  const [error, setError] = React.useState('');
  const [form, setForm] = React.useState(() =>
    createEmptyFormState(defaultTaskType, null),
  );

  React.useEffect(() => {
    const loadData = async () => {
      setLoading(true);

      try {
        const entries = await Promise.all(
          taskTypeOptions.map(async ({ value }) => [
            value,
            await getTaskTypeTemplate(value),
          ]),
        );
        const nextTemplates = Object.fromEntries(entries);
        setTemplates(nextTemplates);

        if (!isEditing) {
          setForm(
            createEmptyFormState(defaultTaskType, nextTemplates[defaultTaskType]),
          );
          setError('');
          return;
        }

        const nextTasks = await getTasks();
        const task = nextTasks.find((currentTask) => currentTask.slug === slug);

        if (!task) {
          setError('Task not found.');
          return;
        }

        setForm(normalizeTaskToFormState(task));
        setError('');
      } catch (nextError) {
        setError(nextError.message);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, [isEditing, slug]);

  const currentTaskPanel = taskTypePanels[form.type] ?? taskTypePanels[defaultTaskType];
  const CurrentConfigPanel = currentTaskPanel.ConfigPanel;

  const updateFormField = (field, value) => {
    setForm((currentForm) => ({
      ...currentForm,
      [field]: value,
    }));
  };

  const handleTaskTypeChange = (event) => {
    const nextTaskType = event.target.value;
    const nextPanel = taskTypePanels[nextTaskType] ?? taskTypePanels[defaultTaskType];
    const nextTemplate = templates[nextTaskType];

    setForm((currentForm) => ({
      ...currentForm,
      type: nextTaskType,
      config:
        currentForm.type === nextTaskType
          ? currentForm.config
          : nextPanel.createInitialConfig(nextTemplate?.config_template ?? {}),
    }));
  };

  const handleSubmit = async () => {
    if (!form.title.trim() || !form.description.trim()) {
      setError('Task title and description are required.');
      return;
    }

    if (isEditing && !form.id) {
      setError('Task not found.');
      return;
    }

    setSubmitting(true);

    try {
      const payload = {
        title: form.title.trim(),
        description: form.description.trim(),
        difficulty: Number(form.difficulty),
        status: form.status,
        visibility: form.visibility,
        type: form.type,
        config: currentTaskPanel.normalizeConfig(form.config),
      };

      const savedTask = isEditing
        ? await updateTask(form.id, payload)
        : await createTask(payload);

      navigate(`/tasks/${savedTask.slug}`, {
        state: {
          successMessage: isEditing
            ? 'Task updated successfully.'
            : savedTask.status === 'DRAFT'
              ? 'Draft created successfully.'
              : 'Task created successfully.',
        },
      });
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSubmitting(false);
    }
  };

  const backTarget = isEditing && form.slug ? `/tasks/${form.slug}` : '/tasks';

  return (
    <div className="tasks">
      <Box className="task-page-header">
        <div>
          <h1>{isEditing ? 'Edit Task' : 'Create Task'}</h1>
          <Typography variant="body2" className="task-muted-copy">
            {isEditing
              ? `Editing ${form.slug || slug || 'task'}.`
              : 'Set the task data and save it when ready.'}
          </Typography>
        </div>
        <Box className="task-page-actions">
          <Button
            component={Link}
            to={backTarget}
            variant="outlined"
            sx={actionButtonSx}
          >
            Back
          </Button>
          <Button
            variant="contained"
            onClick={submitting ? undefined : handleSubmit}
            disabled={submitting || loading}
            sx={primaryButtonSx}
          >
            {isEditing ? 'Save changes' : 'Create task'}
          </Button>
        </Box>
      </Box>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Paper className="task-creator task-editor-shell" elevation={0}>
        {loading ? (
          <Box className="task-loading-state">
            <CircularProgress size={24} />
          </Box>
        ) : (
          <React.Fragment>
            <Typography variant="h5" className="task-title">
              {isEditing ? 'Task Editor' : 'New Task'}
            </Typography>

            <Box className="task-config-grid">
              <TextField
                select
                label="Task Type"
                value={form.type}
                onChange={handleTaskTypeChange}
                className="custom-textfield"
                fullWidth
                SelectProps={selectMenuProps}
              >
                {renderOptions(taskTypeOptions)}
              </TextField>

              <TextField
                label="Difficulty"
                type="number"
                value={form.difficulty}
                onChange={(event) => updateFormField('difficulty', event.target.value)}
                className="custom-textfield"
                inputProps={{ min: 0, max: 10 }}
                fullWidth
              />

              <TextField
                select
                label="Status"
                value={form.status}
                onChange={(event) => updateFormField('status', event.target.value)}
                className="custom-textfield"
                fullWidth
                SelectProps={selectMenuProps}
              >
                {renderOptions(statusOptions)}
              </TextField>
            </Box>

            <TextField
              label="Task Title"
              variant="outlined"
              fullWidth
              margin="normal"
              className="custom-textfield"
              value={form.title}
              onChange={(event) => updateFormField('title', event.target.value)}
            />

            <TextField
              label="Task Description"
              variant="outlined"
              fullWidth
              margin="normal"
              multiline
              rows={7}
              className="custom-textfield"
              value={form.description}
              onChange={(event) => updateFormField('description', event.target.value)}
            />

            <Box className="task-config-grid">
              <TextField
                select
                label="Visibility"
                value={form.visibility}
                onChange={(event) => updateFormField('visibility', event.target.value)}
                className="custom-textfield"
                fullWidth
                SelectProps={selectMenuProps}
              >
                {renderOptions(visibilityOptions)}
              </TextField>
            </Box>

            <CurrentConfigPanel
              value={form.config}
              onChange={(nextConfig) => updateFormField('config', nextConfig)}
            />

            <Box className="task-form-actions">
              <Button
                component={Link}
                to={backTarget}
                variant="outlined"
                sx={actionButtonSx}
              >
                Back
              </Button>
              <Button
                variant="contained"
                onClick={submitting ? undefined : handleSubmit}
                disabled={submitting || loading}
                sx={primaryButtonSx}
              >
                {isEditing ? 'Save changes' : 'Create task'}
              </Button>
            </Box>
          </React.Fragment>
        )}
      </Paper>
    </div>
  );
};

export default TaskEditor;
