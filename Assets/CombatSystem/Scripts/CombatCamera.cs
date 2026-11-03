using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class CombatCamera : MonoBehaviour
    {
        public Transform target;
        public Vector3 offset=new Vector3(7,9,-10);
        Vector3 velocity;
        void LateUpdate()
        {
            if(!target){foreach(var a in FindObjectsByType<CombatActor>())if(a.locallyControlled){target=a.transform;break;}}
            if(!target)return;
            var focus=target.position;focus.y=Mathf.Clamp(focus.y,.8f,2.3f);
            transform.position=Vector3.SmoothDamp(transform.position,focus+offset,ref velocity,.22f);
            transform.rotation=Quaternion.Slerp(transform.rotation,Quaternion.LookRotation(focus+Vector3.up*.35f-transform.position),Time.deltaTime*8);
        }
    }
}
