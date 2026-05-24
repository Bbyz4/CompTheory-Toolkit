using System;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.UI.Extensions;
using UnityEngine.UI.Extensions.ColorPicker;

public class ColorPickerTab : MonoBehaviour
{
    [SerializeField] private Button applyButton;
    
    [SerializeField] private ColorPickerControl color1;
    [SerializeField] private ColorPickerControl color2;
    


    public void ChangeColorTheme()
    {
        Color c1 = color1.CurrentColor;
        Color c2 = color2.CurrentColor;

        int textureWidth = 16;
        int textureHeight = 9;

        Texture2D texture = new Texture2D(textureWidth, textureHeight);

        for(int y=0; y<textureHeight; y++)
        {
            for(int x=0; x<textureWidth; x++)
            {
                float ux = x/(float)(textureWidth-1);
                float uy = 1f - (y / (float)(textureHeight - 1));

                float u = (ux+uy) * 0.5f;

                Color pixelColor = Color.Lerp(c1, c2, u);
                texture.SetPixel(x,y,pixelColor);
            }
        }

        texture.Apply();

        Sprite sprite = Sprite.Create(
            texture,
            new Rect(0, 0, textureWidth, textureHeight),
            new Vector2(0.5f, 0.5f)
        );

        ApplicationData.mainColor1 = c1;
        ApplicationData.mainColor2 = c2;
        ApplicationData.backgroundSprite = sprite;
        
        ApplicationData.InvokeColorSettingsChanged();
    }
}