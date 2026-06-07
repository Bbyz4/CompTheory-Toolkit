using System;
using System.Collections.Generic;
using UnityEngine;

public class TMManager: MonoBehaviour
{
    private List<string> states = new List<string>();
    private List<string> inputAlphabet = new List<string>();
    private List<string> tapeAlphabet = new List<string>();

    private string blankSymbol = null;
    private string startState = null;

    private List<string> acceptStates = new List<string>();

    private List<TMTransition> transitions;

    public class TMTransition
    {
        public string entryState;
        public string entrySymbol;

        public string newState;
        public string newSymbol;
        public int headMovement;

        public TMTransition(string entryState, string entrySymbol, string newState, string newSymbol, int headMovement)
        {
            this.entryState = entryState;
            this.entrySymbol = entrySymbol;

            this.newState = newState;
            this.newSymbol = newSymbol;
            this.headMovement = headMovement;
        }

        public override bool Equals(object obj)
        {
            return Equals(obj as TMTransition);
        }

        public bool Equals(TMTransition other)
        {
            if (other == null)
                return false;

            return entryState == other.entryState &&
                entrySymbol == other.entrySymbol &&
                newState == other.newState &&
                newSymbol == other.newSymbol &&
                headMovement == other.headMovement;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(
                entryState,
                entrySymbol,
                newState,
                newSymbol,
                headMovement
            );
        }

        public static bool operator ==(TMTransition left, TMTransition right)
        {
            if (ReferenceEquals(left, right))
                return true;

            if (left is null || right is null)
                return false;

            return left.Equals(right);
        }

        public static bool operator !=(TMTransition left, TMTransition right)
        {
            return !(left == right);
        }
    }

    void Awake()
    {
        transitions = new List<TMTransition>();
        
        if(ModelData.preopenFromJSON)
        {
            //open json
        }
    }

    public void AddState(string newState)
    {
        if(!states.Contains(newState))
        {
            states.Add(newState);

            if(startState == null)
            {
                startState = newState;
            }
        }
    }

    public void AddInputSymbol(string newInputSymbol)
    {
        if(!inputAlphabet.Contains(newInputSymbol) && !tapeAlphabet.Contains(newInputSymbol))
        {
            inputAlphabet.Add(newInputSymbol);
        }
    }

    public void AddTapeSymbol(string newTapeSymbol)
    {
        if(!inputAlphabet.Contains(newTapeSymbol) && !tapeAlphabet.Contains(newTapeSymbol))
        {
            tapeAlphabet.Add(newTapeSymbol);

            if(blankSymbol == null)
            {
                blankSymbol = newTapeSymbol;
            }
        }
    }

    public void ChangeBlankSymbol(string newSymbol)
    {
        if(tapeAlphabet.Contains(newSymbol))
        {
            blankSymbol = newSymbol;
        }
    }

    public void ChangeStartState(string newSS)
    {
        if(states.Contains(newSS))
        {
            startState = newSS;
        }
    }

    public string GetBlankSymbol()
    {
        return blankSymbol;
    }

    public bool ValidateAndAddTransition(string entryState, string entrySymbol, string newState, string newSymbol, int headMovement)
    {
        if(!states.Contains(entryState) || !states.Contains(newState))
        {
            return false;
        }

        if(!inputAlphabet.Contains(entrySymbol) && !tapeAlphabet.Contains(entrySymbol))
        {
            return false;
        }

        if(!inputAlphabet.Contains(newSymbol) && !tapeAlphabet.Contains(newSymbol))
        {
            return false;
        }

        if(Math.Abs(headMovement) >= 2)
        {
            return false;
        }

        transitions.Add(new TMTransition(
            entryState,
            entrySymbol,
            newState,
            newSymbol,
            headMovement
        ));

        return true;
    }

    public void RemoveTransition(TMTransition toRemove)
    {
        transitions.Remove(toRemove);
    }

    public List<string> GetStates()
    {
        return new List<string>(states);
    }

    public List<string> GetInputAlphabet()
    {
        return new List<string>(inputAlphabet);
    }

    public List<string> GetTapeAlphabet()
    {
        return new List<string>(tapeAlphabet);
    }

    public List<TMTransition> GetTransitions()
    {
        return new List<TMTransition>(transitions);
    }

    public string GetStartState()
    {
        return startState;
    }

    public void Clear()
    {
        states = new List<string>();
        inputAlphabet = new List<string>();
        tapeAlphabet = new List<string>();

        blankSymbol = null;

        transitions = new List<TMTransition>();
    }
}