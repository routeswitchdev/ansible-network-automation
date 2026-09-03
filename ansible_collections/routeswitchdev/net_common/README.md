# Net_Common

Common provides minimal, stable functionality shared across network automation capabilities.

Common provides mechanisms and contracts, not network-domain policy.


## Result Contract

Capabilities report per-host results to Common using `capability_result`.

Example:

```yaml
capability_result:
  host: iol-l2
  capability: vlan_management
  status: changed
  execution_mode: apply
  verification: passed
  timestamp: "2026-09-01T01:30:00Z"
  warnings: []
  errors: []
```

### Required Keys

Every `capability_result` must contain:

| Key              | Description                                                                                                                           |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `host`           | Host the result represents.                                                                                                           |
| `capability`     | Capability that produced the result.                                                                                                  |
| `status`         | Common's normalized result for this host's capability execution. <br> Must be `ok`, `changed`, `failed`, `unreachable`, or `skipped`. |
| `execution_mode` | Whether execution was `apply` or `check`.                                                                                             |
| `verification`   | Verification result: `passed`, `failed`, or `not_attempted`.                                                                          |
| `timestamp`      | UTC ISO 8601 timestamp for the result.                                                                                                |
| `warnings`       | List of warning strings.                                                                                                              |
| `errors`         | List of error strings.                                                                                                                |


### Optional Fields

A `capability_result` may also contain:

| Key                | Description                                                                                                          |
|--------------------|----------------------------------------------------------------------------------------------------------------------|
| `requested_action` | Action requested by the capability consumer, such as `create`, `delete`, or `verify`.                                |
| `outcome`          | Capability-specific result, such as `compliant`, `provisioned`, `remediated`, `removed`, `blocked`, or `unverified`. |
| `previous_state`   | Relevant capability-managed state before execution.                                                                  |
| `resulting_state`  | Relevant capability-managed state after execution.                                                                   |

These fields are optional. When supplied, they must conform to the Common result contract.


## Contract Validation

Validation currently checks:

1. `capability_result` is **defined**.
2. `capability_result` is a mapping/**dict**.
3. All required keys are **present**.
4. No **unknown** keys are present.
5. `status` is one of the allowed values.
6. `execution_mode` is either `apply` or `check`.
7. `verification` is one of: `passed`, `failed`, or `not_attempted`.
8. `host` and `capability` are defined as non-empty strings.
9. `timestamp` is defined and matches the required UTC timestamp format.
10. `requested_action` and `outcome`, if provided, are non-empty strings.
11. `warnings` and `errors` are defined as lists.
12. Every item in `warnings` is a string.
13. Every item in `errors` is a string.
14. `previous_state` and `resulting_state`, if provided, are mappings/dicts.

Additional field validation will be added as the contract is implemented.



## Evidence Schema

The evidence artifact contract is versioned using:

```yaml
common_schema_version: "1.0"
```

The schema version applies to the complete evidence artifact, not individual per-host results.

Increment the version only when an incompatible structural or semantic change is made to the evidence contract.


## Processing Order

Common processes each `capability_result` in the following order:

1. Capability constructs `capability_result`.
2. Common validates the result contract.
3. Common sanitizes/redacts sensitive data.
4. Common records the sanitized result.
5. Common persists the result as evidence.

Only contract validation is currently implemented. Later processing stages should not be assumed to exist until implemented.


## Result Contract Testing

The Common result contract has an independent, 15-case test suite covering both valid and
invalid `capability_result` structures. It runs entirely on `localhost` - no network
inventory or device connectivity required - and currently passes in full.

See [`docs/testing.md`](../../../docs/testing.md) for the full test list, location, and
run instructions.
