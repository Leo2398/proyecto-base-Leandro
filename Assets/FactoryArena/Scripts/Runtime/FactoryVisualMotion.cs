using UnityEngine;

namespace FactoryArena
{
    // Presentation only: reads mechanisms without changing their state.
    public class FactoryVisualMotion : MonoBehaviour
    {
        public HydraulicPress press;
        public Transform ram;
        public Renderer[] warningStrips;
        public ControlLever[] levers;
        public Renderer[] leverSignals;
        public Transform[] gears;
        public Transform[] directionArrows = new Transform[0];
        MaterialPropertyBlock block;
        ConveyorBelt[] gearBelts, arrowBelts;
        float[] activeSince;
        bool[] previouslyActive;

        void Awake()
        {
            block = new MaterialPropertyBlock();
            var belts = FindObjectsByType<ConveyorBelt>();
            gearBelts = Bind(gears, belts);
            arrowBelts = Bind(directionArrows, belts);
            activeSince = new float[levers.Length];
            previouslyActive = new bool[levers.Length];
        }

        static ConveyorBelt[] Bind(Transform[] visuals, ConveyorBelt[] belts)
        {
            var result = new ConveyorBelt[visuals.Length];
            for (int i = 0; i < visuals.Length; i++)
            {
                float nearest = float.MaxValue;
                foreach (var belt in belts)
                {
                    float distance = Mathf.Abs(visuals[i].position.z - belt.transform.position.z);
                    if (distance < nearest) { nearest = distance; result[i] = belt; }
                }
            }
            return result;
        }

        void Update()
        {
            if (press && ram)
            {
                float bottom = press.plate.position.y + .3f;
                ram.position = new Vector3(press.transform.position.x, (5.8f + bottom) * .5f, press.transform.position.z);
                ram.localScale = new Vector3(.65f, (5.8f - bottom) * .5f, .65f);
                bool warning = press.state == HydraulicPress.Phase.Warning;
                float glow = warning ? (Mathf.Sin(Time.time * 16) > 0 ? 4 : 0) :
                    press.state == HydraulicPress.Phase.Compression ? 4 : .15f;
                foreach (var strip in warningStrips)
                {
                    block.Clear();
                    block.SetColor("_EmissionColor", new Color(1, .12f, .025f) * glow);
                    strip.SetPropertyBlock(block);
                }
            }
            for (int i = 0; i < levers.Length; i++)
            {
                var lever = levers[i];
                if (lever.active && !previouslyActive[i]) activeSince[i] = Time.time;
                previouslyActive[i] = lever.active;
                bool ending = lever.active && Time.time - activeSince[i] > lever.duration - 1.5f;
                float pulse = ending ? .5f + 1.5f * Mathf.PingPong(Time.time * 5, 1) : 2;
                block.Clear();
                block.SetColor("_EmissionColor", (lever.active ? new Color(1, .15f, .04f) : new Color(.1f, .8f, .9f)) * pulse);
                leverSignals[i].SetPropertyBlock(block);
            }
            for (int i = 0; i < gears.Length; i++)
            {
                var belt = gearBelts[i];
                if (belt && belt.running) gears[i].Rotate(Vector3.up, 30 * belt.speed * belt.direction * Time.deltaTime, Space.Self);
            }
            for (int i = 0; i < directionArrows.Length; i++)
            {
                var belt = arrowBelts[i];
                if (belt) directionArrows[i].rotation = Quaternion.Euler(0, belt.direction > 0 ? 90 : 270, 0);
            }
        }
    }
}
