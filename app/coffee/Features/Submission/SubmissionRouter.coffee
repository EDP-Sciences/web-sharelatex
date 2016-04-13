SubmissionController = require "./SubmissionController"
SecurityManager = require "../../managers/SecurityManager"
ApiAccessManager = require "./ApiAccessManager"

module.exports =
  apply: (app, api) ->

    app.post '/project/:Project_id/submit', SecurityManager.requestIsOwner, SubmissionController.startSubmission
    app.post '/project/:Project_id/resubmit', SecurityManager.requestIsOwner, SubmissionController.restartSubmission
    app.get  '/project/:Project_id/submissionStatus', SecurityManager.requestCanAccessProject, SubmissionController.getSubmissionStatus

    api.post '/submission/:submission_id/cancel', ApiAccessManager, SubmissionController.cancelSubmission
    api.post '/submission/:submission_id/finalize', ApiAccessManager, SubmissionController.finalizeSubmission
