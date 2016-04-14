define [
  "base"
  "ace/ace"
], (App) ->
  App.controller 'SubmissionReadyModalController', ($scope, $modalInstance) ->
    $scope.finalize = () ->
      $modalInstance.close()
      
    $scope.cancel = () ->
      $modalInstance.dismiss('cancel')

