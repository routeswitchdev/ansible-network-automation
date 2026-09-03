# Testing

Detailed test procedures, peer-review instructions, and scenario commands for this
repository's collections. For a high-level summary of what's tested, see the relevant
role or collection `README.md` instead - this file holds the detail those summaries link to.

## net_common: Result Contract

The Common result contract includes an independent test suite for
`tasks/validate_result_contract.yml`.

The tests run entirely on `localhost` and do not connect to any network device. They verify
both valid and invalid `capability_result` structures.

### Test Coverage

The test suite verifies:

1. A minimal valid `capability_result` is accepted.
2. A fully populated valid `capability_result` is accepted.
3. An undefined `capability_result` is rejected.
4. A non-mapping `capability_result` is rejected.
5. Missing required keys are rejected.
6. Unknown keys are rejected.
7. Invalid `status` values are rejected.
8. Invalid `execution_mode` values are rejected.
9. Invalid `verification` values are rejected.
10. Invalid `host` and `capability` values are rejected.
11. Malformed timestamps are rejected.
12. Invalid `requested_action` and `outcome` values are rejected.
13. `warnings` and `errors` must be lists.
14. Every item in `warnings` and `errors` must be a string.
15. `previous_state` and `resulting_state`, when provided, must be mappings/dicts.

### Test Location

```text
ansible_collections/routeswitchdev/net_common/tests/result_contract/test_validate_result_contract.yml
```

### Run the Tests

From the collection root - no inventory required for this test:

```bash
uv run ansible-playbook tests/result_contract/test_validate_result_contract.yml
```

The test suite uses explicit assertions to verify expected behavior. A negative test only
passes when the validator actually rejects the invalid input; unexpected acceptance causes
the test playbook to fail. No network inventory or device connectivity is required.

---

## net_iosxe: VLAN Role

The `vlan` role includes reusable test input files for every currently coverable scenario
in `vlan.md`'s Minimum Test Coverage list.

Unlike Common's result-contract tests, these do not run on `localhost` and are not
self-contained assertion playbooks. Each file is a YAML `--extra-vars` input, run against
the VLAN management playbook targeting a real or lab device, with expected behavior
documented in comments alongside the scenario. Connection/credential overrides
(`ansible_password`, `ansible_host`) are ordinary Ansible variables, so the two Failure
Handling fixtures below use the same `--extra-vars @file.yml` format as every other
fixture, without needing dedicated inventory entries.

### Covered

**Provisioning** (5) - `create_no_name`, `create_with_name`, `create_already_exists`,
`create_already_exists_matching_name`, `create_existing_different_name`

**Verify** (4) - `verify_vlan_present`, `verify_vlan_present_matching_name`,
`verify_vlan_present_different_name`, `verify_vlan_absent`

**Removal** (4) - `delete_existing_unused`, `delete_already_absent`,
`delete_blocked_by_access_port`, `delete_blocked_by_trunk`. The two blocked-deletion
fixtures are lab-topology-specific (documented in-file) since the role never creates or
modifies interface configuration itself - the dependency has to already exist on the
device.

**Input Validation** (11) - `missing_vlan_id`, `non_integer_vlan_id`,
`vlan_id_below_range`, `vlan_id_above_range`, `vlan_id_reserved_0`, `vlan_id_protected_1`,
`vlan_id_reserved_1002_1005`, `vlan_id_reserved_4095`, `invalid_vlan_action`,
`invalid_vlan_name_characters`, `vlan_name_exceeds_length`

**Idempotency** (3) - `idempotent_create_no_name`, `idempotent_create_named`,
`idempotent_delete`. Each is a two-run test: the first run converges the device, the
second run - the actual test point - must report `changed = false`.

**Check Mode** (6) - `check_mode_change_required`, `check_mode_no_change_required`,
`check_mode_delete_required`, `check_mode_delete_no_change_required`,
`check_mode_delete_blocked_by_access_port`, `check_mode_delete_blocked_by_trunk`. The two
blocked-in-check-mode fixtures confirm `blocked` reporting is identical whether or not
`ansible_check_mode` is set, since dependency evaluation is read-only either way.

**Failure Handling** (2 of 9 - see Not Covered) - `authentication_failure`,
`unreachable_device`. Both live-verified: the role fails safely with the genuine
underlying error preserved, no configuration change, and no `capability_result`
constructed (the role never gets past the initial gather).

35 fixtures total.

### Not Covered, and Why

**Removal - 2 of 6 scenarios:** "access-interface state cannot be determined" and "trunk
state cannot be determined." These collapse into a single testable case in this
implementation - `gather_dependencies.yml` reads both through one
`cisco.ios.ios_l2_interfaces` call, so there's no way to fail only the access half or only
the trunk half of that read. More fundamentally, neither is expressible as a plain
`--extra-vars` input file: both require making a live device read fail on demand, which
needs the same controlled-interruption mechanism described below.

**Failure Handling - 7 of 9 scenarios**, per `vlan.md`'s own test-scenario guidance
("failure or transport scenarios that cannot be represented as input files require an
appropriate simulated or integration test instead"):

* **Authorization failure** - needs a distinct low-privilege lab account (valid login,
  insufficient enable/privilege). A CML lab configuration change, not a code or fixture
  change.
* **Connection loss before configuration**, **Required gathered state unavailable** - need
  a way to interrupt connectivity to the device at a controlled point *during* a running
  playbook - not just point at a wrong host or credential (that's what
  `unreachable_device`/`authentication_failure` already cover). No such mechanism exists
  yet in this repository or lab tooling.
* **Connection loss after configuration attempt**, **Recovery succeeds after a
  post-mutation connection failure**, **State remains indeterminate after bounded recovery
  attempts** - the hardest tier: needs the same controlled interruption, timed to land
  after the apply task specifically, and for two of the three, timed to either recover
  within the bounded retry window (proving the retry succeeds) or persist past it (proving
  the `unverified` outcome fires). Real timing-sensitive integration-test engineering, not
  a fixture file.
* **Verification failure** - was reproducible earlier by deliberately requesting a
  `vlan_name` already claimed by another VLAN (the device would silently reject the
  rename, and post-change verification would correctly catch the mismatch). That path is
  now closed: the duplicate-name pre-flight check added to `evaluate.yml` catches the
  conflict *before* apply, so it can no longer reach `verify.yml`. No other known
  deterministic way to cause a genuine post-apply mismatch has been found without either a
  real, currently-unidentified device quirk, or deliberately injecting configuration drift
  via a raw command mid-test (a real integration-test technique, not a simple fixture).

**Two related implementation findings, documented in `vlan.md`'s Connection Failures
section rather than tested directly:** connection failures currently surface as Ansible's
ordinary `failed` status rather than the dedicated `unreachable` status (traced to the
pinned `ansible.netcommon` collection's "dexec" execution path, which collapses every
exception type into plain result text before Ansible's executor can classify it) - and the
bounded retry (`until`/`retries`/`delay`) applies uniformly regardless of whether a
failure is transient or deterministic, since no structured error type survives dexec to
distinguish them. Both were deliberately left as-is rather than worked around, since the
only lever for either would be pattern-matching volatile error-message text - judged not
worth the fragility for a bounded, safety-neutral cost.

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

Add `--check` for the check-mode fixtures. A negative test only passes when the role
actually rejects the invalid input; unexpected acceptance is a failure.

A reachable device and valid inventory credentials are required - these tests are not
self-contained and do not run against `localhost`.
