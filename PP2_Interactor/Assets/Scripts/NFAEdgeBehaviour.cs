using System.Collections;
using TMPro;
using UnityEngine;

public class NFAEdgeBehaviour : MonoBehaviour
{
    [SerializeField] private Color baseColor;
    [SerializeField] private Color highlightColor;
    [SerializeField] private float scaleFactor = 1f;

    private GameObject arrow;
    private GameObject myText;

    void Awake()
    {
        arrow = transform.Find("Edge").gameObject;
        myText = transform.Find("Label").gameObject;
    }

    public void FillText(string newText)
    {
        myText.GetComponent<TMP_Text>().text = newText;
    }

    public void ResetColor()
    {
        arrow.GetComponent<SpriteRenderer>().color = baseColor;
        myText.GetComponent<TMP_Text>().color = baseColor;
    }

    public void SetPositionAndRotation(Vector3 from, Vector3 to)
    {
        Vector3 midPoint = (from + to) / 2f;
        transform.position = midPoint;

        Vector3 direction = to - from;
        float distance = direction.magnitude;

        float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;

        transform.rotation = Quaternion.Euler(0f, 0f, angle);

        transform.Find("Edge").GetComponent<SpriteRenderer>().size = new Vector2(distance * scaleFactor, transform.localScale.y);
    }

    //-----------------------------------------------------

    private Coroutine highlightRoutine;

    public void HighlightAnimation(float time)
    {
        if (highlightRoutine != null)
        {
            StopCoroutine(highlightRoutine);
        }

        highlightRoutine = StartCoroutine(HighlightCoroutine(time));
    }

    private IEnumerator HighlightCoroutine(float time)
    {
        SpriteRenderer frameImage = arrow.GetComponent<SpriteRenderer>();
        TMP_Text textComp = myText.GetComponent<TMP_Text>();

        Color startFrame = frameImage.color;
        Color startText = textComp.color;

        float t = 0f;

        while (t < time)
        {
            t += Time.deltaTime;
            float lerp = t / time;

            frameImage.color = Color.Lerp(startFrame, highlightColor, lerp);
            textComp.color = Color.Lerp(startText, highlightColor, lerp);

            yield return null;
        }

        frameImage.color = highlightColor;
        textComp.color = highlightColor;
    }
}
