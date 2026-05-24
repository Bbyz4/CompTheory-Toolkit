using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

public class NFAVisualizer : MonoBehaviour
{
    private List<NFAGraphNode> nodes;
    private List<int> transitions;

    private int stepID;

    private float ANIM_TIME = 0.7f;

    [SerializeField] private GameObject ballPrefab;

    public void Initialize(List<NFAGraphNode> nodes, List<int> transitions)
    {
        this.nodes = nodes;
        this.transitions = transitions;

        this.stepID = 0;

        balls = new Dictionary<NFAGraphNode, GameObject>();
    }

    private Dictionary<NFAGraphNode, GameObject> balls;

    private HashSet<NFAGraphNode> traversedThisStep = new HashSet<NFAGraphNode>();

    public void NextStep()
    {
        if (stepID >= (4 * transitions.Count + 1))
            return;

        if (stepID == 0) // spawn balls on starter nodes
        {
            foreach (NFAGraphNode node in nodes)
            {
                if (node.isStarting)
                {
                    balls[node] = Instantiate(ballPrefab, node.go.transform.position, Quaternion.identity);
                }
            }
        }
        else if (stepID % 4 == 1) // ε-closure + highlight
        {
            traversedThisStep.Clear();

            foreach(NFAGraphNode node in nodes)
            {
                foreach(NFAGraphEdge edge in node.outgoingEdges)
                {
                    edge.go.GetComponent<NFAEdgeBehaviour>().ResetColor();
                }
            }

            HashSet<NFAGraphNode> closure = new HashSet<NFAGraphNode>(balls.Keys);
            bool changed = true;

            while (changed)
            {
                changed = false;

                foreach (NFAGraphNode node in closure.ToList())
                {
                    foreach (NFAGraphEdge edge in node.outgoingEdges)
                    {
                        if (edge.transitionLetterID == -1)
                        {
                            edge.go.GetComponent<NFAEdgeBehaviour>().HighlightAnimation(ANIM_TIME);

                            if (!closure.Contains(edge.dest))
                            {
                                closure.Add(edge.dest);
                                traversedThisStep.Add(edge.dest);
                                changed = true;
                            }
                        }
                        else
                        {
                            edge.go.GetComponent<NFAEdgeBehaviour>().ResetColor();
                        }
                    }
                }
            }
        }
        else if (stepID % 4 == 2) // place balls from ε-closure (no deletion)
        {
            foreach (NFAGraphNode node in traversedThisStep)
            {
                if (!balls.ContainsKey(node))
                {
                    balls[node] = Instantiate(ballPrefab, node.go.transform.position, Quaternion.identity);
                }
            }
        }
        else if (stepID % 4 == 3) // highlight letter edges
        {
            int letterID = transitions[Mathf.FloorToInt(stepID / 4f)];

            foreach (var pair in balls)
            {
                NFAGraphNode node = pair.Key;

                foreach (NFAGraphEdge edge in node.outgoingEdges)
                {
                    if (edge.transitionLetterID == letterID)
                    {
                        edge.go.GetComponent<NFAEdgeBehaviour>().HighlightAnimation(ANIM_TIME);
                    }
                    else
                    {
                        edge.go.GetComponent<NFAEdgeBehaviour>().ResetColor();
                    }
                }
            }
        }
        else // stepID % 4 == 0 → traverse letter edges (REPLACE balls)
        {
            int letterID = transitions[Mathf.FloorToInt((stepID - 1) / 4f)];

            traversedThisStep.Clear();

            foreach (var pair in balls)
            {
                NFAGraphNode node = pair.Key;

                foreach (NFAGraphEdge edge in node.outgoingEdges)
                {
                    if (edge.transitionLetterID == letterID)
                    {
                        traversedThisStep.Add(edge.dest);
                    }
                }
            }

            // 🔴 DELETE OLD BALLS
            foreach (GameObject ballObj in balls.Values)
            {
                Destroy(ballObj);
            }
            balls.Clear();

            // ✅ ADD NEW BALLS
            foreach (NFAGraphNode node in traversedThisStep)
            {
                balls[node] = Instantiate(ballPrefab, node.go.transform.position, Quaternion.identity);
            }
        }

        stepID++;
    }

    public void Reset()
    {
        foreach(GameObject ballObj in balls.Values)
        {
            Destroy(ballObj);
        }

        balls.Clear();

        stepID = 0;
    }
}
