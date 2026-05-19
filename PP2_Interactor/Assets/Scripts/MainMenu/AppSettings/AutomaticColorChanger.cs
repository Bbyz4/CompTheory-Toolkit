using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class AutomaticColorChanger : MonoBehaviour
{
    [SerializeField] private float interpolationValue;
    [SerializeField] private bool callOnAwake;

    private Image image;
    private TMP_Text text;

    void Awake()
    {
        image = GetComponent<Image>();
        text = GetComponent<TMP_Text>();

        ApplicationData.ColorSettingsChanged += OnColorChanged;
    
        if(callOnAwake)
        {
            OnColorChanged();
        }
    }

    void OnDestroy()
    {
        ApplicationData.ColorSettingsChanged -= OnColorChanged;
    }

    private void OnColorChanged()
    {
        if(!ApplicationData.wasColorEverModified)
        {
            return;
        }

        Color color = Color.Lerp(ApplicationData.mainColor1, ApplicationData.mainColor2, interpolationValue);

        if(image != null)
        {
            image.color = color;
        }

        if(text != null)
        {
            text.color = color;
        }

        callOnAwake = true;
    }
}