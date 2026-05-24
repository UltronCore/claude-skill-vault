---
name: elasticsearch-search
description: Design and implement full-text search, faceted navigation, autocomplete, and analytics using Elasticsearch. Covers index design, mappings, query DSL, aggregations, and performance tuning.
version: 1.0.0
tags: [elasticsearch, search, full-text, analytics, opensearch, lucene]
---

# Elasticsearch Search Engineering

## Overview

This skill covers production Elasticsearch usage from index design through query optimization. It addresses full-text search with relevance tuning, faceted navigation, autocomplete/suggestions, aggregations for analytics, and operational concerns including index lifecycle management and performance. Applies to Elasticsearch 8.x and OpenSearch 2.x.

## When to Use

- Adding full-text search to an application (product catalog, docs, content)
- Building faceted navigation with filters, counts, and ranges
- Implementing autocomplete or "did you mean" suggestions
- Analytics and log aggregation (replacing parts of a data warehouse)
- Replacing slow LIKE queries in PostgreSQL/MySQL with proper search

## Step-by-Step Workflow

### 1. Index Design and Mappings
```bash
# Create index with explicit mappings (never rely on dynamic mapping in prod)
curl -X PUT "localhost:9200/products" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "autocomplete": {
          "tokenizer": "autocomplete_tokenizer",
          "filter": ["lowercase"]
        },
        "autocomplete_search": {
          "tokenizer": "lowercase"
        }
      },
      "tokenizer": {
        "autocomplete_tokenizer": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 10,
          "token_chars": ["letter", "digit"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "english",
        "fields": {
          "keyword": { "type": "keyword" },
          "autocomplete": {
            "type": "text",
            "analyzer": "autocomplete",
            "search_analyzer": "autocomplete_search"
          }
        }
      },
      "description": { "type": "text", "analyzer": "english" },
      "price": { "type": "scaled_float", "scaling_factor": 100 },
      "category": { "type": "keyword" },
      "tags": { "type": "keyword" },
      "in_stock": { "type": "boolean" },
      "created_at": { "type": "date" },
      "rating": { "type": "float" }
    }
  }
}'
```

### 2. Full-Text Search with Relevance Tuning
```python
from elasticsearch import Elasticsearch

es = Elasticsearch("http://localhost:9200")

def search_products(query: str, page: int = 0, size: int = 20):
    return es.search(
        index="products",
        body={
            "from": page * size,
            "size": size,
            "query": {
                "bool": {
                    "must": [
                        {
                            "multi_match": {
                                "query": query,
                                "fields": ["name^3", "description^1", "tags^2"],
                                "type": "best_fields",
                                "fuzziness": "AUTO",
                                "minimum_should_match": "75%"
                            }
                        }
                    ],
                    "filter": [
                        {"term": {"in_stock": True}}
                    ],
                    "should": [
                        {"term": {"category": "featured"}},
                        {"range": {"rating": {"gte": 4.0}}}
                    ]
                }
            },
            "_source": ["id", "name", "price", "category", "rating"],
            "highlight": {
                "fields": {
                    "name": {},
                    "description": {"fragment_size": 150}
                }
            }
        }
    )
```

### 3. Faceted Navigation with Aggregations
```python
def search_with_facets(query: str, filters: dict = None):
    must_clauses = [{"multi_match": {"query": query, "fields": ["name^2", "description"]}}]
    filter_clauses = []
    
    if filters:
        if "categories" in filters:
            filter_clauses.append({"terms": {"category": filters["categories"]}})
        if "price_range" in filters:
            filter_clauses.append({"range": {"price": {
                "gte": filters["price_range"]["min"],
                "lte": filters["price_range"]["max"]
            }}})
    
    return es.search(index="products", body={
        "query": {
            "bool": {
                "must": must_clauses,
                "filter": filter_clauses
            }
        },
        "aggs": {
            "categories": {
                "terms": {"field": "category", "size": 20}
            },
            "price_ranges": {
                "range": {
                    "field": "price",
                    "ranges": [
                        {"key": "Under $25", "to": 25},
                        {"key": "$25-$50", "from": 25, "to": 50},
                        {"key": "$50-$100", "from": 50, "to": 100},
                        {"key": "Over $100", "from": 100}
                    ]
                }
            },
            "avg_rating": {"avg": {"field": "rating"}}
        },
        "size": 20
    })
```

### 4. Autocomplete
```python
def autocomplete(prefix: str, size: int = 5) -> list[str]:
    result = es.search(index="products", body={
        "size": size,
        "query": {
            "match": {
                "name.autocomplete": {
                    "query": prefix,
                    "analyzer": "autocomplete_search"
                }
            }
        },
        "_source": ["name"],
        "sort": ["_score", {"rating": "desc"}]
    })
    return [hit["_source"]["name"] for hit in result["hits"]["hits"]]
```

### 5. Bulk Indexing
```python
from elasticsearch.helpers import streaming_bulk
import json

def index_products(products: list[dict]):
    def actions():
        for product in products:
            yield {
                "_index": "products",
                "_id": product["id"],
                "_source": product
            }
    
    success, errors = 0, []
    for ok, item in streaming_bulk(es, actions(), chunk_size=500, raise_on_error=False):
        if ok:
            success += 1
        else:
            errors.append(item)
    
    print(f"Indexed {success} docs, {len(errors)} errors")
    return errors
```

## Key Commands Reference

```bash
# Cluster health
curl localhost:9200/_cluster/health?pretty

# Index stats
curl localhost:9200/products/_stats?pretty
curl localhost:9200/products/_count

# Test analyzer
curl -X POST "localhost:9200/products/_analyze?pretty" -H 'Content-Type: application/json' \
  -d '{"analyzer": "english", "text": "Running shoes"}'

# Explain scoring
curl -X GET "localhost:9200/products/_explain/doc-id" -H 'Content-Type: application/json' \
  -d '{"query": {"match": {"name": "shoes"}}}'

# Reindex
curl -X POST "localhost:9200/_reindex" -H 'Content-Type: application/json' \
  -d '{"source": {"index": "products_v1"}, "dest": {"index": "products_v2"}}'

# Index aliases (zero-downtime reindex)
curl -X POST "localhost:9200/_aliases" -H 'Content-Type: application/json' \
  -d '{"actions": [{"add": {"index": "products_v2", "alias": "products"}}, {"remove": {"index": "products_v1", "alias": "products"}}]}'
```

## Common Patterns

### Pattern 1: Index Lifecycle Management (ILM)
```json
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {"max_size": "50GB", "max_age": "7d"},
          "set_priority": {"priority": 100}
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {"number_of_shards": 1},
          "forcemerge": {"max_num_segments": 1},
          "set_priority": {"priority": 50}
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {"delete": {}}
      }
    }
  }
}
```

### Pattern 2: Percolator (Reverse Search — notify when doc matches saved query)
```python
# Store a "saved search" (user wants to be notified of new red shoes under $50)
es.index(index="saved_searches", id="alert-123", body={
    "query": {
        "bool": {
            "must": [{"match": {"name": "shoes"}}],
            "filter": [{"term": {"color": "red"}}, {"range": {"price": {"lte": 50}}}]
        }
    }
})

# Check new product against all saved searches
result = es.search(index="saved_searches", body={
    "query": {
        "percolate": {
            "field": "query",
            "document": {"name": "Red Running Shoes", "color": "red", "price": 45}
        }
    }
})
# Returns IDs of matching saved searches → trigger notifications
```

### Pattern 3: Geo Search
```python
def find_nearby(lat: float, lon: float, radius_km: float = 10):
    return es.search(index="stores", body={
        "query": {
            "geo_distance": {
                "distance": f"{radius_km}km",
                "location": {"lat": lat, "lon": lon}
            }
        },
        "sort": [{"_geo_distance": {"location": {"lat": lat, "lon": lon}, "order": "asc"}}],
        "_source": ["name", "address", "location"]
    })
```

## Pitfalls to Avoid

1. **Too many shards**: Each shard has overhead (threads, file handles, memory). The recommended target is 10-50GB per shard. For a 100GB index, 3 shards is better than 30. Use the `_cat/shards` API to monitor shard sizes. Oversharding is the #1 cause of Elasticsearch performance problems.

2. **Using `_all` or wildcard index patterns carelessly**: Queries like `GET /*/_search` hit every index including system indices. Always specify index names or aliases. Disable `_all` field in mappings (it's disabled by default in ES 6+) to save disk space.

3. **Not using filter context**: Queries in `filter` context are cached and don't affect scoring — much faster for boolean/range/term filters. Only put text relevance queries in `must`/`should`. A common mistake is putting `{"term": {"in_stock": true}}` in `must` instead of `filter`.

## Related Skills

- `dbt-analytics` — Transform data before indexing into Elasticsearch
- `kafka-event-streaming` — Stream events from Kafka into Elasticsearch
- `clickhouse-analytics` — When aggregation analytics needs SQL semantics
- `data-quality-validation` — Validate data before indexing

## GitNexus Index

```json
{
  "skill": "elasticsearch-search",
  "category": "data-engineering",
  "triggers": ["elasticsearch", "opensearch", "full-text search", "lucene", "search engine", "faceted search", "autocomplete"],
  "outputs": ["search index", "search query", "aggregation", "mapping", "autocomplete"],
  "complexity": "high",
  "tools": ["elasticsearch", "opensearch", "kibana", "logstash"]
}
```
