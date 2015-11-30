ObjectDisplayController = require "./ObjectDisplayController"
AuthenticationController = require '../Authentication/AuthenticationController'

module.exports =
  apply: (app) ->

    app.get  '/ews/object/:object_id*', AuthenticationController.requireLogin(), ObjectDisplayController.getObjectData

