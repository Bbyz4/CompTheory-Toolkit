using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Collections;
using UnityEngine.Networking;

public class UploadedModelDescriptor
{
    public int internalID;
    public string modelName;
    public string folderName;
    public string modelAuthor;
    public string modelDesc;
    public string modelType;

    public string modelJSONstring;
}

public class LibraryBehaviour : MonoBehaviour
{
    [SerializeField] private GameObject scrollableViewContent;
    [SerializeField] private GameObject modelsFolderPrefab;
    [SerializeField] private GameObject uploadedModelPrefab;

    [SerializeField] private GameObject gobackButtonObject;

    [SerializeField] private LibraryUploadedModelViewPanelBehaviour modelDetailsPanel;


    private List<string> folderNameList;
    private Dictionary<string, List<UploadedModelDescriptor>> uploadedModelsForGivenFolder;

    private List<UploadedModelDescriptor> GetUploadedModelsListFromBackend()
    {
        List<UploadedModelDescriptor> mockModels = new List<UploadedModelDescriptor>();

        for(int i=1; i<4; i++)
        {
            mockModels.Add(new UploadedModelDescriptor
            {
               modelName = $"NFA basic model #{i}",
               modelAuthor = "Anonymous",
               modelDesc = "This is an example model discussed during our lectures",
               modelType = "NFA",
               folderName = "NFA models",
               internalID = i 
            });

            mockModels.Add(new UploadedModelDescriptor
            {
               modelName = $"PDA basic model #{i}",
               modelAuthor = "Anonymous",
               modelDesc = "This is an example model discussed during our lectures",
               modelType = "PDA",
               folderName = "PDA models",
               internalID = i+3
            });
        }

        return mockModels;
    }

    public void RefreshUploadedModelData()
    {
        List<UploadedModelDescriptor> allModels = GetUploadedModelsListFromBackend();

        folderNameList = new List<string>();
        uploadedModelsForGivenFolder = new Dictionary<string, List<UploadedModelDescriptor>>();

        foreach(UploadedModelDescriptor model in allModels)
        {
            string key = string.IsNullOrEmpty(model.folderName) ? "Uncategorized" : model.folderName;
        
            if(!uploadedModelsForGivenFolder.ContainsKey(key))
            {
                uploadedModelsForGivenFolder.Add(key, new List<UploadedModelDescriptor>());
                folderNameList.Add(key);
            }

            uploadedModelsForGivenFolder[key].Add(model);
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
            var newFolderObj = Instantiate(modelsFolderPrefab, scrollableViewContent.transform);
        
            newFolderObj.GetComponent<LibraryFolderPrefabBehaviour>().FillData(folderName, this);
        }
    }

    public void LoadFolderContent(string folderName)
    {
        ClearScrollablePanel();
        gobackButtonObject.SetActive(true);

        foreach(UploadedModelDescriptor taskDesc in uploadedModelsForGivenFolder[folderName])
        {
            var newTaskObj = Instantiate(uploadedModelPrefab, scrollableViewContent.transform);

            newTaskObj.GetComponent<LibraryModelPrefabBehaviour>().FillData(taskDesc, modelDetailsPanel);
        }
    }

    void Awake()
    {
        modelDetailsPanel.gameObject.SetActive(false);
    }

    void OnEnable()
    {
        StartCoroutine(RefreshUploadedModelsCoroutine());
    }

    [System.Serializable]
    public class SubmissionsResponse
    {
        public List<SubmissionDto> submissions;
    }

    public class SubmissionDto
    {
        public int id;

        [JsonProperty("task_id")]
        public int taskId;

        public JObject data;

        public string verdict;

        [JsonProperty("created_at")]
        public string createdAt;

        [JsonProperty("judged_at")]
        public string judgedAt;
    }

    private IEnumerator RefreshUploadedModelsCoroutine()
    {
        using(UnityWebRequest request =
            UnityWebRequest.Get(
                "https://recognita.xyz/api/v1/submissions?scope=mine"))
        {
            request.downloadHandler = new DownloadHandlerBuffer();

            if(!string.IsNullOrEmpty(ApplicationData.accessToken))
            {
                request.SetRequestHeader(
                    "Authorization",
                    $"Bearer {ApplicationData.accessToken}");
            }

            yield return request.SendWebRequest();

            Debug.Log($"Submissions Status: {(long)request.responseCode}");
            Debug.Log(request.downloadHandler.text);

            if(request.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError(request.error);
                yield break;
            }

            BuildUploadedModelDictionary(
                request.downloadHandler.text);

            LoadFolderList();
        }
    }

    private void BuildUploadedModelDictionary(string json)
    {
        SubmissionsResponse response =
            JsonConvert.DeserializeObject<SubmissionsResponse>(json);

        folderNameList = new List<string>();
        uploadedModelsForGivenFolder =
            new Dictionary<string, List<UploadedModelDescriptor>>();

        const string folderName = "MY_SUBMITS";

        folderNameList.Add(folderName);
        uploadedModelsForGivenFolder[folderName] =
            new List<UploadedModelDescriptor>();

        foreach(SubmissionDto submission in response.submissions)
        {
            string modelType = "UNKNOWN";

            if(submission.data != null &&
            submission.data["type"] != null)
            {
                modelType =
                    submission.data["type"].ToString();
            }

            UploadedModelDescriptor model =
                new UploadedModelDescriptor
                {
                    internalID = -1,

                    modelName = $"#{submission.id}  [{submission.verdict}]",

                    folderName = folderName,

                    modelAuthor = "me",

                    modelDesc =
                        $"task_id: {submission.taskId} \nstatus: {submission.verdict}",

                    modelType = modelType,

                    modelJSONstring =
                        submission.data?.ToString(
                            Formatting.None)
                };

            uploadedModelsForGivenFolder[folderName]
                .Add(model);
        }
    }
}

