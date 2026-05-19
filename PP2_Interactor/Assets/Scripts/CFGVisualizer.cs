using System;
using System.Collections.Generic;
using UnityEngine;

public enum CFGVisualizationType
{
    TREE,
    STRING
}

public class CFGVisualizer : MonoBehaviour
{
    private class NodeDescriptor
    {
        public bool isTerminal;
        public string value;
        public int parentIndex;
        public List<int> childrenIndeces;
        public GameObject nodeObject;
        public List<GameObject> outgoingArrowObjects;

        public NodeDescriptor(bool isTerminal, string value, int parentIndex, GameObject nodeObject)
        {
            this.isTerminal = isTerminal;
            this.value = value;
            this.parentIndex = parentIndex;
            this.childrenIndeces = new List<int>();
            this.nodeObject = nodeObject;
            this.outgoingArrowObjects = new List<GameObject>();
        }
    };

    //-------------------------------------

    [SerializeField] private GameObject ruleParent;
    [SerializeField] private GameObject graphNodePrefab;
    [SerializeField] private GameObject rulePrefab;

    //-------------------------------------
    private List<NodeDescriptor> nodes;
    private List<GameObject> rules;

    private List<string> N;
    private List<string> E;
    private List<(int key, List<Vector2Int> value)> P;
    private int S;
    private CFGVisualizationType visType;

    public void InitializeVisualizer
    (
        List<string> N,
        List<string> E,
        List<(int key, List<Vector2Int> value)> P,
        int S,
        CFGVisualizationType visType
    )
    {
        this.N = N;
        this.E = E;
        this.P = P;
        this.S = S;
        this.visType = visType;

        if(nodes != null)
        {
            foreach(NodeDescriptor node in nodes)
            {
                Destroy(node.nodeObject);
                foreach(GameObject arrow in node.outgoingArrowObjects)
                {
                    Destroy(arrow);
                }
            }
        }

        nodes = new List<NodeDescriptor>();
        rules = new List<GameObject>();

        GameObject firstNode = Instantiate(graphNodePrefab);
        firstNode.transform.position = new Vector3(0f, 0f, 0f);

        nodes.Add(new NodeDescriptor(false, N[S], -1, firstNode));

        float currentYOffset = 0f;
        foreach(var rule in P)
        {
            GameObject newRule = Instantiate(rulePrefab, ruleParent.transform);
            rules.Add(newRule);
            RectTransform rect = newRule.GetComponent<RectTransform>();
            rect.anchoredPosition = new Vector2(0f, currentYOffset);

            currentYOffset -= 90f;

            string valueText = "";

            foreach(Vector2Int prod in rule.value)
            {
                valueText += prod.x == 0 ? N[prod.y] : E[prod.y];
            }

            if (valueText == "")
            {
                valueText = "ε";
            }

            newRule.GetComponent<RulePrefabBehaviour>().FillText(N[rule.key] + " -> " + valueText);
        }
    }

    private List<Vector2Int> visualizationSteps; //form (ruleNumber, non-terminal number applied to) //FOR NOW SIMPLIFIED VERSION
    private int currentVisualStep;
    private float ANIM_TIME = 1f;

    public void GiveSteps(List<Vector2Int> steps)
    {
        this.visualizationSteps = steps;
        this.currentVisualStep = 0;
    }

    //FOR NOW SIMPLIFIED VERSION
    public void NextVisStep()
    {
        if(currentVisualStep == 2*visualizationSteps.Count)
        {
            rules[visualizationSteps[currentVisualStep/2 - 1].x].GetComponent<RulePrefabBehaviour>().ResetColor();
            nodes[visualizationSteps[currentVisualStep/2 - 1].y].nodeObject.GetComponent<GraphNodePrefabBehaviour>().ResetColor();
        }

        if(currentVisualStep >= 2*visualizationSteps.Count)
        {
            return;
        }

        if(currentVisualStep%2 == 0) //highlighting phase
        {
            if(currentVisualStep/2 > 0)
            {
                rules[visualizationSteps[currentVisualStep/2 - 1].x].GetComponent<RulePrefabBehaviour>().ResetColor();
                nodes[visualizationSteps[currentVisualStep/2 - 1].y].nodeObject.GetComponent<GraphNodePrefabBehaviour>().ResetColor();
            }

            rules[visualizationSteps[currentVisualStep/2].x].GetComponent<RulePrefabBehaviour>().HighlightAnimation(ANIM_TIME);
            nodes[visualizationSteps[currentVisualStep/2].y].nodeObject.GetComponent<GraphNodePrefabBehaviour>().HighlightAnimation(ANIM_TIME);
        }
        else
        {
            int transitionID = visualizationSteps[currentVisualStep/2].x;
            int developedNonterminalIndex = visualizationSteps[currentVisualStep/2].y;

            for(int i=0; i<P[transitionID].value.Count; i++)
            {
                GameObject newNodeObj = Instantiate(graphNodePrefab);

                newNodeObj.transform.position = nodes[developedNonterminalIndex].nodeObject.transform.position;

                newNodeObj.GetComponent<GraphNodePrefabBehaviour>().FillText(P[transitionID].value[i].x != 0 ? E[P[transitionID].value[i].y] : N[P[transitionID].value[i].y]);

                NodeDescriptor desc = new NodeDescriptor
                (
                    P[transitionID].value[i].x != 0,
                    P[transitionID].value[i].x != 0 ? E[P[transitionID].value[i].y] : N[P[transitionID].value[i].y],
                    developedNonterminalIndex,
                    newNodeObj
                );

                nodes.Add(desc);
                nodes[developedNonterminalIndex].childrenIndeces.Add(nodes.Count - 1);
            }

            //animate
            Vector2 newPos = new Vector2(nodes[developedNonterminalIndex].nodeObject.transform.position.x, nodes[developedNonterminalIndex].nodeObject.transform.position.y - 3f);
            float xOffset = 3f;

            for(int i=0; i<nodes[developedNonterminalIndex].childrenIndeces.Count; i++)
            {
                nodes[nodes[developedNonterminalIndex].childrenIndeces[i]].nodeObject.GetComponent<GraphNodePrefabBehaviour>().MoveAnimation(new Vector2(newPos.x + xOffset*i, newPos.y), ANIM_TIME);
            }
        }

        currentVisualStep++;
    }

    public void ResetVis()
    {
        this.currentVisualStep = 0;
        InitializeVisualizer(N,E,P,S,visType);
    }
}
