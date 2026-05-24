using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class DiGraphToolbarColorManager : MonoBehaviour
{
    [SerializeField] private List<Image> toolbarButtons;

    private List<Color> toolbarOriginalColors;

    [SerializeField] private Color highlightColor;

    void Start()
    {
        toolbarOriginalColors = new List<Color>();

        foreach(Image go in toolbarButtons)
        {
            toolbarOriginalColors.Add(go.color);
        }
    }

    public void HighlightButton(int buttonIndex)
    {
        for(int i=0; i<toolbarButtons.Count; i++)
        {
            toolbarButtons[i].color = toolbarOriginalColors[i];
            toolbarButtons[i].transform.GetChild(0).GetComponent<Image>().color = toolbarOriginalColors[i];
        }

        toolbarButtons[buttonIndex].color = highlightColor;
        toolbarButtons[buttonIndex].transform.GetChild(0).GetComponent<Image>().color = highlightColor;
    }
}
