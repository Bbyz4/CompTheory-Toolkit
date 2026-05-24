using UnityEngine;

public class DiGraphPopupManager : MonoBehaviour
{
    [SerializeField] private DiGraphGeneralInfoPopup generalInfoPopup;
    [SerializeField] private DiGraphNodeAddPopup nodeAddPopup;
    [SerializeField] private DiGraphNodeEditPopup nodeEditPopup;
    [SerializeField] private DiGraphEdgeAddPopup edgeAddPopup;
    [SerializeField] private DiGraphEdgeEditPopup edgeEditPopup;
    [SerializeField] private DiGraphTestRunPopup testRunPopup;

    void Awake()
    {
        ResetToGeneralInfoPopup();
    }

    public void ResetToGeneralInfoPopup()
    {
        generalInfoPopup.Activate();

        nodeAddPopup.gameObject.SetActive(false);
        nodeEditPopup.gameObject.SetActive(false);
        edgeAddPopup.gameObject.SetActive(false);
        edgeEditPopup.gameObject.SetActive(false);
        testRunPopup.gameObject.SetActive(false);
    }

    public void ActivateNodeAddPopup(Vector2 clickPosition)
    {
        nodeAddPopup.Activate(clickPosition);
    }

    public bool IsAnyBlockingPopupActive()
    {
        return nodeAddPopup.gameObject.activeInHierarchy
        || nodeEditPopup.gameObject.activeInHierarchy
        || edgeAddPopup.gameObject.activeInHierarchy
        || edgeEditPopup.gameObject.activeInHierarchy;
    }

    public void ActivateEdgeAddPopup(int fromID, int toID)
    {
        edgeAddPopup.Activate(fromID, toID);
    }

    public void ActivateNodeEditPopup(DiGraphNodeData node)
    {
        nodeEditPopup.Activate(node);
    }

    public void ActivateEdgeEditPopup(DiGraphEdgeData edge)
    {
        edgeEditPopup.Activate(edge);
    }

    public void ActivateTestRunPopup()
    {
        testRunPopup.Activate();
    }
}
