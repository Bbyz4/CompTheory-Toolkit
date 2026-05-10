import argparse
import json
import re
import sys

try:
    from faker import Faker
    from unidecode import unidecode
except Exception as exc:
    print(json.dumps({"error": str(exc)}))
    sys.exit(2)


def normalize(value: str) -> str:
    value = unidecode(value).lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "user"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--start-index", type=int, required=True)
    parser.add_argument("--count", type=int, required=True)
    args = parser.parse_args()

    fake = Faker("pl_PL")
    items = []
    for index in range(args.start_index, args.start_index + args.count):
        fake.seed_instance(args.seed + index * 104729)
        first_name = fake.first_name()
        last_name = fake.last_name()
        base = normalize(f"{first_name}-{last_name}")[:26]
        username = f"{base}-{index:05d}"
        items.append(
            {
                "first_name": first_name,
                "last_name": last_name,
                "username": username,
                "email": f"{username}@{fake.free_email_domain()}",
                "password": f"Pass{index:05d}word!",
                "client_id": f"loadtest-client-{index:05d}",
            }
        )

    print(json.dumps(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
