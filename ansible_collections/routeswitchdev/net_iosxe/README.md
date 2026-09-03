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

The `vlan` role includes reusable test input files for every currently coverable scenario in `vlan.md`'s Minimum Test Coverage list.

Unlike Common's result-contract tests, these do not run on `localhost` and are not self-contained assertion playbooks. Each file is a YAML `--extra-vars` input, run against the VLAN management playbook targeting a real or lab device, with expected behavior documented in comments alongside the scenario. Connection/credential overrides (`ansible_password`, `ansible_host`) are ordinary Ansible variables, so the two Failure Handling fixtures below use the same `--extra-vars @file.yml` format as every other fixture, without needing dedicated inventory entries.

### Covered

**Provisioning** (5) - `create_no_name`, `create_with_name`, `create_already_exists`, `create_already_exists_matching_name`, `create_existing_different_name`

**Verify** (4) - `verify_vlan_present`, `verify_vlan_present_matching_name`, `verify_vlan_present_different_name`, `verify_vlan_absent`

**Removal** (4) - `delete_existing_unused`, `delete_already_absent`, `delete_blocked_by_access_port`, `delete_blocked_by_trunk`. The two blocked-deletion fixtures are lab-topology-specific (documented in-file) since the role never creates or modifies interface configuration itself - the dependency has to already exist on the device.

**Input Validation** (11) - `missing_vlan_id`, `non_integer_vlan_id`, `vlan_id_below_range`, `vlan_id_above_range`, `vlan_id_reserved_0`, `vlan_id_protected_1`, `vlan_id_reserved_1002_1005`, `vlan_id_reserved_4095`, `invalid_vlan_action`, `invalid_vlan_name_characters`, `vlan_name_exceeds_length`

**Idempotency** (3) - `idempotent_create_no_name`, `idempotent_create_named`, `idempotent_delete`. Each is a two-run test: the first run converges the device, the second run - the actual test point - must report `changed = false`.

**Check Mode** (6) - `check_mode_change_required`, `check_mode_no_change_required`, `check_mode_delete_required`, `check_mode_delete_no_change_required`, `check_mode_delete_blocked_by_access_port`, `check_mode_delete_blocked_by_trunk`. The two blocked-in-check-mode fixtures confirm `blocked` reporting is identical whether or not `ansible_check_mode` is set, since dependency evaluation is read-only either way.

**Failure Handling** (2 of 9 - see Not Covered) - `authentication_failure`, `unreachable_device`. Both live-verified: the role fails safely with the genuine underlying error preserved, no configuration change, and no `capability_result` constructed (the role never gets past the initial gather).

35 fixtures total.

### Not Covered, and Why

**Removal - 2 of 6 scenarios:** "access-interface state cannot be determined" and "trunk state cannot be determined." These collapse into a single testable case in this implementation - `gather_dependencies.yml` reads both through one `cisco.ios.ios_l2_interfaces` call, so there's no way to fail only the access half or only the trunk half of that read. More fundamentally, neither is expressible as a plain `--extra-vars` input file: both require making a live device read fail on demand, which needs the same controlled-interruption mechanism described below.

**Failure Handling - 7 of 9 scenarios**, per `vlan.md`'s own test-scenario guidance ("failure or transport scenarios that cannot be represented as input files require an appropriate simulated or integration test instead"):

* **Authorization failure** - needs a distinct low-privilege lab account (valid login, insufficient enable/privilege). A CML lab configuration change, not a code or fixture change.
* **Connection loss before configuration**, **Required gathered state unavailable** - need a way to interrupt connectivity to the device at a controlled point *during* a running playbook - not just point at a wrong host or credential (that's what `unreachable_device`/`authentication_failure` already cover). No such mechanism exists yet in this repository or lab tooling.
* **Connection loss after configuration attempt**, **Recovery succeeds after a post-mutation connection failure**, **State remains indeterminate after bounded recovery attempts** - the hardest tier: needs the same controlled interruption, timed to land after the apply task specifically, and for two of the three, timed to either recover within the bounded retry window (proving the retry succeeds) or persist past it (proving the `unverified` outcome fires). Real timing-sensitive integration-test engineering, not a fixture file.
* **Verification failure** - was reproducible earlier by deliberately requesting a `vlan_name` already claimed by another VLAN (the device would silently reject the rename, and post-change verification would correctly catch the mismatch). That path is now closed: the duplicate-name pre-flight check added to `evaluate.yml` catches the conflict *before* apply, so it can no longer reach `verify.yml`. No other known deterministic way to cause a genuine post-apply mismatch has been found without either a real, currently-unidentified device quirk, or deliberately injecting configuration drift via a raw command mid-test (a real integration-test technique, not a simple fixture).

**Two related implementation findings, documented in `vlan.md`'s Connection Failures section rather than tested directly:** connection failures currently surface as Ansible's ordinary `failed` status rather than the dedicated `unreachable` status (traced to the pinned `ansible.netcommon` collection's "dexec" execution path, which collapses every exception type into plain result text before Ansible's executor can classify it) - and the bounded retry (`until`/`retries`/`delay`) applies uniformly regardless of whether a failure is transient or deterministic, since no structured error type survives dexec to distinguish them. Both were deliberately left as-is rather than worked around, since the only lever for either would be pattern-matching volatile error-message text - judged not worth the fragility for a bounded, safety-neutral cost.

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
