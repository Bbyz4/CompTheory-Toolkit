import { Box, IconButton, MenuItem, TextField, Typography } from '@mui/material';
import React from 'react';

export const MODEL_CONSTRUCTION_TASK_TYPE = 'MODEL_CONSTRUCTION';

const modelTypeOptions = [
  { value: 'NFA', label: 'NFA' },
  { value: 'CFG', label: 'CFG' },
  { value: 'PDA', label: 'PDA' },
  { value: 'LBA', label: 'LBA' },
  { value: 'TM', label: 'TM' },
];

const graderOptions = [
  { value: 'mock', label: 'Mock' },
  { value: 'explicit-tests', label: 'Explicit tests' },
];

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

export const ModelConstructionTaskTypePanel = ({ value, onChange }) => {
  const config = normalizeModelConstructionConfig(value);

  const updateConfig = (nextConfig) => {
    onChange(normalizeModelConstructionConfig(nextConfig));
  };

  const handleRequiredModelTypeChange = (event) => {
    updateConfig({
      ...config,
      requiredModelType: event.target.value,
    });
  };

  const handleGraderKindChange = (event) => {
    const nextKind = event.target.value;

    if (nextKind === 'explicit-tests') {
      updateConfig({
        ...config,
        grader: {
          kind: 'explicit-tests',
          tests: normalizeTests(config?.grader?.tests),
        },
      });
      return;
    }

    updateConfig({
      ...config,
      grader: {
        kind: 'mock',
      },
    });
  };

  const tests = normalizeTests(config?.grader?.tests);

  const handleTestChange = (index, nextValue) => {
    updateConfig({
      ...config,
      grader: {
        kind: 'explicit-tests',
        tests: tests.map((value, currentIndex) =>
          currentIndex === index ? nextValue : value,
        ),
      },
    });
  };

  const handleAddTest = () => {
    updateConfig({
      ...config,
      grader: {
        kind: 'explicit-tests',
        tests: [...tests, ''],
      },
    });
  };

  const handleRemoveTest = (index) => {
    updateConfig({
      ...config,
      grader: {
        kind: 'explicit-tests',
        tests: tests.filter((_, currentIndex) => currentIndex !== index),
      },
    });
  };

  return (
    <Box className="task-config-panel">
      <Typography variant="h6" className="task-section-title">
        Model Construction Config
      </Typography>

      <Box className="task-config-grid">
        <TextField
          select
          label="Required Model Type"
          value={config.requiredModelType}
          onChange={handleRequiredModelTypeChange}
          className="custom-textfield"
          SelectProps={selectMenuProps}
          fullWidth
        >
          {modelTypeOptions.map((option) => (
            <MenuItem key={option.value} value={option.value} sx={selectItemSx}>
              {option.label}
            </MenuItem>
          ))}
        </TextField>

        <TextField
          select
          label="Grader"
          value={config.grader.kind}
          onChange={handleGraderKindChange}
          className="custom-textfield"
          SelectProps={selectMenuProps}
          fullWidth
        >
          {graderOptions.map((option) => (
            <MenuItem key={option.value} value={option.value} sx={selectItemSx}>
              {option.label}
            </MenuItem>
          ))}
        </TextField>
      </Box>

      {config.grader.kind === 'explicit-tests' ? (
        <Box className="task-explicit-tests">
          <Box className="task-explicit-tests-header">
            <Typography variant="body2" sx={{ color: 'var(--text)' }}>
              Explicit tests
            </Typography>
            <IconButton
              size="small"
              onClick={handleAddTest}
              sx={{ color: 'var(--accent)' }}
            >
              <Typography component="span" sx={{ fontSize: '1rem', lineHeight: 1 }}>
                +
              </Typography>
            </IconButton>
          </Box>

          {tests.length === 0 ? (
            <Typography variant="body2" className="task-muted-copy">
              No explicit tests added yet.
            </Typography>
          ) : (
            tests.map((testValue, index) => (
              <Box key={`explicit-test-${index}`} className="task-explicit-test-row">
                <TextField
                  label={`Test ${index + 1}`}
                  value={testValue}
                  onChange={(event) => handleTestChange(index, event.target.value)}
                  placeholder="Single word"
                  className="custom-textfield"
                  fullWidth
                />
                <IconButton
                  size="small"
                  onClick={() => handleRemoveTest(index)}
                  sx={{ color: 'var(--text)' }}
                >
                  <Typography component="span" sx={{ fontSize: '1rem', lineHeight: 1 }}>
                    ×
                  </Typography>
                </IconButton>
              </Box>
            ))
          )}
        </Box>
      ) : null}
    </Box>
  );
};
