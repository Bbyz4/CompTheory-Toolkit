using UnityEngine;
using UnityEngine.EventSystems;

public class DiGraphInputManager : MonoBehaviour
{
    private DiGraphPopupManager dgpm;
    [SerializeField] private FreeRunManager frm;
    private int INPUT_MODE;

    private DiGraphNodeDisplay mode0FirstHitNode;
    private DiGraphNodeDisplay prevHoveredNode;
    private DiGraphNodeDisplay mode2MovedNode;
    [SerializeField] private GameObject mode0TempEdgeObject;

    void Awake()
    {
        INPUT_MODE = 0;

        dgpm = GameObject.FindWithTag("DiGraphPopupManager").GetComponent<DiGraphPopupManager>();
    }

    public void ChangeInputMode(int newVal)
    {
        if(newVal < 0 || newVal > 3)
        {
            return;
        }

        INPUT_MODE = newVal;

        if(newVal == 3)
        {
            dgpm.ActivateTestRunPopup();
        }
        else
        {
            dgpm.ResetToGeneralInfoPopup();
        }
    }

    private bool IsPointerOverUI()
    {
        return EventSystem.current != null && EventSystem.current.IsPointerOverGameObject();
    }

    public struct DiGraphHitResult
    {
        public DiGraphNodeDisplay node;
        public DiGraphEdgeDisplay edge;
        public Collider2D collider;
    }

    private DiGraphHitResult GetBestHit()
    {
        Vector2 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);

        RaycastHit2D[] hits = Physics2D.RaycastAll(worldPos, Vector2.zero);

        DiGraphNodeDisplay foundNode = null;
        DiGraphEdgeDisplay foundEdge = null;
        Collider2D bestCollider = null;

        foreach (var hit in hits)
        {
            if (bestCollider == null)
                bestCollider = hit.collider;

            if (foundNode == null)
            {
                foundNode = hit.collider.gameObject.GetComponent<DiGraphNodeDisplay>();
            }

            if (foundEdge == null)
            {
                foundEdge = hit.collider.gameObject.GetComponent<DiGraphEdgeDisplay>();
            }
        }

        return new DiGraphHitResult
        {
            node = foundNode,
            edge = foundEdge,
            collider = bestCollider
        };
    }

    void Update()
    {
        if(dgpm.IsAnyBlockingPopupActive())
        {
            return;
        }

        var hit = GetBestHit();

        var node = hit.node;
        var edge = hit.edge;

        if(node != null)
        {
            if(node != prevHoveredNode)
            {
                if(prevHoveredNode != null)
                {
                    prevHoveredNode.Deselect();
                }

                node.Select();
                prevHoveredNode = node;
            }
        }

        if(node == null)
        {
            if(prevHoveredNode != null)
            {
                prevHoveredNode.Deselect();
            }

            prevHoveredNode = null;
        }

        switch(INPUT_MODE)
        {
            case 0:

                if(IsPointerOverUI())
                {
                    return;
                }

                if(Input.GetMouseButtonDown(0) && node != null)
                {
                    mode0FirstHitNode = node;
                }

                if(Input.GetMouseButtonUp(0) && node != null && mode0FirstHitNode != null)
                {
                    dgpm.ActivateEdgeAddPopup(mode0FirstHitNode.gameObject.GetComponent<DiGraphNodeData>().internalID, node.GetComponent<DiGraphNodeData>().internalID);
                }

                if(Input.GetMouseButtonUp(0) && node == null && mode0FirstHitNode == null)
                {
                    Vector2 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
                    dgpm.ActivateNodeAddPopup(worldPos); 
                }

                if(Input.GetMouseButtonUp(0))
                {
                    mode0FirstHitNode = null;
                }

                if(mode0FirstHitNode != null)
                {
                    mode0TempEdgeObject.SetActive(true);

                    Vector3 from = mode0FirstHitNode.transform.position;
                    Vector3 to = Camera.main.ScreenToWorldPoint(Input.mousePosition);
                    to.z = 0f;
                
                    Vector3 midPoint = (from + to) / 2f;
                    mode0TempEdgeObject.transform.position = midPoint;

                    Vector3 direction = to - from;
                    float distance = direction.magnitude;

                    float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;

                    mode0TempEdgeObject.transform.rotation = Quaternion.Euler(0f, 0f, angle);

                    var edgeRenderer = mode0TempEdgeObject.transform.Find("Edge").GetComponent<SpriteRenderer>();

                    edgeRenderer.size = new Vector2(
                        distance - (2141f/2825f),
                        edgeRenderer.size.y
                    );
                }
                else
                {
                    mode0TempEdgeObject.SetActive(false);
                }

                break;

            case 1:
                if(Input.GetMouseButtonDown(0))
                {
                    if(node != null)
                    {
                        dgpm.ActivateNodeEditPopup(node.GetComponent<DiGraphNodeData>());
                    }
                    else if(edge != null)
                    {
                        dgpm.ActivateEdgeEditPopup(edge.GetComponent<DiGraphEdgeData>());
                    }
                }

                break;

            case 2:
                if(mode2MovedNode != null)
                {
                    Vector2 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
                    mode2MovedNode.transform.position = worldPos;
                }

                if(mode2MovedNode != null)
                {
                    foreach (DiGraphEdgeData e in mode2MovedNode.GetComponent<DiGraphNodeData>().edges)
                    {
                        e.GetComponent<DiGraphEdgeDisplay>().UpdateDisplay();
                    }
                }

                if(Input.GetMouseButtonUp(0))
                {
                    mode2MovedNode = null;
                }

                if(Input.GetMouseButtonDown(0) && node != null)
                {
                    mode2MovedNode = node;
                }

                break;

            case 3:
                if(Input.GetMouseButtonDown(0))
                {
                    if(edge != null)
                    {
                        frm.HandleEdgeClick(edge.GetComponent<DiGraphEdgeData>());
                    }
                }

                break;

            default:
                break;
        }
    }
}
