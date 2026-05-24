using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class DiGraphNodeEditPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField nodeName;
    [SerializeField] private Toggle isStarting;
    [SerializeField] private Toggle isAccepting;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button deleteButton;
    [SerializeField] private Button cancelButton;

    private DiGraphManager dgm;

    void Awake()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();
    }

    public void Activate(DiGraphNodeData node)
    {
        gameObject.SetActive(true);

        nodeName.text = node.nodeName;
        isStarting.isOn = node.isStarting;
        isAccepting.isOn = node.isAccepting;

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            node.nodeName = nodeName.text;
            node.isStarting = isStarting.isOn;
            node.isAccepting = isAccepting.isOn;

            node.GetComponent<DiGraphNodeDisplay>().UpdateDisplay();

            gameObject.SetActive(false);
        });

        deleteButton.onClick.RemoveAllListeners();

        deleteButton.onClick.AddListener(() =>
        {
            dgm.RemoveNode(node); 

            gameObject.SetActive(false);
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });
    }
}
