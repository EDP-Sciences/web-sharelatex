settings = require 'settings-sharelatex'
logger = require 'logger-sharelatex'
request = require 'request'

Project = (require '../../models/Project').Project
ProjectGetter = require '../Project/ProjectGetter'

module.exports = SubmissionHandler =

  startSubmission: (project_id, resubmit, is_revision, callback) ->
    opts =
      uri: "#{settings.apis.submit.url}/submit"
      json:
        project: project_id
        resubmission: resubmit
        is_revision: is_revision
      method: "post"
      timeout: 5 * 1000
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
      uri: "#{settings.apis.submit.url}/#{submission_id}/cancel"
      json: true
      method: "post"
      timeout: 5 * 1000
    request opts, (err, response)->
      if err?
        logger.err err:err, response: response,"error cancelling the submission process"
        callback err
      else
        logger.log submission_id:submission_id, response: response, "successfully cancelled the submission process"
        callback()

  finalizeSubmission: (submission_id, callback) ->
    opts =
      uri: "#{settings.apis.submit.url}/#{submission_id}/finalize"
      json: true
      method: "post"
      timeout: 5 * 1000
    request opts, (err, response)->
      if err?
        logger.err err:err, response: response, "error finalizing the submission process"
        callback err
      else
        logger.log submission_id:submission_id, response: response, "successfully finalized the submission process"
        callback()

  getSubmissionStatus: (project_id, callback) ->
    opts =
      uri: "#{settings.apis.submit.url}/#{project_id}/status"
      json: true
      method: "get"
      timeout: 5 * 1000
    request opts, (err, response)->
      if err?
        logger.err err:err, "error getting the submission status"
        callback err
      else
        logger.log project_id:project_id, response: response.body, status: response.statusCode, "successfully got the submission status"
        return callback null, null if response.statusCode == 404
        return callback response.body if 200 < response.statusCode >= 400
        callback null, response.body
    
  deleteSubmission: (project_id, callback) ->
    request
      uri: "#{settings.apis.submit.url}/#{project_id}/status"
      json: true
      method: "get"
      timeout: 5 * 1000
    , (err, response) ->
      if err?
        logger.err err:err, "error getting the submission status"
        callback err
      else
        logger.log project_id:project_id, response: response.body, status: response.statusCode, "got the submission status"
        return callback response.body if 200 < response.statusCode >= 400
        submission_id = response.body.submission_id
        logger.log submission_id: submission_id, body: typeof response.body, "submission_id"
        request
          uri: "#{settings.apis.submit.url}/#{submission_id}/delete"
          json: true
          method: "post"
          timeout: (5 * 1000)
        , (err, response) ->
          if err?
            logger.err err:err, "error deleting the submission"
            callback err
          else
            logger.log project_id:project_id, response: response.body, "successfully deleted the submission"
            callback if 200 < response.statusCode >= 400 then response.body else null

  getUserSubmissions: (user_id, callback) ->
    opts =
      uri: "#{settings.apis.submit.url}/submissions"
      json:
        user: user_id
      method: "post"
      timeout: 5 * 1000
    request opts, (err, response)->
      if err?
        logger.err err:err, "error getting the user submissions"
        callback err
      else
        logger.log user_id: user_id, response: response.body, "successfully got the user submissions"
        callback response.body if 200 < response.statusCode >= 400
        callback null, response.body
