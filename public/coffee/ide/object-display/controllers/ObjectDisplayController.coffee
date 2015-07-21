define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "ObjectDisplayController", ($scope, $http) ->
    $scope.$watch 'value', (object) ->
      if not object
        $scope.open = false
        return
      $scope.open = true
      if object.content
        $scope.object_data = object.content
        $scope.pending = false
        $scope.error = null
      else
        $scope.pending = true
        $scope.object_data = null
        $scope.error = null
        if not object.promise
          object.promise = $http.get("/ews/object/" + object.value).success (content) ->
            object.content = content
            $scope.object_data = content
            $scope.pending = false
            $scope.error = null
            delete object.promise
          .error (error) ->
            $scope.error = error.status
            $scope.pending = false
            $scope.object_data = null
            delete object.promise
