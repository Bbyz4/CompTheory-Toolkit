using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;


public class FreeRunManager : MonoBehaviour
{
    private class StepDescription
    {
        public string readWordText;
        public DiGraphNodeData currentNode;
        public List<string> currentStackContent;
    };

    [SerializeField] private GameObject stepListContent;
    [SerializeField] private TMP_Text readWordText;
    [SerializeField] private TMP_Text stackText;
    [SerializeField] private GameObject freeRunStepPrefab;

    [SerializeField] private GameObject walkerPrefab;
    private GameObject walker;
    [SerializeField] private Vector3 walkerOffset;

    private DiGraphNodeData currentNode;
    private List<string> currentStackContent;
    private int currentStepID;

    private string epsilon = "ε";

    private DiGraphManager dgm;

    private List<StepDescription> stepHistory;

    void Awake()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();
    }

    public void Initialize()
    {
        var V = dgm.GetV();

        foreach(DiGraphNodeData v in V.Values)
        {
            if(v.isStarting)
            {
                currentNode = v;
                break;
            }
        }

        currentStackContent = new List<string>();
        currentStackContent.Add(dgm.GetStartingStackSymbol());

        currentStepID = 0;

        foreach(Transform child in stepListContent.transform)
        {
            Destroy(child.gameObject);
        }

        readWordText.text = "";
        stackText.text = currentStackContent.First();

        if(walker != null)
        {
            Destroy(walker);
        }

        walker = Instantiate(walkerPrefab);

        walker.transform.position = currentNode.gameObject.transform.position + walkerOffset;

        stepHistory = new List<StepDescription>();

        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"0: {currentNode.nodeName}";

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(0);});

        if(ModelData.modelType == ModelData.ModelType.NFA)
        {
            stackText.transform.parent.gameObject.SetActive(false);
        }
    }

    public void HandleEdgeClick(DiGraphEdgeData edge)
    {
        if(edge.begin != currentNode)
        {
            return;
        }

        if(ModelData.modelType == ModelData.ModelType.PDA && (currentStackContent.Count == 0 || currentStackContent[0] != edge.stackSymbol))
        {
            return;
        }

        currentStepID++;

        if(ModelData.modelType == ModelData.ModelType.PDA)
        {
            currentStackContent.RemoveAt(0);

            for(int i = 0; i<edge.toPush.Count; i++)
            {
                currentStackContent.Insert(0, edge.toPush[i]);
            }   
        }

        currentNode = edge.end;

        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        if(ModelData.modelType == ModelData.ModelType.PDA)
        {
            newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"{currentStepID}. ({(edge.inputSymbol != "" ? edge.inputSymbol :  epsilon)},{(edge.stackSymbol != "" ? edge.stackSymbol :  epsilon)}): {edge.begin.nodeName} -> {edge.end.nodeName}";
        }
        else
        {
            newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"{currentStepID}. ({(edge.inputSymbol != "" ? edge.inputSymbol :  epsilon)},): {edge.begin.nodeName} -> {edge.end.nodeName}";
        }

        int capturedStep = currentStepID;

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(capturedStep);});

        UpdateUI(edge.inputSymbol);

        stepHistory.Add(new StepDescription
        {
           readWordText = readWordText.text,
           currentNode = currentNode,
           currentStackContent = new List<string>(currentStackContent),
        });
    }

    private void UpdateUI(string inputSymbol)
    {
        if(!string.IsNullOrEmpty(inputSymbol))
        {
            readWordText.text += inputSymbol;
        }

        if(currentStackContent.Count > 0)
        {
            stackText.text = string.Join("\n", currentStackContent);
        }
        else
        {
            stackText.text = "";
        }

        walker.transform.position = currentNode.gameObject.transform.position + walkerOffset;
    }

    public void CleanUp()
    {
        Destroy(walker);
    }

    private void ComeBackToStep(int stepID)
    {
        if(stepID >= currentStepID)
        {
            return;
        }

        for (int i = stepListContent.transform.childCount - 1; i >= stepID + 1; i--)
        {
            Destroy(stepListContent.transform.GetChild(i).gameObject);
        }

        currentStepID = stepID;
        
        if (stepID == 0)
        {
            Initialize();
        }
        else
        {
            int historyIndex = stepID - 1;
            readWordText.text = stepHistory[historyIndex].readWordText;
            currentNode = stepHistory[historyIndex].currentNode;
            currentStackContent = stepHistory[historyIndex].currentStackContent;

            while(stepHistory.Count > currentStepID)
            {
                stepHistory.RemoveAt(stepHistory.Count - 1);
            }
        }
        
        UpdateUI(null);
    }
}
