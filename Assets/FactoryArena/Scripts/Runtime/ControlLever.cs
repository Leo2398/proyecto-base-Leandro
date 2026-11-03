using UnityEngine;
namespace FactoryArena {
public class ControlLever : MonoBehaviour {
 public ConveyorBelt belt; public Transform handle; public Light indicator; public float duration=6; public bool active; float remaining; int saved;
 [ContextMenu("Activate sabotage")] public void Activate(){if(active||belt==null)return;saved=belt.direction;belt.direction=-saved;remaining=duration;active=true;}
 void Update(){if(active&&(remaining-=Time.deltaTime)<=0){belt.direction=saved;active=false;}handle.localRotation=Quaternion.RotateTowards(handle.localRotation,Quaternion.Euler(0,0,active?-35:35),180*Time.deltaTime);indicator.color=active?Color.red:Color.green;}
 void OnDisable(){if(active&&belt!=null)belt.direction=saved;active=false;}
}
}
