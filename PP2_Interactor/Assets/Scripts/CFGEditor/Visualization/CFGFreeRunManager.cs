using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;


public class CFGFreeRunManager : MonoBehaviour
{
    private class StepDescription
    {
        public List<string> wordState;
        public List<int> expansionIDs;
        public int largestFreeID;
    }

    [SerializeField] private GameObject stepListContent;
    [SerializeField] private GameObject freeRunStepPrefab;
    [SerializeField] private GameObject currentStateContent;
    [SerializeField] private GameObject letterPrefab;

    private CFGManager cfgm;

    private List<StepDescription> stepHistory;

    private List<string> currentWordState;
    private List<int> currentExpansionIDs;
    private int currentLargestFreeID;
    private int currentStepID;

    void Awake()
    {
        cfgm = GameObject.FindWithTag("CFGManager").GetComponent<CFGManager>();
    }

    public void Initialize()
    {
        CleanUp();

        string startSymbol = cfgm.GetStartSymbol();

        stepHistory = new List<StepDescription>();

        currentStepID = 0;

        currentWordState = new List<string>(){startSymbol};
        currentExpansionIDs = new List<int>(){0};
        currentLargestFreeID = 1;

        GameObject letterObj = Instantiate(letterPrefab, currentStateContent.transform);
    
        letterObj.transform.GetChild(0).GetComponent<TMP_Text>().text = startSymbol;

        letterObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        letterObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ChooseSymbolID(0);});
    
        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"0: {startSymbol}";

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(0);});
    }


    private bool isProductionChosen;
    private bool isSymbolChosen;
    private string chosenProductionFrom;
    private List<string> chosenProductionOutput;
    private int chosenSymbolID;

    public void ChooseProduction(string from, List<string> output)
    {
        chosenProductionFrom = from;
        chosenProductionOutput = output;
        isProductionChosen = true;

        if(isSymbolChosen)
        {
            ApplyNewTransition();
        }
    }

    public void ChooseSymbolID(int symbolID)
    {
        Debug.Log($"CFG FRM: Symbol with ID {symbolID} chosen!");

        if(symbolID < 0)
        {
            return;
        }

        chosenSymbolID = symbolID;
        isSymbolChosen = true;

        if(isProductionChosen)
        {
            ApplyNewTransition();
        }
    }

    private void ApplyNewTransition()
    {
        isSymbolChosen = false;
        isProductionChosen = false;

        List<string> nonTerminals = cfgm.GetNonTerminals();

        int transitionListIndex = currentExpansionIDs.IndexOf(chosenSymbolID);

        if(currentWordState[transitionListIndex] != chosenProductionFrom)
        {
            return;
        }

        stepHistory.Add(new StepDescription
        {
           wordState = currentWordState,
           expansionIDs = currentExpansionIDs,
           largestFreeID = currentLargestFreeID 
        });

        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        currentStepID++;
        int capturedStepID = currentStepID;

        newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"{capturedStepID}: {chosenProductionFrom}";

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(capturedStepID);});

        currentWordState.RemoveAt(transitionListIndex);
        currentExpansionIDs.RemoveAt(transitionListIndex);

        for(int i=chosenProductionOutput.Count - 1; i>=0; i--)
        {
            string prodOutputSymbol = chosenProductionOutput[i];

            int pushedID;

            if(nonTerminals.Contains(prodOutputSymbol))
            {
                pushedID = currentLargestFreeID;
                currentLargestFreeID++;
            }
            else
            {
                pushedID = -1;
            }

            currentWordState.Insert(transitionListIndex, prodOutputSymbol);
            currentExpansionIDs.Insert(transitionListIndex, pushedID);
        }

        UpdateUI();
    }

    private void ComeBackToStep(int stepID)
    {
        isSymbolChosen = false;
        isProductionChosen = false;

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

            currentWordState = stepHistory[historyIndex].wordState;
            currentExpansionIDs = stepHistory[historyIndex].expansionIDs;
            currentLargestFreeID = stepHistory[historyIndex].largestFreeID;

            while(stepHistory.Count > currentStepID)
            {
                stepHistory.RemoveAt(stepHistory.Count - 1);
            }

            UpdateUI();
        }
    }

    private void UpdateUI()
    {
        foreach(Transform child in currentStateContent.transform)
        {
            Destroy(child.gameObject);
        }

        for(int i=0; i<currentWordState.Count; i++)
        {
            GameObject letterObj = Instantiate(letterPrefab, currentStateContent.transform);
        
            letterObj.transform.GetChild(0).GetComponent<TMP_Text>().text = currentWordState[i];

            int capturedID = currentExpansionIDs[i];

            Debug.Log(capturedID);

            letterObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
            letterObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ChooseSymbolID(capturedID);});
        }
    }
 
    public void CleanUp()
    {
        foreach(Transform child in currentStateContent.transform)
        {
            Destroy(child.gameObject);
        }

        foreach(Transform child in stepListContent.transform)
        {
            Destroy(child.gameObject);
        }
    }
}