# Net_Iosxe

Net_Iosxe provides capability roles for managing Cisco IOS and IOS-XE devices.

Net_Iosxe owns platform-specific automation logic. It reports results using the shared contract defined by `net_common`.

## VLAN Management

The `vlan` role manages VLAN existence and VLAN name on Cisco IOS-XE devices.

Currently implemented: `create`, `delete`, and `verify`, including access-port and trunk deletion-dependency safety.

Example:

```yaml
- hosts: cisco_ios_switches
  gather_facts: false

  roles:
    - routeswitchdev.net_iosxe.vlan
  vars:
    vlan_id: 100
    vlan_name: SALES
    vlan_action: create
```

### Inputs

| Key           | Required | Description                                                                              |
| ------------- | -------- | ---------------------------------------------------------------------------------------- |
| `vlan_id`     | Yes      | Integer VLAN ID to manage.                                                               |
| `vlan_name`   | No       | Desired VLAN name. Omit to leave the VLAN name unmanaged and preserve the existing name. |
| `vlan_action` | Yes      | Requested action: `create`, `delete`, or `verify`.                                       |

### Actions

| Action   | Behavior                                                                                                        |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| `create` | Ensures the VLAN exists. Manages the VLAN name only when `vlan_name` is provided.                               |
| `delete` | Ensures the VLAN is absent. Deletion is blocked when the VLAN has a configured access-port or trunk dependency. |
| `verify` | Validates, gathers, and evaluates the requested state without applying configuration changes.                   |

When `vlan_name` is omitted, the existing VLAN name is preserved and treated as unmanaged.

### VLAN ID Rules

* Must be an integer between `1` and `4094`.
* VLAN `0` and VLAN `4095` are reserved and not configurable.
* VLAN `1` is the protected default VLAN.
* VLANs `1002`-`1005` are Cisco-reserved legacy VLANs.

Reserved and protected IDs are rejected before any device is contacted.

### VLAN Name Rules

* Must be a string between 1 and 32 characters, when provided.
* Must match `^[A-Za-z0-9_-]+$`: letters, numbers, hyphens, and underscores only.
* Must not already be in use by a different `vlan_id` on the target device.

Cisco IOS requires VLAN names to be unique across the VLAN database. A conflicting name is rejected during evaluation before configuration is attempted.

Invalid or conflicting names are rejected before configuration changes are made.

## Lifecycle

The role follows the standard capability lifecycle:

| Stage        | Behavior                                                                                                                                                                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Validate** | Reject invalid, out-of-range, protected, reserved, or malformed input. No device is contacted.                                                                                                                                            |
| **Gather**   | Read the current VLAN table. For `delete`, when the VLAN exists, also gather access-port and trunk dependency state using `cisco.ios.ios_l2_interfaces`.                                                                                  |
| **Evaluate** | Compare current state with requested state and classify the result as `compliant`, `provisioning_required`, `remediation_required`, `removal_required`, or `blocked`. For `create`, reject a requested name already used by another VLAN. |
| **Apply**    | Apply required `create` or `delete` changes. Only VLAN attributes owned by the role are managed. No configuration is applied when `blocked`.                                                                                              |
| **Verify**   | Re-gather state after a real configuration attempt and confirm convergence. A mismatch fails the host. If state cannot be gathered after bounded retry, report `unverified`.                                                              |

### Lifecycle Exceptions

| Condition             | Behavior                                                                      |
| --------------------- | ----------------------------------------------------------------------------- |
| `verify` action       | Runs Validate, Gather, and Evaluate only. Never changes device configuration. |
| Noncompliant `verify` | Reported as a successful observation, not an execution failure.               |
| `blocked` deletion    | Never changes device configuration. Dependency evaluation is read-only.       |
| Check mode            | Predicts behavior without applying configuration changes.                     |

## Role Ownership

The role owns only:

* VLAN existence for the requested `vlan_id`.
* VLAN name when `vlan_name` is explicitly provided.

The role does not own VLAN administrative state, MTU, or other VLAN attributes.

`cisco.ios.ios_vlans` pinned at `3.3.2` does not emit a configuration command from `vlan_id` alone, so `state: active` is supplied as a compatibility mechanism when creating an unnamed VLAN.

This is an implementation detail for the pinned module version. It does not expand role ownership and does not apply to an already-existing VLAN.

## Result Contract

The role reports results using `capability_result` as defined by `net_common`.

Example for a successful creation:

```yaml
capability_result:
  host: iol-l2
  capability: vlan_management
  status: changed
  execution_mode: apply
  verification: passed
  timestamp: "2026-09-02T08:40:07Z"
  warnings: []
  errors: []
  requested_action: create
  outcome: provisioned
  previous_state: {}
  resulting_state:
    vlan_id: 101
    name: SALES
    mtu: 1500
    shutdown: disabled
    state: active
```

### Outcomes

| Outcome        | Meaning                                                                                                                                                  |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `compliant`    | Requested state already satisfied. No configuration change made.                                                                                         |
| `noncompliant` | `verify` found that observed state does not satisfy requested intent.                                                                                    |
| `provisioned`  | VLAN did not exist and was created.                                                                                                                      |
| `remediated`   | VLAN existed with a different managed name, which was corrected.                                                                                         |
| `removed`      | VLAN existed and was deleted.                                                                                                                            |
| `blocked`      | Deletion prevented by a confirmed access-port or trunk dependency. `verification` is `not_attempted`, and `warnings` identifies the blocking interfaces. |
| `unverified`   | A mutation was attempted, but post-change state could not be gathered after bounded retry. The resulting state is unknown.                               |

`resulting_state` is included only when a real post-change verification occurred or, for a confirmed deletion, to represent confirmed absence as `{}`.

It is omitted for:

* A pure `verify` action.
* An already-compliant `create`.
* A `blocked` deletion.
* An `unverified` result.

### Check Mode

No real device change occurs in check mode.

`status` reflects the predicted change, `verification` is `not_attempted`, and `outcome` is omitted because no configuration change or convergence actually occurred.

A `blocked` deletion reports the same result in check mode as outside check mode because dependency evaluation is read-only.

## Processing Order

The VLAN capability is processed in the following order:

1. The role constructs `capability_result`.
2. The calling playbook validates it against the `net_common` result contract.

Validating `capability_result` is orchestration, not a role-to-role dependency, so validation is not performed inside the VLAN role.

See `playbooks/vlan.yml` for the reference invocation.

## VLAN Testing

The VLAN role has an independent test suite covering provisioning, verification, removal safety, input validation, idempotency, check mode, and failure handling.

Tests use YAML `--extra-vars` fixtures against an IOS/IOS-XE lab or test device.

Some failure scenarios require controlled connectivity interruption or other lab conditions and remain deferred until a reliable integration-test mechanism is available.

See [`docs/testing/vlan.md`](../../../docs/testing/vlan.md) for test coverage, fixtures, execution instructions, expected results, known coverage gaps, and peer-review procedures.
