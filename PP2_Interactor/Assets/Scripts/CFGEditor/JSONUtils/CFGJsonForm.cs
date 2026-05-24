using System.Collections.Generic;

public class CFGTransition
{
    public string from;
    public List<string> to;
}

public class CFGJsonModel
{
    public List<string> nonTerminals;
    public List<string> terminals;
    public List<CFGTransition> transitions;
    public string startSymbol;
}

public class CFGJsonForm
{
    public string type;
    public CFGJsonModel model;
}