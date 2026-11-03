#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace ProyectoFinalRV.Combat.Tests
{
    public class LocomotionProbe : MonoBehaviour
    {
        IEnumerator Start()
        {
            var actor=GameObject.Find("Local fighter").GetComponent<CombatActor>();actor.locallyControlled=false;
            var report=new List<string>();yield return new WaitForSeconds(1);
            report.Add("Rest y="+actor.body.position.y+" upright="+Vector3.Dot(actor.transform.up,Vector3.up)+" grounded="+actor.motor.Grounded);
            Vector3 start=actor.body.position;
            float until=Time.time+1;while(Time.time<until){actor.Submit(new CombatCommand{move=Vector2.up});yield return null;}
            report.Add("Walk displacement="+(actor.body.position-start).z+" speed="+actor.body.linearVelocity.magnitude);
            until=Time.time+.5f;while(Time.time<until){actor.Submit(default);yield return null;}
            report.Add("Brake speed="+Vector3.ProjectOnPlane(actor.body.linearVelocity,Vector3.up).magnitude);
            float baseY=actor.body.position.y,maxY=baseY;
            actor.Submit(new CombatCommand{pressed=CombatButton.Jump});
            until=Time.time+1.6f;while(Time.time<until){actor.Submit(default);maxY=Mathf.Max(maxY,actor.body.position.y);yield return null;}
            report.Add("Jump height="+(maxY-baseY)+" jumps="+actor.motor.JumpCount+" landed="+actor.motor.Grounded);
            until=Time.time+1;while(Time.time<until){actor.Submit(new CombatCommand{move=Vector2.down,held=CombatButton.Run,yaw=180});yield return null;}
            report.Add("Run speed="+Vector3.ProjectOnPlane(actor.body.linearVelocity,Vector3.up).magnitude+" yaw="+actor.transform.eulerAngles.y);
            actor.Submit(default);actor.body.AddForce(new Vector3(12,0,0),ForceMode.Impulse);actor.body.AddTorque(new Vector3(0,0,3),ForceMode.Impulse);
            yield return new WaitForSeconds(2);
            report.Add("After push upright="+Vector3.Dot(actor.transform.up,Vector3.up)+" speed="+actor.body.linearVelocity.magnitude);
            System.IO.File.WriteAllLines("Assets/CombatSystem/Evidence/Locomotion.txt",report);Debug.Log(string.Join(" | ",report));actor.locallyControlled=true;Destroy(gameObject);
        }
    }
}
#endif
