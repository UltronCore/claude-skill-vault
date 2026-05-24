---
name: great-expectations
description: Validate data quality with Great Expectations — a Python library for defining, documenting, and testing data expectations across DataFrames, databases, and files. Use this skill whenever the user wants to add data quality checks, validate data pipelines, create data docs, or test that datasets meet expected properties. Trigger for "great expectations", "data quality tests", "data validation python", "gx expectations", or "validate dataframe".
---

# Great Expectations: Data Quality Testing

Great Expectations (GX) lets you define data quality rules as "expectations" — assertions about your data — then validate datasets against them automatically. It generates human-readable documentation from your expectations.

## Installation

```bash
pip install great_expectations

# With specific connectors
pip install 'great_expectations[sqlalchemy]'     # SQL databases
pip install 'great_expectations[spark]'          # Apache Spark
```

## GX Core (v1.x — Fluent API)

### Basic Validation with DataFrames

```python
import great_expectations as gx
import pandas as pd

# Create GX context
context = gx.get_context()

# Create a Data Source from a DataFrame
df = pd.read_csv("orders.csv")
data_source = context.data_sources.add_pandas("my_datasource")
data_asset = data_source.add_dataframe_asset("orders")
batch_def = data_asset.add_batch_definition_whole_dataframe("whole_df")

# Create or retrieve an Expectation Suite
suite = context.suites.add(
    gx.ExpectationSuite(name="orders_suite")
)

# Add expectations
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="customer_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_date")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="quantity",
        min_value=1,
        max_value=10000,
    )
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeInSet(
        column="status",
        value_set=["pending", "processing", "shipped", "delivered", "cancelled"],
    )
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToMatchRegex(
        column="email",
        regex=r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
        mostly=0.99,  # allow 1% exceptions
    )
)

# Create Validation Definition and run
validation_def = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="orders_validation",
        data=batch_def,
        suite=suite,
    )
)

result = validation_def.run(batch_parameters={"dataframe": df})
print(result)
```

### Common Expectations

```python
from great_expectations import expectations as ge

# Null checks
ge.ExpectColumnValuesToNotBeNull(column="id")
ge.ExpectColumnValuesToBeNull(column="deleted_at")  # should be null initially

# Type checks
ge.ExpectColumnValuesToBeOfType(column="age", type_="int64")
ge.ExpectColumnValuesToBeInTypeList(column="amount", type_list=["float64", "int64"])

# Value range
ge.ExpectColumnValuesToBeBetween(column="rating", min_value=1, max_value=5)
ge.ExpectColumnMinToBeBetween(column="price", min_value=0)
ge.ExpectColumnMaxToBeBetween(column="price", max_value=99999)

# Categorical checks
ge.ExpectColumnValuesToBeInSet(column="currency", value_set=["USD", "EUR", "GBP"])
ge.ExpectColumnValuesToNotBeInSet(column="status", value_set=["DELETED"])  # no deleted

# String patterns
ge.ExpectColumnValuesToMatchRegex(column="phone", regex=r"^\+?[1-9]\d{1,14}$")
ge.ExpectColumnValueLengthsToBeBetween(column="zip_code", min_value=5, max_value=10)

# Uniqueness
ge.ExpectColumnValuesToBeUnique(column="order_id")
ge.ExpectCompoundColumnsToBeUnique(column_list=["user_id", "product_id"])

# Row counts
ge.ExpectTableRowCountToBeBetween(min_value=100, max_value=1_000_000)
ge.ExpectTableRowCountToEqual(value=500)  # exact count

# Column existence
ge.ExpectTableColumnsToMatchOrderedList(
    column_list=["id", "name", "email", "created_at"]
)
ge.ExpectTableColumnCountToBeBetween(min_value=5, max_value=20)

# Statistical
ge.ExpectColumnMeanToBeBetween(column="order_value", min_value=20, max_value=500)
ge.ExpectColumnStdevToBeBetween(column="order_value", min_value=0, max_value=1000)
ge.ExpectColumnMedianToBeBetween(column="age", min_value=18, max_value=80)

# Referential integrity
ge.ExpectColumnPairValuesToBeEqual(column_A="updated_at", column_B="created_at")
```

### SQL Data Source

```python
import great_expectations as gx

context = gx.get_context()

# Connect to PostgreSQL
data_source = context.data_sources.add_postgres(
    name="postgres_ds",
    connection_string="postgresql://user:password@localhost:5432/mydb",
)

# Add a table asset
table_asset = data_source.add_table_asset("users_table", table_name="users")
batch_def = table_asset.add_batch_definition_whole_table("whole_table")

suite = context.suites.add(
    gx.ExpectationSuite(name="users_suite")
)

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="email")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeUnique(column="email")
)
suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(min_value=1)
)

validation_def = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="users_validation",
        data=batch_def,
        suite=suite,
    )
)

result = validation_def.run()
print(f"Success: {result.success}")
for exp_result in result.results:
    if not exp_result.success:
        print(f"FAILED: {exp_result.expectation_config.type}")
        print(f"  Details: {exp_result.result}")
```

### Checkpoints (CI/CD Integration)

```python
import great_expectations as gx

context = gx.get_context()

# Checkpoint runs validations and can trigger actions on failure
checkpoint = context.checkpoints.add(
    gx.Checkpoint(
        name="orders_checkpoint",
        validation_definitions=[
            context.validation_definitions.get("orders_validation"),
        ],
        actions=[
            gx.checkpoint.UpdateDataDocsAction(name="update_data_docs"),
            gx.checkpoint.SlackNotificationAction(
                name="slack_notify",
                slack_webhook="https://hooks.slack.com/...",
                notify_on="failure",
                show_failed_expectations=True,
            ),
        ],
        result_format={
            "result_format": "COMPLETE",
            "unexpected_index_column_names": ["id"],
        },
    )
)

result = checkpoint.run(batch_parameters={"dataframe": df})
if not result.success:
    raise ValueError("Data quality check failed!")
```

### Data Docs (Auto-Generated Reports)

```python
# Build HTML data documentation
context.build_data_docs()

# Open in browser
context.open_data_docs()
# Creates HTML at gx/uncommitted/data_docs/local_site/
```

### Profiling (Auto-Generate Expectations)

```python
import great_expectations as gx
from great_expectations.profile.basic_dataset_profiler import BasicDatasetProfiler
import pandas as pd

# Auto-profile a DataFrame to generate expectations
df = pd.read_csv("data.csv")
profiler = BasicDatasetProfiler()

# This generates an expectation suite based on the data's statistics
suite, validation_result = profiler.profile(df, suite_name="auto_profiled")
print(suite)
```

## Pipeline Integration

```python
# In your ETL pipeline
def validate_and_load(df: pd.DataFrame) -> None:
    context = gx.get_context()
    validation_def = context.validation_definitions.get("my_validation")
    
    result = validation_def.run(batch_parameters={"dataframe": df})
    
    if not result.success:
        failed = [r for r in result.results if not r.success]
        error_msg = f"{len(failed)} expectations failed:\n"
        for r in failed:
            error_msg += f"  - {r.expectation_config.type}: {r.result}\n"
        raise DataQualityError(error_msg)
    
    # Only load if all checks pass
    load_to_warehouse(df)
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/great-expectations/.gitnexus
Last indexed: 2026-05-24
