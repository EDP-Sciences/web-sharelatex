settings = require 'settings-sharelatex'
logger = require 'logger-sharelatex'
request = require 'request'

Project = (require '../../models/Project').Project
ProjectGetter = require '../Project/ProjectGetter'

module.exports = SubmissionHandler =

  startSubmission: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/submit"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    logger.log project_id:project_id, "sending something in the submission queue"
    request opts, (err)->
      if err?
        logger.err err:err, "error queuing something in the submission queue"
        callback err
      else
        logger.log project_id:project_id, "successfully queued up job for submission"
        callback()

  cancelSubmission: (submission_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{submission_id}/cancel"
      method: "post"
      timeout: (5 * 1000)
    request opts, (err)->
      if err?
        logger.err err:err, "error cancelling the submission process"
        callback err
      else
        logger.log submission_id:submission_id, "successfully cancelled the submission process"
        callback()

  finalizeSubmission: (submission_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{submission_id}/finalize"
      method: "post"
      timeout: (5 * 1000)
    request opts, (err)->
      if err?
        logger.err err:err, "error finalizing the submission process"
        callback err
      else
        logger.log project_id:project_id, "successfully finalized the submission process"
        callback()

  getSubmissionStatus: (project_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/#{project_id}/status"
      json :
        project: project_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err, response)->
      if err?
        logger.err err:err, "error getting the submission status"
        callback err
      else
        logger.log project_id:project_id, response: response.body, "successfully got the submission status"
        callback response.body if 200 < response.statusCode >= 400
        callback null, response.body

  getUserSubmissions: (user_id, callback) ->
    opts =
      uri:"#{settings.apis.submit.url}/submissions"
      json :
        user: user_id
      method: "post"
      timeout: (5 * 1000)
    request opts, (err, response)->
      if err?
        logger.err err:err, "error getting the user submissions"
        callback err
      else
        logger.log user_id: user_id, response: response.body, "successfully got the user submissions"
        callback response.body if 200 < response.statusCode >= 400
        callback null, response.body
