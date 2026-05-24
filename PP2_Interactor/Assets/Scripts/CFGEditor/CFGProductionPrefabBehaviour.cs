using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CFGProductionPrefabBehaviour : MonoBehaviour
{
    private TMP_Text productionTitleText;
    private Button productionDeleteButton;

    private CFGProductionListManager cfgplm;
    private CFGInputManager cfgim;
    private CFGFreeRunManager cfgfrm;

    void Awake()
    {
        productionTitleText = transform.Find("Rule").GetComponent<TMP_Text>();
        productionDeleteButton = transform.Find("DeleteButton").GetComponent<Button>();
   
        cfgplm = GameObject.FindWithTag("CFGProductionListManager").GetComponent<CFGProductionListManager>();

        cfgim = GameObject.FindWithTag("CFGInputManager").GetComponent<CFGInputManager>();

        cfgfrm = FindFirstObjectByType<CFGFreeRunManager>(FindObjectsInactive.Include);
    }

    public void FillData(string from, List<string> output, CFGManager cfgm)
    {
        string titleString = $"{from} -> {string.Join("", output)}";
        productionTitleText.text = titleString;

        productionDeleteButton.onClick.RemoveAllListeners();
        productionDeleteButton.onClick.AddListener(() =>
        {
            int inputMode = cfgim.GetInputMode();

            if(inputMode == 0)
            {
                cfgm.RemoveProduction(from, output);
                cfgplm.UpdateDisplay();   
            }
            else if(inputMode == 1)
            {
                cfgfrm.ChooseProduction(from, output);
            }
        });
    }
}
