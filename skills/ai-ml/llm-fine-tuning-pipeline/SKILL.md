---
name: llm-fine-tuning-pipeline
description: Build end-to-end LLM fine-tuning pipelines — dataset preparation with quality filtering, SFT training with Hugging Face Trainer and TRL, LoRA/QLoRA PEFT configuration, DPO preference optimization, evaluation with LM-Eval, and vLLM serving of fine-tuned adapters.
version: 1.0.0
tags: [llm, fine-tuning, lora, qlora, peft, sft, dpo, huggingface, trl, vllm, python, training]
---

# LLM Fine-Tuning Pipeline

## Overview

Fine-tuning adapts a pretrained LLM to a specific task, domain, or style without retraining from scratch. The canonical pipeline is: curate and format a dataset → apply PEFT (LoRA/QLoRA) to train only a small adapter instead of the full model → evaluate against benchmarks → serve the merged or adapter-augmented model. QLoRA (4-bit quantization + LoRA) makes fine-tuning Llama 3 70B feasible on a single A100 80GB GPU. DPO (Direct Preference Optimization) provides a simpler alternative to RLHF for alignment from preference pairs without a separate reward model.

## When to Use

- Improving model performance on a narrow domain (legal documents, medical records, code in a specific language)
- Changing the model's output format or style (always respond as JSON, use company tone)
- Reducing inference costs by distilling a large model's behavior into a smaller one
- Instruction-tuning a base model that has no chat capability
- Alignment from human preference data (DPO) to improve helpfulness/safety
- Reducing hallucination on domain-specific factual questions by training on ground truth

## Step-by-Step Workflow

### 1. Dataset Preparation and Formatting

```python
# src/finetune/dataset_prep.py
from datasets import Dataset, DatasetDict
import json
import re

# Standard chat format for SFT (Supervised Fine-Tuning)
# Most modern models use "chatml" format
SYSTEM_PROMPT = "You are a helpful expert in financial analysis."

def format_as_chatml(examples: list[dict]) -> list[str]:
    """
    Format raw instruction-response pairs into ChatML format.
    ChatML is supported by most modern LLMs (Llama 3, Mistral, Qwen).
    """
    formatted = []
    for ex in examples:
        text = (
            f"<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>\n"
            f"<|im_start|>user\n{ex['instruction']}<|im_end|>\n"
            f"<|im_start|>assistant\n{ex['response']}<|im_end|>"
        )
        formatted.append({"text": text})
    return formatted


def filter_dataset_quality(
    dataset: list[dict],
    min_response_length: int = 50,
    max_response_length: int = 2048,
) -> list[dict]:
    """
    Basic quality filters — remove low-quality examples before training.
    Training on bad data is worse than training on less good data.
    """
    filtered = []
    for ex in dataset:
        response = ex.get("response", "")

        # Length filter
        if len(response.split()) < min_response_length // 4:
            continue
        if len(response) > max_response_length:
            continue

        # Remove truncated responses
        if response.rstrip().endswith(("...", "…")):
            continue

        # Deduplicate (simple exact match — use MinHash for fuzzy dedup at scale)
        filtered.append(ex)

    return filtered


def build_dataset_splits(
    raw_data: list[dict],
    val_pct: float = 0.05,
) -> DatasetDict:
    """Create train/validation split with formatting applied."""
    filtered = filter_dataset_quality(raw_data)
    formatted = format_as_chatml(filtered)

    n_val = max(50, int(len(formatted) * val_pct))
    train_data = formatted[n_val:]
    val_data = formatted[:n_val]

    return DatasetDict({
        "train": Dataset.from_list(train_data),
        "validation": Dataset.from_list(val_data),
    })
```

### 2. QLoRA Training with TRL SFTTrainer

```python
# src/finetune/train_qlora.py
import torch
from transformers import (
    AutoModelForCausalLM, AutoTokenizer,
    BitsAndBytesConfig, TrainingArguments,
)
from peft import LoraConfig, get_peft_model, TaskType
from trl import SFTTrainer, SFTConfig
from datasets import load_from_disk

MODEL_ID = "meta-llama/Meta-Llama-3-8B-Instruct"
OUTPUT_DIR = "models/llama3-8b-finance-lora"

# Step 1: 4-bit quantization config (QLoRA)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,     # Nested quantization: saves ~0.4GB VRAM
    bnb_4bit_quant_type="nf4",          # NF4 dtype is best for normally distributed weights
    bnb_4bit_compute_dtype=torch.bfloat16,  # BF16 for compute (not storage)
)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    quantization_config=bnb_config,
    device_map="auto",                  # Automatically split across GPUs if multi-GPU
    attn_implementation="flash_attention_2",  # 2-4x faster attention
    torch_dtype=torch.bfloat16,
)
model.config.use_cache = False           # Disable KV cache during training

tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right"        # Pad on right for training

# Step 2: LoRA configuration
lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,                   # LoRA rank — higher = more parameters, more capacity
    lora_alpha=32,          # Scaling factor (alpha/r is the effective learning rate multiplier)
    lora_dropout=0.05,
    bias="none",
    # Target modules: typically attention projections + MLP layers
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
)

# Apply LoRA adapter to the quantized model
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# → trainable params: 41,943,040 || all params: 8,072,048,640 || trainable%: 0.52

# Step 3: Training arguments
sft_config = SFTConfig(
    output_dir=OUTPUT_DIR,
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,      # Effective batch size = 4 * 4 = 16
    gradient_checkpointing=True,        # Trade compute for memory (saves ~40% VRAM)
    learning_rate=2e-4,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    weight_decay=0.001,
    fp16=False,
    bf16=True,                          # BF16 (better than FP16 for LLMs)
    max_grad_norm=0.3,
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=100,
    save_strategy="steps",
    save_steps=200,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    max_seq_length=2048,
    dataset_text_field="text",          # Column with formatted text
    packing=True,                       # Pack multiple short sequences into one — faster
)

# Step 4: Train
dataset = load_from_disk("data/finance_sft")
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    args=sft_config,
    train_dataset=dataset["train"],
    eval_dataset=dataset["validation"],
    peft_config=lora_config,
)
trainer.train()
trainer.save_model(OUTPUT_DIR)
```

### 3. DPO Training for Preference Alignment

```python
# src/finetune/train_dpo.py
# DPO (Direct Preference Optimization): train from preference pairs
# Dataset format: {"prompt": str, "chosen": str, "rejected": str}
from trl import DPOConfig, DPOTrainer
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

# Load SFT-trained model as the base for DPO
base_model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype=torch.bfloat16)
sft_model = PeftModel.from_pretrained(base_model, OUTPUT_DIR)
ref_model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype=torch.bfloat16)  # Frozen reference

dpo_config = DPOConfig(
    output_dir="models/llama3-8b-finance-dpo",
    num_train_epochs=1,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    learning_rate=5e-7,             # DPO uses much smaller LR than SFT
    beta=0.1,                       # KL penalty coefficient (0.1-0.5 typical)
    max_length=1024,
    max_prompt_length=512,
    bf16=True,
)

dpo_trainer = DPOTrainer(
    model=sft_model,
    ref_model=ref_model,
    args=dpo_config,
    train_dataset=preference_dataset["train"],
    eval_dataset=preference_dataset["validation"],
    tokenizer=tokenizer,
)
dpo_trainer.train()
```

## Key Commands Reference

```bash
# Environment setup
pip install transformers datasets trl peft bitsandbytes accelerate flash-attn
pip install vllm lm_eval wandb

# Check GPU memory availability
python -c "import torch; print(torch.cuda.get_device_properties(0).total_memory / 1e9, 'GB')"

# Start training (multi-GPU)
accelerate launch --config_file accelerate_config.yaml src/finetune/train_qlora.py

# Merge LoRA adapter into base model (for full model serving)
python -c "
from peft import AutoPeftModelForCausalLM
import torch
model = AutoPeftModelForCausalLM.from_pretrained(
    'models/llama3-8b-finance-lora',
    torch_dtype=torch.bfloat16,
)
merged = model.merge_and_unload()  # Merge LoRA weights into base model
merged.save_pretrained('models/llama3-8b-finance-merged')
"

# Serve fine-tuned model with vLLM
vllm serve models/llama3-8b-finance-merged \
  --tensor-parallel-size 2 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.95

# Serve with LoRA adapter (no merge needed — faster iteration)
vllm serve meta-llama/Meta-Llama-3-8B-Instruct \
  --enable-lora \
  --lora-modules finance=models/llama3-8b-finance-lora \
  --max-lora-rank 16

# Run LM-Eval benchmarks
lm_eval --model vllm \
  --model_args pretrained=models/llama3-8b-finance-merged \
  --tasks hellaswag,mmlu \
  --num_fewshot 5 \
  --batch_size 16
```

## Common Patterns

### Pattern 1: Data Generation from a Larger Model

```python
# src/finetune/generate_dataset.py
# Use GPT-4 or Claude to generate training data for a smaller model
# ("self-instruct" / "alpaca" approach)
from anthropic import Anthropic
import json

client = Anthropic()

def generate_training_examples(
    domain: str,
    n_examples: int = 1000,
    model: str = "claude-haiku-4-5",   # Cheap model for bulk generation
) -> list[dict]:
    """Generate diverse instruction-response pairs for a domain."""
    examples = []

    for i in range(n_examples):
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{
                "role": "user",
                "content": f"""Generate 1 training example for an LLM fine-tuned on {domain}.
Return JSON with fields: instruction (user question), response (ideal answer).
Make the instruction diverse and realistic. Response should be thorough but concise.
Return ONLY valid JSON, no explanation."""
            }],
        )
        try:
            example = json.loads(response.content[0].text)
            examples.append(example)
        except json.JSONDecodeError:
            continue

        if i % 100 == 0:
            print(f"Generated {i}/{n_examples} examples")

    return examples
```

### Pattern 2: Evaluation and Regression Testing

```python
# src/finetune/evaluate.py
# Track metrics before and after fine-tuning to detect regressions
import json
from anthropic import Anthropic
from vllm import LLM, SamplingParams

def evaluate_model(
    model_path: str,
    test_cases: list[dict],   # [{"input": str, "expected_keywords": list[str]}]
) -> dict:
    """Run evaluation on fine-tuned model."""
    llm = LLM(model=model_path, gpu_memory_utilization=0.9)
    sampling_params = SamplingParams(temperature=0.0, max_tokens=512)

    prompts = [tc["input"] for tc in test_cases]
    outputs = llm.generate(prompts, sampling_params)

    keyword_hits = 0
    for output, test_case in zip(outputs, test_cases):
        generated = output.outputs[0].text.lower()
        if any(kw.lower() in generated for kw in test_case["expected_keywords"]):
            keyword_hits += 1

    return {
        "keyword_hit_rate": keyword_hits / len(test_cases),
        "n_evaluated": len(test_cases),
    }


def compare_models(
    baseline_path: str,
    finetuned_path: str,
    test_cases: list[dict],
) -> None:
    """Compare baseline vs fine-tuned model side-by-side."""
    baseline_results = evaluate_model(baseline_path, test_cases)
    finetuned_results = evaluate_model(finetuned_path, test_cases)

    delta = finetuned_results["keyword_hit_rate"] - baseline_results["keyword_hit_rate"]
    print(f"Baseline keyword hit rate: {baseline_results['keyword_hit_rate']:.3f}")
    print(f"Fine-tuned keyword hit rate: {finetuned_results['keyword_hit_rate']:.3f}")
    print(f"Delta: {delta:+.3f}")
    if delta < -0.05:
        print("WARNING: Fine-tuned model performs worse on evaluation set!")
```

### Pattern 3: LoRA Rank Selection and Hyperparameter Guidance

```python
# src/finetune/hyperparams.py
# Practical guidance for LoRA hyperparameter selection

LORA_RANK_GUIDE = {
    # Task → recommended LoRA rank
    "simple_format_change": 4,       # Low rank: output format, tone changes
    "instruction_following": 8,      # Medium: general instruction tuning
    "domain_adaptation": 16,         # Standard: domain knowledge injection
    "complex_reasoning": 32,         # High rank: reasoning-heavy tasks
    "full_capability": 64,           # Max: significant capability changes
}

LEARNING_RATE_GUIDE = {
    "sft_with_lora": 2e-4,          # Standard SFT with LoRA
    "sft_full_finetune": 2e-5,      # Full fine-tune (no LoRA, lower LR)
    "dpo_with_lora": 5e-7,          # DPO is very sensitive to LR
    "continued_pretraining": 1e-5,  # Domain-adaptive pretraining
}

BATCH_SIZE_GUIDE = """
Rule of thumb: gradient_accumulation_steps × per_device_batch_size = 16 to 32 total.
With QLoRA (4-bit), 8B model on 40GB A100:
  - per_device_batch_size = 4, gradient_accumulation_steps = 4
  - max_seq_length = 2048
  - gradient_checkpointing = True

Monitor GPU utilization: should be >90%. If lower, increase batch size.
Monitor loss curve: should decrease steadily. Spike = LR too high. Flat = LR too low.
"""

def estimate_vram_requirements(
    model_params_billions: float,
    lora_rank: int = 16,
    seq_length: int = 2048,
    batch_size: int = 4,
    quantization: str = "4bit",     # or "8bit" or "bf16"
) -> dict:
    bytes_per_param = {"4bit": 0.5, "8bit": 1, "bf16": 2}[quantization]
    model_gb = model_params_billions * 1e9 * bytes_per_param / 1e9

    # LoRA adapter (small fraction)
    lora_gb = model_params_billions * 0.01 * lora_rank / 16 * 2  # BF16

    # Activations (rough: seq_len * batch * model_dim * 2 bytes * n_layers)
    activation_gb = seq_length * batch_size * 4096 * 2 * 32 / 1e9  # 8B model approx

    total = model_gb + lora_gb + activation_gb
    return {
        "model_gb": round(model_gb, 1),
        "lora_adapter_gb": round(lora_gb, 2),
        "activation_gb": round(activation_gb, 1),
        "total_estimated_gb": round(total, 1),
    }
```

## Pitfalls to Avoid

1. **Training on unfiltered or low-quality data**: A 10,000-example dataset of high-quality instruction-response pairs outperforms 100,000 examples with 20% noise. Before training, filter aggressively: remove truncated responses, deduplicate with MinHash, check for formatting errors, and remove examples where the response contradicts the instruction. Use a "judge model" (another LLM) to score a sample of examples for quality before committing to training.

2. **Catastrophic forgetting of general capabilities**: Aggressive fine-tuning on a narrow domain reduces the model's general capabilities (math, reasoning, common knowledge). Mitigate by: mixing 10-20% general instruction data into your fine-tuning set, using LoRA instead of full fine-tuning (LoRA preserves base model weights), and running general benchmarks (MMLU, HellaSwag) before and after to detect regressions. If regression is severe, reduce training epochs or increase the fraction of general data.

3. **Using too-large LoRA rank without need**: Higher LoRA rank (`r=64`) uses more memory, trains slower, and overfits more easily on small datasets. Start with `r=16` for most tasks — it's sufficient for domain adaptation and instruction following. Only increase rank if eval loss plateaus early or you need the model to learn complex new reasoning patterns. More epochs with `r=16` usually outperforms fewer epochs with `r=64` on small datasets (<50k examples).

## Related Skills

- `peft-fine-tuning` — In-depth PEFT/LoRA parameter exploration and techniques
- `huggingface-llm-trainer` — Hugging Face Trainer configuration and callbacks
- `mlops-engineer` — Model versioning, deployment pipelines, and monitoring
- `data-versioning-dvc` — Versioning training datasets and model checkpoints
- `llm-evaluation` — Comprehensive LLM evaluation frameworks and benchmarks

## GitNexus Index

```json
{
  "skill": "llm-fine-tuning-pipeline",
  "category": "ml",
  "triggers": ["LLM fine-tuning", "LoRA training", "QLoRA", "PEFT fine-tuning", "SFT trainer", "DPO training", "instruction tuning", "Llama fine-tune", "HuggingFace TRL", "vLLM serving", "dataset preparation SFT", "preference optimization"],
  "outputs": ["BitsAndBytesConfig", "LoraConfig", "SFTTrainer", "SFTConfig", "DPOTrainer", "DPOConfig", "format_as_chatml()", "filter_dataset_quality()", "evaluate_model()", "estimate_vram_requirements()"],
  "complexity": "high",
  "tools": ["python", "pytorch", "huggingface", "trl", "peft", "bitsandbytes", "vllm", "accelerate", "lm-eval", "wandb"]
}
```
