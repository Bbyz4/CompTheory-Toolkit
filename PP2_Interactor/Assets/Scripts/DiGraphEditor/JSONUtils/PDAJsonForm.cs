using System.Collections.Generic;

public class PDATransition
{
    public string from;
    public string to;
    public string inputSymbol;
    public string stackSymbol;
    public List<string> pushedToStack;
}

public class PDAJsonModel
{
    public List<string> states;
    public List<string> inputAlphabet;
    public List<string> stackAlphabet;
    public List<PDATransition> transitions;
    public string startState;
    public string startStackSymbol;
    public List<string> acceptStates;
    public string acceptanceMode;
}

public class PDAJsonNodePlacement
{
    public string nodeName;
    public float posX;
    public float posY;
}

public class PDAJsonForm
{
    public string type;
    public PDAJsonModel model;
    public List<PDAJsonNodePlacement> nodePlacements;
}
