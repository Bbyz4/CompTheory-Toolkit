using System;
using TMPro;
using UnityEngine;

public class DiGraphEdgeDisplay : MonoBehaviour
{
    private DiGraphEdgeData edgeData;

    private TMP_Text edgeName;

    private Transform labelTransform;
    private SpriteRenderer edgeRenderer;

    [SerializeField] private Sprite normalEdge;
    [SerializeField] private Sprite selfEdge;

    private string epsilon = "ε";
    [SerializeField] private float DIST_BETWEEN_LABELS = 0.5f;

    private BoxCollider2D collider2D;

    void Awake()
    {
        edgeData = gameObject.GetComponent<DiGraphEdgeData>();

        edgeName = transform.Find("Label").GetComponent<TMP_Text>();

        labelTransform = transform.Find("Label");

        edgeRenderer = transform.Find("Edge").GetComponent<SpriteRenderer>();

        collider2D = GetComponent<BoxCollider2D>();
    }

    public void SetPositionAndRotation(Vector3 from, Vector3 to)
    {
        Vector3 direction = to - from;
        float distance = direction.magnitude;

        Vector3 dirNorm = direction.normalized;

        Vector3 rightNormal = new Vector3(dirNorm.y, -dirNorm.x, 0f);
        Vector3 leftNormal  = new Vector3(-dirNorm.y, dirNorm.x, 0f);

        Vector3 midPoint = (from + to) / 2f;

        float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;

        float edgeOffset = 0.05f;

        transform.position = midPoint + leftNormal * edgeOffset;

        transform.rotation = Quaternion.Euler(0f, 0f, angle);

        transform.Find("Edge").GetComponent<SpriteRenderer>().size = new Vector2(distance - (2141f/2825f), transform.localScale.y);

        float offset = 0.3f + edgeData.interlalListIndex * DIST_BETWEEN_LABELS; 

        if (Mathf.Abs(angle) > 90f)
        {
            labelTransform.localRotation = Quaternion.Euler(0f, 0f, 180f);

            labelTransform.position = midPoint + leftNormal * offset;
        }
        else
        {
            labelTransform.localRotation = Quaternion.Euler(0f, 0f, 0f);

            labelTransform.position = midPoint + leftNormal * offset;
            
        }

        collider2D.offset = (Vector2)transform.InverseTransformPoint(labelTransform.position);
    }

    public void UpdateDisplay()
    {
        if(ModelData.modelType == ModelData.ModelType.PDA)
        {
            edgeName.text = $"{(edgeData.inputSymbol != "" ? edgeData.inputSymbol : epsilon)}, {edgeData.stackSymbol} ->";
        
            string pushed = "";
            foreach(string s in edgeData.toPush)
            {
                pushed += s;
            }

            if(pushed == "")
            {
                pushed = epsilon;
            }

            edgeName.text += $" {pushed}";
        }
        else if(ModelData.modelType == ModelData.ModelType.NFA)
        {
            edgeName.text = $"{(edgeData.inputSymbol != "" ? edgeData.inputSymbol : epsilon)}";
        }

        if(edgeData.begin != edgeData.end)
        {
            edgeRenderer.sprite = normalEdge;
            edgeRenderer.color = Color.black; //temp, change sprite later

            Vector3 fromPos = edgeData.begin.gameObject.transform.position;
            Vector3 toPos = edgeData.end.gameObject.transform.position;

            SetPositionAndRotation(fromPos, toPos);   
        }
        else
        {
            edgeRenderer.sprite = selfEdge;
            edgeRenderer.size = new Vector2(2f,2f);

            transform.position = edgeData.begin.gameObject.transform.position + new Vector3(-0.05f, 0.9f, 0f);

            labelTransform.position = transform.position;

            labelTransform.position += new Vector3(0f, edgeData.interlalListIndex * DIST_BETWEEN_LABELS, 0f);
        
            collider2D.offset = (Vector2)transform.InverseTransformPoint(labelTransform.position);
        }
    }
}
