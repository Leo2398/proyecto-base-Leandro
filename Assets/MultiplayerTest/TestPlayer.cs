using Unity.Netcode;
using Unity.Netcode.Components;
using UnityEngine;
using UnityEngine.InputSystem;

namespace ProyectoFinalRV.MultiplayerTest
{
    [RequireComponent(typeof(NetworkObject), typeof(NetworkTransform), typeof(CharacterController))]
    public sealed class TestPlayer : NetworkBehaviour
    {
        private CharacterController controller;
        private Vector2 input;
        private bool jumpRequested;
        private float verticalSpeed;
        private float nextInputTime;
        private bool pendingJump;
        private Vector2 lastSentInput;
        private Renderer bodyRenderer;

        private static readonly Color[] Colors =
        {
            new Color(0.25f, 0.65f, 1f),
            new Color(1f, 0.4f, 0.3f),
            new Color(0.4f, 0.9f, 0.4f),
            new Color(1f, 0.8f, 0.25f)
        };

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            bodyRenderer = GetComponent<Renderer>();
        }

        public override void OnNetworkSpawn()
        {
            controller.enabled = IsServer;
            if (IsServer)
            {
                var slot = (int)(OwnerClientId % 4);
                controller.enabled = false;
                transform.position = new Vector3((slot % 2) * 3f - 1.5f, 1.2f,
                    (slot / 2) * 3f - 1.5f);
                controller.enabled = true;
            }
            var color = Colors[(int)(OwnerClientId % (ulong)Colors.Length)];
            var block = new MaterialPropertyBlock();
            block.SetColor("_BaseColor", color);
            bodyRenderer.SetPropertyBlock(block);

            var labelObject = new GameObject("PlayerLabel");
            labelObject.transform.SetParent(transform, false);
            labelObject.transform.localPosition = new Vector3(0, 1.35f, 0);
            var label = labelObject.AddComponent<TextMesh>();
            label.text = "Jugador " + (OwnerClientId + 1);
            label.anchor = TextAnchor.MiddleCenter;
            label.alignment = TextAlignment.Center;
            label.characterSize = 0.22f;
            label.fontSize = 32;
            label.color = Color.white;

            if (IsOwner)
            {
                var camera = Camera.main;
                if (camera != null)
                    camera.GetComponent<TestCamera>().Target = transform;
            }
        }

        private void Update()
        {
            if (!IsOwner || !IsSpawned || Keyboard.current == null)
                return;

            var keyboard = Keyboard.current;
            pendingJump |= keyboard.spaceKey.wasPressedThisFrame;
            var move = new Vector2(
                (keyboard.dKey.isPressed ? 1 : 0) - (keyboard.aKey.isPressed ? 1 : 0),
                (keyboard.wKey.isPressed ? 1 : 0) - (keyboard.sKey.isPressed ? 1 : 0));
            move = Vector2.ClampMagnitude(move, 1f);
            if (move == lastSentInput && !pendingJump &&
                (move == Vector2.zero || Time.time < nextInputTime))
                return;
            SubmitInputRpc(move, pendingJump);
            lastSentInput = move;
            pendingJump = false;
            nextInputTime = Time.time + 0.1f;
        }

        [Rpc(SendTo.Server)]
        private void SubmitInputRpc(Vector2 move, bool jump)
        {
            input = Vector2.ClampMagnitude(move, 1f);
            jumpRequested |= jump;
        }

        private void FixedUpdate()
        {
            if (!IsSpawned || !IsServer || !controller.enabled)
                return;

            if (controller.isGrounded && verticalSpeed < 0f)
                verticalSpeed = -1f;
            if (jumpRequested && controller.isGrounded)
                verticalSpeed = 6f;
            jumpRequested = false;
            verticalSpeed += Physics.gravity.y * Time.fixedDeltaTime;

            var movement = new Vector3(input.x * 5f, verticalSpeed, input.y * 5f);
            controller.Move(movement * Time.fixedDeltaTime);
            var horizontal = new Vector3(input.x, 0f, input.y);
            if (horizontal.sqrMagnitude > 0.01f)
                transform.rotation = Quaternion.RotateTowards(transform.rotation,
                    Quaternion.LookRotation(horizontal), 720f * Time.fixedDeltaTime);
        }
    }
}
