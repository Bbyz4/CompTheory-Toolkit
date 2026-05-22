import argparse
import json
import sys

try:
    from faker import Faker
except Exception as exc:
    print(json.dumps({"error": str(exc)}))
    sys.exit(2)


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
        profile = fake.simple_profile()
        first_name = fake.first_name()
        last_name = fake.last_name()
        items.append(
            {
                "first_name": first_name,
                "last_name": last_name,
                "username": profile["username"],
                "email": profile["mail"],
                "password": f"Pass{index:05d}word!",
                "client_id": f"loadtest-client-{index:05d}",
            }
        )

    print(json.dumps(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
