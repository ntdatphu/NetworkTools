# Routing Backend and UI Plan

This document describes the planned direction for the Routing module based on the current source code on the `main` branch.

## Objectives

- Complete the Routing configuration management flow per device.
- Support the main Routing configuration groups:
  - Static route.
  - Default route.
  - OSPF.
  - EIGRP.
- Synchronize data between QML UI and the C++ repository/database layer.
- Prepare the foundation for automated configuration generation and lab deployment.

## Current Source Status

Routing-related source is mainly located in:

```text
frontend/qml/routing/
frontend/qml/routing/static/
frontend/qml/routing/ospf/
frontend/qml/routing/eigrp/
frontend/src/database/routing/
```

The related QML and C++ files are registered in:

```text
frontend/CMakeLists.txt
```

## UI Components

### Routing shell

```text
qml/routing/RoutingView.qml
qml/routing/RoutingSubBar.qml
```

Responsibilities:

- Coordinate the Routing screen.
- Switch between Routing feature groups.
- Receive the current device context from the content/device flow.

### Static routing

```text
qml/routing/static/StaticRoutingForm.qml
qml/routing/static/StaticRouteRow.qml
qml/routing/static/StaticRoutingDefaultCard.qml
qml/routing/static/StaticRoutingRoutesCard.qml
```

Responsibilities:

- Input default route.
- Input static routes.
- Display saved route lists.
- Standardize add/edit/delete route interactions.

### OSPF

```text
qml/routing/ospf/OspfRoutingForm.qml
qml/routing/ospf/OspfProcessCard.qml
```

Responsibilities:

- Input OSPF process data.
- Input router ID, network statements, and related options.

### EIGRP

```text
qml/routing/eigrp/EigrpRoutingForm.qml
qml/routing/eigrp/EigrpProcessCard.qml
```

Responsibilities:

- Input EIGRP process data.
- Input network statements and related options.

## Backend/Database Components

Routing repositories are located in:

```text
frontend/src/database/routing/
```

Main repository groups:

```text
RoutingStaticRepository
OspfRoutingRepository
EigrpRoutingRepository
```

Responsibilities:

- Separate SQL query logic by Routing domain.
- Keep `DatabaseManager` as a facade rather than a large SQL container.
- Allow QML to call business operations through exposed C++ methods instead of accessing SQL directly.

## Related Schema

Runtime schema is located in:

```text
python app kenel/sql/main.sql
```

Routing-related table groups may include:

```text
static_default_routes
static_routes
ospf_processes
ospf_networks
eigrp_processes
eigrp_networks
```

## Completion Direction

### Phase 1: Stabilize CRUD

- Ensure UI loads data by `host` correctly.
- Ensure route/process add/edit/delete actions are persisted correctly.
- Ensure device/tab switching reloads the correct data.
- Standardize empty/loading/error states when needed.

### Phase 2: Standardize validation

- Validate required fields.
- Validate IP/subnet/wildcard/AD/process ID formats.
- Display UI errors clearly.
- Prevent invalid data from entering the database.

### Phase 3: Prepare configuration generation

- Convert database records into an intermediate configuration model.
- Define mapping from database fields to configuration commands.
- Keep config generation separate from UI.
- Allow users to preview generated configuration before deployment.

### Phase 4: Lab testing

- Test with mock data.
- Test in a simulated/lab environment.
- Record task time, number of errors, and number of steps compared with manual configuration.

## Completion Criteria

| Group | Criteria |
|---|---|
| UI | User can input/edit/delete Routing configuration clearly |
| Database | Data is stored under the correct host and tables |
| Validation | Basic input errors are reduced |
| Reload state | Switching tabs/devices does not lose or mix data |
| Research | Test scenarios and evaluation results are documented |

## Related Documentation

- [PROJECT_SUMMARY_EN.md](PROJECT_SUMMARY_EN.md)
- [PROJECT_STRUCTURE_EN.md](PROJECT_STRUCTURE_EN.md)
- [analysis/DATA_SQL_ANALYSIS.md](analysis/DATA_SQL_ANALYSIS.md)
- [research/TEST_SCENARIOS.md](research/TEST_SCENARIOS.md)
- [research/EVALUATION_CRITERIA.md](research/EVALUATION_CRITERIA.md)
