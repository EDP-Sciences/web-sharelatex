define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "SubmissionStatusController", ($scope, $http) ->
    $scope.submitProject = () ->
      if $scope.submission_promise
        return
      $scope.project.submittable = false
      $scope.project.submission_pending = true
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/submit", _csrf: window.csrfToken
      .then (result) ->
        $scope.$apply () ->
          $scope.project.submission_pending = false
          $scope.project.submission_url = result.url if result.url?
          $scope.project.submitted = true
          delete $scope.submission_promise
      .catch (error) ->
        $scope.$apply () ->
          $scope.project.submission_pending = false
          $scope.project.submission_error = error
          delete $scope.submission_promise
    $scope.deleteSubmission = () ->
      if $scope.submission_promise
        return
      $scope.project.submission_pending = true
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/deleteSubmission", _csrf: window.csrfToken
      .then () ->
        $scope.$apply () ->
          $scope.project.submission_pending = false
          $scope.project.submittable = false
          delete $scope.project.error
      .catch (error) ->
        $scope.$apply () ->
          $scope.project.submission_pending = false
          $scope.project.submission_error = error
          delete $scope.submission_promise
