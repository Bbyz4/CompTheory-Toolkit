using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CFGProductionAddPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField fromSymbol;
    [SerializeField] private TMP_InputField outputList;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button cancelButton;

    private CFGManager cfgm;
    private CFGProductionListManager cfgplm;

    void Awake()
    {
        cfgm = GameObject.FindWithTag("CFGManager").GetComponent<CFGManager>();
        cfgplm = GameObject.FindWithTag("CFGProductionListManager").GetComponent<CFGProductionListManager>();
    }

    public void Activate()
    {
        gameObject.SetActive(true);

        fromSymbol.text = "";
        outputList.text = "";

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            List<string> oList = outputList.text
                .Split(',')
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            cfgm.ValidateAndAddProduction(fromSymbol.text, oList);
            cfgplm.UpdateDisplay();
            gameObject.SetActive(false);
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false); 
        });
    }
}
