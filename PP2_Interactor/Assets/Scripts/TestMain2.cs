using System.Collections.Generic;
using TMPro;
using UnityEditor.Experimental.GraphView;
using UnityEngine;

public class TestMain2 : MonoBehaviour
{
    NFAGraphManager GM;
    NFAVisualizer NV;

    [SerializeField] private float SCALE;
    void Awake()
    {
/*         GM = GameObject.Find("NFAGraphManager").GetComponent<NFAGraphManager>();

        GM.AddNode("S", new Vector2(0f, 0f));
        GM.AddNode("A", new Vector2(1f*SCALE, -1f*SCALE));
        GM.AddNode("B", new Vector2(0f, -2f*SCALE));
        GM.AddNode("C", new Vector2(-1f*SCALE, -1f*SCALE));
        GM.AddNode("A_1", new Vector2(2f*SCALE, 0f));
        GM.AddNode("A_2", new Vector2(3f*SCALE, -1f*SCALE));
        GM.AddNode("B_1", new Vector2(0f, -3f*SCALE));
        GM.AddNode("C_1", new Vector2(-3f*SCALE, -1f*SCALE));
        GM.AddNode("C_2", new Vector2(-2f*SCALE, 0f));

        GM.AddEdge(-1, 0, 1);
        GM.AddEdge(-1, 1, 2);
        GM.AddEdge(-1, 2, 3);
        GM.AddEdge(-1, 3, 1);
        GM.AddEdge(-1, 7, 8);
        GM.AddEdge(-1, 8, 3);
        GM.AddEdge(0, 1, 4);
        GM.AddEdge(0, 4, 5);
        GM.AddEdge(0, 5, 1);
        GM.AddEdge(1, 2, 6);
        GM.AddEdge(1, 6, 2);
        GM.AddEdge(2, 3, 7);

        NV = GameObject.Find("NFAVisualizer").GetComponent<NFAVisualizer>();

        NV.Initialize(GM.GetNodes(), new System.Collections.Generic.List<int>{0,0,0,1,1,2,0,0,0}); */
    }


    [SerializeField] private int INPUT_MODE = 0;

    [SerializeField] private NodeAddPopup nodeAddPopup;
    [SerializeField] private EdgeAddPopup edgeAddPopup;
    private int? firstNode;
    private int? secondNode;

    void Update()
    {
        if(INPUT_MODE == 2)
        {
            if(Input.GetKeyDown(KeyCode.Space))
            {
                NV.NextStep();
            }

            if(Input.GetKeyDown(KeyCode.R))
            {
                NV.Reset();
            }

            if(Input.GetKeyDown(KeyCode.Escape))
            {
                NV.Reset();
                INPUT_MODE = 0;
            }
        }

        if(Input.GetKeyDown(KeyCode.Alpha0))
        {
            INPUT_MODE = 0;
        }
        else if(Input.GetKeyDown(KeyCode.Alpha1))
        {
            INPUT_MODE = 1;
        }

        if (Input.GetMouseButtonDown(0))
        {
            if(INPUT_MODE == 0 && !nodeAddPopup.gameObject.activeInHierarchy)
            {
                Vector3 mousePos = Input.mousePosition;

                mousePos.z = Mathf.Abs(Camera.main.transform.position.z);

                Vector3 worldPos = Camera.main.ScreenToWorldPoint(mousePos);

                nodeAddPopup.LaunchForGivenPos(worldPos); 
            }

            if(INPUT_MODE == 1 && !edgeAddPopup.gameObject.activeInHierarchy)
            {
                Vector3 mousePos = Input.mousePosition;

                mousePos.z = Mathf.Abs(Camera.main.transform.position.z);

                Vector3 worldPos = Camera.main.ScreenToWorldPoint(mousePos);

                int? clickedNode = null;

                Vector2 mouseWorldPos = new Vector2(worldPos.x, worldPos.y);

                Collider2D hit = Physics2D.OverlapPoint(mouseWorldPos);

                if (hit != null)
                {
                    clickedNode = hit.gameObject.GetComponent<NFANodeNumber>().nodeNumber;
                }

                if(clickedNode != null)
                {
                    if(firstNode==null)
                    {
                        firstNode = clickedNode;
                    }
                    else if(secondNode==null && clickedNode != firstNode)
                    {
                        secondNode = clickedNode;

                        edgeAddPopup.LaunchForGivenNodes((int)firstNode, (int)secondNode);

                        firstNode = null;
                        secondNode = null;
                    }
                }
            }
        }
    }

    private Dictionary<string, int> letterToInt = new Dictionary<string, int>()
    {
        {"e", -1},
        {"a", 0},
        {"b", 1},
        {"c", 2}  
    };

    public void LaunchForGivenWord(string word)
    {
        INPUT_MODE = 2;

        List<int> transitionList = new List<int>();

        for(int i=0; i<word.Length; i++)
        {
            transitionList.Add(letterToInt[word[i].ToString()]);
        }

        NV = GameObject.Find("NFAVisualizer").GetComponent<NFAVisualizer>();
        GM = GameObject.Find("NFAGraphManager").GetComponent<NFAGraphManager>();
        NV.Initialize(GM.GetNodes(), transitionList);
    }
}
