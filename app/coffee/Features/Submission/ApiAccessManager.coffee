settings = require "settings-sharelatex"


module.exports = (req, res, next) ->
  if settings.submissions?.limitAccessToIps? and req.ip not in settings.submissions?.limitAccessToIps
    return res.status 403
  next()
