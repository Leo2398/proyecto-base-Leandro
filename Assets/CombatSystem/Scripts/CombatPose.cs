using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatPose : MonoBehaviour
    {
        public CombatActor actor;
        public Transform[] legs,feet,arms,hands;
        public Renderer[] colored;
        public static readonly Color[] Colors={new Color(.15f,.55f,1),new Color(.95f,.22f,.2f),new Color(.2f,.8f,.35f),new Color(1,.74f,.12f)};
        MaterialPropertyBlock block;
        void Start(){ApplyColor(actor.colorSlot);}
        public void ApplyColor(int slot){block??=new MaterialPropertyBlock();block.SetColor("_BaseColor",Colors[Mathf.Abs(slot)%4]);foreach(var r in colored)r.SetPropertyBlock(block);}
        void LateUpdate()
        {
            float speed=Vector3.ProjectOnPlane(actor.body.linearVelocity,Vector3.up).magnitude;
            for(int i=0;i<2;i++)
            {
                float phase=Time.time*speed*2.4f+i*Mathf.PI;
                float swing=actor.Conscious&&actor.motor.Grounded?Mathf.Sin(phase)*Mathf.Min(.24f,speed*.045f):0;
                feet[i].localPosition=new Vector3(i==0?-.2f:.2f,-.69f+Mathf.Max(0,swing)*.35f,.06f+swing);
                Link(legs[i],transform.TransformPoint(new Vector3(i==0?-.2f:.2f,-.23f,0)),feet[i].position,.16f);
                Link(arms[i],transform.TransformPoint(new Vector3(i==0?-.32f:.32f,.33f,0)),hands[i].position,.13f);
            }
        }
        public static void Link(Transform part,Vector3 a,Vector3 b,float radius){part.position=(a+b)*.5f;part.up=(b-a).normalized;part.localScale=new Vector3(radius,(b-a).magnitude*.5f,radius);}
    }
}
