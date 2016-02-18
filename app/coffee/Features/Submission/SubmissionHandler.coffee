settings = require 'settings-sharelatex'
logger = require 'logger-sharelatex'
request = require 'request'

Project = (require '../../models/Project').Project
ProjectGetter = require '../Project/ProjectGetter'

module.exports = SubmissionHandler =
  startSubmission: (user, project_id, callback) ->
    project_id = project_id.toString()
    ProjectGetter.getProject project_id, null, (err, project) ->
      return callback err if err?
      return callback 'Invalid project id' if not project?
      return callback 'Invalid submission target' if not SubmissionHandler._allowedSubmissionTarget project.submissionTarget
      return callback 'You must be the owner of the project to submit it' if project.owner_ref != user._id

      SubmissionHandler._enqueueSubmission project_id, callback

  cancelSubmission: (user, project_id, callback) ->
    project_id = project_id.toString()
    ProjectGetter.getProject project_id, null, (err, project) ->
      return callback err if err?
      return callback 'Invalid project id' if not project?
      return callback 'Invalid submission target' if not SubmissionHandler._allowedSubmissionTarget project.submissionTarget
      return callback 'You must be the owner of the project to cancel it' if project.owner_ref != user._id

      SubmissionHandler._cancelSubmission project_id, callback

  finalizeSubmission: (user, project_id, callback) ->
    project_id = project_id.toString()
    ProjectGetter.getProject project_id, null, (err, project) ->
      return callback err if err?
      return callback 'Invalid project id' if not project?
      return callback 'Invalid submission target' if not SubmissionHandler._allowedSubmissionTarget project.submissionTarget
      return callback 'You must be the owner of the project to finalize it' if project.owner_ref != user._id

      SubmissionHandler._finalizeSubmission project_id, callback

  getSubmissionStatus: (user, project_id, callback) ->
    project_id = project_id.toString()
    ProjectGetter.getProject project_id, null, (err, project) ->
      return callback err if err?
      return callback 'Invalid project id' if not project?
      return callback 'Invalid project_id' if project.owner_ref != user._id and user._id not in project.readOnly_refs

      SubmissionHandler._getSubmissionStatus project_id, callback


  _allowedSubmissionTarget: (target) ->
    target == 'aa'

  _enqueueSubmission: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/submit"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err)->
      if err?
        logger.err err:err, "error queuing something in the submission queue"
        callback(err)
      else
        logger.log project_id:project_id, "successfully queued up job for submission"
        callback()

  _cancelSubmission: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{project_id}/cancel"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err)->
      if err?
        logger.err err:err, "error cancelling the submission process"
        callback(err)
      else
        logger.log project_id:project_id, "successfully cancelled the submission process"
        callback()

  _finalizeSubmission: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{project_id}/finalize"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err)->
      if err?
        logger.err err:err, "error finalizing the submission process"
        callback(err)
      else
        logger.log project_id:project_id, "successfully finalized the submission process"
        callback()

  _getSubmissionStatus: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{project_id}/status"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err, response)->
      if err?
        logger.err err:err, "error getting the submission status"
        callback(err)
      else
        logger.log project_id:project_id, response: response, "successfully got the submission status"
        callback response