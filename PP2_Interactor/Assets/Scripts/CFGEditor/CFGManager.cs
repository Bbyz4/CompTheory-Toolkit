using System.Collections.Generic;
using UnityEngine;

public class CFGManager : MonoBehaviour
{
    private List<string> nonTerminals = new List<string>();
    private List<string> terminals = new List<string>();

    private string startSymbol = null;

    private Dictionary<string, List<List<string>>> productions;

    //make it a copy of P later for safety
    public Dictionary<string, List<List<string>>> GetP()
    {
        return productions;
    }

    void Awake()
    {
        productions = new Dictionary<string, List<List<string>>>();

        if(ModelData.preopenFromJSON)
        {
            //open json
        }
    }

    public void AddNonTerminal(string newNonTerminal)
    {
        if(!nonTerminals.Contains(newNonTerminal) && !terminals.Contains(newNonTerminal))
        {
            nonTerminals.Add(newNonTerminal);

            if(startSymbol == null)
            {
                startSymbol = newNonTerminal;
            }
        }
    }

    public void AddTerminal(string newTerminal)
    {
        if(!nonTerminals.Contains(newTerminal) && !terminals.Contains(newTerminal))
        {
            terminals.Add(newTerminal);
        }
    }

    public void ChangeStartSymbol(string newSymbol)
    {
        if(nonTerminals.Contains(newSymbol))
        {
            startSymbol = newSymbol;
        }
    }

    public string GetStartSymbol()
    {
        return startSymbol;
    }

    public bool ValidateAndAddProduction(string from, List<string> output)
    {
        if(!nonTerminals.Contains(from))
        {
            return false;
        }

        if(output == null)
        {
            return false;
        }

        foreach(string p in output)
        {
            if(!nonTerminals.Contains(p) && !terminals.Contains(p))
            {
                return false;
            }
        }

        if(!productions.ContainsKey(from))
        {
            productions[from] = new List<List<string>>();
        }

        productions[from].Add(output);

        return true;
    }

    public void RemoveProduction(string from, List<string> output)
    {
        if(productions[from] != null)
        {
            productions[from].Remove(output);
        }
    }

    public List<string> GetNonTerminals()
    {
        return new List<string>(nonTerminals);
    }

    public List<string> GetTerminals()
    {
        return new List<string>(terminals);
    }

    public void Clear()
    {
        nonTerminals = new List<string>();
        terminals = new List<string>();

        startSymbol = null;

        productions = new Dictionary<string, List<List<string>>>();
    }
}
