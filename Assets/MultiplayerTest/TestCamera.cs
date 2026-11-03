using UnityEngine;

namespace ProyectoFinalRV.MultiplayerTest
{
    public sealed class TestCamera : MonoBehaviour
    {
        public Transform Target { get; set; }

        private void LateUpdate()
        {
            if (Target == null) return;
            var desired = Target.position + new Vector3(0f, 7f, -9f);
            transform.position = Vector3.Lerp(transform.position, desired, 8f * Time.deltaTime);
            transform.LookAt(Target.position + Vector3.up);
        }
    }
}
