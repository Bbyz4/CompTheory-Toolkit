using TMPro;
using UnityEngine;

public class DiGraphNodeDisplay : MonoBehaviour
{
    private DiGraphNodeData nodeData;

    private TMP_Text nodeName;
    private GameObject startingInd;
    private GameObject acceptingInd;
    private GameObject selectionHull;


    void Awake()
    {
        nodeData = gameObject.GetComponent<DiGraphNodeData>();
    
        nodeName = transform.Find("Label").GetComponent<TMP_Text>();
        startingInd = transform.Find("StartingIndicator").gameObject;
        acceptingInd = transform.Find("FinishingIndicator").gameObject;
        selectionHull = transform.Find("Hull").gameObject;

        Deselect();
    }

    public void UpdateDisplay()
    {
        nodeName.text = nodeData.nodeName;
        startingInd.SetActive(nodeData.isStarting);
        acceptingInd.SetActive(nodeData.isAccepting);
    }

    public void Select()
    {
        selectionHull.SetActive(true);
    }

    public void Deselect()
    {
        selectionHull.SetActive(false);
    }
}
