define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "ObjectDisplayController", ($scope, $http) ->
    $scope.submitProject = () ->
      if $scope.submission_promise
        return
      $scope.submission_promise = $http.post "/project/#{$scope.project._id}/submit"

