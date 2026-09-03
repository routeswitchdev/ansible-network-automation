# Ansible Network Automation

Ansible-based network automation repository containing reusable collections, roles, playbooks, and supporting tooling for managing network infrastructure.

The repository is organized around two principles:

* **Collections** define platform or shared automation boundaries.
* **Roles** define individual automation capabilities.

## Documentation Map

| I want to...                                | Refer to                                                                             |
|----------------------------------------------|---------------------------------------------------------------------------------------|
| Understand the project, collections, and capabilities | `README.md` (this file)                                                    |
| See what's implemented vs. deferred/future    | `README.md` - Implementation Status and Future Scope, below                          |
| Understand `net_common`                       | [`ansible_collections/routeswitchdev/net_common/README.md`](ansible_collections/routeswitchdev/net_common/README.md) |
| Understand the `vlan` role                    | [`ansible_collections/routeswitchdev/net_iosxe/README.md`](ansible_collections/routeswitchdev/net_iosxe/README.md)   |
| Run or review tests                           | [`docs/testing.md`](docs/testing.md)                                                 |

## Repository Index

| File                                                                                                     | Description                                                                                                                          |
|----------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `ansible.cfg`                                                                                            | Repository Ansible configuration, including inventory location, collection paths, connection settings, timeouts, and SSH pipelining. |
| `requirements.yml`                                                                                       | External Ansible collection and role dependencies required by this repository.                                                       |
| `LICENSE`                                                                                                | Apache License 2.0 governing use and distribution of this repository.                                                                |
| `ansible_collections/routeswitchdev/net_common/README.md`                                                | Documentation for shared functionality provided by the `net_common` collection.                                                      |
| `ansible_collections/routeswitchdev/net_common/roles/result_contract/tasks/main.yml`                     | Entry point for the `result_contract` role.                                                                                          |
| `ansible_collections/routeswitchdev/net_common/roles/result_contract/tasks/validate_result_contract.yml` | Validation logic enforcing the standard `capability_result` contract.                                                                |
| `ansible_collections/routeswitchdev/net_common/roles/result_contract/vars/main.yml`                      | Required keys, allowed keys, and enumerated values used by the result contract validator.                                            |
| `ansible_collections/routeswitchdev/net_common/tests/result_contract/test_validate_result_contract.yml`  | Localhost test suite covering positive and negative result contract validation cases.                                                |
| `ansible_collections/routeswitchdev/net_iosxe/galaxy.yml`                                                | Collection metadata for the Cisco IOS/IOS-XE automation collection.                                                                  |
| `ansible_collections/routeswitchdev/net_iosxe/README.md`                                                 | Documentation for the Cisco IOS/IOS-XE collection and its supported capabilities.                                                    |
| `ansible_collections/routeswitchdev/net_iosxe/roles/vlan/meta/argument_specs.yml`                        | Public input contract for the `vlan` role (`vlan_id`, `vlan_name`, `vlan_action`).                                                    |
| `ansible_collections/routeswitchdev/net_iosxe/roles/vlan/tasks/main.yml`                                 | Entry point for the `vlan` role, orchestrating validate → gather → evaluate → apply → verify.                                        |
| `ansible_collections/routeswitchdev/net_iosxe/tests/vlan/`                                               | VLAN role test fixtures - `--extra-vars` input files covering provisioning, verify, removal, input validation, idempotency, check mode, and failure handling. |
| `playbooks/vlan.yml`                                                                                     | Reference playbook invoking the `vlan` role and exposing its `capability_result`.                                                     |
| `docs/testing.md`                                                                                        | Detailed test coverage, peer-review instructions, and run commands for all collections.                                               |

## Repository Structure

```text
ansible-network-automation/
├── README.md
├── LICENSE
├── ansible.cfg
├── requirements.yml
│
├── inventory/
├── playbooks/
│   └── vlan.yml
├── docs/
│   └── testing.md
│
└── ansible_collections/
    └── routeswitchdev/
        ├── net_common/
        │   ├── README.md
        │   ├── roles/
        │   └── tests/
        │
        └── net_iosxe/
            ├── README.md
            ├── galaxy.yml
            ├── roles/
            │   └── vlan/
            └── tests/
                └── vlan/
```

## Collections

### `routeswitchdev.net_common`

Provides minimal shared functionality used across network automation capabilities.

Current functionality includes:

* Standard capability result contract
* Result validation
* Common evidence structures
* Shared reporting conventions

See [`ansible_collections/routeswitchdev/net_common/README.md`](ansible_collections/routeswitchdev/net_common/README.md) for details.

### `routeswitchdev.net_iosxe`

Provides automation capabilities for Cisco IOS and IOS-XE network devices.

Capabilities are implemented as independently usable Ansible roles.

See [`ansible_collections/routeswitchdev/net_iosxe/README.md`](ansible_collections/routeswitchdev/net_iosxe/README.md) for details.

## Architecture

The repository follows these primary design rules:

* Platform-specific automation belongs in platform-specific collections.
* Individual automation capabilities are implemented as roles.
* Playbooks provide orchestration.
* Roles provide implementation.
* Roles should remain independently usable.
* Shared functionality should remain minimal and stable.
* Prefer declarative Ansible resource modules where available.
* Preserve idempotency.
* Validate inputs before making device changes.
* Fail safely when input or device state is invalid.
* Verify changes before reporting successful convergence.

A capability generally follows this lifecycle:

```text
validate → gather → evaluate → apply → verify
```

## Playbooks

The `playbooks/` directory contains engineer-facing orchestration workflows.

Playbooks should coordinate collections and roles without embedding capability-specific implementation logic.

## Inventory

The `inventory/` directory contains Ansible inventory and environment-specific variables.

Environment-specific configuration should remain outside reusable collection and role implementation.

## Implementation Status

**`net_common`** - the standard `capability_result` contract and its validator are
implemented and tested. Per-host result recording (beyond the contract itself),
sensitive-data redaction, local evidence persistence, and run-level summaries are
currently deferred until a capability demonstrates a shared requirement for them - they
are documented as target ownership, not built yet.

**`net_iosxe` / `vlan` role** - `create`, `delete`, and `verify` are implemented, including
access-port and trunk deletion-dependency safety, bounded retry/recovery on connection
failures, and the `unverified` outcome for results that can't be confirmed even after
bounded retry.

## Future Scope

Documented but intentionally not yet implemented:

* **VTP safety** - whether a VLAN operation could propagate through VTP, and blocking
  operations that could affect other devices. Not implemented; VLAN operations are
  currently assumed to affect only the target switch.
* **Additional VLAN dependency types** - voice VLAN assignments, SVIs, private VLANs,
  SPAN/RSPAN, EVPN/VXLAN, service instances, and other platform-specific references.
  Current VLAN deletion safety is limited to configured access-port and trunk
  allowed-VLAN dependencies.
* **`net_common`'s deferred ownership items** - per-host result recording, redaction,
  local evidence persistence, and run-level summaries (see Implementation Status above).

## Testing

Tests should validate both successful behavior and expected failure conditions.
Collection-specific tests are maintained within their respective collections under
`ansible_collections/routeswitchdev/<collection>/tests/`.

See [`docs/testing.md`](docs/testing.md) for detailed test coverage, peer-review
instructions, and the exact commands to run each collection's tests.

## Requirements

External Ansible dependencies are declared in:

```text
requirements.yml
```

Install repository dependencies with:

```bash
ansible-galaxy install -r requirements.yml
```

## License

This project is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE) for details.
