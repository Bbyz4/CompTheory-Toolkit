using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using System.Linq;

public class DiGraphEdgeAddPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField inputSymbol;
    [SerializeField] private TMP_InputField stackSymbol;
    [SerializeField] private TMP_InputField toPush;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button cancelButton;

    private DiGraphManager dgm;

    void Awake()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();

        if(ModelData.modelType == ModelData.ModelType.NFA)
        {
            stackSymbol.gameObject.SetActive(false);
            toPush.gameObject.SetActive(false);
        }
    }

    public void Activate(int fromID, int toID)
    {
        gameObject.SetActive(true);

        inputSymbol.text = "";
        stackSymbol.text = "";
        toPush.text = "";

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            List<string> pushList = toPush.text
                .Split(',')
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            if(dgm.ValidateEdge(fromID, toID, inputSymbol.text, stackSymbol.text, pushList))
            {
                dgm.AddEdge(
                    fromID,
                    toID,
                    inputSymbol.text,
                    stackSymbol.text,
                    pushList
                );

                gameObject.SetActive(false);   
            }
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });
    }
}
