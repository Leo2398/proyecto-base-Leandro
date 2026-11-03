using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace FactoryArena.Editor
{
    public static class FactoryVisualReview
    {
        const string Output = "Assets/FactoryArena/Generated/Redesign/";

        public static void FinishAssets()
        {
            if (Application.isPlaying) throw new System.InvalidOperationException("Stop Play Mode before saving assets.");
            var root = GameObject.Find("VisualRedesign");
            if (!root) throw new System.InvalidOperationException("Open FactoryArena.");
            var motion = root.GetComponent<FactoryVisualMotion>();
            foreach (var r in root.GetComponentsInChildren<Renderer>())
            {
                bool moving = r.transform.IsChildOf(motion.ram) || motion.gears.Any(t => r.transform.IsChildOf(t)) ||
                    motion.directionArrows.Any(t => r.transform.IsChildOf(t));
                if (!moving) GameObjectUtility.SetStaticEditorFlags(r.gameObject, StaticEditorFlags.BatchingStatic);
                if (r.GetComponent<TextMesh>() || r.name.Contains("strip") || r.name.Contains("bolt") || r.name.Contains("hatch"))
                    r.shadowCastingMode = ShadowCastingMode.Off;
            }
            foreach (var m in root.GetComponentsInChildren<Renderer>().SelectMany(r => r.sharedMaterials).Where(m => m).Distinct())
            { m.enableInstancing = true; EditorUtility.SetDirty(m); }
            string[] roots = { "Exterior production campus", "Conveyor drive assemblies", "Operator stations", "Hydraulic press visual assembly" };
            string[] names = { "IndustrialCampus", "ConveyorDriveVisuals", "OperatorStationVisuals", "HydraulicPressVisuals" };
            for (int i = 0; i < roots.Length; i++)
                PrefabUtility.SaveAsPrefabAsset(root.transform.Find(roots[i]).gameObject, "Assets/FactoryArena/Prefabs/Visuals/" + names[i] + ".prefab");
            var scene = root.scene;
            EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); AssetDatabase.SaveAssets();
            AuditScene();
        }

        public static string AuditScene()
        {
            var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            var objects = scene.GetRootGameObjects().SelectMany(g => g.GetComponentsInChildren<Transform>(true)).ToArray();
            var renderers = objects.Select(t => t.GetComponent<Renderer>()).Where(r => r && r.enabled && r.gameObject.activeInHierarchy).ToArray();
            var mats = renderers.SelectMany(r => r.sharedMaterials).Distinct().ToArray();
            int missingScripts = objects.Sum(t => GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(t.gameObject));
            var report = new StringBuilder(scene.name + " integrity audit\n");
            report.AppendLine("Missing scripts=" + missingScripts);
            int missingRefs = 0;
            foreach (var component in objects.SelectMany(t => t.GetComponents<Component>()).Where(c => c))
            {
                using (var serialized = new SerializedObject(component))
                {
                    var p = serialized.GetIterator();
                    while (p.Next(true))
                        if (p.propertyType == SerializedPropertyType.ObjectReference && p.objectReferenceValue == null && !p.objectReferenceEntityIdValue.Equals(default(UnityEngine.EntityId)))
                        { missingRefs++; report.AppendLine("MISSING: " + component.name + " / " + p.propertyPath); }
                }
            }
            report.AppendLine("Broken serialized object references=" + missingRefs);
            report.AppendLine("Enabled renderers=" + renderers.Length + " distinct materials=" + mats.Length);
            report.AppendLine("Null/unsupported/error materials=" + mats.Count(m => !m || !m.shader || !m.shader.isSupported || m.shader.name.Contains("InternalError")));
            long triangles = 0;
            foreach (var renderer in renderers)
            {
                var mesh = renderer.GetComponent<MeshFilter>();
                if (mesh && mesh.sharedMesh) for (int i = 0; i < mesh.sharedMesh.subMeshCount; i++) triangles += (long)mesh.sharedMesh.GetIndexCount(i) / 3;
            }
            report.AppendLine("Instanced triangle inventory (not visibility-corrected)=" + triangles);
            foreach (var light in objects.Select(t => t.GetComponent<Light>()).Where(l => l && l.enabled))
                report.AppendLine("Light=" + light.name + " type=" + light.type + " shadows=" + light.shadows);
            var camera = Camera.main;
            if (camera) report.AppendLine("Main camera HDR=" + camera.allowHDR + " postprocessing=" + camera.GetUniversalAdditionalCameraData().renderPostProcessing);
            report.AppendLine("Colliders=" + objects.Sum(t => t.GetComponents<Collider>().Length) + " rigidbodies=" + objects.Sum(t => t.GetComponents<Rigidbody>().Length));
            File.WriteAllText(Output + scene.name + "Integrity.txt", report.ToString());
            return report.ToString();
        }

        public static void CaptureViews()
        {
            var camera = Camera.main; var position = camera.transform.position; var rotation = camera.transform.rotation;
            try
            {
                ArtCatalog.Capture(camera, Output + "Gameplay.png");
                string[] names = { "Press", "Conveyors", "Lever", "Exterior", "Front", "Elevated", "Side" };
                Vector3[] positions = { new Vector3(9,8,-12), new Vector3(10,8,-13), new Vector3(-13,4,-4), new Vector3(30,20,0), new Vector3(0,24,-40), new Vector3(0,45,0), new Vector3(39,22,-9) };
                Vector3[] targets = { new Vector3(0,3,0), new Vector3(0,0,-5), new Vector3(-10,1,0), new Vector3(0,0,14), Vector3.zero, Vector3.zero, Vector3.zero };
                for (int i=0;i<names.Length;i++) { camera.transform.position=positions[i];camera.transform.LookAt(targets[i]);ArtCatalog.Capture(camera,Output+names[i]+".png"); }
            }
            finally { camera.transform.SetPositionAndRotation(position,rotation); }
        }
    }
}
