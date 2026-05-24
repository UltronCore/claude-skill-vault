---
name: sentence-transformers-finetuning
description: Fine-tune sentence-transformers models for custom embedding tasks using contrastive and distillation training
version: 1.0.0
tags: [embeddings, fine-tuning, sentence-transformers, nlp, contrastive-learning, retrieval]
---

# Sentence Transformers Fine-Tuning

## Overview

Sentence Transformers (SBERT) provides a full training framework for fine-tuning embedding models on custom data using contrastive loss functions (CosineSimilarityLoss, MultipleNegativesRankingLoss, TripletLoss, etc.) and knowledge distillation. Fine-tuning dramatically improves retrieval and similarity quality on domain-specific text compared to generic pretrained models. The `sentence-transformers` 3.x API uses a `SentenceTransformerTrainer` that mirrors HuggingFace's Trainer API.

GitHub: https://github.com/UKPLab/sentence-transformers (16k+ stars)

## When to Use

- Generic embeddings perform poorly on your domain (legal, medical, code, finance)
- You have labeled pairs, triplets, or query-passage data
- You need to distill a large embedding model into a smaller one
- Building a retrieval system that requires domain-adapted embeddings
- Improving semantic similarity scoring for specific text types

## Installation

```bash
pip install sentence-transformers datasets

# For training with CUDA
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

## Key Patterns / Usage

### Fine-Tune with Cosine Similarity Loss (Pairs + Labels)
```python
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import CosineSimilarityLoss
from sentence_transformers.training_args import SentenceTransformerTrainingArguments
from datasets import Dataset

# Load base model
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

# Prepare training data: pairs with similarity scores (0.0–1.0)
train_data = Dataset.from_dict({
    "sentence1": [
        "The contract is terminated.",
        "The patient has hypertension.",
        "Submit your quarterly report.",
    ],
    "sentence2": [
        "The agreement has been ended.",
        "The client has high blood pressure.",
        "File your Q3 financials.",
    ],
    "label": [0.95, 0.90, 0.85],
})

loss = CosineSimilarityLoss(model)

args = SentenceTransformerTrainingArguments(
    output_dir="models/finetuned-minilm",
    num_train_epochs=3,
    per_device_train_batch_size=16,
    learning_rate=2e-5,
    warmup_ratio=0.1,
    fp16=True,
    logging_steps=50,
    save_steps=500,
)

trainer = SentenceTransformerTrainer(
    model=model,
    args=args,
    train_dataset=train_data,
    loss=loss,
)

trainer.train()
model.save_pretrained("models/finetuned-minilm")
```

### Fine-Tune for Retrieval with MultipleNegativesRankingLoss
```python
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import MultipleNegativesRankingLoss
from sentence_transformers.training_args import SentenceTransformerTrainingArguments
from datasets import Dataset

# Best loss for retrieval tasks — only needs (query, positive) pairs
# In-batch negatives are used automatically
model = SentenceTransformer("BAAI/bge-base-en-v1.5")

train_data = Dataset.from_dict({
    "anchor": [
        "How do I cancel my subscription?",
        "What is the return policy?",
        "How to reset my password?",
    ],
    "positive": [
        "To cancel your subscription, go to Account Settings and click Cancel Plan.",
        "We accept returns within 30 days with original receipt for a full refund.",
        "Click 'Forgot Password' on the login page and enter your email address.",
    ],
})

loss = MultipleNegativesRankingLoss(model)

args = SentenceTransformerTrainingArguments(
    output_dir="models/retrieval-bge",
    num_train_epochs=5,
    per_device_train_batch_size=32,
    learning_rate=2e-5,
    warmup_steps=100,
    fp16=True,
)

trainer = SentenceTransformerTrainer(
    model=model,
    args=args,
    train_dataset=train_data,
    loss=loss,
)
trainer.train()
```

### Triplet Loss Training (Anchor, Positive, Negative)
```python
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import TripletLoss
from sentence_transformers.training_args import SentenceTransformerTrainingArguments
from datasets import Dataset

model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")

# Triplets: anchor, positive (similar), negative (dissimilar)
train_data = Dataset.from_dict({
    "anchor": ["The sky is blue.", "Dogs are loyal animals."],
    "positive": ["The sky has a blue color.", "Canines are faithful creatures."],
    "negative": ["The earth is round.", "Cats are independent."],
})

loss = TripletLoss(model, triplet_margin=1.0)

args = SentenceTransformerTrainingArguments(
    output_dir="models/triplet-mpnet",
    num_train_epochs=3,
    per_device_train_batch_size=16,
)

trainer = SentenceTransformerTrainer(
    model=model,
    args=args,
    train_dataset=train_data,
    loss=loss,
)
trainer.train()
```

### Evaluate During Training with MTEB-Style Evaluator
```python
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import MultipleNegativesRankingLoss
from sentence_transformers.evaluation import EmbeddingSimilarityEvaluator
from sentence_transformers.training_args import SentenceTransformerTrainingArguments
from datasets import Dataset

model = SentenceTransformer("BAAI/bge-small-en-v1.5")

train_data = Dataset.from_dict({
    "anchor": ["What are operating hours?", "How to contact support?"],
    "positive": ["We are open 9am-5pm weekdays.", "Email support@company.com or call 1-800-XXX-XXXX."],
})

# Validation evaluator
val_evaluator = EmbeddingSimilarityEvaluator(
    sentences1=["Opening hours?", "Customer service contact?"],
    sentences2=["Hours of operation are 9-5.", "Reach support at 1-800-XXX-XXXX."],
    scores=[0.9, 0.88],
    name="val",
)

loss = MultipleNegativesRankingLoss(model)

args = SentenceTransformerTrainingArguments(
    output_dir="models/bge-finetuned",
    num_train_epochs=5,
    per_device_train_batch_size=16,
    eval_strategy="epoch",
    save_strategy="best",
    metric_for_best_model="val_spearman_cosine",
)

trainer = SentenceTransformerTrainer(
    model=model,
    args=args,
    train_dataset=train_data,
    evaluator=val_evaluator,
    loss=loss,
)
trainer.train()
```

### Knowledge Distillation from Large to Small Model
```python
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import MSELoss
from sentence_transformers.training_args import SentenceTransformerTrainingArguments
from datasets import Dataset
import numpy as np

# Teacher: large, accurate model
teacher = SentenceTransformer("BAAI/bge-large-en-v1.5")

# Student: smaller, faster model to train
student = SentenceTransformer("BAAI/bge-small-en-v1.5")

# Generate teacher embeddings as soft labels
sentences = [
    "Machine learning automates model training.",
    "Neural networks learn hierarchical features.",
    "Transformers use self-attention mechanisms.",
]

teacher_embeddings = teacher.encode(sentences, convert_to_numpy=True)

train_data = Dataset.from_dict({
    "sentence": sentences,
    "label": teacher_embeddings.tolist(),
})

# MSELoss trains student to match teacher embeddings
loss = MSELoss(model=student)

args = SentenceTransformerTrainingArguments(
    output_dir="models/distilled-bge",
    num_train_epochs=10,
    per_device_train_batch_size=32,
    learning_rate=3e-5,
)

trainer = SentenceTransformerTrainer(
    model=student,
    args=args,
    train_dataset=train_data,
    loss=loss,
)
trainer.train()
student.save_pretrained("models/distilled-bge")
```

### Load and Use the Fine-Tuned Model
```python
from sentence_transformers import SentenceTransformer
import numpy as np

# Load fine-tuned model
model = SentenceTransformer("models/retrieval-bge")

queries = ["How to cancel subscription?"]
documents = [
    "To cancel your subscription, go to Account Settings and click Cancel Plan.",
    "Our return policy allows 30-day returns.",
    "Reset your password via the Forgot Password link.",
]

query_embs = model.encode(queries)
doc_embs = model.encode(documents)

# Cosine similarity
scores = np.dot(query_embs, doc_embs.T) / (
    np.linalg.norm(query_embs, axis=1, keepdims=True) *
    np.linalg.norm(doc_embs, axis=1)
)

for doc, score in zip(documents, scores[0]):
    print(f"[{score:.3f}] {doc[:60]}...")
```

## Common Pitfalls

- **Batch size matters for MNRL**: `MultipleNegativesRankingLoss` uses in-batch negatives — larger batch = more negatives = better training; aim for 32-256
- **Data quality over quantity**: 1000 high-quality pairs beats 10,000 noisy ones; clean your data carefully
- **Learning rate**: typical range is 1e-5 to 3e-5; too high causes catastrophic forgetting of pretrained knowledge
- **Normalization required for cosine**: fine-tuned models for retrieval should normalize embeddings; check if base model already does this
- **Validation set is critical**: without evaluation, you can't detect overfitting; always hold out 5-10% for validation
- **Base model selection**: start with a model already strong on your domain (legal, code, medical) rather than general-purpose
- **Checkpoint saving**: save the best checkpoint during training, not the last — fine-tuning can overfit on small datasets

## Related Skills

- `train-sentence-transformers` — general sentence-transformers usage and training basics
- `mteb` — evaluating embedding models with standard benchmarks
- `peft-fine-tuning` — parameter-efficient fine-tuning for LLMs (LoRA, etc.)
- `embedding-pipeline` — productionizing fine-tuned embeddings
- `huggingface-llm-trainer` — HuggingFace Trainer API patterns

## GitNexus Index

```
tool: sentence-transformers-finetuning
category: llm-training
tier: library
interface: python-sdk
platform: cross-platform
stars: 16000+
```
