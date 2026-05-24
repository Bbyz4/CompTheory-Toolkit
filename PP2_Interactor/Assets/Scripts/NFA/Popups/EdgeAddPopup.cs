using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class EdgeAddPopup : MonoBehaviour
{
    private int fromNodeID;
    private int toNodeID;

    private Dictionary<string, int> letterToInt = new Dictionary<string, int>()
    {
        {"e", -1},
        {"a", 0},
        {"b", 1},
        {"c", 2}  
    };

    void Awake()
    {
        this.gameObject.SetActive(false);

        letterToInt = new Dictionary<string, int>()
            {
                {"e", -1},
                {"a", 0},
                {"b", 1},
                {"c", 2}  
            };

        transform.Find("Confirm").GetComponent<Button>().onClick.AddListener(() => ConfirmAction());
    }

    public void LaunchForGivenNodes(int fromID, int toID)
    {
        fromNodeID = fromID;
        toNodeID = toID;

        this.gameObject.SetActive(true);
    }

    public void ConfirmAction()
    {
        GameObject.Find("NFAGraphManager").GetComponent<NFAGraphManager>().AddEdge(letterToInt[transform.Find("EdgeLetter").GetComponent<TMP_InputField>().text], fromNodeID, toNodeID);

        this.gameObject.SetActive(false);
    }
}