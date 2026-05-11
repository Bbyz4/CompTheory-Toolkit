const basePath = '/api/v1/tasks'; 

export const getTasks = async () => 
  fetch(basePath).then((data) => data.json()).catch((error) => {
    console.error('Error fetching tasks:', error);
    return [];
  });

export const createTask = async (taskData) =>
  fetch(basePath, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(taskData),
  }).then((data) => data.json()).catch((error) => {
    console.error('Error creating task:', error);
    return null;
  });
