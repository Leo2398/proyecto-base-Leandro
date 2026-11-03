using System.Collections.Generic;
using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatHands : MonoBehaviour
    {
        public CombatActor actor;
        public Rigidbody[] fists;
        public float handSpring=210,handDamping=22,maxHandForce=110,punchCooldown=.48f,punchImpulse=21,punchStress=36;
        public int Hits {get;private set;}
        public int Punches {get;private set;}
        readonly float[] started={-10,-10};
        readonly HashSet<CombatActor>[] struck={new HashSet<CombatActor>(),new HashSet<CombatActor>()};
        readonly Collider[] contacts=new Collider[32];
        readonly Vector3[] previous=new Vector3[2];
        public bool PunchActive(int hand)=>Time.time-started[hand]<.38f;
        public void Tick(CombatCommand command)
        {
            for(int i=0;i<2;i++)
            {
                if(actor.Controllable&&(!actor.grabbing||!actor.grabbing.IsHolding(i))&&command.Presses(i==0?CombatButton.PunchLeft:CombatButton.PunchRight)&&Time.time-started[i]>=punchCooldown)
                {started[i]=Time.time;struck[i].Clear();Punches++;}
                float age=Time.time-started[i];
                float reach=age<.08f?-.12f:age<.2f?Mathf.Lerp(0,.65f,(age-.08f)/.12f):age<.38f?Mathf.Lerp(.65f,0,(age-.2f)/.18f):0;
                float spread=Mathf.Lerp(.42f,.24f,Mathf.Clamp01(reach/.65f));
                Vector3 local=new Vector3(i==0?-spread:spread,.13f,.3f+reach);
                bool grabbing=command.Holds(i==0?CombatButton.GrabLeft:CombatButton.GrabRight);
                if(grabbing)local=new Vector3(i==0?-.28f:.28f,.18f,.79f);
                bool lifting=grabbing&&command.Holds(CombatButton.Lift)&&actor.grabbing&&actor.grabbing.IsHolding(i);
                if(lifting)local=new Vector3(i==0?-.28f:.28f,.92f,.5f);
                if(actor.Conscious)
                {
                    Vector3 target=transform.TransformPoint(local);
                    var force=(target-fists[i].position)*handSpring-(fists[i].linearVelocity-actor.body.GetPointVelocity(target))*handDamping;
                    fists[i].AddForce(Vector3.ClampMagnitude(force,lifting?maxHandForce*1.6f:maxHandForce)-Physics.gravity*fists[i].mass);
                }
                if(actor.Conscious&&age>=.09f&&age<=.29f)
                {
                    int count=Physics.OverlapCapsuleNonAlloc(previous[i]==Vector3.zero?fists[i].position:previous[i],fists[i].position,.21f,contacts,~0,QueryTriggerInteraction.Ignore);
                    for(int n=0;n<count;n++)
                    {
                        var victim=contacts[n].GetComponentInParent<CombatActor>();
                        if(!victim||victim==actor||!victim.vitals||!struck[i].Add(victim))continue;
                        if(Vector3.Distance(actor.body.position,victim.body.position)>1.8f)continue;
                        Vector3 direction=victim.body.worldCenterOfMass-actor.body.worldCenterOfMass;direction.y=0;
                        float relative=Vector3.Dot(actor.body.linearVelocity-victim.body.linearVelocity,direction.normalized);
                        float multiplier=Mathf.Clamp(1+relative*.07f,.8f,1.3f);
                        victim.vitals.ReceiveHit(direction,punchImpulse*multiplier,punchStress*multiplier,contacts[n].ClosestPoint(fists[i].position));Hits++;
                    }
                }
                previous[i]=fists[i].position;
            }
        }
    }
}
