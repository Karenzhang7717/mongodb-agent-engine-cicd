from unittest.mock import patch
import mongomock
 
 
def test_exact_title_query():
    client = mongomock.MongoClient()
    client.cicd_tutorial.movies.insert_one({
        "title": "Dune", "year": 2021,
        "plot": "Arrakis. Test marker: verification-unit-test-123"})
    from agent_movie_agent.movie_query import lookup_movie_record
    with patch("agent_movie_agent.movie_query.MongoClient", return_value=client), \
         patch("agent_movie_agent.movie_query._client", None):
        result = lookup_movie_record("Dune")
    assert result["year"] == 2021
    assert result["plot"] == "Arrakis. Test marker: verification-unit-test-123"


def test_missing_movie():
    client = mongomock.MongoClient()
    from agent_movie_agent.movie_query import lookup_movie_record
    with patch("agent_movie_agent.movie_query.MongoClient", return_value=client), \
         patch("agent_movie_agent.movie_query._client", None):
        assert lookup_movie_record("Missing") is None


def test_regex_special_characters():
    client = mongomock.MongoClient()
    client.cicd_tutorial.movies.insert_one({"title": "Dune (2021)", "year": 2021})
    from agent_movie_agent.movie_query import lookup_movie_record
    with patch("agent_movie_agent.movie_query.MongoClient", return_value=client), \
         patch("agent_movie_agent.movie_query._client", None):
        assert lookup_movie_record("dune (2021)")["year"] == 2021
