using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.EventSystems;
namespace ProyectoFinalRV.Combat
{
    public class CombatInput : MonoBehaviour
    {
        public CombatActor actor;
        public InputActionAsset controls;
        InputActionAsset actions;
        public bool suspended;
        public System.Action<CombatCommand> Send;
        void OnEnable(){if(controls){actions=Instantiate(controls);actions.Enable();}}
        void OnDisable(){if(actions){actions.Disable();Destroy(actions);}if(actor)actor.Submit(default);}
        void Update()
        {
            if(!actor.locallyControlled||!actions)return;
            if(actions["Pause"].WasPressedThisFrame())suspended=!suspended;
            var command=new CombatCommand{yaw=actor.transform.eulerAngles.y};
            if(!suspended)
            {
                Vector2 move=actions["Move"].ReadValue<Vector2>();var camera=Camera.main;
                Vector3 forward=camera?Vector3.ProjectOnPlane(camera.transform.forward,Vector3.up).normalized:Vector3.forward;
                Vector3 right=Vector3.Cross(Vector3.up,forward);var world=right*move.x+forward*move.y;
                command.move=new Vector2(world.x,world.z);
                if(world.sqrMagnitude>.01f)command.yaw=Quaternion.LookRotation(world).eulerAngles.y;
                if(camera && Mouse.current!=null)
                {
                    var pos=Mouse.current.position.ReadValue();
                    if(camera.pixelRect.Contains(pos))
                    {
                        var plane=new Plane(Vector3.up,actor.body.position);
                        var ray=camera.ScreenPointToRay(pos);
                        if(plane.Raycast(ray,out float distance)){var aim=ray.GetPoint(distance)-actor.body.position;aim.y=0;if(aim.sqrMagnitude>.15f)command.yaw=Quaternion.LookRotation(aim).eulerAngles.y;}
                    }
                }
                if(actions["Run"].IsPressed())command.held|=CombatButton.Run;
                if(actions["GrabLeft"].IsPressed())command.held|=CombatButton.GrabLeft;
                if(actions["GrabRight"].IsPressed())command.held|=CombatButton.GrabRight;
                if(actions["Lift"].IsPressed())command.held|=CombatButton.Lift;
                if(actions["Jump"].WasPressedThisFrame())command.pressed|=CombatButton.Jump;
                bool ui=EventSystem.current&&EventSystem.current.IsPointerOverGameObject();
                if(!ui&&actions["PunchLeft"].WasPressedThisFrame())command.pressed|=CombatButton.PunchLeft;
                if(!ui&&actions["PunchRight"].WasPressedThisFrame())command.pressed|=CombatButton.PunchRight;
                if(actions["Throw"].WasPressedThisFrame())command.pressed|=CombatButton.Throw;
            }
            if(Send!=null)Send(command);else actor.Submit(command);
        }
    }
}
