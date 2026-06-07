using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using System.Collections;
using System.IO;
using System.Text;
using UnityEngine.Networking;
using SimpleFileBrowser;

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
        taksDescText.text = $"REQUIRED AUTOMATON TYPE: {taskDesc.automatonType} \n\n {taskDesc.taskDescription}";

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
                case "CFG":
                    ModelData.modelType = ModelData.ModelType.CFG;
                    SceneManager.LoadScene("CFGEditor");
                    break;
                case "TM":
                    ModelData.modelType = ModelData.ModelType.TM;
                    SceneManager.LoadScene("TMEditor");
                    break;
                default:
                    Debug.LogError("Automaton type not supported yet");
                    break;
            }
        });

        uploadSolutionButton.onClick.RemoveAllListeners();
        uploadSolutionButton.onClick.AddListener(() =>
        {
            FileBrowser.ShowLoadDialog(
                (paths) =>
                {
                    if(paths == null || paths.Length == 0)
                        return;

                    StartCoroutine(
                        UploadSubmissionCoroutine(
                            taskDesc.taskID,
                            paths[0]
                        )
                    );
                },
                () => { },
                FileBrowser.PickMode.Files,
                false,
                Application.persistentDataPath,
                null,
                "json"
            );
        });
    }

    private IEnumerator UploadSubmissionCoroutine(
        int taskId,
        string jsonFilePath)
    {
        string automatonJson = File.ReadAllText(jsonFilePath);

        string requestBody = $@"
        {{
            ""data"": {automatonJson}
        }}";

        byte[] bodyRaw = Encoding.UTF8.GetBytes(requestBody);

        string url =
            $"https://recognita.xyz/api/v1/tasks/{taskId}/submissions";

        using(UnityWebRequest request =
            new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST))
        {
            request.uploadHandler = new UploadHandlerRaw(bodyRaw);
            request.downloadHandler = new DownloadHandlerBuffer();

            request.SetRequestHeader(
                "Content-Type",
                "application/json");

            if(!string.IsNullOrEmpty(ApplicationData.accessToken))
            {
                request.SetRequestHeader(
                    "Authorization",
                    $"Bearer {ApplicationData.accessToken}");
            }

            yield return request.SendWebRequest();

            Debug.Log($"Submission status: {(long)request.responseCode}");
            Debug.Log(request.downloadHandler.text);

            if(request.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError(
                    $"Submission failed: {request.error}");
            }
            else
            {
                Debug.Log("Submission uploaded successfully");
            }
        }
    }
}
