using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
namespace ProyectoFinalRV.Combat.Editor
{
    public static class CombatUpgrade
    {
        public static void AddHands(CombatActor actor)
        {
            if(actor.hands)return;
            var pose=actor.GetComponent<CombatPose>();var hands=actor.gameObject.AddComponent<CombatHands>();hands.actor=actor;actor.hands=hands;hands.fists=new Rigidbody[2];
            actor.vitals=actor.gameObject.AddComponent<CombatVitals>();actor.vitals.actor=actor;
            for(int i=0;i<2;i++)
            {
                var go=pose.hands[i].gameObject;go.AddComponent<SphereCollider>().radius=.5f;
                var rb=go.AddComponent<Rigidbody>();rb.mass=1.1f;rb.linearDamping=.4f;rb.angularDamping=2;rb.interpolation=RigidbodyInterpolation.Interpolate;rb.collisionDetectionMode=CollisionDetectionMode.ContinuousDynamic;rb.solverIterations=12;rb.solverVelocityIterations=4;rb.maxAngularVelocity=8;hands.fists[i]=rb;
                var joint=go.AddComponent<ConfigurableJoint>();joint.connectedBody=actor.body;joint.autoConfigureConnectedAnchor=false;joint.anchor=Vector3.zero;joint.connectedAnchor=new Vector3(i==0?-.32f:.32f,.33f,0);
                joint.xMotion=joint.yMotion=joint.zMotion=ConfigurableJointMotion.Limited;joint.linearLimit=new SoftJointLimit{limit=.85f};joint.angularXMotion=joint.angularYMotion=joint.angularZMotion=ConfigurableJointMotion.Locked;joint.enableCollision=false;joint.projectionMode=JointProjectionMode.PositionAndRotation;joint.projectionDistance=.1f;
            }
        }
        public static void StageC()
        {
            string path="Assets/CombatSystem/Prefabs/PlayerCharacter.prefab";
            var prefab=PrefabUtility.LoadPrefabContents(path);AddHands(prefab.GetComponent<CombatActor>());PrefabUtility.SaveAsPrefabAsset(prefab,path);PrefabUtility.UnloadPrefabContents(prefab);
            foreach(var a in Object.FindObjectsByType<CombatActor>())AddHands(a);
            EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveOpenScenes();AssetDatabase.SaveAssets();
        }
        public static void AddGrabbing(CombatActor actor)
        {
            if(!actor.grabbing){actor.grabbing=actor.gameObject.AddComponent<CombatGrab>();actor.grabbing.actor=actor;}
            var target=actor.GetComponent<Grabbable>();if(!target)target=actor.gameObject.AddComponent<Grabbable>();target.body=actor.body;target.fighter=actor;
        }
        public static void StageD()
        {
            string path="Assets/CombatSystem/Prefabs/PlayerCharacter.prefab";var prefab=PrefabUtility.LoadPrefabContents(path);AddGrabbing(prefab.GetComponent<CombatActor>());PrefabUtility.SaveAsPrefabAsset(prefab,path);PrefabUtility.UnloadPrefabContents(prefab);
            foreach(var a in Object.FindObjectsByType<CombatActor>())AddGrabbing(a);
            foreach(var rb in Object.FindObjectsByType<Rigidbody>())if(rb.name=="Pushable crate"&&!rb.GetComponent<Grabbable>()){var g=rb.gameObject.AddComponent<Grabbable>();g.body=rb;}
            EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());EditorSceneManager.SaveOpenScenes();AssetDatabase.SaveAssets();
        }
    }
}
