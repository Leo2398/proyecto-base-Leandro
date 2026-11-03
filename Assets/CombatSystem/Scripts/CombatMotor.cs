using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatMotor : MonoBehaviour
    {
        public CombatActor actor;
        public float walkSpeed=4.6f,runSpeed=6,acceleration=24,braking=18,airControl=.28f,jumpSpeed=5.2f,coyoteTime=.12f,jumpBuffer=.14f;
        public bool Grounded {get;private set;}
        public float CarryPenalty {get;set;}=1;
        public int JumpCount {get;private set;}
        readonly RaycastHit[] hits=new RaycastHit[20];
        float lastGround=-10,jumpUntil=-10,lastJump=-10;
        public void Tick(CombatCommand command)
        {
            var body=actor.body;
            Grounded=false;Vector3 supportVelocity=Vector3.zero;
            int count=Physics.SphereCastNonAlloc(body.position+Vector3.down*.48f,.23f,Vector3.down,hits,.27f,~0,QueryTriggerInteraction.Ignore);
            for(int i=0;i<count;i++)
            {
                var hit=hits[i];
                if(hit.collider.transform.IsChildOf(transform)||hit.normal.y<.6f)continue;
                if(Time.time-lastJump<.18f)continue;
                Grounded=true;
                if(hit.rigidbody) supportVelocity=hit.rigidbody.GetPointVelocity(hit.point);
                break;
            }
            if(Grounded) lastGround=Time.time;
            if(command.Presses(CombatButton.Jump))jumpUntil=Time.time+jumpBuffer;
            if(!actor.Controllable)return;
            float speed=(command.Holds(CombatButton.Run)?runSpeed:walkSpeed)*CarryPenalty;
            var target=new Vector3(command.move.x,0,command.move.y)*speed+supportVelocity;
            var current=new Vector3(body.linearVelocity.x,0,body.linearVelocity.z);
            float control=Grounded?1:airControl;
            float limit=(command.move.sqrMagnitude>.01f?acceleration:braking)*control;
            body.AddForce(Vector3.ClampMagnitude((target-current)/Time.fixedDeltaTime,limit),ForceMode.Acceleration);
            if(jumpUntil>=Time.time&&Time.time-lastGround<=coyoteTime&&Time.time-lastJump>.22f)
            {
                body.AddForce(Vector3.up*Mathf.Max(0,jumpSpeed-body.linearVelocity.y),ForceMode.VelocityChange);
                jumpUntil=-10;lastGround=-10;lastJump=Time.time;Grounded=false;JumpCount++;
            }
        }
    }
}
