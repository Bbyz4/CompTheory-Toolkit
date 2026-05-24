using System;
using System.Collections.Generic;
using UnityEngine;

public class CFGJsonConverter : MonoBehaviour
{
    public static CFGJsonForm ConvertGraphicCFGToJSON(CFGManager manager)
    {
        var N = manager.GetNonTerminals();
        var E = manager.GetTerminals();
        var P = manager.GetP();
        var S = manager.GetStartSymbol();

        CFGJsonForm result = new CFGJsonForm();

        result.type = "CFG";
        
        result.model = new CFGJsonModel();

        result.model.nonTerminals = N;
        
        result.model.terminals = E;

        result.model.startSymbol = S;

        result.model.transitions = new List<CFGTransition>();

        foreach(KeyValuePair<string, List<List<string>>> production in P)
        {
            string from = production.Key;

            foreach(List<string> output in production.Value)
            {
                CFGTransition transition = new CFGTransition();

                transition.from = from;

                transition.to = new List<string>(output);

                result.model.transitions.Add(transition);
            }
        }

        return result;
    }

    public static void ApplyCFGFromJSON(CFGManager manager, CFGJsonForm jsonForm)
    {
        manager.Clear();

        foreach(string nt in jsonForm.model.nonTerminals)
        {
            manager.AddNonTerminal(nt);
        }

        foreach(string t in jsonForm.model.terminals)
        {
            manager.AddTerminal(t);
        }

        manager.ChangeStartSymbol(jsonForm.model.startSymbol);

        foreach(CFGTransition trans in jsonForm.model.transitions)
        {
            manager.ValidateAndAddProduction(trans.from, trans.to);
        }
    }
}