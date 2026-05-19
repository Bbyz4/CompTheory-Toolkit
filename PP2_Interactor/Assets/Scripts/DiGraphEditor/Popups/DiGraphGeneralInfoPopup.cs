using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class DiGraphGeneralInfoPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField addInputField;
    [SerializeField] private Button addInputButton;
    [SerializeField] private TMP_InputField addStackField;
    [SerializeField] private Button addStackButton;
    [SerializeField] private TMP_Dropdown startStackSymbolDropdown;


    [SerializeField] private TMP_Text inputAlphabetDisplay;
    [SerializeField] private TMP_Text stackAlphabetDisplay;

    [SerializeField] private TMP_Text stackAlphabetLabelText;

    private DiGraphManager dgm;

    void Awake()
    {
        if(ModelData.modelType == ModelData.ModelType.NFA)
        {
            addStackField.gameObject.SetActive(false);
            addStackButton.gameObject.SetActive(false);
            startStackSymbolDropdown.gameObject.SetActive(false);

            stackAlphabetDisplay.gameObject.SetActive(false);

            stackAlphabetLabelText.gameObject.SetActive(false);
        }
    }

    public void UpdateDisplay()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();

        var inputAlphabet = dgm.GetInputAlphabet();

        inputAlphabetDisplay.text = "";

        foreach (string inputSymbol in inputAlphabet)
        {
            inputAlphabetDisplay.text += $"{inputSymbol} ";
        }

        var stackAlphabet = dgm.GetStackAlphabet();

        stackAlphabetDisplay.text = "";

        foreach (string stackSymbol in stackAlphabet)
        {
            stackAlphabetDisplay.text += $"{stackSymbol} ";
        }

        startStackSymbolDropdown.ClearOptions();

        startStackSymbolDropdown.AddOptions(stackAlphabet);
    }

    public void Activate()
    {
        UpdateDisplay();
        this.gameObject.SetActive(true);

        addInputButton.onClick.RemoveAllListeners();
        addInputButton.onClick.AddListener(() =>
        {
            string newSymbol = addInputField.text;
            addInputField.text = "";
            dgm.AddInputSymbol(newSymbol); 
            UpdateDisplay();
        });

        addStackButton.onClick.RemoveAllListeners();
        addStackButton.onClick.AddListener(() =>
        {
            string newSymbol = addStackField.text;
            addStackField.text = "";
            dgm.AddStackSymbol(newSymbol); 
            UpdateDisplay();
        });

        startStackSymbolDropdown.onValueChanged.RemoveAllListeners();
        startStackSymbolDropdown.onValueChanged.AddListener((index) =>
        {
           string selectedSymbol = startStackSymbolDropdown.options[index].text;
           dgm.ChangeStartingStackSymbol(selectedSymbol); 
        });
    }
}
