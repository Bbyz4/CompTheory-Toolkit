using System;
using System.Collections.Generic;
using UnityEngine;

public class TMJsonConverter : MonoBehaviour
{
    public static TMJsonForm ConvertGraphicTMToJSON(TMManager manager)
    {
        var states = manager.GetStates();
        var ia = manager.GetInputAlphabet();
        var ta = manager.GetTapeAlphabet();

        var transitions = manager.GetTransitions();

        string blank = manager.GetBlankSymbol();
        string qs = manager.GetStartState();

        TMJsonForm result = new TMJsonForm();

        result.type = "TM";

        result.model = new TMJsonModel();

        result.model.states = states;
        result.model.inputAlphabet = ia;
        result.model.tapeAlphabet = ta;
        result.model.blankSymbol = blank;
        result.model.startState = qs;
        result.model.acceptStates = states; //for now

        result.model.transitions = new List<TMManager.TMTransition>();

        foreach(TMManager.TMTransition t in transitions)
        {
            result.model.transitions.Add(t);
        }

        return result;
    }

    public static void ApplyTMFromJSON(TMManager manager, TMJsonForm jsonForm)
    {
        manager.Clear();

        foreach(string q in jsonForm.model.states)
        {
            manager.AddState(q);
        }

        foreach(string a in jsonForm.model.inputAlphabet)
        {
            manager.AddInputSymbol(a);
        }

        foreach(string t in jsonForm.model.tapeAlphabet)
        {
            manager.AddTapeSymbol(t);
        }

        foreach(TMManager.TMTransition t in jsonForm.model.transitions)
        {
            manager.ValidateAndAddTransition(t.entryState, t.entrySymbol, t.newState, t.newSymbol, t.headMovement);
        }

        manager.ChangeBlankSymbol(jsonForm.model.blankSymbol);

        manager.ChangeStartState(jsonForm.model.startState);

        //set accept states here
    }
}