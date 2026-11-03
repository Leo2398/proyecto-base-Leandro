using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.InputSystem;
using System.IO;

namespace ProyectoFinalRV.Combat.Editor
{
    public static class CombatBuilder
    {
        const string Root="Assets/CombatSystem/";
        static Material suit,dark,skin,white;
        static Material Mat(string name,Color color)
        {
            string path=Root+"Materials/"+name+".mat";
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(!material){material=new Material(Shader.Find("Universal Render Pipeline/Lit"));AssetDatabase.CreateAsset(material,path);}
            material.color=color;material.SetFloat("_Smoothness",.25f);return material;
        }
        public static GameObject Part(string name,Transform parent,Vector3 position,Vector3 size,Material material,PrimitiveType type=PrimitiveType.Cube,bool collision=false)
        {
            var g=GameObject.CreatePrimitive(type);g.name=name;g.transform.SetParent(parent,false);g.transform.localPosition=position;g.transform.localScale=size;g.GetComponent<Renderer>().sharedMaterial=material;
            if(!collision)Object.DestroyImmediate(g.GetComponent<Collider>());return g;
        }
        static InputActionAsset InputAsset()
        {
            var asset=ScriptableObject.CreateInstance<InputActionAsset>();var map=asset.AddActionMap("Combat");
            var move=map.AddAction("Move",InputActionType.Value);move.AddCompositeBinding("2DVector").With("Up","<Keyboard>/w").With("Down","<Keyboard>/s").With("Left","<Keyboard>/a").With("Right","<Keyboard>/d");move.AddBinding("<Gamepad>/leftStick");
            string[] names={"Run","Jump","PunchLeft","PunchRight","GrabLeft","GrabRight","Lift","Throw","Pause"};
            string[] keys={"<Keyboard>/leftShift","<Keyboard>/space","<Mouse>/leftButton","<Mouse>/rightButton","<Keyboard>/q","<Keyboard>/e","<Keyboard>/r","<Keyboard>/f","<Keyboard>/escape"};
            for(int i=0;i<names.Length;i++)map.AddAction(names[i],InputActionType.Button,keys[i]);
            var path=Root+"Input/CombatControls.inputactions";File.WriteAllText(path,asset.ToJson());Object.DestroyImmediate(asset);AssetDatabase.ImportAsset(path);return AssetDatabase.LoadAssetAtPath<InputActionAsset>(path);
        }
        public static CombatActor Character(InputActionAsset input)
        {
            var g=new GameObject("PlayerCharacter");var actor=g.AddComponent<CombatActor>();actor.body=g.AddComponent<Rigidbody>();actor.body.mass=16;actor.body.linearDamping=.12f;actor.body.angularDamping=.5f;actor.body.interpolation=RigidbodyInterpolation.Interpolate;actor.body.collisionDetectionMode=CollisionDetectionMode.ContinuousDynamic;actor.body.solverIterations=12;actor.body.solverVelocityIterations=4;actor.body.maxAngularVelocity=8;actor.body.centerOfMass=new Vector3(0,-.3f,0);
            var capsule=g.AddComponent<CapsuleCollider>();capsule.height=1.35f;capsule.radius=.28f;capsule.center=new Vector3(0,-.18f,0);
            var friction=new PhysicsMaterial("Fighter friction"){dynamicFriction=.12f,staticFriction=.15f,frictionCombine=PhysicsMaterialCombine.Minimum,bounciness=0};
            string frictionPath=Root+"Materials/FighterFriction.physicMaterial";var existing=AssetDatabase.LoadAssetAtPath<PhysicsMaterial>(frictionPath);if(!existing){AssetDatabase.CreateAsset(friction,frictionPath);existing=friction;}else Object.DestroyImmediate(friction);capsule.sharedMaterial=existing;
            actor.motor=g.AddComponent<CombatMotor>();actor.motor.actor=actor;actor.balance=g.AddComponent<CombatBalance>();actor.balance.actor=actor;
            var control=g.AddComponent<CombatInput>();control.actor=actor;control.controls=input;
            var visual=new GameObject("Replaceable visuals");visual.transform.SetParent(g.transform,false);
            var torso=Part("Rounded work jacket",visual.transform,new Vector3(0,.17f,0),new Vector3(.74f,.52f,.5f),suit,PrimitiveType.Capsule);
            Part("Hip belt",visual.transform,new Vector3(0,-.24f,0),new Vector3(.57f,.21f,.45f),dark,PrimitiveType.Sphere);
            Part("Head",visual.transform,new Vector3(0,.81f,0),new Vector3(.67f,.64f,.63f),skin,PrimitiveType.Sphere);
            Part("Work cap",visual.transform,new Vector3(0,1.04f,0),new Vector3(.72f,.23f,.67f),suit,PrimitiveType.Sphere);
            Part("Cap visor",visual.transform,new Vector3(0,1.02f,.28f),new Vector3(.66f,.08f,.33f),dark,PrimitiveType.Sphere);
            Part("Goggle band",visual.transform,new Vector3(0,.83f,.275f),new Vector3(.54f,.19f,.13f),dark,PrimitiveType.Sphere);
            for(int i=-1;i<=1;i+=2){Part("Eye lens",visual.transform,new Vector3(i*.14f,.84f,.335f),new Vector3(.15f,.12f,.05f),white,PrimitiveType.Sphere);Part("Pupil",visual.transform,new Vector3(i*.14f,.84f,.365f),new Vector3(.055f,.075f,.035f),dark,PrimitiveType.Sphere);}
            Part("Jacket zip",visual.transform,new Vector3(0,.2f,.26f),new Vector3(.045f,.43f,.02f),white);
            Part("Chest badge",visual.transform,new Vector3(-.19f,.3f,.25f),new Vector3(.12f,.1f,.035f),white);
            var pose=g.AddComponent<CombatPose>();pose.actor=actor;pose.arms=new Transform[2];pose.hands=new Transform[2];pose.legs=new Transform[2];pose.feet=new Transform[2];
            for(int i=0;i<2;i++){float x=i==0?-1:1;pose.arms[i]=Part(i==0?"Left arm":"Right arm",g.transform,new Vector3(x*.4f,0,.1f),Vector3.one*.2f,suit,PrimitiveType.Cylinder).transform;pose.hands[i]=Part(i==0?"Left glove":"Right glove",g.transform,new Vector3(x*.48f,-.05f,.25f),Vector3.one*.33f,dark,PrimitiveType.Sphere).transform;pose.legs[i]=Part(i==0?"Left leg":"Right leg",g.transform,new Vector3(x*.2f,-.5f,0),new Vector3(.18f,.23f,.18f),suit,PrimitiveType.Cylinder).transform;pose.feet[i]=Part(i==0?"Left boot":"Right boot",g.transform,new Vector3(x*.2f,-.69f,.06f),new Vector3(.32f,.3f,.49f),dark,PrimitiveType.Sphere).transform;}
            pose.colored=new[]{torso.GetComponent<Renderer>(),visual.transform.Find("Work cap").GetComponent<Renderer>(),pose.arms[0].GetComponent<Renderer>(),pose.arms[1].GetComponent<Renderer>(),pose.legs[0].GetComponent<Renderer>(),pose.legs[1].GetComponent<Renderer>()};
            return actor;
        }
        public static void Build()
        {
            if(EditorApplication.isPlaying)throw new System.Exception("Stop Play Mode first");
            if(UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty)throw new System.Exception("Save the open scene first");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            suit=Mat("WorkSuit",CombatPose.Colors[0]);dark=Mat("Rubber",new Color(.055f,.085f,.12f));skin=Mat("WarmShell",new Color(.94f,.67f,.4f));white=Mat("Reflector",new Color(.85f,.95f,1));
            var ground=Mat("SandboxFloor",new Color(.2f,.29f,.36f));var trim=Mat("SafetyTrim",new Color(1,.7f,.1f));
            Part("Combat platform",null,new Vector3(0,-.5f,0),new Vector3(22,1,18),ground,PrimitiveType.Cube,true);
            Part("Practice slope",null,new Vector3(-7,.3f,4),new Vector3(3,.4f,4),ground,PrimitiveType.Cube,true).transform.rotation=Quaternion.Euler(0,0,12);
            Part("Low step",null,new Vector3(5,.06f,4),new Vector3(2,.12f,3),trim,PrimitiveType.Cube,true);
            for(int i=0;i<3;i++){var box=Part("Pushable crate",null,new Vector3(3+i,1,3),Vector3.one*.7f,trim,PrimitiveType.Cube,true);box.AddComponent<Rigidbody>().mass=4;}
            var input=InputAsset();var actor=Character(input);var prefab=PrefabUtility.SaveAsPrefabAsset(actor.gameObject,Root+"Prefabs/PlayerCharacter.prefab");Object.DestroyImmediate(actor.gameObject);
            for(int i=0;i<3;i++){var p=(GameObject)PrefabUtility.InstantiatePrefab(prefab);p.name=i==0?"Local fighter":"Training dummy "+i;p.transform.position=new Vector3((i-1)*2.4f,1.1f,0);var a=p.GetComponent<CombatActor>();a.locallyControlled=i==0;a.colorSlot=i;PrefabUtility.RecordPrefabInstancePropertyModifications(a);}
            var camera=new GameObject("Combat Camera",typeof(Camera),typeof(AudioListener),typeof(CombatCamera));camera.tag="MainCamera";camera.transform.position=new Vector3(8,10,-12);camera.transform.LookAt(Vector3.up);camera.GetComponent<Camera>().fieldOfView=45;camera.GetComponent<Camera>().clearFlags=CameraClearFlags.SolidColor;camera.GetComponent<Camera>().backgroundColor=new Color(.08f,.12f,.17f);
            var light=new GameObject("Sandbox light").AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.6f;light.shadows=LightShadows.Soft;light.transform.rotation=Quaternion.Euler(50,-30,0);RenderSettings.ambientLight=new Color(.55f,.6f,.7f);
            EditorSceneManager.SaveScene(scene,Root+"Scenes/CombatSandbox.unity");AssetDatabase.SaveAssets();
        }
    }
}
