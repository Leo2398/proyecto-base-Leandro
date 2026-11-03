using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace FactoryArena {
public class FactoryValidation : MonoBehaviour {
 IEnumerator Start(){var report=new List<string>();var belts=FindObjectsByType<ConveyorBelt>();foreach(var belt in belts){var box=GameObject.CreatePrimitive(PrimitiveType.Cube);box.name="Validation body";box.transform.position=belt.transform.position+Vector3.up;box.transform.localScale=Vector3.one*.5f;var rb=box.AddComponent<Rigidbody>();rb.constraints=RigidbodyConstraints.FreezeRotation;yield return new WaitForSeconds(1);var start=rb.position;yield return new WaitForSeconds(1);report.Add(belt.transform.parent.name+" normal displacement="+(rb.position.x-start.x));belt.Reverse();yield return new WaitForSeconds(1);start=rb.position;yield return new WaitForSeconds(1);report.Add("reversed displacement="+(rb.position.x-start.x));belt.speed=3.5f;yield return new WaitForSeconds(1);report.Add("accelerated velocity="+rb.linearVelocity.x);belt.running=false;yield return new WaitForSeconds(1);report.Add("stopped velocity="+rb.linearVelocity.x);belt.running=true;belt.Reverse();belt.speed=2;Destroy(box);}
 foreach(var lever in FindObjectsByType<ControlLever>()){int before=lever.belt.direction;lever.Activate();lever.Activate();report.Add(lever.name+" reversed="+(lever.belt.direction==-before));yield return new WaitForSeconds(6.3f);report.Add(lever.name+" restored="+(lever.belt.direction==before&&!lever.active));}
 var press=FindFirstObjectByType<HydraulicPress>();var seen=new HashSet<HydraulicPress.Phase>();float end=Time.time+8;while(Time.time<end){seen.Add(press.state);yield return null;}report.Add("Press phases="+string.Join(",",seen));report.Add("Press height="+press.plate.position.y);System.IO.File.WriteAllLines("Assets/FactoryArena/Generated/LocalValidation.txt",report);Debug.Log("Factory validation complete: "+string.Join(" | ",report));}
}
}
