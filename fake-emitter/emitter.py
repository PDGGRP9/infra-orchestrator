from __future__ import annotations

import json
import os
import random
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timezone

import paho.mqtt.client as mqtt


@dataclass
class Sample:
    sample_type: str
    sample_index: int
    sample_value: float


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


class FakeBraceletEmitter:
    def __init__(self) -> None:
        self.mqtt_host = os.getenv("MQTT_HOST", "mqtt-broker")
        self.mqtt_port = int(os.getenv("MQTT_PORT", "1883"))
        self.mqtt_user = os.getenv("MQTT_USER", "mqtt")
        self.mqtt_password = os.getenv("MQTT_PASSWORD", "mqtt")
        self.topic = os.getenv("MQTT_TOPIC", "bracelets/fake-bracelet-001/measurements")
        self.device_uid = os.getenv("DEVICE_UID", "11111111-1111-1111-1111-111111111111")
        self.serial_number = os.getenv("SERIAL_NUMBER", "FAKE-BRACELET-001")
        self.display_name = os.getenv("DISPLAY_NAME", "Bracelet de test")
        self.interval_seconds = float(os.getenv("EMIT_INTERVAL_SECONDS", "5"))
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="fake-emitter")
        self.client.username_pw_set(self.mqtt_user, self.mqtt_password)

    def build_payload(self, sequence: int) -> dict[str, object]:
        base_heart_rate = 68 + 10 * random.random()
        heart_rate = int(bounded(base_heart_rate + random.uniform(-6, 6), 45, 180))
        spo2 = round(bounded(97.5 + random.uniform(-1.2, 0.8), 90, 100), 1)
        step_count = max(0, sequence * random.randint(1, 3))
        motion_level = round(bounded(random.uniform(0.05, 1.0), 0.0, 1.0), 3)
        signal_quality = int(bounded(88 + random.uniform(-18, 8), 0, 100))
        red_ppg = round(1800 + random.uniform(-120, 120), 3)
        ir_ppg = round(2200 + random.uniform(-150, 150), 3)

        samples = [
            asdict(Sample("red_ppg", 0, red_ppg)),
            asdict(Sample("ir_ppg", 0, ir_ppg)),
            asdict(Sample("motion_x", 0, round(random.uniform(-1.5, 1.5), 4))),
            asdict(Sample("motion_y", 0, round(random.uniform(-1.5, 1.5), 4))),
            asdict(Sample("motion_z", 0, round(random.uniform(-1.5, 1.5), 4))),
        ]

        return {
            "device_uid": self.device_uid,
            "serial_number": self.serial_number,
            "display_name": self.display_name,
            "captured_at": utc_now(),
            "heart_rate_bpm": heart_rate,
            "spo2_percent": spo2,
            "step_count": step_count,
            "motion_level": motion_level,
            "signal_quality": signal_quality,
            "source_topic": self.topic,
            "raw_payload": {
                "sequence": sequence,
                "red_ppg": red_ppg,
                "ir_ppg": ir_ppg,
            },
            "samples": samples,
        }

    def run(self) -> None:
        sequence = 0

        while True:
            try:
                self.client.connect(self.mqtt_host, self.mqtt_port, keepalive=60)
                self.client.loop_start()
                while True:
                    payload = self.build_payload(sequence)
                    self.client.publish(self.topic, json.dumps(payload), qos=1, retain=False)
                    sequence += 1
                    time.sleep(self.interval_seconds)
            except Exception as exc:
                print(f"MQTT unavailable, retrying: {exc}")
                time.sleep(3)
            finally:
                self.client.loop_stop()
                self.client.disconnect()


def main() -> None:
    FakeBraceletEmitter().run()


if __name__ == "__main__":
    main()