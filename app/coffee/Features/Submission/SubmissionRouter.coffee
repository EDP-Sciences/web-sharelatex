SubmissionController = require "./SubmissionController"

SecurityManager = require "../../managers/SecurityManager"

module.exports =
  apply: (app) ->

    app.post '/project/:Project_id/submit', SecurityManager.requestIsOwner, SubmissionController.startSubmission
    app.post '/project/:Project_id/deleteSubmission', SecurityManager.requestIsOwner, SubmissionController.deleteSubmission
    app.get  '/project/:Project_id/submissionStatus', SecurityManager.requestCanAccessProject, SubmissionController.getSubmissionStatus

    app.post '/submission/:submission_id/cancel', SubmissionController.cancelSubmission
    app.post '/submission/:submission_id/finalize', SubmissionController.finalizeSubmission
