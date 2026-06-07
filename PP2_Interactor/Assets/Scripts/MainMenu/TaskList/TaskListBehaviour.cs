using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

public class TaskDescriptor
{
    public string taskName;
    public string taskDescription;
    public string folderName;
    public bool isDone;
    public string automatonType;

    public int taskID;
}

public class TaskListBehaviour : MonoBehaviour
{
    [SerializeField] private GameObject scrollableViewContent;
    [SerializeField] private GameObject taskFolderPrefab;
    [SerializeField] private GameObject taskPrefab;

    [SerializeField] private GameObject gobackButtonObject;


    [SerializeField] private TaskDetailsViewPanelBehaviour taskDetailsPanel;



    //for efficient displaying
    private List<string> folderNameList;
    private Dictionary<string, List<TaskDescriptor>> tasksForGivenFolder; 

    //right now mocked
    private List<TaskDescriptor> GetTaskListFromBackend()
    {
        List<TaskDescriptor> mockTasks = new List<TaskDescriptor>();

        for(int i=1; i<4; i++)
        {
            mockTasks.Add(new TaskDescriptor{
                taskName = $"NFA beginner's task #{i}",
                taskDescription = "This is a very beginner friendly task about creating an automaton for a given regular language",
                folderName = "NFA Set #1",
                isDone = false,
                automatonType = "NFA"
            });

            mockTasks.Add(new TaskDescriptor{
                taskName = $"PDA beginner's task #{i}",
                taskDescription = "This is a very beginner friendly task about creating an automaton for a given context-free language",
                folderName = "PDA Set #1",
                isDone = false,
                automatonType = "PDA"
            });
        }

        return mockTasks;
    }

    public void RefreshTaskData()
    {
        List<TaskDescriptor> allTasks = GetTaskListFromBackend();

        folderNameList = new List<string>();
        tasksForGivenFolder = new Dictionary<string, List<TaskDescriptor>>();

        foreach(TaskDescriptor task in allTasks)
        {
            string key = string.IsNullOrEmpty(task.folderName) ? "Uncategorized" : task.folderName;

            if(!tasksForGivenFolder.ContainsKey(key))
            {
                tasksForGivenFolder.Add(key, new List<TaskDescriptor>());
                folderNameList.Add(key);
            }

            tasksForGivenFolder[key].Add(task);
        }
    }

    public void ClearScrollablePanel()
    {
        foreach (Transform child in scrollableViewContent.transform)
        {
            Destroy(child.gameObject);
        }
    }

    public void LoadFolderList()
    {
        ClearScrollablePanel();
        gobackButtonObject.SetActive(false);

        foreach(string folderName in folderNameList)
        {
            var newFolderObj = Instantiate(taskFolderPrefab, scrollableViewContent.transform);
        
            newFolderObj.GetComponent<TaskFolderPrefabBehaviour>().FillData(folderName, this);
        }
    }

    public void LoadFolderContent(string folderName)
    {
        ClearScrollablePanel();
        gobackButtonObject.SetActive(true);

        foreach(TaskDescriptor taskDesc in tasksForGivenFolder[folderName])
        {
            var newTaskObj = Instantiate(taskPrefab, scrollableViewContent.transform);

            newTaskObj.GetComponent<TaskPrefabBehaviour>().FillData(taskDesc, taskDetailsPanel);
        }
    }

    void Awake()
    {
        taskDetailsPanel.gameObject.SetActive(false);
    }

    void OnEnable()
    {
        StartCoroutine(RefreshTaskDataCoroutine());
    }

    [System.Serializable]
    public class TasksResponse
    {
        public List<ApiTask> tasks;
    }

    [System.Serializable]
    public class ApiTask
    {
        public int id;
        public string title;
        public string short_description;
        public string description;
        public string type;
        public int difficulty;
        public TaskConfig config;
    }

    [System.Serializable]
    public class TaskConfig
    {
        public GraderConfig grader;
        public string requiredModelType;
    }

    [System.Serializable]
    public class GraderConfig
    {
        public string kind;
    }

    private IEnumerator RefreshTaskDataCoroutine()
    {
        using(UnityWebRequest request =
            UnityWebRequest.Get("https://recognita.xyz/api/v1/tasks"))
        {
            request.downloadHandler = new DownloadHandlerBuffer();

            if(!string.IsNullOrEmpty(ApplicationData.accessToken))
            {
                request.SetRequestHeader(
                    "Authorization",
                    $"Bearer {ApplicationData.accessToken}"
                );
            }

            yield return request.SendWebRequest();

            Debug.Log($"Tasks Status: {(long)request.responseCode}");
            Debug.Log(request.downloadHandler.text);

            if(request.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError(request.error);
                yield break;
            }

            TasksResponse response =
                JsonUtility.FromJson<TasksResponse>(
                    request.downloadHandler.text
                );

            BuildTaskDictionary(response.tasks);

            LoadFolderList();
        }
    }

    private void BuildTaskDictionary(List<ApiTask> apiTasks)
    {
        folderNameList = new List<string>();
        tasksForGivenFolder = new Dictionary<string, List<TaskDescriptor>>();

        const string folderName = "MO 2025/26";

        folderNameList.Add(folderName);
        tasksForGivenFolder[folderName] = new List<TaskDescriptor>();

        foreach(ApiTask apiTask in apiTasks)
        {
            TaskDescriptor task = new TaskDescriptor
            {
                taskName = apiTask.title,
                taskDescription =
                    !string.IsNullOrEmpty(apiTask.short_description)
                        ? apiTask.short_description
                        : apiTask.description,

                folderName = folderName,
                isDone = false,

                automatonType =
                    apiTask.config != null
                    ? apiTask.config.requiredModelType
                    : "UNKNOWN",

                taskID = apiTask.id
            };

            tasksForGivenFolder[folderName].Add(task);
        }
    }
}
