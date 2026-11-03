using UnityEngine;
using UnityEngine.Events;
namespace FactoryArena {
public class HazardZone : MonoBehaviour {
 public bool armed=true; public UnityEvent<GameObject> detected=new UnityEvent<GameObject>(); public int detections;
 void OnTriggerEnter(Collider other){if(armed&&other.attachedRigidbody!=null){detections++;detected.Invoke(other.attachedRigidbody.gameObject);}}
 void OnTriggerStay(Collider other){if(armed&&other.attachedRigidbody!=null)detected.Invoke(other.attachedRigidbody.gameObject);}
}
}
