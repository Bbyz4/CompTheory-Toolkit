using System.Collections.Generic;
using UnityEngine;

public class TaskDescriptor
{
    public string taskName;
    public string taskDescription;
    public string folderName;
    public bool isDone;
    public string automatonType;
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

        RefreshTaskData();
        LoadFolderList();
    }
}
