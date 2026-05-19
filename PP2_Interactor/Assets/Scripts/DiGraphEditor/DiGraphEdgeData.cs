using System.Collections.Generic;
using UnityEngine;

public class DiGraphEdgeData : MonoBehaviour
{
    public string inputSymbol;
    public string stackSymbol;
    public List<string> toPush;
    //---
    public DiGraphNodeData begin;
    public DiGraphNodeData end;

    public int interlalListIndex;

    public DiGraphEdgeData()
    {
        toPush = new List<string>();
    }
}
