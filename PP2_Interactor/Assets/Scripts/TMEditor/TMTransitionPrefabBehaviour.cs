using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class TMTransitionPrefabBehaviour : MonoBehaviour
{
    private TMP_Text productionTitleText;
    private Button productionDeleteButton;

    private TMTransitionListManager tmplm;
    private TMInputManager tmim;
    private TMFreeRunManager tmfrm;

    void Awake()
    {
        productionTitleText = transform.Find("Rule").GetComponent<TMP_Text>();
        productionDeleteButton = transform.Find("DeleteButton").GetComponent<Button>();
   
        tmplm = GameObject.FindWithTag("TMTransitionListManager").GetComponent<TMTransitionListManager>();

        tmim = GameObject.FindWithTag("TMInputManager").GetComponent<TMInputManager>();

        tmfrm = FindFirstObjectByType<TMFreeRunManager>(FindObjectsInactive.Include);
    }

    public void FillData(string fromState, string fromSymbol, string toState, string toSymbol, int headMovement, TMManager tmm)
    {
        string titleString = $"({fromState},{fromSymbol}) -> ({toState},{toSymbol},{headMovement})";
        productionTitleText.text = titleString;

        productionDeleteButton.onClick.RemoveAllListeners();
        productionDeleteButton.onClick.AddListener(() =>
        {
            int inputMode = tmim.GetInputMode();

            if(inputMode == 0)
            {
                tmm.RemoveTransition(new TMManager.TMTransition(fromState, fromSymbol, toState, toSymbol, headMovement));
                tmplm.UpdateDisplay();   
            }
            else if(inputMode == 1)
            {
                tmfrm.ChooseTransition(fromState, fromSymbol, toState, toSymbol, headMovement);
            }
        });
    }
}