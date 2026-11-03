using UnityEngine;

namespace ProyectoFinalRV.Combat
{
    public enum FighterState : byte { Normal, Airborne, Unbalanced, Stunned, Unconscious, Recovering, Eliminated }
    [System.Flags] public enum CombatButton : ushort { Run=1, GrabLeft=2, GrabRight=4, Lift=8, Jump=16, PunchLeft=32, PunchRight=64, Throw=128 }
    public struct CombatCommand
    {
        public Vector2 move;
        public float yaw;
        public CombatButton held, pressed;
        public bool Holds(CombatButton b) => (held & b) != 0;
        public bool Presses(CombatButton b) => (pressed & b) != 0;
    }

    // Coordinates simulation. Competitive physics will run only on the authority.
    [DefaultExecutionOrder(-20)]
    public class CombatActor : MonoBehaviour
    {
        public Rigidbody body;
        public CombatMotor motor;
        public CombatBalance balance;
        public CombatHands hands;
        public CombatVitals vitals;
        public CombatGrab grabbing;
        public bool simulate = true;
        public bool locallyControlled;
        public int colorSlot;
        public FighterState state;
        public CombatCommand Command { get; private set; }
        public bool Conscious => state != FighterState.Unconscious && state != FighterState.Eliminated && state != FighterState.Recovering;
        public bool Controllable => Conscious && state != FighterState.Stunned;
        float lastInput;

        public void Submit(CombatCommand command)
        {
            if (!float.IsFinite(command.move.x) || !float.IsFinite(command.move.y) || !float.IsFinite(command.yaw)) return;
            command.move=Vector2.ClampMagnitude(command.move,1);
            command.yaw=Mathf.Repeat(command.yaw,360);
            command.pressed |= Command.pressed;
            Command=command;lastInput=Time.time;
        }
        void FixedUpdate()
        {
            if(!simulate) return;
            var input=Command;
            if(Time.time-lastInput>.4f){input.move=Vector2.zero;input.held=0;input.pressed=0;}
            if(vitals)vitals.Tick();
            if(grabbing)grabbing.Tick(input);
            motor.Tick(input);balance.Tick(input);
            if(hands)hands.Tick(input);
            if(state==FighterState.Normal || state==FighterState.Airborne) state=motor.Grounded?FighterState.Normal:FighterState.Airborne;
            input.pressed=0;Command=input;
        }
        void Awake()
        {
            var colliders=GetComponentsInChildren<Collider>();
            for(int i=0;i<colliders.Length;i++)for(int j=i+1;j<colliders.Length;j++)Physics.IgnoreCollision(colliders[i],colliders[j]);
        }
    }
}
