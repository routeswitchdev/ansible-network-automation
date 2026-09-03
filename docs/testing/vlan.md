# VLAN Testing

VLAN tests use YAML `--extra-vars` fixtures against an IOS/IOS-XE lab or test device.

Each table below includes an **Ansible Result** column - the host status as it appears in
Ansible's own `PLAY RECAP` (`changed`, `ok`, or `failed`), verified against this repository's
CML lab. This is deliberately a different axis than the domain-level **Expected Result**
column: a `blocked` deletion or a `noncompliant` verify are still `ok` at the Ansible level -
the role reporting a safety block or a discovered mismatch is a successful run, not a host
failure. Only genuine execution problems (input rejected, connection/auth failure) produce
`failed`.

## Test Coverage

### Provisioning

|  # | Scenario                                 | Fixture                               | Ansible Result | Expected Result                  |
| -: | ----------------------------------------- | -------------------------------------- | :-------------: | -------------------------------- |
|  1 | Create VLAN without a name               | `create_no_name`                      | `changed`       | VLAN created                     |
|  2 | Create VLAN with a name                  | `create_with_name`                    | `changed`       | VLAN created with requested name |
|  3 | VLAN already exists                      | `create_already_exists`               | `ok`            | No unnecessary change            |
|  4 | Existing VLAN already has requested name | `create_already_exists_matching_name` | `ok`            | No change                        |
|  5 | Existing VLAN has a different name       | `create_existing_different_name`      | `changed`       | VLAN renamed                     |

### Verification

|  # | Scenario                        | Fixture                              | Ansible Result | Expected Result        |
| -: | -------------------------------- | ------------------------------------- | :-------------: | ---------------------- |
|  1 | Verify VLAN exists              | `verify_vlan_present`                | `ok`            | VLAN reported present  |
|  2 | Verify VLAN and name match      | `verify_vlan_present_matching_name`  | `ok`            | Verification succeeds  |
|  3 | Verify VLAN with different name | `verify_vlan_present_different_name` | `ok`            | Name mismatch reported |
|  4 | Verify VLAN is absent           | `verify_vlan_absent`                 | `ok`            | VLAN reported absent   |

Rows 3-4 are the deliberate nuance called out above: `verify` finding drift or absence is a
successful observation, so the host reports `ok` even though the capability-level
`verification` field is `failed`.

### Removal

|  # | Scenario                           | Fixture                         | Ansible Result | Expected Result  |
| -: | ------------------------------------ | -------------------------------- | :-------------: | ----------------- |
|  1 | Delete unused VLAN                 | `delete_existing_unused`        | `changed`       | VLAN removed     |
|  2 | Delete VLAN that is already absent | `delete_already_absent`         | `ok`            | No change        |
|  3 | Delete VLAN used by an access port | `delete_blocked_by_access_port` | `ok`            | Deletion blocked |
|  4 | Delete VLAN allowed on a trunk     | `delete_blocked_by_trunk`       | `ok`            | Deletion blocked |

The blocked-deletion scenarios require the dependency to already exist on the test device.
A `blocked` deletion is `ok`, not `failed` - the request was valid and safely evaluated, it
just couldn't proceed.

### Input Validation

|  # | Scenario                               | Fixture                        | Ansible Result | Expected Result |
| -: | ----------------------------------------- | -------------------------------- | :-------------: | --------------- |
|  1 | VLAN ID missing                        | `missing_vlan_id`              | `failed`        | Rejected        |
|  2 | VLAN ID is not an integer              | `non_integer_vlan_id`          | `failed`        | Rejected        |
|  3 | VLAN ID below valid range              | `vlan_id_below_range`          | `failed`        | Rejected        |
|  4 | VLAN ID above valid range              | `vlan_id_above_range`          | `failed`        | Rejected        |
|  5 | VLAN ID is 0                           | `vlan_id_reserved_0`           | `failed`        | Rejected        |
|  6 | VLAN ID is 1                           | `vlan_id_protected_1`          | `failed`        | Rejected        |
|  7 | VLAN ID is in reserved range 1002-1005 | `vlan_id_reserved_1002_1005`   | `failed`        | Rejected        |
|  8 | VLAN ID is 4095                        | `vlan_id_reserved_4095`        | `failed`        | Rejected        |
|  9 | VLAN action is invalid                 | `invalid_vlan_action`          | `failed`        | Rejected        |
| 10 | VLAN name contains invalid characters  | `invalid_vlan_name_characters` | `failed`        | Rejected        |
| 11 | VLAN name exceeds allowed length       | `vlan_name_exceeds_length`     | `failed`        | Rejected        |

Every row here is a genuine `failed` - input rejection is either an `argument_specs.yml`
validation failure or an explicit `ansible.builtin.fail` in `validate.yml`, both before any
device is contacted.

### Idempotency

Each idempotency scenario is run twice. The second run is the test point.

|  # | Scenario                  | Fixture                     | Ansible Result (run 1 → run 2) | Expected Result               |
| -: | --------------------------- | ----------------------------- | :------------------------------: | ----------------------------- |
|  1 | Create unnamed VLAN twice | `idempotent_create_no_name` | `changed` → `ok`                | Second run: `changed = false` |
|  2 | Create named VLAN twice   | `idempotent_create_named`   | `changed` → `ok`                | Second run: `changed = false` |
|  3 | Delete VLAN twice         | `idempotent_delete`         | `changed` → `ok`                | Second run: `changed = false` |

### Check Mode

Every fixture in this section must be run with `--check` (see Run, below).

|  # | Scenario                      | Fixture                                    | Ansible Result | Expected Result                      |
| -: | -------------------------------- | --------------------------------------------- | :-------------: | ------------------------------------- |
|  1 | Create requires a change      | `check_mode_change_required`               | `changed`       | Change predicted, device unchanged   |
|  2 | Create requires no change     | `check_mode_no_change_required`            | `ok`            | No change predicted                  |
|  3 | Delete requires a change      | `check_mode_delete_required`               | `changed`       | Deletion predicted, device unchanged |
|  4 | VLAN is already absent        | `check_mode_delete_no_change_required`     | `ok`            | No change predicted                  |
|  5 | Delete blocked by access port | `check_mode_delete_blocked_by_access_port` | `ok`            | Deletion blocked                     |
|  6 | Delete blocked by trunk       | `check_mode_delete_blocked_by_trunk`       | `ok`            | Deletion blocked                     |

`changed` here is a *predicted* change - check mode never actually modifies the device.
Dependency evaluation is read-only, so blocked behavior (rows 5-6) is identical in normal
and check mode.

### Failure Handling

#### Covered

|  # | Scenario              | Fixture                  | Ansible Result | Expected Result                       |
| -: | ------------------------ | --------------------------- | :-------------: | -------------------------------------- |
|  1 | Authentication fails  | `authentication_failure` | `failed`        | Fails safely; no configuration change |
|  2 | Device is unreachable | `unreachable_device`     | `failed`        | Fails safely; no configuration change |

Row 2 is not a typo: despite the scenario name, the observed Ansible-level result is
`failed`, not the dedicated `unreachable` status - see "Connection Failure Limitation"
below for why.

#### Deferred

These scenarios require controlled lab conditions or failure injection that cannot be represented by a normal `--extra-vars` fixture.

|  # | Scenario                                    | Reason                                                |
| -: | ------------------------------------------- | ----------------------------------------------------- |
|  1 | Access-interface state cannot be determined | Requires controlled dependency-gather failure         |
|  2 | Trunk state cannot be determined            | Requires controlled dependency-gather failure         |
|  3 | Authorization failure                       | Requires a valid low-privilege lab account            |
|  4 | Connection loss before configuration        | Requires timed connectivity interruption              |
|  5 | Required gathered state unavailable         | Requires controlled gather failure                    |
|  6 | Connection loss after configuration attempt | Requires interruption after apply                     |
|  7 | Recovery succeeds after post-change failure | Requires failure and recovery within the retry window |
|  8 | State remains indeterminate after recovery  | Requires failure beyond the retry window              |
|  9 | Verification failure                        | No deterministic post-apply mismatch is available     |

These scenarios remain documented until a reliable integration-test mechanism is available.

### Connection Failure Limitation

Connection failures currently surface as Ansible `failed` rather than `unreachable`.

The pinned `ansible.netcommon` execution path does not preserve the structured exception Ansible requires to classify the host as unreachable. Retry behavior also cannot reliably distinguish transient from deterministic failures.

No error-message parsing workaround is used because it would depend on unstable error text.

## Running Tests

### Requirements

* Reachable IOS/IOS-XE test device
* Valid inventory entry
* Valid credentials
* Required starting device state for the selected scenario

### Test Location

```text
ansible_collections/routeswitchdev/net_iosxe/tests/vlan/
```

### Run

From the repository root:

```bash
ansible-playbook playbooks/vlan.yml -l iol-l2 --extra-vars @ansible_collections/routeswitchdev/net_iosxe/tests/vlan/create_no_name.yml
```

Replace `create_no_name.yml` with the fixture listed for the scenario being tested.

For check-mode scenarios, add:

```text
--check
```

### Expected Result

Compare both the **Ansible Result** (the `PLAY RECAP` host status) and the domain-level
**Expected Result** column for the selected scenario - the fixture's own comments carry the
same information, plus any precondition.

Negative tests pass only when the role rejects the invalid condition as expected.

## Peer-Review Procedure

For each test:

1. Find the scenario you want to test.
2. Prepare the required starting device state.
3. Use the fixture listed for that scenario.
4. Run the test.
5. Compare the result with the documented Ansible Result and Expected Result.
6. Verify the resulting device state where applicable.
7. Record the test as pass or fail.

A reviewer should be able to reproduce each covered test without assistance from the original developer.
