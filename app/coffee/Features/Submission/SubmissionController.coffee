metrics = require '../../infrastructure/Metrics'
SubmissionHandler = require './SubmissionHandler'
logger = require "logger-sharelatex"

module.exports =
  startSubmission: (req, res, next) ->
    metrics.inc "start-submission"
    project_id = req.params.Project_id
    logger.log project_id:project_id, "startSubmission"
    SubmissionHandler.startSubmission project_id, (err) ->
      next err if err?
      res.sendStatus 200

  cancelSubmission: (req, res, next) ->
    metrics.inc "cancel-submission"
    submission_id = req.params.submission_id
    SubmissionHandler.cancelSubmission submission_id, (err) ->
      next err if err?
      res.sendStatus 200

  finalizeSubmission: (req, res, next) ->
    metrics.inc "finalize-submission"
    submission_id = req.params.submission_id
    SubmissionHandler.finalizeSubmission submission_id, (err) ->
      next err if err?
      res.sendStatus 200

  getSubmissionStatus: (req, res, next) ->
    project_id = req.params.Project_id
    SubmissionHandler.getSubmissionStatus project_id, (err, status) ->
      next err if err?
      res.status 200
      .json status

  deleteSubmission: (req, res, next) ->
    metrics.inc "delete-submission"
    project_id = req.params.Project_id
    logger.log project_id:project_id, "deleteSubmission"
    SubmissionHandler.deleteSubmission project_id, (err, status) ->
      if err?
        res.status 400
        .json error: err
      else
        res.status 200
        .json status
