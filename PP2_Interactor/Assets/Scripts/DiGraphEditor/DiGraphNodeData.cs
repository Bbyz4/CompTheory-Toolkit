using System.Collections.Generic;
using UnityEngine;

public class DiGraphNodeData : MonoBehaviour
{
    public string nodeName;
    public bool isStarting;
    public bool isAccepting;
    //---
    public List<DiGraphEdgeData> edges;
    public int internalID;

    public DiGraphNodeData()
    {
        edges = new List<DiGraphEdgeData>();
        internalID = 0;
    }
}
