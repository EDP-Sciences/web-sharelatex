define [
  "base"
], (App) ->
  # console.log "cdsObjectDisplay load"
  App.directive "cdsObjectDisplay", ($log) ->
    # $log.debug "cdsObjectDisplay init"

    restrict: "E"
    scope:
      error: "="
      object_data: "="
    templateUrl: "cdsObjectDisplayTemplate"
