using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using System.Linq;

public class DiGraphEdgeEditPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField inputSymbol;
    [SerializeField] private TMP_InputField stackSymbol;
    [SerializeField] private TMP_InputField toPush;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button deleteButton;
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

    public void Activate(DiGraphEdgeData edge)
    {
        gameObject.SetActive(true);

        inputSymbol.text = edge.inputSymbol;
        stackSymbol.text = edge.stackSymbol;
        toPush.text = "";

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            List<string> pushList = toPush.text
                .Split(',')
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            
            if(dgm.ValidateEdge(edge.begin.internalID, edge.end.internalID, inputSymbol.text, stackSymbol.text, pushList))
            {
                edge.inputSymbol = inputSymbol.text;
                edge.stackSymbol = stackSymbol.text;
                edge.toPush = pushList;

                edge.GetComponent<DiGraphEdgeDisplay>().UpdateDisplay();

                gameObject.SetActive(false);
            }
        });

        deleteButton.onClick.RemoveAllListeners();

        deleteButton.onClick.AddListener(() =>
        {
            dgm.RemoveEdge(edge);

            gameObject.SetActive(false);
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });
    }
}
