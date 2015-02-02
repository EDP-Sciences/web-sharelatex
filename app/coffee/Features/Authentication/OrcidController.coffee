AuthenticationController = require "./AuthenticationController"
UserGetter = require "../User/UserGetter"
UserCreator = require "../User/UserCreator"
UserUpdater = require "../User/UserUpdater"
Metrics = require '../../infrastructure/Metrics'
logger = require "logger-sharelatex"
querystring = require "querystring"
Url = require "url"
https = require "https"
Settings = require "settings-sharelatex"
xml2js = require "xml2js"

find_node_content = (root, nodes, callback) ->
  return (callback null, root) if not nodes
  for node in nodes
    return (callback "#{node} not found") if not root[node]
    subnodes = root[node]
    snodes = nodes.clone()
    snodes.splice 0, 1
    for subnode in subnodes
      find_node_content subnode, snodes, callback

module.exports = OrcidController =
  init: () ->
    OrcidController.endpoint_url = Settings.orcid?.endpoint_url or "https://sandbox.orcid.org/"
    OrcidController.authorize_url = Settings.orcid?.authorize_url or "https://sandbox.orcid.org/oauth/authorize"
    OrcidController.token_url = Settings.orcid?.token_url or "https://pub.sandbox.orcid.org/oauth/token"
    OrcidController.scope = Settings.orcid?.scope or "/authenticate"
    OrcidController.client_id = Settings.orcid?.client_id
    OrcidController.client_secret = Settings.orcid?.client_secret
    # OrcidController.redirect_uri = "#{Settings.siteUrl}/ews/orcid_endpoint"
    OrcidController.redirect_uri = "http://lithium.edpsciences.net:3000/ews/orcid_endpoint"

  apply: (app) ->
    if Settings.orcid?.useOrcidLogin?
      OrcidController.init()
      app.get  '/ews/orcid_endpoint', OrcidController.endpoint


  getUserByOrcid: (orcid, callback = (error, user, isNew) ->) ->
    UserGetter.getUser {orcid: orcid}, (error, user) ->
      return (callback error) if error?
      return (callback null, user) if user?
      UserCreator.createNewUser orcid: orcid, (error, user) ->
        return (callback error) if error?
        callback null, user, true

  updateUserCredentials: (user, refresh_token, access_token, callback = (error) ->) ->
    UserUpdater.updaterUser user.id.toString(),
      $set:
        orcid_refresh_token: refresh_token,
        orcid_access_token: access_token
    , (error) ->
      callback error

  updateUserInfoFromOrcid: (user, callback = (error) ->) ->
    https.get "#{@endpoint_url}#{user.orcid}/orcid-bio", (error, response) ->
      return (callback error) if error?
      parser = new xml2js.Parser()

      parser.parseString response, (error, body) ->
          return (callback error) if error?
          data =
            errors: []
          find_node_content body, ['orcid-profile', 'orcid-bio', 'personal-details'], (error, node) ->
            data.errors.push error if error?
            if node
              find_node_content node, ['given-name'], (error, node) ->
                data.errors.push error if error?
                data.first_name = node._ if node?
              find_node_content node, ['family-name'], (error, node) ->
                data.errors.push error if error?
                data.last_name = node._ if node?
          find_node_content body, ['orcid-profile', 'orcid-bio', 'contact-details', 'email'], (error, node) ->
            data.errors.push error if error?
            if node and node?.$.primary?
              data.email = node._
          return (callback data.errors) if data.errors.length > 0
          UserUpdater.updaterUser user.id.toString(),
            $set:
              first_name: data.first_name,
              last_name: data.last_name,
              email: data.email,
          , (error) ->
            return (callback error) if error?
            user.first_name = first_name
            user.last_name = last_name
            user.email = email
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

    orcid_req = https.request options

    orcid_req.write body

    orcid_req.on 'response', (response) ->
      logger.info 'response', response.statusCode, response.headers

      response.on "data", (body) ->
        logger.info 'data', body.toString()
        return(next response.statusCode) if response.statusCode >= 300
        result = JSON.parse body.toString()
        if result?.token_type != "bearer"
          return next "Invalid token_type"
        orcid = result?.orcid
        refresh_token = result?.refresh_token
        access_token = result?.access_token
        if not orcid or not access_token
          return next "Missing orcid"

        OrcidController.getUserByOrcid orcid, (error, user, isNew) ->
          return(next error) if error?
          OrcidController.updateUserCredentials user, refresh_token, access_token, (error) ->
            if error
              AuthenticationController._recordFailedLogin (error) ->
              return next error
            OrcidController.updateUserInfoFromOrcid user, (error) ->
              if error
                AuthenticationController._recordFailedLogin (error) ->
                return next error
              AuthenticationController._recordSuccessfullLogin user.id, (error) ->
                return(next error) if error?
              AuthenticationController._establishUserSession req, user, (error) ->
                return(next error) if error?
              next()