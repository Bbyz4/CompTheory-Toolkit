using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using TMPro;
using System.Text;
using System;

public class LoginCanvasBehaviour : MonoBehaviour
{
    [Header("Input Fields")]
    [SerializeField] private TMP_InputField usernameField;
    [SerializeField] private TMP_InputField emailField;
    [SerializeField] private TMP_InputField passwordField;
    [SerializeField] private TMP_Text loginNameText;

    private const string BaseUrl = "https://recognita.xyz/api/v1/auth";

    public void Login()
    {
        StartCoroutine(LoginCoroutine());
    }

    public void Register()
    {
        StartCoroutine(RegisterCoroutine());
    }

    private IEnumerator LoginCoroutine()
    {
        LoginRequest requestBody = new LoginRequest
        {
            username = usernameField.text,
            password = passwordField.text
        };

        string json = JsonUtility.ToJson(requestBody);

        using (UnityWebRequest request = new UnityWebRequest($"{BaseUrl}/login", "POST"))
        {
            byte[] bodyRaw = Encoding.UTF8.GetBytes(json);

            request.uploadHandler = new UploadHandlerRaw(bodyRaw);
            request.downloadHandler = new DownloadHandlerBuffer();

            request.SetRequestHeader("Content-Type", "application/json");

            yield return request.SendWebRequest();

            Debug.Log($"Login Status: {(long)request.responseCode}");
            Debug.Log($"Login Response: {request.downloadHandler.text}");

            if (request.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"Login Error: {request.error}");
            }
            else
            {
                try
                {
                    LoginResponse response =
                        JsonUtility.FromJson<LoginResponse>(request.downloadHandler.text);

                    Debug.Log(response);

                    if (response != null &&
                        response.user != null &&
                        response.tokens != null)
                    {
                        ApplicationData.isUserLogged = true;
                        ApplicationData.loggedUserID = response.user.id;
                        ApplicationData.loggedUserName = response.user.username;
                        ApplicationData.accessToken = response.tokens.access_token;

                        Debug.Log("ESSA");
                        loginNameText.text = response.user.username;
                    }
                }
                catch (Exception ex)
                {
                    Debug.LogError($"Failed to parse login response: {ex}");
                }
            }
        }
    }

    private IEnumerator RegisterCoroutine()
    {
        RegisterRequest requestBody = new RegisterRequest
        {
            username = usernameField.text,
            email = emailField.text,
            password = passwordField.text
        };

        string json = JsonUtility.ToJson(requestBody);

        using (UnityWebRequest request = new UnityWebRequest($"{BaseUrl}/register", "POST"))
        {
            byte[] bodyRaw = Encoding.UTF8.GetBytes(json);

            request.uploadHandler = new UploadHandlerRaw(bodyRaw);
            request.downloadHandler = new DownloadHandlerBuffer();

            request.SetRequestHeader("Content-Type", "application/json");

            yield return request.SendWebRequest();

            Debug.Log($"Register Status: {(long)request.responseCode}");
            Debug.Log($"Register Response: {request.downloadHandler.text}");

            if (request.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"Login Error: {request.error}");
            }
        }
    }

    [System.Serializable]
    private class LoginRequest
    {
        public string username;
        public string password;
    }

    [System.Serializable]
    private class RegisterRequest
    {
        public string username;
        public string email;
        public string password;
    }

    [System.Serializable]
    private class LoginResponse
    {
        public UserData user;
        public TokenData tokens;
    }

    [System.Serializable]
    private class UserData
    {
        public int id;
        public string username;
        public string email;
        public string role;
        public bool verified;
        public bool is_banned;
        public string ban_reason;
        public string created_at;
        public string updated_at;
    }

    [System.Serializable]
    private class TokenData
    {
        public string access_token;
        public string refresh_token;
        public string access_expires_at;
        public string refresh_expires_at;
    }
}
