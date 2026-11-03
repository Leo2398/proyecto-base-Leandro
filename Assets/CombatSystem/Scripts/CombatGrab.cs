using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatGrab : MonoBehaviour
    {
        public CombatActor actor;
        public float reach=.34f,gripSpring=240,gripDamping=24,breakForce=320,maxSeparation=1.9f,liftForcePerHand=145,liftHeight=1.0f,throwSpeed=5.3f;
        public bool enableLiftThrow;
        public int Grabs {get;private set;}
        public int Throws {get;private set;}
        readonly SpringJoint[] joints=new SpringJoint[2];
        readonly Grabbable[] targets=new Grabbable[2];
        readonly float[] escape=new float[2];
        readonly float[] acquired=new float[2];
        readonly Collider[] nearby=new Collider[32];
        float reacquireAfter;
        public int HeldCount=0;
        public bool IsHolding(int hand)=>targets[hand]&&joints[hand];
        public Grabbable Target(int hand)=>targets[hand];
        public void Tick(CombatCommand command)
        {
            bool upright=Vector3.Dot(transform.up,Vector3.up)>.45f;
            for(int i=0;i<2;i++)
            {
                bool held=command.Holds(i==0?CombatButton.GrabLeft:CombatButton.GrabRight)&&actor.Conscious&&upright;
                if(targets[i]&&(!held||!joints[i]||targets[i].fighter&&targets[i].fighter.state==FighterState.Eliminated)){Release(i);continue;}
                if(IsHolding(i))
                {
                    var victim=targets[i].fighter;
                    bool pulling=victim&&victim.Conscious&&victim.Command.move.sqrMagnitude>.3f&&Vector3.Dot(new Vector3(victim.Command.move.x,0,victim.Command.move.y),victim.body.position-actor.body.position)>.1f;
                    escape[i]=pulling?escape[i]+Time.fixedDeltaTime:Mathf.Max(0,escape[i]-Time.fixedDeltaTime);
                    if(Vector3.Distance(actor.body.position,targets[i].body.position)>maxSeparation||escape[i]>.9f||victim&&victim.Conscious&&Time.time-acquired[i]>6){Release(i);reacquireAfter=Time.time+.55f;}
                }
                else if(held&&Time.time>=reacquireAfter&&!actor.hands.PunchActive(i))TryAcquire(i);
            }
            HeldCount=(IsHolding(0)?1:0)+(IsHolding(1)?1:0);actor.motor.CarryPenalty=HeldCount>0?.73f:1;
            if(enableLiftThrow&&actor.Conscious)
            {
                if(command.Presses(CombatButton.Throw))Throw();
                else if(command.Holds(CombatButton.Lift)&&actor.motor.Grounded)
                    for(int i=0;i<2;i++)if(IsHolding(i)&&(i==0||targets[i]!=targets[0]))Lift(targets[i]);
            }
        }
        void TryAcquire(int hand)
        {
            var fist=actor.hands.fists[hand];int count=Physics.OverlapSphereNonAlloc(fist.position,reach,nearby,~0,QueryTriggerInteraction.Ignore);
            Grabbable best=null;Vector3 point=default;float nearest=float.MaxValue;
            for(int n=0;n<count;n++)
            {
                var target=nearby[n].GetComponentInParent<Grabbable>();
                if(!target||target.fighter==actor||!target.body||target.body.isKinematic||target.fighter&&target.fighter.state==FighterState.Eliminated)continue;
                var closest=nearby[n].ClosestPoint(fist.position);float distance=(closest-fist.position).sqrMagnitude;
                if(distance>=nearest||Vector3.Distance(actor.body.position,target.body.position)>1.55f)continue;
                bool blocked=false;Vector3 delta=closest-fist.position;
                foreach(var hit in Physics.RaycastAll(fist.position,delta.normalized,delta.magnitude,~0,QueryTriggerInteraction.Ignore))
                    if(!hit.collider.transform.IsChildOf(transform)&&hit.collider.GetComponentInParent<Grabbable>()!=target)blocked=true;
                if(blocked)continue;nearest=distance;best=target;point=closest;
            }
            if(!best||!best.Register(this))return;
            var joint=fist.gameObject.AddComponent<SpringJoint>();joint.autoConfigureConnectedAnchor=false;joint.connectedBody=best.body;joint.anchor=Vector3.zero;joint.connectedAnchor=best.body.transform.InverseTransformPoint(point);
            joint.minDistance=0;joint.maxDistance=.04f;joint.spring=gripSpring;joint.damper=gripDamping;joint.breakForce=breakForce;joint.enableCollision=false;
            joints[hand]=joint;targets[hand]=best;escape[hand]=0;acquired[hand]=Time.time;Grabs++;
        }
        void Lift(Grabbable target)
        {
            if(target.fighter&&target.fighter.grabbing&&target.fighter.grabbing.IsHoldingBody(actor.body))return;
            int count=(targets[0]==target&&IsHolding(0)?1:0)+(targets[1]==target&&IsHolding(1)?1:0);
            float desired=actor.body.position.y+liftHeight;
            float force=(desired-target.body.position.y)*180-target.body.linearVelocity.y*28+target.body.mass*-Physics.gravity.y;
            force=Mathf.Clamp(force,0,liftForcePerHand*count);
            target.body.AddForce(Vector3.up*force);actor.body.AddForce(Vector3.down*force*.25f);
        }
        public bool IsHoldingBody(Rigidbody body)=>(IsHolding(0)&&targets[0].body==body)||(IsHolding(1)&&targets[1].body==body);
        public void Throw()
        {
            var a=IsHolding(0)?targets[0]:null;var b=IsHolding(1)?targets[1]:null;
            ReleaseAll();reacquireAfter=Time.time+.65f;
            Launch(a);if(b!=a)Launch(b);
        }
        void Launch(Grabbable target)
        {
            if(!target||!target.body)return;
            float bonus=Mathf.Clamp(Vector3.Dot(actor.body.linearVelocity,transform.forward)*.18f,0,1);
            var direction=(Vector3.ProjectOnPlane(transform.forward,Vector3.up).normalized+Vector3.up*.45f).normalized;
            target.body.AddForce(direction*(throwSpeed+bonus),ForceMode.VelocityChange);
            target.body.AddTorque(transform.right*3,ForceMode.Impulse);Throws++;
        }
        public void Release(int hand)
        {
            if(joints[hand]){joints[hand].spring=0;joints[hand].damper=0;Destroy(joints[hand]);}
            if(targets[hand])targets[hand].Unregister(this);
            joints[hand]=null;targets[hand]=null;escape[hand]=0;
        }
        public void ReleaseAll(){Release(0);Release(1);HeldCount=0;if(actor&&actor.motor)actor.motor.CarryPenalty=1;}
        public void ReleaseTarget(Grabbable target){for(int i=0;i<2;i++)if(targets[i]==target)Release(i);}
        void OnDisable()=>ReleaseAll();
    }
}
