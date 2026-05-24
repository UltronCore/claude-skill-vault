---
name: knowledge-graph
description: Build and query knowledge graphs using Neo4j, NetworkX, and RDF/SPARQL for representing complex relationships. Covers graph modeling, Cypher queries, graph embeddings, community detection, and integrating knowledge graphs with LLM RAG pipelines.
version: 1.0.0
tags: [knowledge-graph, neo4j, cypher, networkx, rdf, sparql, graph-db, graph-embeddings, rag, llm]
---

# Knowledge Graph

## Overview

A knowledge graph represents entities (nodes) and their relationships (edges) as a structured network, enabling queries that are impossible or prohibitively expensive in relational databases — multi-hop traversals, path finding, centrality analysis, and community detection. When integrated with LLMs, knowledge graphs provide factual grounding and relationship reasoning that pure vector search cannot supply, making them ideal for enterprise RAG, recommendation engines, and domain-specific AI assistants.

## When to Use

- Data with complex many-to-many relationships (customers → products → suppliers → reviews)
- Fraud detection and entity resolution across datasets
- Recommendation engines where collaborative filtering needs explicit relationship context
- Ontology-backed search that must understand taxonomies and hierarchies
- RAG pipelines where multi-hop reasoning over facts is required
- Knowledge bases that mix structured data with unstructured text
- Regulatory or compliance graphs (who approved what, which policy covers which contract)

## Step-by-Step Workflow

### 1. Graph Data Modeling

```python
# Design entities (nodes) and relationships (edges) before writing any code
# Think in: (Entity)-[:RELATIONSHIP {props}]->(Entity)

# E-commerce knowledge graph model:
# (User)-[:PURCHASED {at: datetime, amount: float}]->(Product)
# (Product)-[:BELONGS_TO]->(Category)
# (Product)-[:MADE_BY]->(Supplier)
# (User)-[:SIMILAR_TO {score: float}]->(User)
# (Product)-[:REVIEWED_BY {rating: int, text: str}]->(User)

# Key modeling decisions:
# - Nodes: things (nouns) — User, Product, Category, Supplier
# - Edges: actions or relationships (verbs) — PURCHASED, BELONGS_TO, REVIEWED_BY
# - Properties: attributes on both nodes and edges
# - Avoid modeling as a node anything that is purely an attribute (e.g., color)
```

### 2. Neo4j Setup and Cypher CRUD

```python
# pip install neo4j
from neo4j import GraphDatabase

class KnowledgeGraphClient:
    def __init__(self, uri: str, auth: tuple[str, str]):
        self.driver = GraphDatabase.driver(uri, auth=auth)

    def close(self):
        self.driver.close()

    def __enter__(self): return self
    def __exit__(self, *_): self.close()

    def create_product(self, product_id: str, name: str, price: float, category: str):
        with self.driver.session() as session:
            session.execute_write(self._create_product_tx, product_id, name, price, category)

    @staticmethod
    def _create_product_tx(tx, product_id, name, price, category):
        tx.run("""
            MERGE (p:Product {id: $product_id})
            SET p.name = $name, p.price = $price
            MERGE (c:Category {name: $category})
            MERGE (p)-[:BELONGS_TO]->(c)
        """, product_id=product_id, name=name, price=price, category=category)

    def record_purchase(self, user_id: str, product_id: str, amount: float):
        with self.driver.session() as session:
            session.execute_write(lambda tx: tx.run("""
                MERGE (u:User {id: $user_id})
                MERGE (p:Product {id: $product_id})
                CREATE (u)-[:PURCHASED {amount: $amount, at: datetime()}]->(p)
            """, user_id=user_id, product_id=product_id, amount=amount))

    def get_recommendations(self, user_id: str, limit: int = 5) -> list[dict]:
        """Collaborative filtering via 2-hop graph traversal."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (u:User {id: $user_id})-[:PURCHASED]->(p:Product)<-[:PURCHASED]-(similar:User)
                WHERE similar.id <> $user_id
                MATCH (similar)-[:PURCHASED]->(rec:Product)
                WHERE NOT (u)-[:PURCHASED]->(rec)
                RETURN rec.id AS product_id, rec.name AS name,
                       count(similar) AS social_proof
                ORDER BY social_proof DESC
                LIMIT $limit
            """, user_id=user_id, limit=limit)
            return [dict(r) for r in result]

    def find_shortest_path(self, from_id: str, to_id: str) -> list[dict]:
        """Find shortest path between two products via shared categories/suppliers."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH path = shortestPath(
                  (a:Product {id: $from_id})-[*]-(b:Product {id: $to_id})
                )
                RETURN [n IN nodes(path) | {labels: labels(n), id: n.id, name: n.name}] AS nodes,
                       length(path) AS hops
            """, from_id=from_id, to_id=to_id)
            return [dict(r) for r in result]

# Docker Compose for Neo4j development
# docker-compose.yml:
# services:
#   neo4j:
#     image: neo4j:5
#     environment:
#       - NEO4J_AUTH=neo4j/password
#       - NEO4J_PLUGINS=["apoc", "graph-data-science"]
#     ports:
#       - "7474:7474"  # Browser UI
#       - "7687:7687"  # Bolt protocol
#     volumes:
#       - neo4j_data:/data

# Connect:
with KnowledgeGraphClient("bolt://localhost:7687", ("neo4j", "password")) as kg:
    kg.create_product("prod_001", "Widget Pro", 49.99, "Electronics")
    kg.record_purchase("user_123", "prod_001", 49.99)
    recs = kg.get_recommendations("user_123")
```

### 3. NetworkX for In-Memory Graph Analysis

```python
# pip install networkx matplotlib scipy
import networkx as nx
from collections import defaultdict

def build_product_graph(purchases: list[dict]) -> nx.Graph:
    """
    Build a co-purchase graph: products as nodes,
    edge weight = number of users who bought both.
    """
    G = nx.Graph()
    user_products: dict[str, set] = defaultdict(set)

    for purchase in purchases:
        user_products[purchase["user_id"]].add(purchase["product_id"])

    for user, products in user_products.items():
        product_list = list(products)
        for i, p1 in enumerate(product_list):
            for p2 in product_list[i + 1:]:
                if G.has_edge(p1, p2):
                    G[p1][p2]["weight"] += 1
                else:
                    G.add_edge(p1, p2, weight=1)

    return G

def analyze_graph(G: nx.Graph) -> dict:
    """Compute key graph metrics for the co-purchase graph."""
    return {
        "nodes": G.number_of_nodes(),
        "edges": G.number_of_edges(),
        "density": nx.density(G),
        # PageRank: which products appear in many co-purchases (hubs)
        "pagerank": dict(sorted(
            nx.pagerank(G, weight="weight").items(),
            key=lambda x: x[1], reverse=True
        )[:10]),
        # Communities: clusters of frequently co-purchased products
        "communities": list(nx.community.greedy_modularity_communities(G)),
        # Centrality: most "bridging" products across categories
        "betweenness": dict(sorted(
            nx.betweenness_centrality(G, weight="weight").items(),
            key=lambda x: x[1], reverse=True
        )[:10]),
    }

# Fraud detection: find users in tight suspicious clusters
def detect_fraud_rings(transaction_graph: nx.DiGraph, min_ring_size: int = 3) -> list[list]:
    """Find strongly connected components (potential fraud rings)."""
    sccs = list(nx.strongly_connected_components(transaction_graph))
    return [list(scc) for scc in sccs if len(scc) >= min_ring_size]
```

### 4. RDF and SPARQL for Semantic Knowledge Graphs

```python
# pip install rdflib
from rdflib import Graph, Namespace, URIRef, Literal, RDF, RDFS, OWL
from rdflib.namespace import XSD

# Build an RDF knowledge graph with formal ontology
def build_ontology() -> Graph:
    g = Graph()
    EX = Namespace("http://example.org/")
    SCHEMA = Namespace("https://schema.org/")
    g.bind("ex", EX)
    g.bind("schema", SCHEMA)

    # Define classes
    g.add((EX.Product, RDF.type, OWL.Class))
    g.add((EX.Category, RDF.type, OWL.Class))
    g.add((EX.Supplier, RDF.type, OWL.Class))

    # Define properties
    g.add((EX.belongsTo, RDF.type, OWL.ObjectProperty))
    g.add((EX.belongsTo, RDFS.domain, EX.Product))
    g.add((EX.belongsTo, RDFS.range, EX.Category))

    # Add instances
    widget = EX["product/widget-pro"]
    g.add((widget, RDF.type, EX.Product))
    g.add((widget, RDFS.label, Literal("Widget Pro")))
    g.add((widget, EX.price, Literal(49.99, datatype=XSD.float)))
    g.add((widget, EX.belongsTo, EX["category/electronics"]))

    return g

def sparql_query(g: Graph, query: str) -> list[dict]:
    results = g.query(query)
    return [
        {str(var): str(row[var]) for var in results.vars if row[var] is not None}
        for row in results
    ]

# SPARQL: find all products in Electronics under $100
g = build_ontology()
results = sparql_query(g, """
    PREFIX ex: <http://example.org/>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    SELECT ?product ?name ?price WHERE {
        ?product a ex:Product ;
                 rdfs:label ?name ;
                 ex:price ?price ;
                 ex:belongsTo ex:category/electronics .
        FILTER(?price < 100)
    }
    ORDER BY ?price
""")
```

### 5. Knowledge Graph + LLM RAG Integration

```python
# pip install neo4j openai langchain-community
from langchain_community.graphs import Neo4jGraph
from langchain.chains import GraphCypherQAChain
from langchain_openai import ChatOpenAI

def build_graph_rag_chain():
    """
    LLM generates Cypher from natural language,
    Neo4j executes it, LLM answers from graph results.
    """
    graph = Neo4jGraph(
        url="bolt://localhost:7687",
        username="neo4j",
        password="password",
    )

    llm = ChatOpenAI(model="gpt-4o", temperature=0)

    chain = GraphCypherQAChain.from_llm(
        llm=llm,
        graph=graph,
        verbose=True,
        # Validate generated Cypher before execution
        validate_cypher=True,
        # Return intermediate Cypher for debugging
        return_intermediate_steps=True,
    )
    return chain

# Usage
chain = build_graph_rag_chain()
result = chain.invoke({"query": "Which products are frequently bought together with Widget Pro?"})
print(result["result"])
print("Cypher used:", result["intermediate_steps"][0]["query"])

# Graph embeddings for node similarity using node2vec
# pip install node2vec
from node2vec import Node2Vec

def compute_graph_embeddings(G: nx.Graph) -> dict[str, list[float]]:
    """Learn node embeddings from graph structure using node2vec."""
    node2vec = Node2Vec(
        G,
        dimensions=64,
        walk_length=30,
        num_walks=200,
        workers=4,
        weight_key="weight",
        p=1,   # return parameter
        q=0.5  # in-out parameter (< 1 = DFS-like, explores communities)
    )
    model = node2vec.fit(window=10, min_count=1, batch_words=4)

    return {node: model.wv[node].tolist() for node in G.nodes()}
```

### 6. Graph Schema and Index Setup (Neo4j)

```cypher
// Cypher DDL: constraints and indexes for performance
// Run in Neo4j Browser or via session.run()

// Uniqueness constraints (also create index automatically)
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
  FOR (u:User) REQUIRE u.id IS UNIQUE;

CREATE CONSTRAINT product_id_unique IF NOT EXISTS
  FOR (p:Product) REQUIRE p.id IS UNIQUE;

// Full-text index for product search
CREATE FULLTEXT INDEX product_search IF NOT EXISTS
  FOR (p:Product) ON EACH [p.name, p.description];

// Range index for price filtering
CREATE INDEX product_price IF NOT EXISTS
  FOR (p:Product) ON (p.price);

// Vector index for semantic similarity (Neo4j 5.15+)
CREATE VECTOR INDEX product_embeddings IF NOT EXISTS
  FOR (p:Product) ON p.embedding
  OPTIONS {
    indexConfig: {
      `vector.dimensions`: 1536,
      `vector.similarity_function`: 'cosine'
    }
  };

// Semantic similarity search
CALL db.index.vector.queryNodes('product_embeddings', 10, $queryVector)
YIELD node, score
WHERE score > 0.8
RETURN node.name, node.id, score
ORDER BY score DESC;
```

## Key Commands Reference

```bash
# Neo4j via Docker
docker run -d \
  --name neo4j \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/password \
  -e NEO4J_PLUGINS='["apoc","graph-data-science"]' \
  neo4j:5

# Python packages
pip install neo4j networkx node2vec rdflib langchain-community

# Neo4j command-line tools
cypher-shell -a bolt://localhost:7687 -u neo4j -p password

# Export graph to CSV for analysis
cypher-shell "CALL apoc.export.csv.all('export.csv', {})"

# Graph Data Science: run PageRank via GDS plugin
# CALL gds.pageRank.write('product-graph', {writeProperty: 'pagerank'})

# Validate ontology (OWL/RDF)
pip install owlready2
# python -c "from owlready2 import *; onto = get_ontology('file://ontology.owl').load(); sync_reasoner()"

# NetworkX visualization
python -c "import networkx as nx; import matplotlib.pyplot as plt; G = nx.karate_club_graph(); nx.draw(G, with_labels=True); plt.savefig('graph.png')"
```

## Common Patterns

### Pattern 1: Entity Resolution Across Data Sources

```python
# Merge entities from multiple data sources that refer to the same real-world entity
def resolve_entities(kg: KnowledgeGraphClient, source_records: list[dict]) -> dict[str, str]:
    """
    For each incoming record, find the canonical entity in the graph.
    Match on email, phone, or name similarity.
    """
    canonical_map = {}
    with kg.driver.session() as session:
        for record in source_records:
            # Try exact email match first
            result = session.run("""
                MATCH (u:User)
                WHERE u.email = $email
                   OR u.phone = $phone
                RETURN u.id AS canonical_id
                LIMIT 1
            """, email=record.get("email"), phone=record.get("phone"))
            row = result.single()
            if row:
                canonical_map[record["source_id"]] = row["canonical_id"]
            else:
                # Create new canonical entity
                new_id = f"user_{record['source_id']}"
                session.run("""
                    CREATE (u:User {id: $id, email: $email, phone: $phone})
                """, id=new_id, email=record.get("email"), phone=record.get("phone"))
                canonical_map[record["source_id"]] = new_id

    return canonical_map
```

### Pattern 2: Temporal Knowledge Graph

```python
# Track how relationships change over time using relationship properties
def add_temporal_relationship(kg: KnowledgeGraphClient, from_id: str, to_id: str, rel_type: str, valid_from: str, valid_to: str | None = None):
    """
    Store relationships with temporal validity.
    Allows querying "what was true at time T".
    """
    with kg.driver.session() as session:
        session.run(f"""
            MATCH (a {{id: $from_id}}), (b {{id: $to_id}})
            CREATE (a)-[:{rel_type} {{
                valid_from: datetime($valid_from),
                valid_to: CASE WHEN $valid_to IS NOT NULL THEN datetime($valid_to) ELSE null END
            }}]->(b)
        """, from_id=from_id, to_id=to_id, valid_from=valid_from, valid_to=valid_to)

# Query state at a specific point in time
def query_at_time(kg: KnowledgeGraphClient, timestamp: str) -> list[dict]:
    with kg.driver.session() as session:
        result = session.run("""
            MATCH (e:Employee)-[r:REPORTS_TO]->(m:Manager)
            WHERE r.valid_from <= datetime($ts)
              AND (r.valid_to IS NULL OR r.valid_to > datetime($ts))
            RETURN e.name AS employee, m.name AS manager
        """, ts=timestamp)
        return [dict(r) for r in result]
```

### Pattern 3: GraphRAG — Graph-Augmented LLM Context

```python
# Retrieve multi-hop graph context to augment LLM generation
def get_graph_context(kg: KnowledgeGraphClient, query_entity: str, depth: int = 2) -> str:
    """
    Extract neighborhood of an entity as structured text for LLM context.
    """
    with kg.driver.session() as session:
        result = session.run("""
            MATCH path = (n {id: $entity_id})-[*1..$depth]-(neighbor)
            RETURN
              [r IN relationships(path) | type(r)] AS rel_types,
              [node IN nodes(path) | coalesce(node.name, node.id)] AS node_names
            LIMIT 50
        """, entity_id=query_entity, depth=depth)

        facts = []
        for row in result:
            nodes = row["node_names"]
            rels = row["rel_types"]
            for i, rel in enumerate(rels):
                facts.append(f"{nodes[i]} --[{rel}]--> {nodes[i+1]}")

    return "\n".join(facts)

# Use in RAG pipeline
context = get_graph_context(kg, "prod_001", depth=2)
prompt = f"""
Based on the following knowledge graph facts:
{context}

Answer: What suppliers are associated with products frequently bought with Widget Pro?
"""
```

## Pitfalls to Avoid

1. **Supernode problem**: Nodes with millions of relationships (e.g., a "root" category node connected to every product) cause query timeouts when traversed. Detect supernodes with `MATCH (n) RETURN n.id, count{(n)--()}` and either shard them into sub-nodes, filter relationships by type, or use relationship limits in queries.

2. **Modeling relationships as nodes**: If "purchase" is always traversed and never queried on its own, keep it as a relationship with properties — not a (:Purchase) node. Intermediate nodes add traversal cost. Only reify a relationship into a node if it has its own outgoing relationships (e.g., a purchase that also links to promotions).

3. **Missing indexes on high-cardinality lookup properties**: Every `MATCH (n:User {email: $email})` without an index does a full label scan. Always create constraints or indexes on the properties used in WHERE clauses and MERGE conditions. Check with `EXPLAIN MATCH (n:User {email: $email}) RETURN n` — look for "NodeByLabelScan" (bad) vs "NodeIndexSeek" (good).

## Related Skills

- `embedding-pipeline` — Generating node embeddings for vector similarity search in the graph
- `vector-rag-advanced` — Combining graph traversal with dense vector retrieval
- `postgres-advanced` — Using PostgreSQL + Apache AGE as an alternative graph layer
- `functional-python` — Immutable data transformations when processing graph query results

## GitNexus Index

```json
{
  "skill": "knowledge-graph",
  "category": "data-engineering",
  "triggers": ["knowledge graph", "neo4j", "cypher query", "graph database", "networkx", "rdf sparql", "entity resolution", "graph rag", "node embeddings"],
  "outputs": ["KnowledgeGraphClient", "Cypher query", "NetworkX graph", "RDF ontology", "graph embeddings", "GraphRAG context"],
  "complexity": "high",
  "tools": ["neo4j", "networkx", "rdflib", "node2vec", "langchain", "python", "docker"]
}
```
