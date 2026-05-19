using System.Collections.Generic;
using UnityEngine;

public class UploadedModelDescriptor
{
    public int internalID;
    public string modelName;
    public string folderName;
    public string modelAuthor;
    public string modelDesc;
    public string modelType;
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

        RefreshUploadedModelData();
        LoadFolderList();
    }

}

