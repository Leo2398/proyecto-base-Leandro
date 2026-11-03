using System;
using Unity.Netcode;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

namespace ProyectoFinalRV.MultiplayerTest
{
    [RequireComponent(typeof(NetworkManager))]
    public sealed class MultiplayerMenu : MonoBehaviour
    {
        private NetworkManager manager;
        private ISession session;
        private InputField codeInput;
        private Text statusText;
        private Button createButton;
        private Button joinButton;
        private Button leaveButton;
        private bool ready;
        private bool busy;
        private Font font;

        private void Awake()
        {
            manager = GetComponent<NetworkManager>();
            manager.NetworkConfig.ConnectionApproval = true;
            manager.ConnectionApprovalCallback = ApproveConnection;
            BuildMenu();
        }

        private async void Start()
        {
            SetStatus("Conectando con Unity Services...");
            try
            {
                await UnityServices.InitializeAsync();
                if (!AuthenticationService.Instance.IsSignedIn)
                    await AuthenticationService.Instance.SignInAnonymouslyAsync();
                ready = true;
                SetStatus("Listo. Crea una sala privada o introduce un código.");
            }
            catch (Exception ex)
            {
                SetStatus("No se pudo iniciar Unity Services: " + ex.Message);
                Debug.LogException(ex);
            }
            RefreshButtons();
        }

        private void ApproveConnection(NetworkManager.ConnectionApprovalRequest request,
            NetworkManager.ConnectionApprovalResponse response)
        {
            var approved = manager.ConnectedClientsIds.Count < 4;
            response.Approved = approved;
            response.CreatePlayerObject = approved;
            response.Pending = false;
            response.Reason = approved ? string.Empty : "Sala completa";
            var slot = (int)(request.ClientNetworkId % 4);
            response.Position = new Vector3((slot % 2) * 3f - 1.5f, 1.2f,
                (slot / 2) * 3f - 1.5f);
            response.Rotation = Quaternion.identity;
        }

        private async void CreateRoom()
        {
            if (!ready || busy || session != null) return;
            busy = true;
            RefreshButtons();
            SetStatus("Creando sala privada...");
            try
            {
                var options = new SessionOptions { MaxPlayers = 4, IsPrivate = true };
                session = await MultiplayerService.Instance.CreateSessionAsync(options.WithRelayNetwork());
                SetStatus("Sala creada. Código: " + session.Code + " | Jugadores: " + session.PlayerCount + "/4");
            }
            catch (Exception ex)
            {
                SetStatus("Error al crear sala: " + ex.Message);
                Debug.LogException(ex);
            }
            busy = false;
            RefreshButtons();
        }

        private async void JoinRoom()
        {
            if (!ready || busy || session != null) return;
            var code = codeInput.text.Trim().ToUpperInvariant();
            if (code.Length == 0) { SetStatus("Introduce el código de la sala."); return; }
            busy = true;
            RefreshButtons();
            SetStatus("Uniéndose a " + code + "...");
            try
            {
                session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code);
                SetStatus("Conectado a " + session.Code + " | Jugadores: " + session.PlayerCount + "/4");
            }
            catch (Exception ex)
            {
                SetStatus("Error al unirse: " + ex.Message);
                Debug.LogException(ex);
            }
            busy = false;
            RefreshButtons();
        }

        private async void LeaveRoom()
        {
            if (session == null || busy) return;
            busy = true;
            RefreshButtons();
            try
            {
                await session.LeaveAsync();
                session = null;
                SetStatus("Has salido de la sala.");
            }
            catch (Exception ex)
            {
                SetStatus("Error al salir: " + ex.Message);
                Debug.LogException(ex);
            }
            busy = false;
            RefreshButtons();
        }

        private void RefreshButtons()
        {
            createButton.interactable = ready && !busy && session == null;
            joinButton.interactable = ready && !busy && session == null;
            leaveButton.interactable = !busy && session != null;
        }

        private void Update()
        {
            if (session == null || busy || !manager.IsListening) return;
            var prefix = manager.IsHost ? "Sala creada. Código: " : "Conectado a ";
            var message = prefix + session.Code + " | Jugadores: " +
                manager.ConnectedClientsIds.Count + "/4";
            if (statusText.text != message) statusText.text = message;
        }

        private void SetStatus(string message)
        {
            statusText.text = message;
            Debug.Log("[MultiplayerTest] " + message);
        }

        private void BuildMenu()
        {
            font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            var canvasObject = new GameObject("MultiplayerCanvas", typeof(Canvas),
                typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvasObject.GetComponent<CanvasScaler>().uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            canvasObject.GetComponent<CanvasScaler>().referenceResolution = new Vector2(1280, 720);

            if (FindAnyObjectByType<EventSystem>() == null)
                new GameObject("EventSystem", typeof(EventSystem), typeof(InputSystemUIInputModule));

            var panel = new GameObject("MenuPanel", typeof(RectTransform), typeof(Image));
            panel.transform.SetParent(canvasObject.transform, false);
            var panelRect = panel.GetComponent<RectTransform>();
            panelRect.anchorMin = panelRect.anchorMax = new Vector2(0f, 1f);
            panelRect.pivot = new Vector2(0f, 1f);
            panelRect.anchoredPosition = new Vector2(16f, -16f);
            panelRect.sizeDelta = new Vector2(410f, 236f);
            panel.GetComponent<Image>().color = new Color(0.06f, 0.09f, 0.15f, 0.9f);

            MakeText(panel.transform, "Título", "MultiplayerTest · 2–4 jugadores", 22,
                new Vector2(16, -12), new Vector2(380, 34));
            createButton = MakeButton(panel.transform, "Crear sala privada", new Vector2(16, -55), CreateRoom);
            codeInput = MakeInput(panel.transform, new Vector2(16, -102));
            joinButton = MakeButton(panel.transform, "Unirse por código", new Vector2(212, -102), JoinRoom);
            leaveButton = MakeButton(panel.transform, "Salir de sala", new Vector2(16, -149), LeaveRoom);
            statusText = MakeText(panel.transform, "Estado", "Preparando...", 15,
                new Vector2(16, -193), new Vector2(380, 36));
            RefreshButtons();
        }

        private Text MakeText(Transform parent, string name, string value, int size,
            Vector2 position, Vector2 dimensions)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Text));
            obj.transform.SetParent(parent, false);
            var rect = obj.GetComponent<RectTransform>();
            rect.anchorMin = rect.anchorMax = new Vector2(0f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = position;
            rect.sizeDelta = dimensions;
            var label = obj.GetComponent<Text>();
            label.font = font;
            label.fontSize = size;
            label.color = Color.white;
            label.text = value;
            label.horizontalOverflow = HorizontalWrapMode.Wrap;
            return label;
        }

        private Button MakeButton(Transform parent, string title, Vector2 position, Action action)
        {
            var obj = new GameObject(title, typeof(RectTransform), typeof(Image), typeof(Button));
            obj.transform.SetParent(parent, false);
            var rect = obj.GetComponent<RectTransform>();
            rect.anchorMin = rect.anchorMax = new Vector2(0f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = position;
            rect.sizeDelta = new Vector2(184f, 36f);
            obj.GetComponent<Image>().color = new Color(0.18f, 0.39f, 0.65f);
            MakeText(obj.transform, "Label", title, 16, new Vector2(8, -6), new Vector2(170, 26));
            var button = obj.GetComponent<Button>();
            button.onClick.AddListener(() => action());
            return button;
        }

        private InputField MakeInput(Transform parent, Vector2 position)
        {
            var obj = new GameObject("Código", typeof(RectTransform), typeof(Image), typeof(InputField));
            obj.transform.SetParent(parent, false);
            var rect = obj.GetComponent<RectTransform>();
            rect.anchorMin = rect.anchorMax = new Vector2(0f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = position;
            rect.sizeDelta = new Vector2(184f, 36f);
            obj.GetComponent<Image>().color = Color.white;
            var text = MakeText(obj.transform, "Texto", "", 17,
                new Vector2(8, -6), new Vector2(170, 26));
            text.color = Color.black;
            var placeholder = MakeText(obj.transform, "Placeholder", "Código", 17,
                new Vector2(8, -6), new Vector2(170, 26));
            placeholder.color = Color.gray;
            var field = obj.GetComponent<InputField>();
            field.textComponent = text;
            field.placeholder = placeholder;
            return field;
        }
    }
}
