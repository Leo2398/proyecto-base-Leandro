#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

namespace FactoryArena.Editor
{
    // Added temporarily in Play Mode by the CLI. Never saved in the scene or shipped.
    public class RedesignRegressionProbe : MonoBehaviour
    {
        IEnumerator Start()
        {
            var report = new List<string> { "Local redesign regression; " + System.DateTime.UtcNow.ToString("O") };
            var created = new List<GameObject>();
            var spawnBodies = new List<Rigidbody>();
            foreach (var spawn in GameObject.Find("SpawnPoints").GetComponentsInChildren<Transform>().Where(t => t.name.StartsWith("SpawnPoint_")))
            {
                bool floor = Physics.Raycast(spawn.position, Vector3.down, out var hit, 3, ~0, QueryTriggerInteraction.Ignore);
                var overlaps = Physics.OverlapCapsule(spawn.position + Vector3.down * .5f, spawn.position + Vector3.up * .5f, .35f, ~0, QueryTriggerInteraction.Ignore);
                report.Add(spawn.name + " solidFloor=" + floor + " floor=" + (floor ? hit.collider.name : "NONE") + " initialBlockingColliders=" + overlaps.Length);
                var capsule = GameObject.CreatePrimitive(PrimitiveType.Capsule);
                capsule.name = "Probe " + spawn.name;
                capsule.transform.position = spawn.position;
                var shape = capsule.GetComponent<CapsuleCollider>(); shape.height = 1.8f; shape.radius = .35f;
                var body = capsule.AddComponent<Rigidbody>(); body.constraints = RigidbodyConstraints.FreezeRotation;
                created.Add(capsule); spawnBodies.Add(body);
            }
            var fall = GameObject.Find("FallDetection").GetComponent<HazardZone>();
            int fallEvents = 0;
            var falling = GameObject.CreatePrimitive(PrimitiveType.Cube);
            falling.name = "Probe falling body"; falling.transform.position = new Vector3(15.2f, 1, -8);
            falling.transform.localScale = Vector3.one * .3f; falling.AddComponent<Rigidbody>(); created.Add(falling);
            UnityEngine.Events.UnityAction<GameObject> onFall = g => { if (g == falling) fallEvents++; };
            fall.detected.AddListener(onFall);
            var press = FindAnyObjectByType<HydraulicPress>();
            var sensorBody = GameObject.CreatePrimitive(PrimitiveType.Cube);
            sensorBody.name = "Probe press sensor"; sensorBody.transform.position = new Vector3(0, .29f, 0);
            sensorBody.transform.localScale = Vector3.one * .05f;
            sensorBody.AddComponent<Rigidbody>().isKinematic = true; created.Add(sensorBody);
            int pressEvents = 0;
            UnityEngine.Events.UnityAction<GameObject> onPress = g => { if (g == sensorBody) pressEvents++; };
            press.hazard.detected.AddListener(onPress);
            var visual = FindAnyObjectByType<FactoryVisualMotion>();
            float low = float.MaxValue, high = float.MinValue, maximumRamError = 0;
            var phases = new HashSet<HydraulicPress.Phase>();
            float end = Time.time + 10;
            while (Time.time < end)
            {
                yield return null;
                phases.Add(press.state);
                low = Mathf.Min(low, press.plate.position.y); high = Mathf.Max(high, press.plate.position.y);
                float expectedBottom = press.plate.position.y + .3f;
                maximumRamError = Mathf.Max(maximumRamError, Mathf.Abs(visual.ram.position.y - visual.ram.localScale.y - expectedBottom));
            }
            foreach (var body in spawnBodies) report.Add(body.name + " restingCenterY=" + body.position.y + " remainsOnArena=" + (body.position.y > .7f && body.position.y < 1.2f));
            report.Add("Fall trigger events=" + fallEvents);
            report.Add("Press armed sensor events=" + pressEvents);
            report.Add("Press phases=" + string.Join(",", phases) + " low=" + low + " high=" + high);
            report.Add("Maximum visual ram endpoint error=" + maximumRamError);
            report.Add("New decoration colliders=" + visual.GetComponentsInChildren<Collider>().Length + " rigidbodies=" + visual.GetComponentsInChildren<Rigidbody>().Length);
            fall.detected.RemoveListener(onFall); press.hazard.detected.RemoveListener(onPress);
            foreach (var item in created) Destroy(item);
            yield return null;
            foreach (var belt in FindObjectsByType<ConveyorBelt>())
            {
                int direction = belt.direction; bool running = belt.running;
                var gear = visual.gears.OrderBy(t => Mathf.Abs(t.position.z - belt.transform.position.z)).First();
                belt.running = false; yield return null;
                var before = gear.rotation; yield return new WaitForSeconds(.3f);
                report.Add(belt.transform.parent.name + " stoppedGearAngle=" + Quaternion.Angle(before, gear.rotation));
                belt.running = true; yield return new WaitForSeconds(.3f);
                report.Add(belt.transform.parent.name + " runningGearAngle=" + Quaternion.Angle(before, gear.rotation));
                belt.direction = -direction; yield return null;
                var arrow = visual.directionArrows.OrderBy(t => Mathf.Abs(t.position.z - belt.transform.position.z)).First();
                report.Add(belt.transform.parent.name + " reversedArrowYaw=" + arrow.eulerAngles.y + " physicalDirection=" + belt.direction);
                belt.direction = direction; belt.running = running;
            }
            File.WriteAllLines("Assets/FactoryArena/Generated/Redesign/Regression.txt", report);
            Debug.Log("Redesign regression complete: " + string.Join(" | ", report));
            Destroy(gameObject);
        }
    }
}


#endif
