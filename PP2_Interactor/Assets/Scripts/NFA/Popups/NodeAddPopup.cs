using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class NodeAddPopup : MonoBehaviour
{
    private Vector2 position;

    void Awake()
    {
        this.gameObject.SetActive(false);

        transform.Find("Confirm").GetComponent<Button>().onClick.AddListener(() => ConfirmAction());
    }

    public void LaunchForGivenPos(Vector2 newPos)
    {
        position = newPos;

        this.gameObject.SetActive(true);
    }

    public void ConfirmAction()
    {
        GameObject.Find("NFAGraphManager").GetComponent<NFAGraphManager>().AddNode(transform.Find("NodeName").GetComponent<TMP_InputField>().text, position);

        this.gameObject.SetActive(false);
    }
}
