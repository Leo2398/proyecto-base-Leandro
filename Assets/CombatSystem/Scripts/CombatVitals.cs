using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatVitals : MonoBehaviour
    {
        public CombatActor actor;
        public float resistance=100,unconsciousSeconds=3.2f,recoverySeconds=1.2f,stunSeconds=.25f;
        public bool allowKnockout;
        public float Stress {get;private set;}
        public int ReceivedHits {get;private set;}
        public float StateUntil {get;private set;}
        public System.Action<Vector3,float> Impact;
        float lastHit=-10,protectedUntil;
        public void ReceiveHit(Vector3 direction,float impulse,float stress,Vector3 point)
        {
            if(!actor.simulate||actor.state==FighterState.Eliminated)return;
            direction.y=Mathf.Max(direction.y,.12f);direction.Normalize();
            actor.body.AddForceAtPosition(direction*Mathf.Clamp(impulse,0,32),point,ForceMode.Impulse);
            ReceivedHits++;Impact?.Invoke(point,impulse);
            if(actor.state==FighterState.Unconscious||actor.state==FighterState.Recovering||Time.time<protectedUntil)return;
            Stress+=Mathf.Clamp(stress,0,60);lastHit=Time.time;
            if(allowKnockout&&Stress>=resistance){KnockOut();return;}
            actor.state=FighterState.Stunned;StateUntil=Time.time+stunSeconds;actor.balance.Stability=.3f;
        }
        public void KnockOut()
        {
            if(!actor.simulate)return;
            actor.state=FighterState.Unconscious;StateUntil=Time.time+unconsciousSeconds;
            if(actor.grabbing)actor.grabbing.ReleaseAll();
            actor.body.AddTorque(actor.transform.right*4,ForceMode.Impulse);
        }
        public void Eliminate(){if(actor.simulate){actor.state=FighterState.Eliminated;if(actor.grabbing)actor.grabbing.ReleaseAll();var target=GetComponent<Grabbable>();if(target)target.ReleaseEveryone();}}
        public void Tick()
        {
            if(actor.body.position.y<-5){Eliminate();return;}
            if(actor.state==FighterState.Stunned&&Time.time>=StateUntil){actor.state=FighterState.Normal;actor.balance.Stability=1;}
            if(actor.state==FighterState.Unconscious&&Time.time>=StateUntil)
            {
                // Do not stand into a ceiling. Ignore own colliders when testing clearance.
                bool clear=true;
                foreach(var c in Physics.OverlapCapsule(actor.body.position+Vector3.up*.3f,actor.body.position+Vector3.up*1.1f,.3f,~0,QueryTriggerInteraction.Ignore))
                    if(!c.transform.IsChildOf(transform))clear=false;
                if(clear){actor.state=FighterState.Recovering;StateUntil=Time.time+recoverySeconds;actor.balance.Stability=.5f;}
            }
            if(actor.state==FighterState.Recovering)
            {
                actor.balance.Stability=Mathf.Lerp(.5f,1,1-(StateUntil-Time.time)/recoverySeconds);
                if(Time.time>=StateUntil&&Vector3.Dot(actor.transform.up,Vector3.up)>.85f){actor.state=FighterState.Normal;Stress=0;protectedUntil=Time.time+1.5f;actor.balance.Stability=1;}
            }
            if(Time.time-lastHit>1&&actor.Conscious)Stress=Mathf.Max(0,Stress-Time.fixedDeltaTime*8);
        }
        void OnCollisionEnter(Collision collision)
        {
            if(!actor.simulate||!allowKnockout||collision.relativeVelocity.magnitude<6.5f||Time.time-lastHit<.4f)return;
            if(collision.contactCount>0)ReceiveHit(collision.GetContact(0).normal,0,Mathf.Min(60,collision.relativeVelocity.magnitude*5),collision.GetContact(0).point);
        }
    }
}
