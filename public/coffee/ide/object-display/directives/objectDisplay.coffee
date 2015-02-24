define [
  "base"
], (App) ->
  # console.log "cdsObjectDisplay load"
  App.directive "cdsObjectDisplay", ($log) ->
    # $log.debug "cdsObjectDisplay init"

    restrict: "E"
    scope:
      value: "=cdsValue"
      top: "=cdsTop"
      bottom: "=cdsBottom"
      left: "=cdsLeft"
      right: "=cdsRight"
    templateUrl: "cdsObjectDisplayTemplate"
