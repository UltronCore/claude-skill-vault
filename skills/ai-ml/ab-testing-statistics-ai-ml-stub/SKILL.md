---
name: ab-testing-statistics-ai-ml-stub
description: Design and analyze A/B tests with statistical rigor: sample sizing, significance testing, CUPED variance reduction, multi-armed bandits, and experiment reporting.
tags: [statistics, experimentation, a-b-testing, data-science]
version: 1.0.0
---

## Overview

Run statistically valid experiments: from pre-experiment power analysis through post-experiment significance testing, variance reduction, and decision reporting. Covers both frequentist and Bayesian approaches.

## When to Use

- Designing a new A/B or multivariate experiment
- Calculating required sample size before launching
- Analyzing results for statistical significance
- Reducing variance to detect smaller effects faster
- Choosing between frequentist p-values and Bayesian posteriors
- Detecting sample ratio mismatch (SRM) or data quality issues

## Sample Size Calculation

Always calculate before launching. Use two-proportion z-test for binary metrics, t-test for continuous.

```python
from scipy import stats
import numpy as np

def sample_size_two_proportion(p_control, mde, alpha=0.05, power=0.80):
    """
    p_control: baseline conversion rate
    mde: minimum detectable effect (relative), e.g. 0.05 for 5%
    Returns: n per variant
    """
    p_treatment = p_control * (1 + mde)
    p_pooled = (p_control + p_treatment) / 2
    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_beta = stats.norm.ppf(power)
    n = (z_alpha + z_beta)**2 * (p_control*(1-p_control) + p_treatment*(1-p_treatment)) / (p_treatment - p_control)**2
    return int(np.ceil(n))

# Example: 5% baseline, detect 10% relative lift, α=0.05, 80% power
n = sample_size_two_proportion(p_control=0.05, mde=0.10)
# → ~3,744 per variant
```

## Significance Testing

**Binary metrics (conversion rate):**
```python
from statsmodels.stats.proportion import proportions_ztest

def test_proportions(conversions_c, n_c, conversions_t, n_t):
    counts = np.array([conversions_t, conversions_c])
    nobs = np.array([n_t, n_c])
    stat, p_value = proportions_ztest(counts, nobs)
    return stat, p_value
```

**Continuous metrics (revenue, time on page):**
```python
from scipy.stats import ttest_ind

def test_continuous(control_values, treatment_values):
    stat, p_value = ttest_ind(control_values, treatment_values, equal_var=False)  # Welch's
    effect_size = (np.mean(treatment_values) - np.mean(control_values)) / np.std(control_values)
    return stat, p_value, effect_size
```

## CUPED — Variance Reduction

CUPED (Controlled-experiment Using Pre-Experiment Data) reduces variance using pre-experiment covariates, enabling smaller sample sizes or faster detection.

```python
def cuped_adjustment(Y, X):
    """
    Y: outcome metric (post-experiment)
    X: pre-experiment covariate (same metric, pre-period)
    Returns: variance-reduced Y_cuped
    """
    theta = np.cov(Y, X)[0, 1] / np.var(X)
    Y_cuped = Y - theta * (X - np.mean(X))
    variance_reduction = 1 - np.var(Y_cuped) / np.var(Y)
    print(f"Variance reduced by {variance_reduction:.1%}")
    return Y_cuped

# Then run standard t-test on Y_cuped values per variant
```

Typical variance reduction: 20-50%. Requires: pre-experiment data for the same users, covariate correlated with outcome (r > 0.3 helps).

## Multi-Armed Bandits (Thompson Sampling)

Use when exploration-exploitation trade-off matters more than clean causal inference. Not appropriate when you need an unbiased p-value.

```python
import numpy as np

class ThompsonSamplingBeta:
    """For binary reward (click/no-click, convert/no-convert)."""
    def __init__(self, n_arms):
        self.alpha = np.ones(n_arms)  # successes + 1
        self.beta = np.ones(n_arms)   # failures + 1

    def select_arm(self):
        samples = np.random.beta(self.alpha, self.beta)
        return np.argmax(samples)

    def update(self, arm, reward):
        self.alpha[arm] += reward
        self.beta[arm] += (1 - reward)

    def winning_probability(self, n_samples=10000):
        """Monte Carlo estimate of P(arm_i is best)."""
        samples = np.random.beta(self.alpha[:, None], self.beta[:, None], (len(self.alpha), n_samples))
        wins = np.argmax(samples, axis=0)
        return np.bincount(wins, minlength=len(self.alpha)) / n_samples
```

## Sample Ratio Mismatch (SRM) Detection

SRM means traffic split is not what you configured — invalidates results. Always check before analyzing.

```python
def detect_srm(observed_counts, expected_ratios, alpha=0.01):
    """
    observed_counts: [n_control, n_treatment, ...]
    expected_ratios: [0.5, 0.5] for equal split
    """
    total = sum(observed_counts)
    expected_counts = [r * total for r in expected_ratios]
    stat, p_value = stats.chisquare(observed_counts, expected_counts)
    srm_detected = p_value < alpha
    if srm_detected:
        print(f"WARNING: SRM detected (p={p_value:.4f}). Do not ship results.")
    return srm_detected, p_value
```

Common SRM causes: bot traffic, caching bugs, logging loss, session vs. user randomization mismatch.

## Decision Framework

| Scenario | Approach | Ship threshold |
|----------|----------|----------------|
| Binary metric, clean data | Two-proportion z-test | p < 0.05, effect > MDE |
| Continuous metric | Welch's t-test + CUPED | p < 0.05 |
| Many variants (>5) | Bonferroni correction: α/k | Adjusted p-value |
| Continuous allocation OK | Thompson Sampling | P(best) > 0.95 |
| Short experiment window | Bayesian with informative prior | P(positive) > 0.90 |
| SRM detected | Stop, debug, rerun | Never ship |

## Common Pitfalls

- **Peeking problem**: Checking p-values repeatedly inflates Type I error. Use sequential testing (mSPRT) or pre-commit to a fixed sample size.
- **Multiple comparisons**: Testing 10 metrics at α=0.05 gives ~40% chance of at least one false positive. Use Bonferroni or Benjamini-Hochberg FDR correction.
- **Network effects / interference**: SUTVA violation when users interact. Use cluster randomization.
- **Novelty effect**: New UI often gets a short-term boost. Run for at least 2 full business cycles.
- **Survivorship bias**: Only analyzing users who completed a funnel step biases results upward.

## Related Skills

- `statistical-analyst` — general statistical methods beyond A/B testing
- `analytics-tracking` — event instrumentation for experiments
- `ab-test-setup` — experiment configuration and launch checklist
