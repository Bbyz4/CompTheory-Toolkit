using TMPro;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.UI;

public class TaskPrefabBehaviour : MonoBehaviour
{
    private TMP_Text taskTitleText;
    private Button taskOpenButton;

    void Awake()
    {
        taskTitleText = transform.Find("Title").GetComponent<TMP_Text>();
        taskOpenButton = transform.Find("OpenButton").GetComponent<Button>();
    }

    public void FillData(TaskDescriptor taskDesc, TaskDetailsViewPanelBehaviour detailPanel)
    {
        taskTitleText.text = taskDesc.taskName.Length > 15
            ? taskDesc.taskName.Substring(0, 15) + "..."
            : taskDesc.taskName;

        taskOpenButton.onClick.RemoveAllListeners();

        taskOpenButton.onClick.AddListener(() =>
        {
            detailPanel.gameObject.SetActive(true);
            detailPanel.FillData(taskDesc);
        });
    }
}
