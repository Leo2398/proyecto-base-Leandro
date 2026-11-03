using UnityEngine;
namespace FactoryArena {
public class ConveyorBelt : MonoBehaviour {
 readonly System.Collections.Generic.HashSet<Rigidbody> contacts=new System.Collections.Generic.HashSet<Rigidbody>(); void OnCollisionEnter(Collision c){if(c.rigidbody)contacts.Add(c.rigidbody);} void OnCollisionExit(Collision c){if(c.rigidbody)contacts.Remove(c.rigidbody);} void FixedUpdate(){if(running)foreach(var b in contacts)if(b)b.WakeUp();} public float speed=2f; public int direction=1; public bool running=true; public Renderer surface;
 Transform[] treads; void Start(){var list=new System.Collections.Generic.List<Transform>();foreach(Transform t in transform.parent)if(t.name=="Belt tread")list.Add(t);treads=list.ToArray();} void Update(){if(!running||treads==null)return;foreach(var t in treads){var p=t.localPosition;p.x=Mathf.Repeat(p.x+10+speed*direction*Time.deltaTime,20)-10;t.localPosition=p;}} public Vector3 Velocity => running ? transform.right*speed*direction : Vector3.zero;
 void OnCollisionStay(Collision c) { var b=c.rigidbody; if(!running||b==null||b.isKinematic)return; foreach(var p in c.contacts) { if(p.normal.y < -0.5f && p.point.y>transform.position.y) { var v=b.linearVelocity; var target=Velocity; b.linearVelocity=new Vector3(target.x,v.y,target.z); break; } } }
 public void SetRunning(bool value)=>running=value;
 public void Reverse()=>direction=-direction;
}
}



