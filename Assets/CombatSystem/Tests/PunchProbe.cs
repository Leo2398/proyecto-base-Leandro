#if UNITY_EDITOR
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
namespace ProyectoFinalRV.Combat.Tests
{
    public class PunchProbe:MonoBehaviour
    {
        IEnumerator Start()
        {
            var attacker=GameObject.Find("Local fighter").GetComponent<CombatActor>();var target=GameObject.Find("Training dummy 1").GetComponent<CombatActor>();attacker.locallyControlled=false;
            var report=new List<string>();
            Place(attacker,new Vector3(-2,.86f,0));Place(target,new Vector3(-2,.86f,.95f));yield return new WaitForSeconds(.4f);
            attacker.Submit(new CombatCommand{pressed=CombatButton.PunchLeft});yield return new WaitForSeconds(.45f);
            report.Add("Left: hits="+attacker.hands.Hits+" received="+target.vitals.ReceivedHits+" target speed="+target.body.linearVelocity.magnitude);
            Place(attacker,new Vector3(-2,.86f,0));Place(target,new Vector3(-2,.86f,.95f));yield return new WaitForSeconds(.3f);
            attacker.Submit(new CombatCommand{pressed=CombatButton.PunchRight});yield return new WaitForSeconds(.45f);
            report.Add("Right cumulative hits="+attacker.hands.Hits+" received="+target.vitals.ReceivedHits);
            Place(target,new Vector3(5,.86f,0));yield return new WaitForSeconds(.2f);int before=attacker.hands.Hits;
            float end=Time.time+.25f;while(Time.time<end){attacker.Submit(new CombatCommand{pressed=CombatButton.PunchLeft});yield return null;}
            yield return new WaitForSeconds(.5f);report.Add("Miss additional hits="+(attacker.hands.Hits-before)+" punches total="+attacker.hands.Punches);
            report.Add("Attacker upright="+Vector3.Dot(attacker.transform.up,Vector3.up));
            System.IO.File.WriteAllLines("Assets/CombatSystem/Evidence/Punches.txt",report);Debug.Log(string.Join(" | ",report));attacker.locallyControlled=true;Destroy(gameObject);
        }
        public static void Place(CombatActor actor,Vector3 position)
        {
            actor.body.position=position;actor.body.rotation=Quaternion.identity;
            if(actor.hands)for(int i=0;i<2;i++){actor.hands.fists[i].position=position+new Vector3(i==0?-.42f:.42f,.13f,.3f);actor.hands.fists[i].rotation=Quaternion.identity;}
            foreach(var rb in actor.GetComponentsInChildren<Rigidbody>()){rb.linearVelocity=Vector3.zero;rb.angularVelocity=Vector3.zero;}
            actor.Submit(default);
        }
    }
}
#endif
