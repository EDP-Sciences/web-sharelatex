AuthenticationController = require "./AuthenticationController"
UserGetter = require "../User/UserGetter"
UserCreator = require "../User/UserCreator"
UserUpdater = require "../User/UserUpdater"
Metrics = require '../../infrastructure/Metrics'
logger = require "logger-sharelatex"
querystring = require "querystring"
Url = require "url"
https = require "https"
http = require "http"
Settings = require "settings-sharelatex"
xml2js = require "xml2js"
isArray = require "isarray"

auto_request = (options) ->
  if options.protocol == 'http:'
    return http.request options
  if options.protocol == 'https:'
    return https.request options
  throw 'Invalid protocol'

find_node_content = (root, nodes, callback) ->
  return (callback null, root) if not nodes
  for node in nodes
    return (callback "#{node} not found") if not root[node]
    subnodes = root[node]
    snodes = nodes.clone()
    snodes.splice 0, 1
    for subnode in subnodes
      find_node_content subnode, snodes, callback

find_email = (emails) ->
  return null if !emails?
  if not isArray emails
    emails = [emails]
  first_email = null
  primary_email = null
  current_email = null
  valid_email = null
  for entry in emails
    primary_email = entry.value if entry.primary
    valid_email = entry.value if entry.verified
    current_email = entry.value if entry.current
    first_email = entry.value if not first_email?
  return primary_email or valid_email or current_email or first_email

module.exports = OrcidController =
  init: () ->
    OrcidController.endpoint_url = Settings.orcid?.endpoint_url or "http://pub.sandbox.orcid.org/v1.1/"
    OrcidController.authorize_url = Settings.orcid?.authorize_url or "https://sandbox.orcid.org/oauth/authorize"
    OrcidController.token_url = Settings.orcid?.token_url or "https://pub.sandbox.orcid.org/oauth/token"
    OrcidController.scope = Settings.orcid?.scope or "/authenticate"
    OrcidController.client_id = Settings.orcid?.client_id
    OrcidController.client_secret = Settings.orcid?.client_secret
    OrcidController.redirect_uri = "#{Settings.siteUrl}/ews/orcid_endpoint"

  apply: (app) ->
    if Settings.orcid?.useOrcidLogin?
      OrcidController.init()
      app.get  '/ews/orcid_endpoint', OrcidController.endpoint


  getUserByOrcid: (orcid, callback = (error, user=null, isNew=false) ->) ->
    UserGetter.getUser {orcid: orcid}, (error, user) ->
      return (callback error) if error?
      return (callback null, user) if user?
      if Settings.orcid?.disableOrcidRegistration?
        return callback()
      UserCreator.createNewUser {orcid: orcid, holdingAccount: false}, (error, user) ->
        return (callback error) if error?
        callback null, user, true

  updateUserCredentials: (user, refresh_token, access_token, callback = (error) ->) ->
    UserUpdater.updateUser user._id.toString(),
      $set:
        orcid_refresh_token: refresh_token,
        orcid_access_token: access_token
    , (error) ->
      callback error

  updateUserInfoFromOrcid: (user, callback = (error) ->) ->
    options = Url.parse "#{OrcidController.endpoint_url}#{user.orcid}/orcid-bio"
    options.headers =
        authorization: "Bearer #{user.orcid_access_token}"
        accept: "application/json"
    options.method = 'GET'
    logger.info "orcid-get", options
    req = auto_request options
    req.end()

    req.on 'response', (response) ->
      logger.info 'orcid-bio', response.statusCode
      return (callback response.statusCode) if response.statusCode >= 400

      response.on 'data', (data) ->
        logger.info 'orcid-bio data', data.toString()
        result = JSON.parse data.toString()

        first_name = result?["orcid-profile"]?["orcid-bio"]?["personal-details"]?["given-names"].value
        last_name  = result?["orcid-profile"]?["orcid-bio"]?["personal-details"]?["family-name"].value
        email = find_email result?["orcid-profile"]?["orcid-bio"]?["contact-details"]?["email"]

        update = {}
        update.first_name = first_name if first_name?
        update.last_name = last_name if last_name?
        update.email = email if email?

        logger.info 'orcid-bio data', update

        UserUpdater.updateUser user._id.toString(),
          $set:
            update
        , (error) ->
          return (callback error) if error?
          user.first_name = first_name if first_name?
          user.last_name = last_name if last_name?
          user.email = email if email?
          callback()

  setLoginUrl: (req, res, next) ->
    useOrcidLogin = res.locals.displayOrcidLogin = Settings?.orcid.useOrcidLogin
    next() if not useOrcidLogin
    url = Url.parse OrcidController.authorize_url
    url.query =
      client_id: OrcidController.client_id
      response_type: "code"
      scope: OrcidController.scope
      redirect_uri: OrcidController.redirect_uri
      show_login: "true"
    res.locals.orcidLoginUrl = Url.format url
    next()

  endpoint: (req, res, next) ->
    if req.query?.error
      res.statusCode = 500
      return res.render "orcid/error",
        error: req.query.error
        error_description: req.query.error_description
    if not req.query?.code
      return next "Missing token"

    body = querystring.stringify
      client_id: OrcidController.client_id
      client_secret: OrcidController.client_secret
      grant_type: "authorization_code"
      redirect_uri: OrcidController.redirect_uri
      code: req.query.code
    options = Url.parse OrcidController.token_url
    options.method = 'POST'
    options.headers =
      "accept": "application/json"
      "content-type": "application/x-www-form-urlencoded"
      "content-length": body.length

    logger.info 'request', options, body

    orcid_req = auto_request options

    orcid_req.end body

    orcid_req.on 'response', (response) ->
      logger.info 'response', response.statusCode, response.headers
      if response.statusCode >= 400
        return (next response.statusCode) if response.statusCode >= 300

      response.on "data", (body) ->
        logger.info 'data', body.toString()
        return (next response.statusCode) if response.statusCode >= 300
        result = JSON.parse body.toString()
        if result?.token_type != "bearer"
          return next "Invalid token_type"
        orcid = result?.orcid
        refresh_token = result?.refresh_token
        access_token = result?.access_token
        if not orcid or not access_token
          return next "Missing orcid"

        OrcidController.getUserByOrcid orcid, (error, user, isNew) ->
          return (next error) if error?
          return (res.render 'orcid/popup_close', redirect: "#{Settings.siteUrl}/register") if not user?
          logger.info 'get_user', user, isNew
          OrcidController.updateUserCredentials user, refresh_token, access_token, (error) ->
            if error
              AuthenticationController._recordFailedLogin (error) ->
              return next error
            user.orcid_refresh_token = refresh_token
            user.orcid_access_token = access_token
            OrcidController.updateUserInfoFromOrcid user, (error) ->
              if error
                AuthenticationController._recordFailedLogin (error) ->
                return next error
              AuthenticationController._recordSuccessfulLogin user._id, (error) ->
                return(next error) if error?
              AuthenticationController.establishUserSession req, user, (error) ->
                return(next error) if error?
                logger.log user.orcid, user.email, user_id: user._id.toString(), "successful ORCID log in"
                res.render 'orcid/popup_close', redirect: "#{Settings.siteUrl}/project"
