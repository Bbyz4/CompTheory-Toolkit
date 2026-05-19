using System.Collections.Generic;
using UnityEngine;

public class NFAGraphNode
{
    public GameObject go;

    public List<NFAGraphEdge> outgoingEdges;
    public List<NFAGraphEdge> incomingEdges;

    public string name;

    public bool isStarting;
    public bool isFinal;

    public NFAGraphNode(GameObject go, string name)
    {
        this.go = go;
        this.outgoingEdges = new List<NFAGraphEdge>();
        this.incomingEdges = new List<NFAGraphEdge>();
        this.name = name;

        this.isStarting = false;
        this.isFinal = false;
    }
}

public class NFAGraphEdge
{
    public GameObject go;

    public NFAGraphNode source;
    public NFAGraphNode dest;

    public int transitionLetterID;

    public NFAGraphEdge(GameObject go, NFAGraphNode source, NFAGraphNode dest, int transitionLetterID)
    {
        this.go = go;
        this.source = source;
        this.dest = dest;
        this.transitionLetterID = transitionLetterID;
    }
}

public class NFAGraphManager : MonoBehaviour
{
    private List<NFAGraphNode> nodes = new List<NFAGraphNode>();
    private List<NFAGraphEdge> edges = new List<NFAGraphEdge>();

    [SerializeField] private GameObject nodePrefab;
    [SerializeField] private GameObject edgePrefab;

    public void AddNode(string name, Vector2 position)
    {
        GameObject newNode = Instantiate(nodePrefab, position, Quaternion.identity);

        nodes.Add(new NFAGraphNode(newNode, name));

        newNode.GetComponent<NFANodeBehaviour>().FillText(name);
        newNode.GetComponent<NFANodeNumber>().nodeNumber = nodes.Count - 1;

        if(name == "S")
        {
            nodes[^1].isStarting = true;
        }
    }

    public void AddEdge(int letter, int fromID, int toID)
    {
        List<string> tempLabels = new List<string>{"ε", "a", "b", "c"}; //temporary

        GameObject newEdge = Instantiate(edgePrefab, Vector3.zero, Quaternion.identity);

        edges.Add(new NFAGraphEdge(newEdge, nodes[fromID], nodes[toID], letter));

        newEdge.GetComponent<NFAEdgeBehaviour>().SetPositionAndRotation(nodes[fromID].go.transform.position, nodes[toID].go.transform.position);
    
        newEdge.GetComponent<NFAEdgeBehaviour>().FillText(tempLabels[letter+1]); //temporary (and ugly)


        nodes[fromID].outgoingEdges.Add(edges[^1]);
        nodes[toID].incomingEdges.Add(edges[^1]);
    }

    public List<NFAGraphNode> GetNodes()
    {
        return nodes; //unsafe
    }
}
