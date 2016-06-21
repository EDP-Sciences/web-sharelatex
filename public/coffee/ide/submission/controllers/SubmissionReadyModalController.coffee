define [
  "base"
  "ace/ace"
], (App) ->
  App.controller 'SubmissionReadyModalController', ($scope, $modalInstance) ->
    $scope.project_title = $scope.project?.name
    $scope.finalize = () ->
      $modalInstance.close()
      
    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

