import argparse
import json


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--start-index", type=int, required=True)
    parser.add_argument("--count", type=int, required=True)
    args = parser.parse_args()

    items = []
    for index in range(args.start_index, args.start_index + args.count):
        items.append(
            {
                "title": f"Generated Task {args.seed}-{index:05d}",
                "description": f"Mock task description {index}.",
                "difficulty": index % 11,
            }
        )

    print(json.dumps(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
