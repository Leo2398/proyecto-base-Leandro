using System.Collections.Generic;
using UnityEngine;
namespace ProyectoFinalRV.Combat
{
    public class Grabbable : MonoBehaviour
    {
        public Rigidbody body;
        public CombatActor fighter;
        public int maximumHands=2;
        readonly List<CombatGrab> holders=new List<CombatGrab>();
        public bool Register(CombatGrab grab){if(holders.Count>=maximumHands||!body||body.isKinematic)return false;holders.Add(grab);return true;}
        public void Unregister(CombatGrab grab)=>holders.Remove(grab);
        public void ReleaseEveryone(){foreach(var h in holders.ToArray())if(h)h.ReleaseTarget(this);holders.Clear();}
        void OnDisable()=>ReleaseEveryone();
    }
}
