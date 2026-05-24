using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CFGGeneralInfoPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField addNonTerminalField;
    [SerializeField] private Button addNonTerminalButton;
    [SerializeField] private TMP_InputField addTerminalField;
    [SerializeField] private Button addTerminalButton;
    [SerializeField] private TMP_Dropdown startSymbolDropdown;

    [SerializeField] private TMP_Text nonTerminalsDisplay;
    [SerializeField] private TMP_Text terminalsDisplay;

    private CFGManager cfgm;

    void Awake()
    {
        
    }

    public void UpdateDisplay()
    {
        cfgm = GameObject.FindWithTag("CFGManager").GetComponent<CFGManager>();

        var nonTerminals = cfgm.GetNonTerminals();

        nonTerminalsDisplay.text = "";

        foreach (string inputSymbol in nonTerminals)
        {
            nonTerminalsDisplay.text += $"{inputSymbol} ";
        } 

        var terminals = cfgm.GetTerminals();

        terminalsDisplay.text = "";

        foreach (string inputSymbol in terminals)
        {
            terminalsDisplay.text += $"{inputSymbol} ";
        } 

        startSymbolDropdown.ClearOptions();

        startSymbolDropdown.AddOptions(nonTerminals);
    }

    public void Activate()
    {
        UpdateDisplay();
        gameObject.SetActive(true);

        addNonTerminalButton.onClick.RemoveAllListeners();
        addNonTerminalButton.onClick.AddListener(() =>
        {
            string newNonTerminal = addNonTerminalField.text;
            addNonTerminalField.text = "";
            cfgm.AddNonTerminal(newNonTerminal);
            UpdateDisplay();
        });

        addTerminalButton.onClick.RemoveAllListeners();
        addTerminalButton.onClick.AddListener(() =>
        {
            string newTerminal = addTerminalField.text;
            addTerminalField.text = "";
            cfgm.AddTerminal(newTerminal);
            UpdateDisplay();
        });

        startSymbolDropdown.onValueChanged.RemoveAllListeners();
        startSymbolDropdown.onValueChanged.AddListener((index) =>
        {
            string selectedSymbol = startSymbolDropdown.options[index].text;
            cfgm.ChangeStartSymbol(selectedSymbol);
        });
    }
}