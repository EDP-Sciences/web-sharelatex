define [
  "base"
  "ace/ace"
], (App) ->
  App.controller 'SubmissionConfirmModalController', ($scope, $modalInstance) ->
    $scope.project_title = $scope.project?.name
    $scope.confirm = () ->
      $modalInstance.close()
      
    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

