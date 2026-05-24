using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class RulePrefabBehaviour : MonoBehaviour
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
        frame.GetComponent<Image>().color = baseColor;
        myText.GetComponent<TMP_Text>().color = baseColor;
    }
    
    //----------------------------------------------------------

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
        Image frameImage = frame.GetComponent<Image>();
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
