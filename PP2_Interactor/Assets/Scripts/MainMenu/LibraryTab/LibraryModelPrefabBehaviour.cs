using TMPro;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class LibraryModelPrefabBehaviour : MonoBehaviour
{
    private TMP_Text modelTitleText;
    private Button modelOpenButton;

    void Awake()
    {
        modelTitleText = transform.Find("Title").GetComponent<TMP_Text>();
        modelOpenButton = transform.Find("OpenButton").GetComponent<Button>();
    }

    public void FillData(UploadedModelDescriptor modelDesc, LibraryUploadedModelViewPanelBehaviour detailPanel)
    {
        modelTitleText.text = modelDesc.modelName;

        modelOpenButton.onClick.RemoveAllListeners();

        modelOpenButton.onClick.AddListener(() =>
        {
           detailPanel.gameObject.SetActive(true);
           detailPanel.FillData(modelDesc); 
        });
    }
}