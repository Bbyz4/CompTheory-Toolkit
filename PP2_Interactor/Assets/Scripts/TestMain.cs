using UnityEngine;
using System.Collections.Generic;

public class TestMain : MonoBehaviour
{
    private CFGVisualizer cfg;

    void Awake()
    {
        cfg = GameObject.Find("CFGVisualizer").GetComponent<CFGVisualizer>();

        cfg.InitializeVisualizer
        (
            new List<string>{"S", "A", "B"},
            new List<string>{"a", "b"},
            new List<(int, List<Vector2Int>)>
            {
                (0, new List<Vector2Int>{new Vector2Int(0,1), new Vector2Int(0,0), new Vector2Int(0,2)}),
                (0, new List<Vector2Int>()),
                (1, new List<Vector2Int>{new Vector2Int(1,0)}),
                (2, new List<Vector2Int>{new Vector2Int(1,1)})
            },
            0,
            CFGVisualizationType.TREE
        );

        cfg.GiveSteps(new List<Vector2Int>
        {
            new Vector2Int(0,0),
            new Vector2Int(2,1),
            new Vector2Int(0,2),
            new Vector2Int(3,7),
            new Vector2Int(2,5),
            new Vector2Int(1,6),
            new Vector2Int(3,3)
        });
    }

    void Update()
    {
        if(Input.GetKeyDown(KeyCode.Space))
        {
            cfg.NextVisStep();
        }

        if(Input.GetKeyDown(KeyCode.R))
        {
            cfg.ResetVis();
        }
    }
}
