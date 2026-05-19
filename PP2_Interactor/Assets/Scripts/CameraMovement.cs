using System;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class CameraPanZoom2D : MonoBehaviour
{
    public float panSpeed = 1.0f;
    public float zoomSpeed = 10f;
    public float minZoom = 2f;
    public float maxZoom = 100f;

    private int currentClosestKeyZoomIndex = 5;

    public static event Action<float> OnZoomChanged;

    private Camera cam;
    private Vector3 lastMouseWorldPos;

    private Vector3 defaultBackgroundZoom;

    void Start()
    {
        cam = GetComponent<Camera>();
        cam.orthographic = true;

        cam.orthographicSize = minZoom;

        defaultBackgroundZoom = GameObject.Find("BG").transform.localScale;
    }

    void Update()
    {
        HandlePan();
        HandleZoom();
    }

    void HandlePan()
    {
        if (Input.GetMouseButtonDown(1))
        {
            lastMouseWorldPos = cam.ScreenToWorldPoint(Input.mousePosition);
        }

        if (Input.GetMouseButton(1))
        {
            Vector3 currentMouseWorldPos = cam.ScreenToWorldPoint(Input.mousePosition);
            Vector3 delta = lastMouseWorldPos - currentMouseWorldPos;

            transform.position += delta;
        }
    }

    void HandleZoom()
    {
        float scroll = Input.GetAxis("Mouse ScrollWheel");

        if (Mathf.Abs(scroll) > 0.0001f)
        {
            cam.orthographicSize -= scroll * zoomSpeed;
            cam.orthographicSize = Mathf.Clamp(cam.orthographicSize, minZoom, maxZoom);
        
            GameObject.Find("BG").transform.localScale = new Vector3(defaultBackgroundZoom.x * (cam.orthographicSize/5f), defaultBackgroundZoom.y * (cam.orthographicSize/5f), defaultBackgroundZoom.z);
        }
    }
}
