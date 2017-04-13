metrics = require '../../infrastructure/Metrics'
SubmissionHandler = require './SubmissionHandler'
logger = require "logger-sharelatex"

module.exports =
  startSubmission: (req, res) ->
    metrics.inc "start-submission"
    project_id = req.params.Project_id
    logger.log project_id:project_id, "startSubmission"
    SubmissionHandler.startSubmission project_id, req.body.resubmit, req.body.is_revision, (err) ->
      if err?
        res.status 400
        .json error: err?.error or err
      else
        res.status 200
        .json "OK"

  cancelSubmission: (req, res) ->
    metrics.inc "cancel-submission"
    submission_id = req.params.submission_id
    SubmissionHandler.cancelSubmission submission_id, (err) ->
      if err?
        res.status 400
        .json error: err?.error or err
      else
        res.status 200
        .json "OK"

  finalizeSubmission: (req, res) ->
    metrics.inc "finalize-submission"
    submission_id = req.params.submission_id
    SubmissionHandler.finalizeSubmission submission_id, (err) ->
      if err?
        res.status 400
        .json error: err?.error or err
      else
        res.status 200
        .json "OK"

  getSubmissionStatus: (req, res) ->
    project_id = req.params.Project_id
    SubmissionHandler.getSubmissionStatus project_id, (err, status) ->
      if err?
        res.status 400
        .json error: err?.error or err
      else
        res.status 200
        .json status
