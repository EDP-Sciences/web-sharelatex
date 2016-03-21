SubmissionController = require "./SubmissionController"

SecurityManager = require "../../managers/SecurityManager"

module.exports =
  apply: (app) ->

    app.post '/project/:Project_id/submit', SecurityManager.requestIsOwner, SubmissionController.startSubmission
    app.get  '/project/:Project_id/submission_status', SecurityManager.requestCanAccessProject, SubmissionController.getSubmissionStatus

    app.post '/submission/:submission_id/cancel', SubmissionController.cancelSubmission
    app.post '/submission/:submission_id/finalize', SubmissionController.finalizeSubmission
