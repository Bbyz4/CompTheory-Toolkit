using System.Collections.Generic;

public class TMJsonModel
{
    public List<string> states;
    public List<string> inputAlphabet;
    public List<string> tapeAlphabet;
    public string blankSymbol;
    public List<TMManager.TMTransition> transitions;
    public string startState;
    public List<string> acceptStates;
}

public class TMJsonForm
{
    public string type;
    public TMJsonModel model;
}