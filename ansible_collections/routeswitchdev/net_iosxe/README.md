# Net_Iosxe

Net_Iosxe provides capability roles for managing Cisco IOS and IOS-XE devices.

Net_Iosxe owns platform-specific automation logic. It reports results using the shared contract defined by `net_common`.


## VLAN Management

The `vlan` role manages VLAN existence and VLAN name on Cisco IOS-XE devices.

Currently implemented: `create` and `verify`.

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

`create` means the desired VLAN state is present. `verify` validates, gathers, and evaluates without applying configuration changes. `delete` is a recognized value - preserving the role's public interface - but is rejected during validation until deletion is implemented.

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
2. **Gather** - Read the device's current VLAN table.
3. **Evaluate** - Compare current state against requested state and classify the result as `compliant`, `provisioning_required`, or `remediation_required`. Reject a requested name already claimed by a different VLAN.
4. **Apply** - For `create` only, when a change is required. Applies only the VLAN attributes the role owns.
5. **Verify** - Re-gather state independently and confirm convergence. Runs only after a real configuration attempt outside check mode; a mismatch here fails the host.

`verify` as a requested action performs steps 1-3 only and never mutates the device. A `verify` action that discovers noncompliance is a successful observation, not an execution failure.


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

`resulting_state` is included only when a real post-change verification occurred. It is omitted for a pure `verify` action and for an already-compliant `create`.

**Check mode:** No real device change occurs. `status` reflects the predicted change, `verification` is `not_attempted`, and `outcome` is intentionally omitted - the correct outcome value for a predicted, unconfirmed change is not yet defined.


### Processing Order

1. The role constructs `capability_result`.
2. The calling playbook validates it against the `net_common` result contract.

Validating `capability_result` is orchestration, not a role-to-role dependency, so it is not performed inside this role. See `playbooks/vlan.yml` for the reference invocation.


## VLAN Test Coverage

The `vlan` role includes reusable test input files for every currently supported scenario.

Unlike Common's result-contract tests, these do not run on `localhost` and are not self-contained assertion playbooks. Each file is a YAML `--extra-vars` input, run against the VLAN management playbook targeting a real or lab device, with expected behavior documented in comments alongside the scenario.

### Test Coverage

The test suite covers:

**Provisioning** (5)

1. Create VLAN without a name.
2. Create VLAN with a name.
3. VLAN already exists, name unmanaged.
4. VLAN already exists with matching managed name.
5. VLAN exists with a different managed name (remediation).

**Verify** (4)

6. Verify existing VLAN, name unmanaged.
7. Verify existing VLAN, matching managed name.
8. Verify existing VLAN, different managed name.
9. Verify absent VLAN.

**Input Validation** (12)

10. Missing `vlan_id`.
11. Non-integer `vlan_id`.
12. `vlan_id` below supported range.
13. `vlan_id` above supported range.
14. VLAN `0`.
15. VLAN `1`.
16. VLANs `1002`-`1005`.
17. VLAN `4095`.
18. Invalid `vlan_action`.
19. Invalid VLAN name characters.
20. VLAN name exceeding supported length.
21. `delete` requested (rejected as not yet implemented).

**Idempotency** (2)

22. Run identical unnamed create intent twice.
23. Run identical named create intent twice.

Each idempotency fixture is a two-run test: the first run converges the device, the second run - the actual test point - must report `changed = false`.

**Check Mode** (2)

24. Change would be required.
25. No change would be required.

Not yet covered: deletion, dependency discovery, VTP safety, and conflicting-intent scenarios - these are future scope, not yet implemented by the role.

### Test Location

```text
ansible_collections/routeswitchdev/net_iosxe/tests/vlan/
```

### Run the Tests

From the repository root, against a specific host:

```bash
uv run ansible-playbook playbooks/vlan.yml \
  -l iol-l2 \
  --extra-vars @ansible_collections/routeswitchdev/net_iosxe/tests/vlan/create_no_name.yml
```

Add `--check` for the check-mode fixtures. A negative test only passes when the role actually rejects the invalid input; unexpected acceptance is a failure.

A reachable device and valid inventory credentials are required - these tests are not self-contained and do not run against `localhost`.
