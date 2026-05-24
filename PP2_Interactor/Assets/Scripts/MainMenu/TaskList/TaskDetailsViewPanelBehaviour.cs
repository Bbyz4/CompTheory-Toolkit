using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class TaskDetailsViewPanelBehaviour : MonoBehaviour
{
    private TMP_Text taskTitleText;
    private TMP_Text taksDescText;
    private Button goToAutomataButton;
    private Button uploadSolutionButton;
    private Button goBackButton;

    void Awake()
    {
        goBackButton = transform.Find("GoBackButton").GetComponent<Button>();
        uploadSolutionButton = transform.Find("UploadSolutionButton").GetComponent<Button>();
        goToAutomataButton = transform.Find("GoToAutomataButton").GetComponent<Button>();

        taskTitleText = transform.Find("TaskTitle").GetComponent<TMP_Text>();
        taksDescText = transform.Find("TaskDescription").GetComponent<TMP_Text>();
    }

    public void FillData(TaskDescriptor taskDesc)
    {
        taskTitleText.text = taskDesc.taskName;
        taksDescText.text = taskDesc.taskDescription;

        goBackButton.onClick.RemoveAllListeners();
        goBackButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });

        goToAutomataButton.onClick.RemoveAllListeners();
        goToAutomataButton.onClick.AddListener(() =>
        {
            switch(taskDesc.automatonType)
            {
                case "PDA":
                    ModelData.modelType = ModelData.ModelType.PDA;
                    SceneManager.LoadScene("DiGraphEditor");
                    break;
                case "NFA":
                    ModelData.modelType = ModelData.ModelType.NFA;
                    SceneManager.LoadScene("DiGraphEditor");
                    break;
                default:
                    Debug.LogError("Automaton type not supported yet");
                    break;
            }
        });

        uploadSolutionButton.onClick.RemoveAllListeners();
        uploadSolutionButton.onClick.AddListener(() =>
        {
            //This for now will only work in the unity editor

            #if UNITY_EDITOR

            string path = EditorUtility.OpenFilePanel("Select JSON file", Application.persistentDataPath, "json");

            if(!string.IsNullOrEmpty(path))
            {
                Debug.Log("Here, solution would be sent to the backend and we would wait for response");
            }

            #endif
        });
    }
}
