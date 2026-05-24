---
name: ab-testing-statistics
description: Run statistically rigorous A/B tests — sample size calculation, z-tests and t-tests for conversion rates, Chi-squared tests, CUPED variance reduction, sequential testing with alpha spending, and interpreting p-values, confidence intervals, and practical significance.
version: 1.0.0
tags: [ab-testing, statistics, experimentation, hypothesis-testing, p-value, confidence-interval, cuped, sequential-testing, python, scipy]
---

# A/B Testing Statistics

## Overview

A/B testing (controlled experimentation) is the gold standard for measuring causal effects of product changes. The core challenge is that observed differences between control and treatment groups may be due to chance — statistical hypothesis testing quantifies this risk. Getting the math wrong leads to either shipping harmful changes (false positives) or abandoning good ones (false negatives). CUPED variance reduction can cut required sample sizes by 30-60% using pre-experiment covariates, and sequential testing lets you peek at results safely without inflating Type I error.

## When to Use

- Evaluating any product change that affects a measurable metric (conversion rate, revenue, engagement)
- Determining minimum sample size before starting an experiment to avoid under-powered tests
- Checking whether an observed difference is statistically significant after an experiment ends
- Reducing experiment runtime with CUPED when pre-experiment user data is available
- Running long experiments where you need to check results early without p-value inflation
- Diagnosing why an A/A test (both groups get control) is showing unexpected significant results

## Step-by-Step Workflow

### 1. Sample Size Calculation (Before Running the Test)

```python
# src/experiments/sample_size.py
import numpy as np
from scipy import stats
import math

def calculate_sample_size(
    baseline_rate: float,   # Current conversion rate (e.g., 0.05 = 5%)
    mde: float,             # Minimum detectable effect (relative, e.g., 0.10 = 10% lift)
    alpha: float = 0.05,    # Type I error rate (false positive rate)
    power: float = 0.80,    # 1 - beta (probability of detecting true effect)
) -> dict:
    """
    Calculate sample size per variant for a two-tailed proportions test.

    Example: baseline_rate=0.05, mde=0.10 → treatment_rate=0.055
    With alpha=0.05, power=0.80 → ~31,000 per variant
    """
    treatment_rate = baseline_rate * (1 + mde)

    # Z-scores for alpha/2 (two-tailed) and beta
    z_alpha = stats.norm.ppf(1 - alpha / 2)   # 1.96 for alpha=0.05
    z_beta = stats.norm.ppf(power)             # 0.84 for power=0.80

    # Pooled proportion
    p_bar = (baseline_rate + treatment_rate) / 2

    delta = abs(treatment_rate - baseline_rate)
    numerator = (
        z_alpha * math.sqrt(2 * p_bar * (1 - p_bar)) +
        z_beta * math.sqrt(baseline_rate * (1 - baseline_rate) +
                            treatment_rate * (1 - treatment_rate))
    ) ** 2
    n = math.ceil(numerator / delta ** 2)

    days_needed = n / (10_000 * 0.5)  # Assuming 10k daily users, 50% in experiment

    return {
        "n_per_variant": n,
        "total_n": n * 2,
        "baseline_rate": baseline_rate,
        "treatment_rate": round(treatment_rate, 4),
        "mde_absolute": round(delta, 4),
        "estimated_days": round(days_needed, 1),
    }


def calculate_sample_size_continuous(
    mean: float,
    std_dev: float,
    mde_absolute: float,    # Absolute change in mean (e.g., $0.50 more revenue)
    alpha: float = 0.05,
    power: float = 0.80,
) -> int:
    """Sample size for two-sample t-test on continuous metric."""
    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_beta = stats.norm.ppf(power)
    n = math.ceil(2 * ((z_alpha + z_beta) * std_dev / mde_absolute) ** 2)
    return n
```

### 2. Significance Testing After the Experiment

```python
# src/experiments/significance_test.py
from scipy import stats
import numpy as np
from dataclasses import dataclass

@dataclass
class ExperimentResult:
    metric: str
    control_n: int
    treatment_n: int
    control_mean: float
    treatment_mean: float
    p_value: float
    confidence_interval: tuple[float, float]
    relative_lift: float
    is_significant: bool
    practical_significance: bool

def test_proportions(
    control_conversions: int,
    control_n: int,
    treatment_conversions: int,
    treatment_n: int,
    alpha: float = 0.05,
    min_practical_lift: float = 0.02,
) -> ExperimentResult:
    """Two-proportion z-test for conversion rates."""
    p_c = control_conversions / control_n
    p_t = treatment_conversions / treatment_n

    # Pooled proportion under null hypothesis
    p_pool = (control_conversions + treatment_conversions) / (control_n + treatment_n)
    se = np.sqrt(p_pool * (1 - p_pool) * (1 / control_n + 1 / treatment_n))

    z_stat = (p_t - p_c) / se
    p_value = 2 * (1 - stats.norm.cdf(abs(z_stat)))  # Two-tailed

    # 95% CI for the difference
    se_diff = np.sqrt(p_c * (1 - p_c) / control_n + p_t * (1 - p_t) / treatment_n)
    margin = stats.norm.ppf(1 - alpha / 2) * se_diff
    ci = (p_t - p_c - margin, p_t - p_c + margin)

    return ExperimentResult(
        metric="conversion_rate",
        control_n=control_n,
        treatment_n=treatment_n,
        control_mean=round(p_c, 4),
        treatment_mean=round(p_t, 4),
        p_value=round(p_value, 4),
        confidence_interval=(round(ci[0], 4), round(ci[1], 4)),
        relative_lift=round((p_t - p_c) / p_c, 4),
        is_significant=p_value < alpha,
        practical_significance=abs(p_t - p_c) >= min_practical_lift,
    )


def test_means(
    control_values: list[float],
    treatment_values: list[float],
    alpha: float = 0.05,
) -> ExperimentResult:
    """Welch's t-test for continuous metrics (unequal variance)."""
    t_stat, p_value = stats.ttest_ind(
        control_values, treatment_values,
        equal_var=False,    # Welch's t-test — more robust than Student's
    )
    ctrl_mean = np.mean(control_values)
    treat_mean = np.mean(treatment_values)

    # Bootstrap 95% CI for the difference in means
    diffs = [
        np.mean(np.random.choice(treatment_values, len(treatment_values)))
        - np.mean(np.random.choice(control_values, len(control_values)))
        for _ in range(1000)
    ]
    ci = (np.percentile(diffs, 2.5), np.percentile(diffs, 97.5))

    return ExperimentResult(
        metric="mean",
        control_n=len(control_values),
        treatment_n=len(treatment_values),
        control_mean=round(ctrl_mean, 4),
        treatment_mean=round(treat_mean, 4),
        p_value=round(p_value, 4),
        confidence_interval=(round(ci[0], 4), round(ci[1], 4)),
        relative_lift=round((treat_mean - ctrl_mean) / ctrl_mean, 4),
        is_significant=p_value < alpha,
        practical_significance=abs(treat_mean - ctrl_mean) / ctrl_mean > 0.05,
    )
```

### 3. CUPED — Variance Reduction

```python
# src/experiments/cuped.py
# CUPED (Controlled-experiment Using Pre-Experiment Data)
# Reduces variance by removing variance explained by a pre-experiment covariate.
# Typical variance reduction: 30-60% for stable metrics (purchases, revenue)
import numpy as np
from scipy import stats

def apply_cuped(
    control_post: np.ndarray,
    treatment_post: np.ndarray,
    control_pre: np.ndarray,    # Same metric measured BEFORE experiment
    treatment_pre: np.ndarray,
) -> dict:
    """
    Formula: Y_cuped = Y - theta * (X - E[X])
    theta = Cov(Y, X) / Var(X)
    """
    all_post = np.concatenate([control_post, treatment_post])
    all_pre = np.concatenate([control_pre, treatment_pre])
    theta = np.cov(all_post, all_pre)[0, 1] / np.var(all_pre)

    grand_mean_pre = np.mean(all_pre)

    control_cuped = control_post - theta * (control_pre - grand_mean_pre)
    treatment_cuped = treatment_post - theta * (treatment_pre - grand_mean_pre)

    original_var = (np.var(control_post) + np.var(treatment_post)) / 2
    cuped_var = (np.var(control_cuped) + np.var(treatment_cuped)) / 2
    variance_reduction = 1 - cuped_var / original_var

    _, p_value = stats.ttest_ind(treatment_cuped, control_cuped, equal_var=False)

    return {
        "theta": round(theta, 4),
        "variance_reduction_pct": round(variance_reduction * 100, 1),
        "original_variance": round(original_var, 4),
        "cuped_variance": round(cuped_var, 4),
        "p_value_cuped": round(p_value, 4),
        # A 50% variance reduction is equivalent to doubling your sample size
        "effective_sample_size_multiplier": round(1 / (1 - variance_reduction), 2),
    }
```

## Key Commands Reference

```python
# scipy stats quick reference
from scipy import stats

# Two-proportion z-test
_, p_value = stats.proportions_ztest(
    [conversions_c, conversions_t],
    [n_c, n_t],
    alternative='two-sided',    # or 'larger' / 'smaller' for one-sided
)

# Welch's t-test (continuous metrics)
t_stat, p_value = stats.ttest_ind(control_arr, treatment_arr, equal_var=False)

# Chi-squared (multiple variants or categorical metrics)
contingency_table = [[conv_c, n_c - conv_c],
                     [conv_t, n_t - conv_t]]
chi2, p_value, dof, expected = stats.chi2_contingency(contingency_table)

# Mann-Whitney U (non-parametric, for skewed distributions like revenue)
u_stat, p_value = stats.mannwhitneyu(control_arr, treatment_arr, alternative='two-sided')

# Cohen's h effect size (for proportions)
def cohens_h(p1, p2):
    return 2 * (np.arcsin(np.sqrt(p1)) - np.arcsin(np.sqrt(p2)))

# Multiple testing correction (Benjamini-Hochberg FDR)
from statsmodels.stats.multitest import multipletests
rejected, p_corrected, _, _ = multipletests(p_values, method='benjamini-hochberg')

# Sample Ratio Mismatch check
chi2_srm, p_srm = stats.chisquare([actual_n_c, actual_n_t], f_exp=[expected_n_c, expected_n_t])
if p_srm < 0.001:
    print("WARNING: Sample Ratio Mismatch — assignment is biased, results invalid")
```

## Common Patterns

### Pattern 1: Sequential Testing (Safe Early Peeking)

```python
# O'Brien-Fleming alpha spending — look at results during the experiment
# without inflating Type I error beyond alpha
import numpy as np
from scipy import stats

def obrien_fleming_alpha(t: float, alpha: float = 0.05) -> float:
    """
    Alpha boundary at information fraction t (0 < t <= 1).
    t = current_n / planned_n
    Very conservative early; nearly full alpha at the end.
    """
    z_boundary = stats.norm.ppf(1 - alpha / 2) / np.sqrt(t)
    return 2 * (1 - stats.norm.cdf(z_boundary))

def check_sequential(
    current_conversions_c: int, current_n_c: int,
    current_conversions_t: int, current_n_t: int,
    planned_n: int,
    alpha: float = 0.05,
) -> dict:
    current_n = (current_n_c + current_n_t) / 2
    t = current_n / planned_n
    alpha_at_t = obrien_fleming_alpha(t, alpha)

    _, p_value = stats.proportions_ztest(
        [current_conversions_c, current_conversions_t],
        [current_n_c, current_n_t],
    )
    return {
        "information_fraction": round(t, 3),
        "alpha_threshold": round(alpha_at_t, 4),
        "p_value": round(p_value, 4),
        "stop_experiment": p_value < alpha_at_t,
        "recommendation": "STOP — significant" if p_value < alpha_at_t else "Continue",
    }
```

### Pattern 2: Sample Ratio Mismatch (SRM) Detection

```python
def check_srm(
    assigned_control: int,
    assigned_treatment: int,
    expected_split: float = 0.5,
) -> dict:
    """
    SRM occurs when actual group sizes differ from assigned ratio.
    Common causes: bot traffic, caching bugs, redirect issues.
    p < 0.001 = strong evidence of SRM — results are NOT valid.
    """
    total = assigned_control + assigned_treatment
    expected_c = total * expected_split
    expected_t = total * (1 - expected_split)

    chi2_stat, p_value = stats.chisquare(
        [assigned_control, assigned_treatment],
        f_exp=[expected_c, expected_t],
    )

    actual_split = assigned_control / total
    return {
        "actual_split": round(actual_split, 4),
        "expected_split": expected_split,
        "chi2": round(chi2_stat, 4),
        "p_value": round(p_value, 4),
        "has_srm": p_value < 0.001,
        "action": "STOP — debug assignment pipeline" if p_value < 0.001 else "OK to analyze",
    }
```

### Pattern 3: Full Experiment Report Generator

```python
def generate_experiment_report(
    experiment_name: str,
    control: dict,    # {"n": int, "conversions": int, "revenue": list[float]}
    treatment: dict,
) -> str:
    conv = test_proportions(control["conversions"], control["n"],
                            treatment["conversions"], treatment["n"])
    rev = test_means(control["revenue"], treatment["revenue"])

    srm = check_srm(control["n"], treatment["n"])
    srm_warning = "\nWARNING: Sample Ratio Mismatch detected!\n" if srm["has_srm"] else ""

    decision = "SHIP" if (conv.is_significant and conv.practical_significance
                          and not srm["has_srm"]) else "DO NOT SHIP"
    lines = [
        f"## {experiment_name}{srm_warning}",
        f"N: {control['n']:,} control | {treatment['n']:,} treatment",
        "",
        f"Conversion: {conv.control_mean:.2%} → {conv.treatment_mean:.2%} "
        f"({conv.relative_lift:+.1%} lift, p={conv.p_value}, sig={conv.is_significant})",
        f"95% CI: ({conv.confidence_interval[0]:+.4f}, {conv.confidence_interval[1]:+.4f})",
        "",
        f"Revenue/user: ${rev.control_mean:.2f} → ${rev.treatment_mean:.2f} "
        f"({rev.relative_lift:+.1%}, p={rev.p_value})",
        "",
        f"Decision: {decision}",
    ]
    return "\n".join(lines)
```

## Pitfalls to Avoid

1. **Peeking at results and stopping early without sequential testing**: Looking at p-values during an experiment and stopping when p < 0.05 inflates your Type I error rate dramatically. With 5 peeks at even intervals, your effective false positive rate is ~23% instead of 5%. Either commit to a fixed sample size and check only at the end, or use a sequential testing framework (O'Brien-Fleming, always-valid inference) that accounts for multiple looks with an alpha spending function.

2. **Ignoring practical significance in favor of statistical significance**: With large sample sizes (>100k users), you can detect a 0.001% conversion improvement as statistically significant (p < 0.001) — but it's meaningless in practice. Always compute the confidence interval and compare the effect size against a minimum detectable effect that would justify the engineering cost of shipping. Statistical significance confirms the effect is real; practical significance determines whether it matters.

3. **Not checking for Sample Ratio Mismatch before analyzing results**: If you intended a 50/50 split but the actual split is 48/52, your results are invalid — the imbalance indicates a systematic bias in user assignment (caching, bot filtering, redirect chains). Always run a Chi-squared test on group sizes before any metric analysis. An SRM p-value below 0.001 means stop and debug the assignment mechanism, not interpret metrics.

## Related Skills

- `statistical-analyst` — Broader statistical analysis and hypothesis testing
- `data-quality-validation` — Validating experiment data integrity and completeness
- `feature-flag-manager` — Feature flagging infrastructure for A/B test assignment
- `analytics-tracking` — Event tracking pipeline for experiment metrics
- `ab-test-setup` — Experiment setup, configuration, and randomization

## GitNexus Index

```json
{
  "skill": "ab-testing-statistics",
  "category": "data",
  "triggers": ["A/B test statistics", "sample size calculation", "hypothesis testing", "p-value interpretation", "CUPED variance reduction", "sequential testing", "alpha spending", "conversion rate test", "proportions z-test", "Welch t-test", "experiment significance", "sample ratio mismatch"],
  "outputs": ["calculate_sample_size()", "test_proportions()", "test_means()", "apply_cuped()", "obrien_fleming_alpha()", "check_sequential()", "check_srm()", "ExperimentResult", "generate_experiment_report()"],
  "complexity": "high",
  "tools": ["python", "scipy", "numpy", "statsmodels", "pandas"]
}
```
