# Net_Iosxe

Net_Iosxe provides capability roles for managing Cisco IOS and IOS-XE devices.

Net_Iosxe owns platform-specific automation logic. It reports results using the shared contract defined by `net_common`.


## VLAN Management

The `vlan` role manages VLAN existence and VLAN name on Cisco IOS-XE devices.

Currently implemented: `create`, `delete`, and `verify`, including access-port and
trunk deletion-dependency safety.

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

| Key           | Description                                                                                                                           |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `vlan_id`     | Required. Integer VLAN ID to manage.                                                                                                    |
| `vlan_name`   | Optional. Desired VLAN name. Omit to leave the VLAN name unmanaged.                                                                     |
| `vlan_action` | Required. Must be `create`, `delete`, or `verify`.                                                                                      |

`create` means the desired VLAN state is present. `delete` means the desired VLAN state is absent, and is blocked when the requested VLAN has a configured access-port or trunk dependency. `verify` validates, gathers, and evaluates without applying configuration changes.

An omitted `vlan_name` is never treated as an empty value or a request to reset the name. An existing VLAN's name is preserved and treated as unmanaged.


### VLAN ID Rules

* Must be an integer between `1` and `4094`.
* VLAN `0` and VLAN `4095` are reserved and not configurable.
* VLAN `1` is the protected default VLAN.
* VLANs `1002`-`1005` are Cisco-reserved legacy VLANs.

Reserved and protected IDs are rejected before any device is contacted.


### VLAN Name Rules

* Must be a string between 1 and 32 characters, when provided.
* Must match `^[A-Za-z0-9_-]+$` - letters, numbers, hyphens, and underscores only.
* Must not already be in use by a different `vlan_id` on the target device. Cisco IOS requires VLAN names to be unique across the whole VLAN database; a conflicting name is rejected during evaluation, before any configuration is attempted.

Invalid or conflicting names are rejected before configuration changes are made.


### Lifecycle

The role follows the standard capability lifecycle:

1. **Validate** - Reject invalid, out-of-range, protected, reserved, or malformed input. No device is contacted.
2. **Gather** - Read the device's current VLAN table. For `delete`, when the VLAN exists, additionally gather access-port and trunk dependency state via `cisco.ios.ios_l2_interfaces`.
3. **Evaluate** - Compare current state against requested state and classify the result as `compliant`, `provisioning_required`, `remediation_required`, `removal_required`, or `blocked`. Reject a requested name already claimed by a different VLAN (`create` only).
4. **Apply** - For `create`/`delete`, when a change is required. Applies only the VLAN attributes the role owns; never applied when `blocked`.
5. **Verify** - Re-gather state independently and confirm convergence. Runs only after a real configuration attempt outside check mode; a mismatch here fails the host, unless the re-gather itself cannot be completed after bounded retry, in which case the result is reported `unverified` instead.

`verify` as a requested action performs steps 1-3 only and never mutates the device. A `verify` action that discovers noncompliance is a successful observation, not an execution failure. A `blocked` deletion likewise never mutates the device - dependency evaluation is read-only.


### Role Ownership

The role owns only:

* VLAN existence for the requested `vlan_id`.
* VLAN name, when `vlan_name` is explicitly provided.

It does not own VLAN administrative state, MTU, or any other attribute. `cisco.ios.ios_vlans` (pinned at `3.3.2`) does not emit a configuration command from `vlan_id` alone, so `state: active` is supplied as a compatibility mechanism when creating an unnamed VLAN. This is an implementation detail for the pinned module version, not an expansion of role ownership, and does not apply to an already-existing VLAN.


### Result Contract

The role builds `capability_result` using the `net_common` result contract but does not validate it against that contract itself - see `Processing Order` below.

Example, for a successful creation:

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

`outcome` values currently produced:

| Outcome        | Meaning                                                                 |
|----------------|--------------------------------------------------------------------------|
| `compliant`    | Requested state already satisfied. No configuration change made.        |
| `noncompliant` | `verify` found the observed state does not satisfy requested intent.    |
| `provisioned`  | VLAN did not exist and was created.                                     |
| `remediated`   | VLAN existed with a different managed name, which was corrected.        |
| `removed`      | VLAN existed and was deleted.                                           |
| `blocked`      | Deletion prevented by a confirmed access-port or trunk dependency. `verification` is `not_attempted`; `warnings` names the blocking interface(s). |
| `unverified`   | A mutation was attempted, but the post-change re-gather could not be completed even after bounded retry - the resulting state is genuinely unknown, not assumed successful or failed. |

`resulting_state` is included only when a real post-change verification occurred (or, for a confirmed deletion, to represent confirmed absence as `{}`). It is omitted for a pure `verify` action, an already-compliant `create`, a `blocked` deletion, and an `unverified` result.

**Check mode:** No real device change occurs. `status` reflects the predicted change, `verification` is `not_attempted`, and `outcome` is deliberately omitted - no existing outcome value fits a predicted-but-unapplied change without implying real convergence that did not happen (see `vlan.md`'s Check Mode section for the full reasoning). A `blocked` deletion reports the same in check mode as outside it, since dependency evaluation is read-only regardless of `ansible_check_mode`.


### Processing Order

1. The role constructs `capability_result`.
2. The calling playbook validates it against the `net_common` result contract.

Validating `capability_result` is orchestration, not a role-to-role dependency, so it is not performed inside this role. See `playbooks/vlan.yml` for the reference invocation.


## VLAN Test Coverage

35 fixtures cover Provisioning (5), Verify (4), Removal (4), Input Validation (11),
Idempotency (3), Check Mode (6), and Failure Handling (2 of 9). Each is a YAML
`--extra-vars` input run against a real or lab device.

Not yet covered: 2 Removal "state cannot be determined" scenarios and 7 Failure Handling
scenarios (authorization failure, connection loss, recovery/indeterminate timing) - these
need a controlled connectivity-interruption test mechanism or lab infrastructure that
doesn't exist yet, not just another fixture file.

See [`docs/testing.md`](../../../docs/testing.md) for the full fixture list, the detailed
reason for each uncovered scenario, and run instructions.
