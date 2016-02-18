metrics = require '../../infrastructure/Metrics'
SubmissionHandler = require './SubmissionHandler'

module.exports =
  startSubmissionProcess: (req, res, next) ->
    metrics.inc "start-submission"
    project_id = req.params.project_id
    SubmissionHandler.startSubmission req.session.user, project_id, (err) ->
      next err if err?
      res.sendStatus 200

  cancelSubmissionProcess: (req, res, next) ->
    metrics.inc "cancel-submission"
    project_id = req.params.project_id
    SubmissionHandler.cancelSubmission req.session.user, project_id, (err) ->
      next err if err?
      res.sendStatus 200

  finalizeSubmissionProcess: (req, res, next) ->
    metrics.inc "finalize-submission"
    project_id = req.params.project_id
    SubmissionHandler.finalizeSubmission req.session.user, project_id, (err) ->
      next err if err?
      res.sendStatus 200

  getSubmissionStatus: (req, res, next) ->
    project_id = req.params.project_id
    SubmissionHandler.getSubmissionStatus req.session.user, project_id, (status, err) ->
      next err if err?
      res.status 200
      .json status
