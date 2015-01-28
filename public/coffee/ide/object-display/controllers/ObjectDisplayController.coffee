define [
  "base"
  "ace/ace"
], (App) ->
  App.controller "ObjectDisplayController", ($scope, $http) ->
    $scope.$on "cdsObjectDisplayUpdate", (event, args) ->
      if args?.object
        object = args.object
        $scope.open = true
        $scope.top = args.top
        $scope.bottom = args.bottom
        $scope.left = args.left
        $scope.right = args.right
        if object.content
          $scope.object_data = object.content
          $scope.pending = false
        else
          $scope.pending = true
          $scope.object_data = null
          if not object.promise
            object.promise = $http.get("/ews/object/" + object.value).success (content) ->
              object.content = content
              $scope.object_data = content
              $scope.pending = false
              delete object.promise
            .error (error) ->
              $scope.error = error.status
              $scope.pending = false
              $scope.object_data = null
              delete object.promise
      else
        $scope.open = false
        $scope.object_data = null
