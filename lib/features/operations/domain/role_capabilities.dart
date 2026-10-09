enum OperationAction {
  reportConflict,
  communityReports,
  incidents,
  alerts,
  analytics,
  cameras,
  addStaff,
  addPark,
  assignPatrol,
  rangers,
  myPatrols,
  reportIncident,
  outbox,
}

List<OperationAction> actionsForRole(String role) => switch (role) {
  'PARK_MANAGER' => [
    OperationAction.communityReports,
    OperationAction.incidents,
    OperationAction.alerts,
    OperationAction.analytics,
    OperationAction.cameras,
    OperationAction.addStaff,
    OperationAction.addPark,
    OperationAction.assignPatrol,
    OperationAction.rangers,
  ],
  'RANGER' => [
    OperationAction.myPatrols,
    OperationAction.reportIncident,
    OperationAction.incidents,
    OperationAction.communityReports,
    OperationAction.alerts,
    OperationAction.outbox,
  ],
  'LIAISON_OFFICER' => [
    OperationAction.communityReports,
    OperationAction.alerts,
  ],
  'RESEARCHER' => [OperationAction.analytics, OperationAction.cameras],
  'COMMUNITY_MEMBER' => [
    OperationAction.reportConflict,
    OperationAction.communityReports,
    OperationAction.outbox,
  ],
  _ => [],
};
