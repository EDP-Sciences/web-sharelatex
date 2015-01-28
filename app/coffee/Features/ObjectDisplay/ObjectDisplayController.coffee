ObjectDisplayHandler = require "./ObjectDisplayHandler"
RateLimiter = require "../../infrastructure/RateLimiter"

module.exports =
  getObjectData: (req, res) ->
    object_id = req.params.object_id

    opts =
      endpointName: "object_display_rate_limit"
      timeInterval: 60
      subjectName: req.ip
      throttle: 60
    RateLimiter.addCount opts, (err, canContinue)->
      if !canContinue
        return res.status(500).send { message: req.i18n.translate("rate_limit_hit_wait")}
      ObjectDisplayHandler.getObjectData object_id, (err, object_data)->
        if err?
          res.status(500).send {message:err?.message}
        else
          res.status(200).send object_data
