---
name: kafka-event-streaming
description: Design and implement event-driven architectures with Apache Kafka. Covers producers, consumers, consumer groups, schema registry, Kafka Streams, and deployment patterns.
version: 1.0.0
tags: [kafka, event-streaming, event-driven, messaging, data-pipeline, distributed-systems]
---

# Kafka Event Streaming

## Overview

This skill enables building reliable event-driven systems using Apache Kafka. It covers the full stack: topic design and partitioning strategy, producer/consumer implementation, schema management with Avro/Protobuf, Kafka Streams for stream processing, and operational concerns like consumer lag monitoring and replay strategies. Works with any Kafka client (Java, Python, Go, Node.js).

## When to Use

- Decoupling microservices with durable, replayable message queues
- Building real-time data pipelines from application events to data warehouses
- Implementing event sourcing or CQRS patterns
- Replacing point-to-point REST calls between services with async messaging
- Fan-out scenarios: one event triggers many downstream consumers

## Step-by-Step Workflow

### 1. Topic Design
```bash
# Create topics with proper partitions and replication
kafka-topics.sh --create \
  --topic orders.created \
  --partitions 12 \
  --replication-factor 3 \
  --config retention.ms=604800000 \   # 7 days
  --config cleanup.policy=delete \
  --bootstrap-server localhost:9092

# Partition count heuristic: target_throughput_MB/s / 10 MB/s per partition
# Always use replication-factor=3 in production

# List and describe topics
kafka-topics.sh --list --bootstrap-server localhost:9092
kafka-topics.sh --describe --topic orders.created --bootstrap-server localhost:9092
```

### 2. Producer (Python with confluent-kafka)
```python
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
import json

conf = {
    'bootstrap.servers': 'localhost:9092',
    'acks': 'all',                    # Strongest durability guarantee
    'retries': 10,
    'retry.backoff.ms': 100,
    'enable.idempotence': True,       # Exactly-once semantics
    'compression.type': 'snappy',
    'batch.size': 65536,
    'linger.ms': 5,                   # Batch up to 5ms for throughput
}

producer = Producer(conf)

def delivery_report(err, msg):
    if err is not None:
        print(f'Delivery failed: {err}')
    else:
        print(f'Delivered to {msg.topic()}[{msg.partition()}] @ {msg.offset()}')

# Produce with key (same key → same partition, ordering guaranteed)
producer.produce(
    topic='orders.created',
    key=str(order_id).encode(),
    value=json.dumps(order_event).encode(),
    callback=delivery_report
)
producer.flush()  # Wait for all messages to be delivered
```

### 3. Consumer with Error Handling
```python
from confluent_kafka import Consumer, KafkaError, KafkaException

conf = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'order-processor-v1',
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False,      # Manual commit for at-least-once
    'max.poll.interval.ms': 300000,
    'session.timeout.ms': 45000,
}

consumer = Consumer(conf)
consumer.subscribe(['orders.created'])

try:
    while True:
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue
            raise KafkaException(msg.error())
        
        try:
            event = json.loads(msg.value())
            process_order(event)
            consumer.commit(msg)  # Commit only after successful processing
        except Exception as e:
            send_to_dead_letter_queue(msg, e)
            consumer.commit(msg)  # Commit to advance past poison pill
finally:
    consumer.close()
```

### 4. Schema Registry with Avro
```bash
# Register schema
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"Order\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"total\",\"type\":\"double\"},{\"name\":\"created_at\",\"type\":\"long\"}]}"}' \
  http://localhost:8081/subjects/orders.created-value/versions
```

```python
# Producer with Avro serialization
schema_registry_conf = {'url': 'http://localhost:8081'}
schema_registry_client = SchemaRegistryClient(schema_registry_conf)
avro_serializer = AvroSerializer(schema_registry_client, schema_str)

producer = SerializingProducer({
    'bootstrap.servers': 'localhost:9092',
    'value.serializer': avro_serializer,
})
```

### 5. Kafka Streams (Java/Kotlin)
```java
StreamsBuilder builder = new StreamsBuilder();

KStream<String, OrderEvent> orders = builder.stream("orders.created");

// Filter, transform, and produce to new topic
orders
    .filter((key, value) -> value.getTotal() > 100.0)
    .mapValues(order -> new HighValueOrder(order.getId(), order.getTotal()))
    .to("orders.high-value", Produced.with(Serdes.String(), highValueSerde));

// Aggregate with windowing
orders
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
    .count()
    .toStream()
    .to("orders.count-per-minute");

KafkaStreams streams = new KafkaStreams(builder.build(), props);
streams.start();
Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
```

### 6. Monitor Consumer Lag
```bash
# Check lag for all consumer groups
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group order-processor-v1

# Output: TOPIC, PARTITION, CURRENT-OFFSET, LOG-END-OFFSET, LAG, CONSUMER-ID

# Reset offsets (replay)
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group order-processor-v1 \
  --topic orders.created \
  --reset-offsets --to-earliest --execute
```

## Key Commands Reference

```bash
# Produce/consume from CLI for testing
kafka-console-producer.sh --topic orders.created --bootstrap-server localhost:9092
kafka-console-consumer.sh --topic orders.created --from-beginning --bootstrap-server localhost:9092

# Show messages with keys
kafka-console-consumer.sh --topic orders.created \
  --formatter kafka.tools.DefaultMessageFormatter \
  --property print.key=true \
  --bootstrap-server localhost:9092

# Delete topic
kafka-topics.sh --delete --topic orders.created --bootstrap-server localhost:9092

# Increase partitions (can only increase, never decrease)
kafka-topics.sh --alter --topic orders.created --partitions 24 --bootstrap-server localhost:9092

# List consumer groups
kafka-consumer-groups.sh --list --bootstrap-server localhost:9092
```

## Common Patterns

### Pattern 1: Dead Letter Queue (DLQ)
```python
DLQ_TOPIC = "orders.created.dlq"

def send_to_dead_letter_queue(original_msg, error: Exception):
    dlq_value = {
        "original_topic": original_msg.topic(),
        "original_partition": original_msg.partition(),
        "original_offset": original_msg.offset(),
        "original_key": original_msg.key().decode() if original_msg.key() else None,
        "original_value": original_msg.value().decode(),
        "error": str(error),
        "failed_at": datetime.utcnow().isoformat(),
    }
    producer.produce(DLQ_TOPIC, value=json.dumps(dlq_value).encode())
    producer.flush()
```

### Pattern 2: Transactional Producer (Exactly-Once)
```python
producer = Producer({
    'bootstrap.servers': 'localhost:9092',
    'transactional.id': 'order-service-producer-1',
    'enable.idempotence': True,
})
producer.init_transactions()

try:
    producer.begin_transaction()
    producer.produce('orders.created', key=key, value=value)
    producer.commit_transaction()
except Exception as e:
    producer.abort_transaction()
    raise
```

### Pattern 3: Compacted Topic for State
```bash
# Compacted topics keep only latest value per key (like a KV store)
kafka-topics.sh --create \
  --topic user.preferences \
  --partitions 6 \
  --replication-factor 3 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.1 \
  --config segment.ms=300000 \
  --bootstrap-server localhost:9092
```

## Pitfalls to Avoid

1. **Too few partitions**: Partitions determine max parallelism — once created, you can only increase them. Start with more than you need: `max(target_consumers * 2, expected_MB_s / 10)`. Repartitioning breaks key-based ordering guarantees.

2. **Committing before processing**: With `enable.auto.commit=True`, offsets commit every 5 seconds regardless of processing status. Messages can be lost on consumer crash. Always use `enable.auto.commit=False` and commit manually after successful processing.

3. **Large message payloads**: Kafka is optimized for messages <1MB. For large payloads (images, binaries), store the data in S3/blob storage and put only the reference in Kafka. Configure `message.max.bytes` carefully — increasing it affects broker memory.

## Related Skills

- `event-driven-architecture` — Overall EDA design patterns
- `cqrs-patterns` — Command/Query Responsibility Segregation with Kafka
- `data-pipeline-engineer` — End-to-end data pipeline design
- `opentelemetry-instrumentation` — Tracing across Kafka producers/consumers
- `clickhouse-analytics` — Consuming Kafka topics into ClickHouse

## GitNexus Index

```json
{
  "skill": "kafka-event-streaming",
  "category": "data-engineering",
  "triggers": ["kafka", "event streaming", "message queue", "consumer group", "kafka streams", "apache kafka", "confluent"],
  "outputs": ["topic design", "producer code", "consumer code", "schema", "stream processor"],
  "complexity": "high",
  "tools": ["kafka", "confluent-kafka", "schema-registry", "kafka-streams", "ksqldb"]
}
```
