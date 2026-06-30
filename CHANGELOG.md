# Changelog

All notable changes to this project will be documented in this file.

## [1.2] - 2026-04-06

### Fixed

- Made the bootstrap deployment name unique per `azd` environment (`daga-bootstrap-noop-<env>`) to prevent `InvalidDeploymentLocation` errors when redeploying to a different Azure region.
- Switched `Connect-ExchangeOnline` to device-code flow (`-Device`) so interactive M365 authentication works from containers and Codespaces.

## [1.1] - 2026-03-09

### Added

- Added Fabric lakehouse Sensitivity Labels support in the spec-driven governance flow.
- Added explicit Microsoft 365 / Exchange Online prerequisites messaging when Fabric label application is configured.

### Changed

- Updated `docs/spec-example.json` with an anonymized, current-schema example.
- Updated spec documentation to clearly show Fabric workspace and lakehouse sensitivity label configuration.

### Fixed

- Improved Fabric datasource and scan reliability for multi-workspace runs.

## [1.0] - 2024-12-09

### Added

- Initial release of the template.
