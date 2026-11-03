using UnityEngine;
namespace FactoryArena {
public class HydraulicPress : MonoBehaviour {
 public enum Phase { Rest, Warning, Descending, Compression, Rising }
 public Phase state; public float rest=3,warning=1.5f,descent=.7f,compression=1,rise=.8f; public Rigidbody plate; public HazardZone hazard; public Light beacon; public float high=4,low=.65f; float elapsed;
 void FixedUpdate(){elapsed+=Time.fixedDeltaTime; float duration=state==Phase.Rest?rest:state==Phase.Warning?warning:state==Phase.Descending?descent:state==Phase.Compression?compression:rise; float t=Mathf.Clamp01(elapsed/Mathf.Max(.05f,duration)); var pos=plate.position; pos.y=state==Phase.Descending?Mathf.Lerp(high,low,t):state==Phase.Rising?Mathf.Lerp(low,high,t):state==Phase.Compression?low:high;plate.MovePosition(pos);hazard.armed=state==Phase.Compression;beacon.intensity=state==Phase.Warning?(Mathf.Sin(elapsed*18)>0?8:0):state==Phase.Compression?6:0;if(t>=1){elapsed=0;state=(Phase)(((int)state+1)%5);}}
}
}
