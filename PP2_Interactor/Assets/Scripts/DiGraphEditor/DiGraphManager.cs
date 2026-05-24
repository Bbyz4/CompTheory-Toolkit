using System.Collections.Generic;
using Newtonsoft.Json;
using Unity.VisualScripting;
using UnityEngine;

public class DiGraphManager : MonoBehaviour
{
    private List<string> inputAlphabet = new List<string>();
    private List<string> stackAlphabet = new List<string>();

    private string startingStackSymbol = null;

    private Dictionary<int, DiGraphNodeData> V;
    private int currentAddedNodeID = 0;
    private Dictionary<Vector2Int, List<DiGraphEdgeData>> E;

    [SerializeField] private GameObject nodePrefab;
    [SerializeField] private GameObject edgePrefab;


    //make it a copy of V later for safety
    public Dictionary<int, DiGraphNodeData> GetV()
    {
        return V;
    }

    //make it a copy of E later for safety
    public Dictionary<Vector2Int, List<DiGraphEdgeData>> GetE()
    {
        return E;
    }

    void Awake()
    {
        V = new Dictionary<int, DiGraphNodeData>();
        E = new Dictionary<Vector2Int, List<DiGraphEdgeData>>();

        //handle preloaded model
        if(ModelData.preopenFromJSON)
        {
            if(ModelData.modelType == ModelData.ModelType.PDA)
            {
                DiGraphJSONConverter.ApplyPDAFromJSON(this, JsonConvert.DeserializeObject<PDAJsonForm>(ModelData.JSONFile));
            }
            else
            {
                DiGraphJSONConverter.ApplyNFAFromJSON(this, JsonConvert.DeserializeObject<NFAJsonForm>(ModelData.JSONFile)); 
            }
        }
    }

    public int AddNode(Vector2 position, string nodeName, bool isStarting, bool isAccepting)
    {
        GameObject newNodeObject = Instantiate(nodePrefab, position, Quaternion.identity);

        var newNode = newNodeObject.GetComponent<DiGraphNodeData>();
        newNode.nodeName = nodeName;
        newNode.isStarting = isStarting;
        newNode.isAccepting = isAccepting;
        newNode.edges = new List<DiGraphEdgeData>();
        newNode.internalID = currentAddedNodeID;

        V.Add(currentAddedNodeID, newNode);
        currentAddedNodeID++;

        newNodeObject.GetComponent<DiGraphNodeDisplay>().UpdateDisplay();

        return currentAddedNodeID-1;
    }

    public bool ValidateEdge(int fromID, int toID, string inputSymbol, string stackSymbol, List<string> toPush)
    {
        if((!inputAlphabet.Contains(inputSymbol) && inputSymbol != "") || (ModelData.modelType == ModelData.ModelType.PDA && !stackAlphabet.Contains(stackSymbol)))
        {
            return false;
        }

        if(ModelData.modelType == ModelData.ModelType.PDA)
        {
            if(toPush == null)
            {
                return false;
            }

            foreach(string pushedSymbol in toPush)
            {
                if(!stackAlphabet.Contains(pushedSymbol))
                {
                    return false;
                }
            }
        }

        if(!V.ContainsKey(fromID) || !V.ContainsKey(toID))
        {
            return false;
        }

        return true;
    }

    public void AddEdge(int fromID, int toID, string inputSymbol, string stackSymbol, List<string> toPush)
    {
        if(!ValidateEdge(fromID, toID, inputSymbol, stackSymbol, toPush))
        {
            return;
        }

        GameObject newEdgeObject = Instantiate(edgePrefab);

        var key = new Vector2Int(fromID, toID);

        var newEdge = newEdgeObject.GetComponent<DiGraphEdgeData>();
        newEdge.inputSymbol = inputSymbol;
        newEdge.stackSymbol = stackSymbol;
        newEdge.toPush = toPush;
        newEdge.begin = V[fromID];
        newEdge.end = V[toID];

        if(!E.ContainsKey(key))
        {
            E[key] = new List<DiGraphEdgeData>();
        }

        E[key].Add(newEdge);

        newEdge.interlalListIndex = E[key].Count - 1;

        V[fromID].edges.Add(newEdge);
        V[toID].edges.Add(newEdge);

        newEdgeObject.GetComponent<DiGraphEdgeDisplay>().UpdateDisplay();
    }

    public void RemoveEdge(DiGraphEdgeData edge)
    {
        var key = new Vector2Int(edge.begin.internalID, edge.end.internalID);

        if(E.ContainsKey(key))
        {
            int removedIndex = E[key].IndexOf(edge);

            E[key].RemoveAt(removedIndex);

            for(int i=removedIndex; i<E[key].Count; i++)
            {
                E[key][i].interlalListIndex = i;
            }

            if(E[key].Count == 0)
            {
                E.Remove(key);
            }
        }

        V[key.x].edges.Remove(edge);
        V[key.y].edges.Remove(edge);

        Destroy(edge.gameObject);
    }

    public void RemoveNode(DiGraphNodeData node)
    {
        foreach (DiGraphEdgeData edge in new List<DiGraphEdgeData>(node.edges))
        {
            RemoveEdge(edge);
        }

        V.Remove(node.internalID);
        Destroy(node.gameObject);
    }

    public List<string> GetInputAlphabet()
    {
        return new List<string>(inputAlphabet);
    }

    public List<string> GetStackAlphabet()
    {
        return new List<string>(stackAlphabet);
    }

    public string GetStartingStackSymbol()
    {
        return startingStackSymbol;
    }

    public void AddInputSymbol(string newSymbol)
    {
        if(!inputAlphabet.Contains(newSymbol) && !stackAlphabet.Contains(newSymbol))
        {
            inputAlphabet.Add(newSymbol);
        }
    }

    public void AddStackSymbol(string newSymbol)
    {
        if(!inputAlphabet.Contains(newSymbol) && !stackAlphabet.Contains(newSymbol))
        {
            stackAlphabet.Add(newSymbol);

            if(startingStackSymbol == null)
            {
                startingStackSymbol = newSymbol;
            }
        }
    }

    public void ChangeStartingStackSymbol(string newSymbol)
    {
        if(stackAlphabet.Contains(newSymbol))
        {
            startingStackSymbol = newSymbol;
        }
    }

    public void Clear()
    {
        foreach(var edgeList in new Dictionary<Vector2Int, List<DiGraphEdgeData>>(E).Values)
        {
            for(int i = edgeList.Count - 1; i >= 0; i--)
            {
                RemoveEdge(edgeList[i]);
            }
        }

        foreach(var node in new Dictionary<int, DiGraphNodeData>(V).Values)
        {
            RemoveNode(node);
        }

        V.Clear();
        E.Clear();

        currentAddedNodeID = 0;
        inputAlphabet.Clear();
        stackAlphabet.Clear();
        startingStackSymbol = "";
    }
}
