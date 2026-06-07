using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class TaskFolderPrefabBehaviour : MonoBehaviour
{
    private TMP_Text taskTitleText;
    private Button taskOpenButton;

    void Awake()
    {
        taskTitleText = transform.Find("Title").GetComponent<TMP_Text>();
        taskOpenButton = transform.Find("OpenButton").GetComponent<Button>();
    }

    public void FillData(string folderName, TaskListBehaviour listParent)
    {
        taskTitleText.text = folderName.Length > 15
            ? folderName.Substring(0, 15) + "..."
            : folderName;

        taskOpenButton.onClick.RemoveAllListeners();

        taskOpenButton.onClick.AddListener(() =>
        {
           listParent.LoadFolderContent(folderName);
        });
    }
}
