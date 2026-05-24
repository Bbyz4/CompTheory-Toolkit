using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class AutomaticBackgroundChanger : MonoBehaviour
{
    [SerializeField] private bool callOnAwake = true;


    void Awake()
    {
        ApplicationData.ColorSettingsChanged += OnBGTextureChanged;

        if(callOnAwake)
        {
            OnBGTextureChanged();
        }
    }

    void OnDestroy()
    {
        ApplicationData.ColorSettingsChanged -= OnBGTextureChanged;
    }

    private void OnBGTextureChanged()
    {
        if(!ApplicationData.wasColorEverModified)
        {
            return;
        }

        GetComponent<SpriteRenderer>().sprite = ApplicationData.backgroundSprite;
        transform.localScale = new Vector3(120f, 120f, 1f);

        callOnAwake = true;
    }
}