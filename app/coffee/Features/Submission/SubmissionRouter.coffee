SubmissionController = require "./SubmissionController"
AuthorizationMiddleware = require "../Authorization/AuthorizationMiddlewear"
ApiAccessManager = require "./ApiAccessManager"

module.exports =
  apply: (app, api) ->

    app.post '/project/:Project_id/submit', AuthorizationMiddleware.ensureUserCanAdminProject, SubmissionController.startSubmission
    app.get  '/project/:Project_id/submissionStatus', AuthorizationMiddleware.ensureUserCanReadProject, SubmissionController.getSubmissionStatus

    api.post '/submission/:submission_id/cancel', ApiAccessManager, SubmissionController.cancelSubmission
    api.post '/submission/:submission_id/finalize', ApiAccessManager, SubmissionController.finalizeSubmission
