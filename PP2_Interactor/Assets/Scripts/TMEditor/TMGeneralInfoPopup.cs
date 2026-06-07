using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class TMGeneralInfoPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField addStateField;
    [SerializeField] private Button addStateButton;
    [SerializeField] private TMP_InputField addInputSymbolField;
    [SerializeField] private Button addInputSymbolButton;
    [SerializeField] private TMP_InputField addTapeSymbolField;
    [SerializeField] private Button addTapeSymbolButton;
    [SerializeField] private TMP_Dropdown blankSymbolDropdown;
    [SerializeField] private TMP_Dropdown startStateDropdown;

    [SerializeField] private TMP_Text statesDisplay;
    [SerializeField] private TMP_Text inputAlphabetDisplay;
    [SerializeField] private TMP_Text tapeAlphabetDisplay;

    private TMManager tmm;

    void Awake()
    {
        
    }

    public void UpdateDisplay()
    {
        tmm = GameObject.FindWithTag("TMManager").GetComponent<TMManager>();

        var states = tmm.GetStates();

        statesDisplay.text = "";

        foreach (string state in states)
        {
            statesDisplay.text += $"{state} ";
        }
    
        var inputAlphabet = tmm.GetInputAlphabet();

        inputAlphabetDisplay.text = "";

        foreach (string ia in inputAlphabet)
        {
            inputAlphabetDisplay.text += $"{ia} ";
        }

        var tapeAlphabet = tmm.GetTapeAlphabet();

        tapeAlphabetDisplay.text = "";

        foreach (string ta in tapeAlphabet)
        {
            tapeAlphabetDisplay.text += $"{ta} ";
        }

        blankSymbolDropdown.ClearOptions();

        blankSymbolDropdown.AddOptions(tapeAlphabet);

        startStateDropdown.ClearOptions();

        startStateDropdown.AddOptions(states);
    }

    public void Activate()
    {
        UpdateDisplay();
        gameObject.SetActive(true);

        addStateButton.onClick.RemoveAllListeners();
        addStateButton.onClick.AddListener(() =>
        {
            string s = addStateField.text;
            addStateField.text = "";
            tmm.AddState(s);
            UpdateDisplay();
        });

        addInputSymbolButton.onClick.RemoveAllListeners();
        addInputSymbolButton.onClick.AddListener(() =>
        {
            string s = addInputSymbolField.text;
            addInputSymbolField.text = "";
            tmm.AddInputSymbol(s);
            UpdateDisplay();
        });

        addTapeSymbolButton.onClick.RemoveAllListeners();
        addTapeSymbolButton.onClick.AddListener(() =>
        {
            string s = addTapeSymbolField.text;
            addTapeSymbolField.text = "";
            tmm.AddTapeSymbol(s);
            UpdateDisplay();
        });

        blankSymbolDropdown.onValueChanged.RemoveAllListeners();
        blankSymbolDropdown.onValueChanged.AddListener((index) =>
        {
            string selectedSymbol = blankSymbolDropdown.options[index].text;
            tmm.ChangeBlankSymbol(selectedSymbol);
        });

        startStateDropdown.onValueChanged.RemoveAllListeners();
        startStateDropdown.onValueChanged.AddListener((index) =>
        {
            string selectedState = startStateDropdown.options[index].text;
            tmm.ChangeStartState(selectedState);
        });
    }
}