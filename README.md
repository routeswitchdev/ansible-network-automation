# Ansible Network Automation

Ansible-based network automation repository containing reusable collections, roles, playbooks, and supporting tooling for managing network infrastructure.

The repository follows two primary principles:

* **Collections** define platform or shared automation boundaries.
* **Roles** define individual automation capabilities.

## Documentation Map

| I want to...                                          | Refer to                                                                                                             |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Understand the project, Collections, and capabilities | `README.md` (this file)                                                                                              |
| See what is implemented or planned                    | `README.md` → Implementation Status / Planned Scope                                                                  |
| Understand the `net_common` Collection                | [`ansible_collections/routeswitchdev/net_common/README.md`](ansible_collections/routeswitchdev/net_common/README.md) |
| Understand the `net_iosxe` Collection and VLAN role   | [`ansible_collections/routeswitchdev/net_iosxe/README.md`](ansible_collections/routeswitchdev/net_iosxe/README.md)   |
| Run or peer-review test cases                         | [`docs/testing/`](docs/testing/README.md)                                                                            |

## Collections

| Collection                  | Purpose                      | Capabilities                   |
| --------------------------- | ---------------------------- | ------------------------------ |
| `routeswitchdev.net_common` | Minimal shared functionality | Result contract and validation |
| `routeswitchdev.net_iosxe`  | Cisco IOS/IOS-XE automation  | VLAN management                |

See each Collection's README for detailed usage and behavior.

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
│   └── testing/
│       ├── README.md
│       ├── net_common.md
│       └── vlan.md
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

### Important Files

#### Repository-Level

| File                 | Purpose                               |
| -------------------- | ------------------------------------- |
| `ansible.cfg`        | Ansible configuration                 |
| `requirements.yml`   | External Ansible dependencies         |
| `playbooks/vlan.yml` | Reference VLAN playbook               |
| `docs/testing/`      | Test procedures and peer-review guide |

#### net_common

Base path: `ansible_collections/routeswitchdev/net_common/`

| File                                                       | Purpose                       |
| ---------------------------------------------------------- | ----------------------------- |
| `README.md`                                                | Collection documentation      |
| `roles/result_contract/tasks/main.yml`                     | Result contract entry point   |
| `roles/result_contract/tasks/validate_result_contract.yml` | Validates `capability_result` |
| `roles/result_contract/vars/main.yml`                      | Result contract definitions   |
| `tests/result_contract/test_validate_result_contract.yml`  | Result contract tests         |

#### net_iosxe

Base path: `ansible_collections/routeswitchdev/net_iosxe/`

| File                                 | Purpose                                 |
| ------------------------------------ | --------------------------------------- |
| `README.md`                          | Collection and capability documentation |
| `galaxy.yml`                         | Collection metadata                     |
| `roles/vlan/meta/argument_specs.yml` | VLAN role input contract                |
| `roles/vlan/tasks/main.yml`          | VLAN role entry point and workflow      |
| `tests/vlan/`                        | VLAN test inputs and scenarios          |

## Architecture

The repository follows these design rules:

* Platform-specific automation belongs in platform-specific Collections.
* Automation capabilities are implemented as roles.
* Playbooks orchestrate; roles implement.
* Roles remain independently usable.
* Shared functionality remains minimal and stable.
* Prefer declarative Ansible resource modules where available.
* Validate inputs before making changes.
* Preserve idempotency.
* Fail safely.
* Verify changes before reporting successful convergence.

A capability generally follows:

1. validate
2. gather
3. evaluate
4. apply
5. verify

## Implementation Status

| Collection / Capability | Implemented                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| `net_common`            | `capability_result` contract and validator                                                |
| `net_iosxe` / `vlan`    | Create, delete, verify, deletion safety, connection retry/recovery, `unverified` handling |

## Planned / Deferred Scope

| Area              | Scope                                                                                             | Current Limitation                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| VTP safety        | Detect and prevent VLAN changes that could propagate through VTP                                  | Operations assume changes affect only the target switch               |
| VLAN dependencies | Voice VLANs, SVIs, private VLANs, SPAN/RSPAN, EVPN/VXLAN, service instances, and other references | Deletion safety currently covers access ports and trunk allowed VLANs |
| `net_common`      | Per-host result recording, redaction, evidence persistence, and run-level summaries               | Deferred until a shared requirement is demonstrated                   |

## Testing

Tests cover shared result-contract validation and VLAN capability behavior.

| Collection / Capability        | Coverage                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `net_common` / Result Contract | Valid results, structure validation, value validation, and collection validation                            |
| `net_iosxe` / VLAN             | Provisioning, verification, removal safety, input validation, idempotency, check mode, and failure handling |

Tests are maintained within each Collection under:

```text
ansible_collections/routeswitchdev/<collection>/tests/
```

See [`docs/testing/`](docs/testing/README.md) for individual test scenarios, fixtures, expected results, known coverage gaps, execution commands, and peer-review procedures.

## Requirements

External Ansible dependencies are declared in `requirements.yml`.

```bash
ansible-galaxy install -r requirements.yml
```

## License

Licensed under the Apache License 2.0. See [`LICENSE`](LICENSE).
