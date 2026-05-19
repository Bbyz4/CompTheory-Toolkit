using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LibraryFolderPrefabBehaviour : MonoBehaviour
{
    private TMP_Text taskTitleText;
    private Button taskOpenButton;

    void Awake()
    {
        taskTitleText = transform.Find("Title").GetComponent<TMP_Text>();
        taskOpenButton = transform.Find("OpenButton").GetComponent<Button>();
    }

    public void FillData(string folderName, LibraryBehaviour listParent)
    {
        taskTitleText.text = folderName;
        taskOpenButton.onClick.RemoveAllListeners();

        taskOpenButton.onClick.AddListener(() =>
        {
           listParent.LoadFolderContent(folderName);
        });
    }
}