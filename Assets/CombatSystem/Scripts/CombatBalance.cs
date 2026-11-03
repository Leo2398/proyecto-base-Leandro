using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatBalance : MonoBehaviour
    {
        public CombatActor actor;
        public float strength=65,damping=12,maxTorque=65,turnStrength=18,turnDamping=8;
        public float Stability {get;set;}=1;
        public void Tick(CombatCommand command)
        {
            if(actor.state==FighterState.Unconscious||actor.state==FighterState.Eliminated)return;
            var body=actor.body;
            var axis=Vector3.Cross(transform.up,Vector3.up);
            // Recover even when completely upside-down, where the cross product is zero.
            if(Vector3.Dot(transform.up,Vector3.up)<-.9f)axis=transform.right;
            var torque=axis*strength*Stability-new Vector3(body.angularVelocity.x,0,body.angularVelocity.z)*damping;
            if(actor.Conscious)
            {
                float error=Mathf.DeltaAngle(transform.eulerAngles.y,command.yaw)*Mathf.Deg2Rad;
                torque.y=error*turnStrength-body.angularVelocity.y*turnDamping;
            }
            body.AddTorque(Vector3.ClampMagnitude(torque,maxTorque),ForceMode.Acceleration);
        }
    }
}
