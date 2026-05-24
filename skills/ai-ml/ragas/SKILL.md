---
name: ragas
description: Evaluation framework for RAG pipelines measuring faithfulness, relevance, and answer correctness
version: 1.0.0
tags: [llm, rag, evaluation, metrics, testing, quality-assurance]
---

# Ragas — RAG Evaluation Framework

## Overview

Ragas (RAG Assessment) is a Python framework for evaluating Retrieval-Augmented Generation pipelines without requiring human-annotated ground truth labels. It computes reference-free metrics (faithfulness, answer relevance, context precision/recall) and reference-based metrics (answer correctness) using LLMs as judges. Integrates with LangChain, LlamaIndex, and Haystack.

GitHub: https://github.com/explodinggradients/ragas (8k+ stars)

## When to Use

- Evaluating RAG pipeline quality before deployment
- A/B testing different retrieval strategies or chunk sizes
- Monitoring RAG quality in production over time
- Automated regression testing for RAG systems
- Debugging poor RAG responses with metric-level analysis

## Installation

```bash
pip install ragas

# With specific integrations
pip install ragas langchain
```

## Key Patterns / Usage

### Core Metrics Overview
```
- faithfulness: Are answers faithful to the retrieved context? (0-1)
- answer_relevancy: Does the answer address the question? (0-1)
- context_precision: Is retrieved context relevant and precise? (0-1)
- context_recall: Does context cover all info needed? (needs ground truth, 0-1)
- answer_correctness: Is the answer factually correct? (needs ground truth, 0-1)
```

### Basic Evaluation Dataset
```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision
from datasets import Dataset

# Prepare evaluation data
eval_data = {
    "question": [
        "What is the capital of France?",
        "Who wrote Harry Potter?",
        "When was Python created?",
    ],
    "answer": [
        "The capital of France is Paris.",
        "Harry Potter was written by J.K. Rowling.",
        "Python was created in 1991 by Guido van Rossum.",
    ],
    "contexts": [
        ["Paris is the capital and largest city of France."],
        ["J.K. Rowling wrote the Harry Potter series starting in 1997."],
        ["Python is a programming language created by Guido van Rossum in 1991."],
    ],
    # Optional: ground truth for reference-based metrics
    "ground_truth": [
        "Paris is the capital of France.",
        "J.K. Rowling wrote Harry Potter.",
        "Python was created in 1991.",
    ],
}

dataset = Dataset.from_dict(eval_data)

# Run evaluation
result = evaluate(
    dataset=dataset,
    metrics=[faithfulness, answer_relevancy, context_precision],
)

print(result)
# {'faithfulness': 0.97, 'answer_relevancy': 0.95, 'context_precision': 0.92}
```

### Evaluate a LangChain RAG Pipeline
```python
from ragas.integrations.langchain import EvaluatorChain
from ragas.metrics import faithfulness, answer_relevancy
from langchain.chains import RetrievalQA

# Your LangChain RAG chain
qa_chain = RetrievalQA.from_chain_type(...)

# Wrap with Ragas evaluator
evaluator = EvaluatorChain(metric=faithfulness)

# Run and evaluate
questions = ["What is machine learning?", "How does RAG work?"]
for question in questions:
    result = qa_chain({"query": question})
    score = evaluator({"question": question, "answer": result["result"], "contexts": result["source_documents"]})
    print(f"Q: {question} | Faithfulness: {score['faithfulness']:.2f}")
```

### With Custom LLM Judge
```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy
from ragas.llms import LangchainLLMWrapper
from langchain_anthropic import ChatAnthropic

# Use Claude as the evaluation LLM
claude = ChatAnthropic(model="claude-3-5-haiku-20241022")
ragas_llm = LangchainLLMWrapper(claude)

result = evaluate(
    dataset=dataset,
    metrics=[faithfulness, answer_relevancy],
    llm=ragas_llm,
)
print(result)
```

### Testset Generation (No Ground Truth Needed)
```python
from ragas.testset import TestsetGenerator
from ragas.testset.evolutions import simple, reasoning, multi_context
from langchain_community.document_loaders import DirectoryLoader
from langchain_openai import ChatOpenAI, OpenAIEmbeddings

# Load your documents
loader = DirectoryLoader("./docs/", glob="**/*.txt")
documents = loader.load()

# Generate test questions from your documents
generator = TestsetGenerator.from_langchain(
    generator_llm=ChatOpenAI(model="gpt-4o"),
    critic_llm=ChatOpenAI(model="gpt-4o"),
    embeddings=OpenAIEmbeddings(),
)

testset = generator.generate_with_langchain_docs(
    documents,
    test_size=20,
    distributions={simple: 0.5, reasoning: 0.25, multi_context: 0.25},
)

# Convert to dataset for evaluation
eval_df = testset.to_pandas()
print(eval_df.head())
```

### Scoring Individual Samples
```python
from ragas.metrics import Faithfulness
from ragas.dataset_schema import SingleTurnSample
import asyncio

metric = Faithfulness()

sample = SingleTurnSample(
    user_input="What is the speed of light?",
    response="The speed of light is approximately 3×10^8 m/s in a vacuum.",
    retrieved_contexts=["The speed of light in a vacuum is 299,792,458 meters per second."],
)

score = asyncio.run(metric.single_turn_ascore(sample))
print(f"Faithfulness score: {score:.3f}")
```

### Batch Evaluation with Metrics Comparison
```python
import pandas as pd
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_precision,
    answer_correctness,
)

# Evaluate two RAG configurations
results_v1 = evaluate(dataset_v1, metrics=[faithfulness, answer_relevancy, context_precision])
results_v2 = evaluate(dataset_v2, metrics=[faithfulness, answer_relevancy, context_precision])

comparison = pd.DataFrame({
    "Metric": ["Faithfulness", "Answer Relevancy", "Context Precision"],
    "Config V1": [results_v1["faithfulness"], results_v1["answer_relevancy"], results_v1["context_precision"]],
    "Config V2": [results_v2["faithfulness"], results_v2["answer_relevancy"], results_v2["context_precision"]],
})
print(comparison)
```

### Production Monitoring
```python
import pandas as pd
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy

def evaluate_production_batch(logs: list[dict]) -> pd.DataFrame:
    """Evaluate a batch of production RAG logs."""
    dataset = Dataset.from_dict({
        "question": [log["query"] for log in logs],
        "answer": [log["response"] for log in logs],
        "contexts": [log["retrieved_docs"] for log in logs],
    })
    
    result = evaluate(dataset, metrics=[faithfulness, answer_relevancy])
    return result.to_pandas()

# Log failing responses for investigation
df = evaluate_production_batch(recent_logs)
failing = df[df["faithfulness"] < 0.5]
print(f"Low faithfulness cases: {len(failing)}")
```

## Common Pitfalls

- **API costs**: Ragas uses LLMs as judges — evaluating 100 samples costs real API money; budget accordingly
- **No ground truth needed** for faithfulness/relevancy; required for context_recall/answer_correctness
- **Context format**: pass contexts as a list of strings per question, not a single string
- **OpenAI default**: Ragas defaults to OpenAI; explicitly configure if using Anthropic or local models
- **Score interpretation**: scores are relative, not absolute; track trends over time rather than fixating on a threshold
- **Async**: modern Ragas uses async scoring; wrap in `asyncio.run()` if not in async context

## Related Skills

- `rag-pipeline` — building RAG systems to evaluate
- `llm-evaluation` — general LLM evaluation patterns
- `haystack` — pipeline framework with built-in evaluation
- `mteb` — embedding model benchmarks
- `data-quality-validation` — general data quality patterns

## GitNexus Index

```
tool: ragas
category: llm-evaluation
tier: library
interface: python-sdk
platform: cross-platform
stars: 8000+
```
