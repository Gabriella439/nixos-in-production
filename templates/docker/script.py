import json

start_all()

expected = [
    {"id": 1, "done": False, "task": "finish tutorial 0", "due": None},
    {"id": 2, "done": False, "task": "pat self on back", "due": None},
]

actual = json.loads(
    client.wait_until_succeeds(
        "curl --fail --silent http://server:3000/todos",
        55,
    )
)

assert expected == actual
