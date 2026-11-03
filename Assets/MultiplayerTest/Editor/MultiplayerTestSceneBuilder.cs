using ProyectoFinalRV.MultiplayerTest;
using Unity.Netcode;
using Unity.Netcode.Components;
using Unity.Netcode.Transports.UTP;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ProyectoFinalRV.MultiplayerTest.Editor
{
    public static class MultiplayerTestSceneBuilder
    {
        private const string ScenePath = "Assets/MultiplayerTest/MultiplayerTest.unity";
        private const string PlayerPath = "Assets/MultiplayerTest/TestPlayer.prefab";

        [MenuItem("Tools/Multiplayer Test/Build Test Scene")]
        public static void Build()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
            ground.name = "Ground";
            ground.transform.position = new Vector3(0f, -0.5f, 0f);
            ground.transform.localScale = new Vector3(200f, 1f, 200f);

            var cameraObject = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener), typeof(TestCamera));
            cameraObject.tag = "MainCamera";
            cameraObject.transform.position = new Vector3(0f, 8f, -12f);
            cameraObject.transform.LookAt(Vector3.up);

            var lightObject = new GameObject("Directional Light", typeof(Light));
            lightObject.GetComponent<Light>().type = LightType.Directional;
            lightObject.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            var player = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            player.name = "TestPlayer";
            Object.DestroyImmediate(player.GetComponent<CapsuleCollider>());
            player.AddComponent<CharacterController>();
            player.AddComponent<NetworkObject>();
            player.AddComponent<NetworkTransform>();
            player.AddComponent<TestPlayer>();
            PrefabUtility.SaveAsPrefabAsset(player, PlayerPath);
            Object.DestroyImmediate(player);
            // NGO's prefab hash is generated after the asset receives its stable GUID.
            // Persist it now so host and virtual players register the same prefab ID.
            AssetDatabase.ImportAsset(PlayerPath, ImportAssetOptions.ForceUpdate);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PlayerPath);
            var prefabNetworkObject = prefab.GetComponent<NetworkObject>();
            EditorUtility.SetDirty(prefabNetworkObject);
            AssetDatabase.SaveAssetIfDirty(prefab);

            var networkObject = new GameObject("NetworkManager", typeof(UnityTransport),
                typeof(NetworkManager), typeof(MultiplayerMenu));
            var networkManager = networkObject.GetComponent<NetworkManager>();
            var transport = networkObject.GetComponent<UnityTransport>();
            transport.MaxPacketQueueSize = 1024;
            networkManager.NetworkConfig.NetworkTransport = transport;
            networkManager.NetworkConfig.PlayerPrefab = prefab;
            networkManager.NetworkConfig.TickRate = 20;
            networkManager.NetworkConfig.EnableSceneManagement = true;
            networkManager.NetworkConfig.ConnectionApproval = true;

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(ScenePath, true),
                new EditorBuildSettingsScene("Assets/Scenes/SampleScene.unity", false)
            };
            AssetDatabase.SaveAssets();
            Debug.Log("[MultiplayerTest] Scene and player prefab created: " + ScenePath);
        }
    }
}
