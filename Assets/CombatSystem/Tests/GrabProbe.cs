#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace ProyectoFinalRV.Combat.Tests
{
    public class GrabProbe:MonoBehaviour
    {
        IEnumerator Start()
        {
            var a=GameObject.Find("Local fighter").GetComponent<CombatActor>();var b=GameObject.Find("Training dummy 1").GetComponent<CombatActor>();a.locallyControlled=false;
            var report=new List<string>();PunchProbe.Place(a,new Vector3(-2,.86f,0));PunchProbe.Place(b,new Vector3(-2,.86f,.9f));
            yield return Hold(a,CombatButton.GrabLeft,1);report.Add("One hand="+a.grabbing.HeldCount);
            yield return Hold(a,CombatButton.GrabLeft|CombatButton.GrabRight,.6f);report.Add("Two hands="+a.grabbing.HeldCount);
            var before=b.body.position;float end=Time.time+.6f;
            while(Time.time<end){a.Submit(new CombatCommand{held=CombatButton.GrabLeft|CombatButton.GrabRight,move=Vector2.down});yield return null;}
            report.Add("Drag target distance="+Vector3.Distance(before,b.body.position));
            yield return Hold(a,CombatButton.GrabRight,.2f);report.Add("Release left remaining="+a.grabbing.HeldCount);
            yield return Hold(a,0,.3f);report.Add("Release all="+a.grabbing.HeldCount+" spring joints="+a.GetComponentsInChildren<SpringJoint>().Length);
            report.Add("Upright after drag="+Vector3.Dot(a.transform.up,Vector3.up));
            System.IO.File.WriteAllLines("Assets/CombatSystem/Evidence/Grabs.txt",report);Debug.Log(string.Join(" | ",report));a.locallyControlled=true;Destroy(gameObject);
        }
        public static IEnumerator Hold(CombatActor a,CombatButton held,float seconds){float end=Time.time+seconds;while(Time.time<end){a.Submit(new CombatCommand{held=held});yield return null;}}
    }
}
#endif
