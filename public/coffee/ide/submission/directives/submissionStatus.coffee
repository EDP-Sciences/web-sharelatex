define [
  "base"
], (App) ->
  App.directive "submissionStatus", () ->
    restrict: "E"
    scope:
      project: "=project"
    templateUrl: "SubmissionStatusTemplate"
