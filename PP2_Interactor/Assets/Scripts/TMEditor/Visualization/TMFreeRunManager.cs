using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class TMFreeRunManager : MonoBehaviour
{
    private class StepDescription
    {
        public List<string> tapeState;
        public int headPosition;
        public string headState;
    }

    [SerializeField] private GameObject stepListContent;
    [SerializeField] private GameObject freeRunStepPrefab;
    [SerializeField] private GameObject currentStateContent;
    [SerializeField] private GameObject letterPrefab;

    private TMManager tmm;

    private List<StepDescription> stepHistory;

    private List<string> currentTapeState;
    private int currentHeadPosition;
    private string currentHeadState;
    private int currentStepID;

    private List<string> usedStartingWord;

    void Awake()
    {
        tmm = GameObject.FindWithTag("TMManager").GetComponent<TMManager>();
    }

    public void Initialize(List<string> startingWord)
    {
        CleanUp();

        usedStartingWord = new List<string>(startingWord);

        stepHistory = new List<StepDescription>();

        currentStepID = 0;

        currentTapeState = new List<string>(startingWord);
        currentHeadPosition = 0;
        currentHeadState = tmm.GetStartState();

        for(int i=0; i<startingWord.Count; i++)
        {
            string symbol = startingWord[i];

            GameObject letterObj = Instantiate(letterPrefab, currentStateContent.transform);
        
            letterObj.transform.GetChild(0).GetComponent<TMP_Text>().text = symbol;

            letterObj.GetComponent<Image>().color = (currentHeadPosition == i ? Color.yellow : Color.white);

            letterObj.transform.GetChild(2).GetComponent<TMP_Text>().text = currentHeadState;
            letterObj.transform.GetChild(2).gameObject.SetActive(currentHeadPosition == i);
        }

        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"0";

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(0);});
    }

    public void ChooseTransition(string fromState, string fromSymbol, string toState, string toSymbol, int headMovement)
    {
        ApplyNewTransition(fromState, fromSymbol, toState, toSymbol, headMovement);
    }

    private void ApplyNewTransition(string fromState, string fromSymbol, string toState, string toSymbol, int headMovement)
    {
        if(fromSymbol != currentTapeState[currentHeadPosition] || fromState != currentHeadState)
        {
            return;
        }

        stepHistory.Add(new StepDescription
        {
            tapeState = new List<string>(currentTapeState),
            headPosition = currentHeadPosition,
            headState = currentHeadState
        });

        GameObject newStepObj = Instantiate(freeRunStepPrefab, stepListContent.transform);

        currentStepID++;
        int capturedStepID = currentStepID;

        newStepObj.transform.GetChild(0).GetComponent<TMP_Text>().text = $"{capturedStepID}: ({fromState},{fromSymbol})";

        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.RemoveAllListeners();
        newStepObj.transform.GetChild(1).GetComponent<Button>().onClick.AddListener(() => {ComeBackToStep(capturedStepID);});


        currentTapeState[currentHeadPosition] = toSymbol;
        currentHeadState = toState;

        currentHeadPosition += headMovement;

        if(currentHeadPosition == -1)
        {
            currentTapeState.Insert(0, tmm.GetBlankSymbol());
            currentHeadPosition = 0;
        }
        else if(currentHeadPosition == currentTapeState.Count)
        {
            currentTapeState.Add(tmm.GetBlankSymbol());
        }

        UpdateUI();
    }

    private void ComeBackToStep(int stepID)
    {
        if(stepID >= currentStepID)
        {
            return;
        } 

        for(int i = stepListContent.transform.childCount - 1; i >= stepID + 1; i--)
        {
            Destroy(stepListContent.transform.GetChild(i).gameObject);
        }

        currentStepID = stepID;

        if (stepID == 0)
        {
            Initialize(usedStartingWord);
        }
        else
        {    
            int historyIndex = stepID;

            currentTapeState = new List<string>(stepHistory[historyIndex].tapeState);
            currentHeadPosition = stepHistory[historyIndex].headPosition;
            currentHeadState = stepHistory[historyIndex].headState;

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

        for(int i=0; i<currentTapeState.Count; i++)
        {
            GameObject letterObj = Instantiate(letterPrefab, currentStateContent.transform);
        
            letterObj.transform.GetChild(0).GetComponent<TMP_Text>().text = currentTapeState[i];

            letterObj.GetComponent<Image>().color = (currentHeadPosition == i ? Color.yellow : Color.white);

            letterObj.transform.GetChild(2).GetComponent<TMP_Text>().text = currentHeadState;
            letterObj.transform.GetChild(2).gameObject.SetActive(currentHeadPosition == i);
        }
    }

    //---

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