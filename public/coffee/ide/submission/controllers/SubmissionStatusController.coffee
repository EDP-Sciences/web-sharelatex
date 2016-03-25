define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "SubmissionStatusController", ($scope, $http, $timeout) ->

    $scope.updateProjectStatus = () ->
      if $scope.submission_promise
        $timeout $scope.updateProjectStatus, 250
        return
      $scope.submission_promise = $http.get "/project/#{$scope.project.id}/submissionStatus", _csrf: window.csrfToken
      .then (response) ->
        data = response.data
        $scope.project.submission_status = status = data.status
        switch status
          when 'finalized'
            $scope.project.submitted = false
            $scope.project.finalized = true
          when 'cancelled'
            $scope.project.submitted = false
            $scope.project.finalized = true
          when 'submitted'
            $scope.project.submission_pending = false
            delete $scope.project.submission_error
            $scope.project.submission_url = data.url
            $scope.project.submitted = true
          when 'failed'
            $scope.project.submission_pending = false
            $scope.project.submission_error = data.error
          else
            $scope.project.submission_pending = true
            $timeout $scope.updateProjectStatus, 1000
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise

    $scope.submitProject = () ->
      if $scope.submission_promise
        return
      $scope.project.submittable = false
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/submit", _csrf: window.csrfToken
      .then (response) ->
        $scope.project.submission_pending = true
        $timeout $scope.updateProjectStatus, 1000
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise

    $scope.deleteSubmission = () ->
      if $scope.submission_promise
        return
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/deleteSubmission", _csrf: window.csrfToken
      .then (result) ->
        $scope.project.submittable = true
        $scope.project.submission_pending = false
        delete $scope.project.submission_error
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise
