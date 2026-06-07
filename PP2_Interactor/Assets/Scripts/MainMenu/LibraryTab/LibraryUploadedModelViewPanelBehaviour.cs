using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class LibraryUploadedModelViewPanelBehaviour : MonoBehaviour
{
    private TMP_Text modelTitleText;
    private TMP_Text modelAuthorText;
    private TMP_Text modelDescText;
    private Button editModelButton;
    private Button goBackButton;

    void Awake()
    {
        modelTitleText = transform.Find("ModelTitle").GetComponent<TMP_Text>();
        modelAuthorText = transform.Find("ModelAuthor").GetComponent<TMP_Text>();
        modelDescText = transform.Find("ModelDescription").GetComponent<TMP_Text>();
        editModelButton = transform.Find("GoToAutomataButton").GetComponent<Button>();
        goBackButton = transform.Find("GoBackButton").GetComponent<Button>();
    }

    public void FillData(UploadedModelDescriptor modelDesc)
    {
        modelTitleText.text = modelDesc.modelName;
        modelAuthorText.text = modelDesc.modelAuthor;
        modelDescText.text = modelDesc.modelDesc;

        goBackButton.onClick.RemoveAllListeners();
        goBackButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });

        editModelButton.onClick.RemoveAllListeners();
        editModelButton.onClick.AddListener(() =>
        {
            string JSONModelForm = LibraryModelObtainer.LoadJSONFileForModel(modelDesc);
            ModelData.preopenFromJSON = true;
            ModelData.JSONFile = JSONModelForm;

            switch(modelDesc.modelType)
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
    }
}