import os
import secrets
from pymongo import MongoClient

# Generate a fresh, non-public marker each time the seed script runs.
nonce = "verification-" + secrets.token_hex(12)
MOVIES = [
    {"title": "Dune", "year": 2021,
     "plot": f"Paul Atreides travels to Arrakis, a desert planet. Test marker: {nonce}"},
    {"title": "Arrival", "year": 2016,
     "plot": "A linguist tries to communicate with alien visitors."},
    {"title": "The Matrix", "year": 1999,
     "plot": "A hacker discovers his world is a simulation."},
]
 
with MongoClient(
    os.environ["MONGODB_URI"],
    appname="devrel-tutorial-python-langgraph-cicd",
) as client:
    coll = client["cicd_tutorial"]["movies"]
    for movie in MOVIES:
        coll.replace_one({"title": movie["title"]}, movie, upsert=True)
    print("Tutorial movies seeded:", len(MOVIES))
    print("SMOKE_TEST_NONCE for this database:", nonce)
