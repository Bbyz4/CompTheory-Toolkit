using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class GraphNodePrefabBehaviour : MonoBehaviour
{
    [SerializeField] private Color baseColor;
    [SerializeField] private Color highlightColor;

    private GameObject frame;
    private GameObject myText;

    void Awake()
    {
        frame = transform.Find("Frame").gameObject;
        myText = transform.Find("Text").gameObject;
    }

    public void FillText(string newText)
    {
        myText.GetComponent<TMP_Text>().text = newText;
    }

    public void ResetColor()
    {
        frame.GetComponent<SpriteRenderer>().color = baseColor;
        myText.GetComponent<TMP_Text>().color = baseColor;
    }

    //-----------------------------------------------------
    
    private Coroutine moveRoutine;
    private Coroutine highlightRoutine;
    
    public void MoveAnimation(Vector3 targetPosition, float time)
    {
        if (moveRoutine != null)
        {
            StopCoroutine(moveRoutine);
        }

        moveRoutine = StartCoroutine(MoveCoroutine(targetPosition, time));
    }

    private IEnumerator MoveCoroutine(Vector3 targetPosition, float time)
    {
        Vector3 startPos = transform.localPosition;

        float t = 0f;

        while (t < time)
        {
            t += Time.deltaTime;
            float lerp = t / time;

            transform.localPosition = Vector3.Lerp(startPos, targetPosition, lerp);
            yield return null;
        }

        transform.localPosition = targetPosition;
    }

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
        SpriteRenderer frameImage = frame.GetComponent<SpriteRenderer>();
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
