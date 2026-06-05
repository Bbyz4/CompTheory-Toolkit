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
                "first_name": f"Mock{args.seed}",
                "last_name": f"User{index}",
                "username": f"mock_user_{index:05d}",
                "email": f"mock_user_{index:05d}@example.test",
                "password": f"Pass{index:05d}word!",
                "client_id": f"mock-client-{index:05d}",
            }
        )

    print(json.dumps(items))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
