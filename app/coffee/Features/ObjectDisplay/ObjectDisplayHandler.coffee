settings = require "settings-sharelatex"
logger = require "logger-sharelatex"
http = require "http"
xml2js = require "xml2js"
isArray = require "isarray"

getName = (entry) ->
  if isArray entry?.oname
    entry.oname[0]
  else
    entry?.oname

simplifyObjectData = (data) ->
  sesame = data?.Sesame
  target = sesame?.Target[0]
  name = if isArray target?.name
    target.name[0]
  else
    target?.name
  result =
    name: name
  resolvers = target["Resolver"]
  for resolver in (resolvers or [])
    resolver_name = resolver?.$?.name
    switch
      when (resolver_name.indexOf "Simbad") >= 0 then result.Simbad = getName resolver
      when (resolver_name.indexOf "VizieR") >= 0 then result.VizieR = getName resolver
      when (resolver_name.indexOf "NED") >= 0 then result.NED = getName resolver
      else result.unknown = resolver_name
  return result

module.exports =
  getObjectData: (object_id, callback = (err, data) ->) ->
    cds_url = settings.ews?.object_display?.cds_url
    if not cds_url
      return callback message: "no CDS url configured"

    url = cds_url + "?" + object_id

    logger.log url, "CDS query"

    req = http.get url, (res) ->
      if res.statusCode >= 400
        callback message: "CDS returned an error"
      else
        body = ""
        res.on "data", (data) ->
          body += data.toString("utf8")
        .on "end", () ->
          parser = new xml2js.Parser()
          parser.parseString body, (error, data) ->
            if error
              callback error
            else
              callback null, simplifyObjectData data
    req.on "error", (error) ->
      callback error