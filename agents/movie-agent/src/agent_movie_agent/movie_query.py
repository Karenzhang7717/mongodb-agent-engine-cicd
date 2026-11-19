import os
import re
from pymongo import MongoClient
 
_client = None
 
 
def lookup_movie_record(title: str):
    global _client
    if _client is None:
        _client = MongoClient(
            os.environ["MONGODB_URI"],
            appname="devrel-tutorial-python-langgraph-cicd",
            serverSelectionTimeoutMS=5000,
        )
    return _client["cicd_tutorial"]["movies"].find_one(
        {"title": {"$regex": f"^{re.escape(title)}$", "$options": "i"}},
        {"_id": 0, "title": 1, "year": 1, "plot": 1},
    )
