define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "SubmissionStatusController", ($scope, $http, $timeout, $modal, $window) ->

    $scope.$watch 'project.submission', () ->
      project = $scope.project
      if project?.show_submission_status and project?.submission?
        if project.submission.status not in ['finalized', 'cancelled']
            $timeout $scope.updateProjectStatus, 1000

    $scope.updateProjectStatus = () ->
      if $scope.submission_promise
        $timeout $scope.updateProjectStatus, 250
        return
      $scope.submission_promise = $http.get "/project/#{$scope.project.id}/submissionStatus", _csrf: window.csrfToken
      .then (response) ->
        data = response.data
        $scope.project.submission_status = status = data.status
        for attr in ['submitted', 'cancelled', 'submission_pending', 'submission_error', 'finalized']
          delete $scope.project[attr]
        switch status
          when 'finalized'
            $scope.project.finalized = true
          when 'cancelled'
            $scope.project.cancelled = true
          when 'submitted'
            $scope.project.submission_url = data.url
            $scope.project.submitted = true
            $timeout $scope.updateProjectStatus, 1000
            $scope.submissionReady $scope.project
          when 'failed'
            $scope.project.submission_error = data.error
          else
            $scope.project.submission_pending = true
            $timeout $scope.updateProjectStatus, 1000
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise

    $scope.submissionReady = (project) ->
      return if not project.submission_url? or project.modal_shown
      project.modal_shown = true
      modalInstance = $modal.open
        templateUrl: "submissionReadyModalTemplate"
        controller: "SubmissionReadyModalController"
 
      modalInstance.result.then
        () ->
          $window.open project.submission_url, '_blank'

    $scope.submitProject = () ->
      if $scope.submission_promise
        return
      $scope.project.submittable = false
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/submit", _csrf: window.csrfToken
      .then (response) ->
        $scope.project.submission_pending = true
        $timeout $scope.updateProjectStatus, 200
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise

    $scope.resubmitProject = () ->
      if $scope.submission_promise
        return
      $scope.submission_promise = $http.post "/project/#{$scope.project.id}/resubmit", _csrf: window.csrfToken
      .then (result) ->
        $scope.project.submission_pending = true
        $timeout $scope.updateProjectStatus, 200
        delete $scope.project.cancelled
        delete $scope.project.submission_error
      .catch (error) ->
        $scope.project.submission_error = error
      .finally () ->
        delete $scope.submission_promise
