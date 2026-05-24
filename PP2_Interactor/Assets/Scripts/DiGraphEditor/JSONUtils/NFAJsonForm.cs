using System.Collections.Generic;

public class NFATransition
{
    public string from;
    public string to;
    public string symbol;
}

public class NFAJsonModel
{
    public List<string> states;
    public List<string> inputAlphabet;
    public List<NFATransition> transitions;
    public List<string> startStates;
    public List<string> acceptStates;
}

public class NFAJsonNodePlacement
{
    public string nodeName;
    public float posX;
    public float posY;
}

public class NFAJsonForm
{
    public string type;
    public NFAJsonModel model;
    public List<NFAJsonNodePlacement> nodePlacements;
}
