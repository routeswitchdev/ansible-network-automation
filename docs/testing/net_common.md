# `net_common` Result Contract Testing

The result contract tests validate the standard `capability_result` structure.

These tests run on `localhost` and do not require a network device.

## Test Coverage

### Valid Results

|  # | Scenario                                  | Expected Result |
| -: | ----------------------------------------- | --------------- |
|  1 | Minimal valid `capability_result`         | Accepted        |
|  2 | Fully populated valid `capability_result` | Accepted        |

### Structure Validation

|  # | Scenario                      | Expected Result |
| -: | ----------------------------- | --------------- |
|  1 | Undefined `capability_result` | Rejected        |
|  2 | Result is not a mapping       | Rejected        |
|  3 | Required keys are missing     | Rejected        |
|  4 | Unknown keys are present      | Rejected        |

### Value Validation

|  # | Scenario                                | Expected Result |
| -: | --------------------------------------- | --------------- |
|  1 | Invalid `status`                        | Rejected        |
|  2 | Invalid `execution_mode`                | Rejected        |
|  3 | Invalid `verification`                  | Rejected        |
|  4 | Invalid `host` or `capability`          | Rejected        |
|  5 | Malformed timestamp                     | Rejected        |
|  6 | Invalid `requested_action` or `outcome` | Rejected        |

### Collection Validation

|  # | Scenario                                               | Expected Result |
| -: | ------------------------------------------------------ | --------------- |
|  1 | `warnings` or `errors` is not a list                   | Rejected        |
|  2 | Non-string item in `warnings` or `errors`              | Rejected        |
|  3 | `previous_state` or `resulting_state` is not a mapping | Rejected        |

## Test Location

```text
ansible_collections/routeswitchdev/net_common/tests/result_contract/test_validate_result_contract.yml
```

## Run

From the repository root:

```bash
ansible-playbook ansible_collections/routeswitchdev/net_common/tests/result_contract/test_validate_result_contract.yml
```

## Expected Result

* Valid results are accepted.
* Invalid results are rejected.
* The test playbook fails if invalid data is unexpectedly accepted.
* No inventory or network device is required.

## Peer-Review Procedure

1. Run the result contract test playbook.
2. Confirm all valid results are accepted.
3. Confirm all invalid results are rejected.
4. Confirm the playbook completes successfully.

A reviewer should be able to reproduce the tests without assistance from the original developer.
