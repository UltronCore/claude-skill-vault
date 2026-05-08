---
name: llm-eval
description: Route LLM evaluation tasks to the right framework — unit testing, RAG eval, tracing, experiment tracking
type: tool-routing
repos_absorbed: [deepeval, trulens, phoenix, langsmith-sdk, prompttools]
---

# LLM Eval

Routes LLM evaluation tasks to the correct framework based on eval type and integration needs.

## Routing Table

| Use Case | Framework | Key Strength |
|----------|-----------|-------------|
| Unit-test LLM outputs like pytest | deepeval | Assertion-based, CI-ready |
| RAG triad (relevancy, faithfulness, context) | trulens | RAG-native metrics |
| OTel tracing + experiment tracking | phoenix (Arize) | Observability-first |
| LangChain/LangSmith-integrated evals | langsmith-sdk | Tight LangChain integration |
| Prompt comparison / A/B testing | prompttools | Multi-provider prompt testing |

## deepeval — Pytest-style LLM Unit Testing

```python
# pip install deepeval

from deepeval import assert_test
from deepeval.metrics import AnswerRelevancyMetric, HallucinationMetric
from deepeval.test_case import LLMTestCase

def test_answer_quality():
    test_case = LLMTestCase(
        input="What is the capital of France?",
        actual_output="Paris is the capital of France.",
        expected_output="Paris",
        context=["France is a country in Western Europe. Its capital is Paris."]
    )
    assert_test(test_case, [
        AnswerRelevancyMetric(threshold=0.7),
        HallucinationMetric(threshold=0.3)
    ])

# Run with: deepeval test run test_file.py
```

**Key metrics**: AnswerRelevancy, Hallucination, Faithfulness, ContextualPrecision, ContextualRecall, Summarization, GEval (custom)

**CI usage**:
```bash
deepeval test run tests/ --confident-api-key $CONFIDENT_API_KEY  # optional cloud reporting
# or without cloud:
pytest tests/ -v
```

## trulens — RAG Evaluation

```python
# pip install trulens-eval

from trulens_eval import Tru, TruChain, Feedback
from trulens_eval.feedback.provider import OpenAI

tru = Tru()
provider = OpenAI()

# RAG triad: the three core RAG metrics
f_answer_relevance = Feedback(provider.relevance).on_input_output()
f_context_relevance = Feedback(provider.context_relevance).on_input().on(TruChain.select_context())
f_groundedness = Feedback(provider.groundedness_measure_with_cot_reasons).on(TruChain.select_context()).on_output()

tru_recorder = TruChain(
    chain,  # your LangChain chain
    app_id="my-rag-app",
    feedbacks=[f_answer_relevance, f_context_relevance, f_groundedness]
)

with tru_recorder as recording:
    response = chain.invoke({"question": "What is RAG?"})

# View results
tru.run_dashboard()  # opens at localhost:8501
```

**RAG triad explained**:
- **Answer relevance**: Does the answer address the question?
- **Context relevance**: Does retrieved context relate to the question?
- **Groundedness**: Is the answer grounded in the retrieved context?

## phoenix — OTel Tracing + Experiment Tracking

```python
# pip install arize-phoenix opentelemetry-sdk opentelemetry-exporter-otlp

import phoenix as px
from phoenix.otel import register

# Start local Phoenix server
session = px.launch_app()

# Instrument your LLM calls
tracer_provider = register(
    project_name="my-llm-project",
    endpoint="http://localhost:6006/v1/traces"
)

# Auto-instrument LangChain
from openinference.instrumentation.langchain import LangChainInstrumentor
LangChainInstrumentor().instrument(tracer_provider=tracer_provider)

# Auto-instrument OpenAI
from openinference.instrumentation.openai import OpenAIInstrumentor
OpenAIInstrumentor().instrument(tracer_provider=tracer_provider)

# View traces at http://localhost:6006
```

**Use phoenix when**: You need distributed tracing, latency analysis, cost tracking, or visual span inspection across complex chains.

## langsmith-sdk — LangChain-Integrated Evals

```python
# pip install langsmith

from langsmith import Client
from langsmith.evaluation import evaluate

client = Client()

# Define evaluator
def correct_answer(run, example):
    return {"score": int(run.outputs["output"] == example.outputs["answer"])}

# Run evaluation on a dataset
results = evaluate(
    lambda inputs: llm_chain.invoke(inputs),
    data="my-dataset-name",  # dataset in LangSmith
    evaluators=[correct_answer],
    experiment_prefix="experiment-v1"
)
```

**Best for**: Teams already using LangChain/LangSmith with existing datasets in LangSmith cloud. Requires `LANGCHAIN_API_KEY`.

## prompttools — Prompt A/B Testing

```python
# pip install prompttools

from prompttools.experiment import OpenAICompletionExperiment

# Compare prompts across models/parameters
experiment = OpenAICompletionExperiment(
    ["gpt-3.5-turbo", "gpt-4"],
    [
        "Answer concisely: {question}",
        "Be detailed and thorough: {question}"
    ],
    {"question": ["What is ML?", "What is RAG?"]}
)

experiment.run()
experiment.visualize()  # Jupyter notebook output
```

**Best for**: Comparing prompt variants, testing across models, finding best temperature/system prompt combinations.

## Decision Guide

**"My LLM answers wrong — write a test"** → deepeval
**"My RAG is hallucinating — diagnose why"** → trulens (RAG triad)
**"Trace latency and cost across my pipeline"** → phoenix
**"I use LangChain and want cloud eval tracking"** → langsmith-sdk
**"Compare prompt A vs B across GPT-3.5 and GPT-4"** → prompttools

## API Requirements

| Tool | Required Keys |
|------|--------------|
| deepeval | None (local); `CONFIDENT_API_KEY` for cloud dashboard |
| trulens | `OPENAI_API_KEY` for OpenAI-based feedback provider |
| phoenix | None (fully local) |
| langsmith-sdk | `LANGCHAIN_API_KEY`, `LANGCHAIN_TRACING_V2=true` |
| prompttools | Provider keys (e.g. `OPENAI_API_KEY`) |
