using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class DiGraphNodeAddPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField nodeName;
    [SerializeField] private Toggle isStarting;
    [SerializeField] private Toggle isAccepting;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button cancelButton;

    private DiGraphManager dgm;

    void Awake()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();
    }

    public void Activate(Vector2 clickedPosition)
    {
        gameObject.SetActive(true);

        nodeName.text = "";
        isStarting.isOn = false;
        isAccepting.isOn = false;

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            dgm.AddNode(
                clickedPosition,
                nodeName.text,
                isStarting.isOn,
                isAccepting.isOn
            );

            gameObject.SetActive(false);
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });
    }
}
