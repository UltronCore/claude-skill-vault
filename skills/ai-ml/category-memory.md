# AI/ML Category Memory

**Category:** ai-ml
**Created:** 2026-05-08
**Last updated:** 2026-05-08

## Overview
This category covers AI/ML development tools, frameworks, and workflows — from model fine-tuning and RAG pipelines to agent orchestration and evaluation.

## Sub-Categories

### HuggingFace Ecosystem (7 skills)
Core HuggingFace tooling: model training, datasets, local inference, CLI, Gradio UIs, JavaScript transformers, and sentence embedding fine-tuning.

### Fine-Tuning (2 skills)
Efficient fine-tuning techniques: Unsloth for 2-5x speedup, PEFT for LoRA/QLoRA parameter-efficient training.

### Agents & Orchestration (3 skills)
LangChain for LLM app building, LangGraph for stateful multi-actor workflows, CrewAI for multi-agent task orchestration.

### Prompt Engineering (4 skills)
DSPy for declarative/auto-optimized prompting, Instructor for structured LLM output, plus prompt optimization and evaluation tooling.

### Vector Databases & RAG (4 skills)
Chroma (open-source), Qdrant (high-performance), Pinecone (managed), FAISS (Facebook, large-scale) — all for embedding storage and retrieval-augmented generation.

## Import Notes
- Skills 1-7 (HuggingFace): downloaded from github.com/huggingface/skills
- Skills 8-18 (Orchestra-Research): downloaded from github.com/Orchestra-Research/AI-Research-SKILLs
  - langgraph (skill 11): 404 on source repo, created from scratch
- Skills 19-20 (sickn33): downloaded from github.com/sickn33/antigravity-awesome-skills

## Usage
Load a specific skill when working on tasks in that domain. For RAG pipelines, consider chroma + langchain together. For fine-tuning, unsloth + peft-fine-tuning complement each other.
