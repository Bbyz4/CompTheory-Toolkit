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
        fake.seed_instance(args.seed + index * 130363)
        title = fake.catch_phrase()
        description = "\n\n".join(fake.paragraphs(nb=3))
        difficulty = fake.random_int(min=0, max=10)
        items.append(
            {
                "title": title,
                "description": description,
                "difficulty": difficulty,
            }
        )

    print(json.dumps(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
