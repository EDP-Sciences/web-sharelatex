sanitize = require('sanitizer')
User = require("../../models/User").User
UserCreator = require("./UserCreator")
AuthenticationManager = require("../Authentication/AuthenticationManager")
NewsLetterManager = require("../Newsletter/NewsletterManager")
async = require("async")
EmailHandler = require("../Email/EmailHandler")
logger = require("logger-sharelatex")

module.exports =
	validateEmail : (email) ->
		re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
		return re.test(email)

	_registrationRequestIsValid : (body)->
		email = sanitize.escape(body.email).trim().toLowerCase()
		body.password.length > 0 and email.length > 0 and @validateEmail email

	_createNewUserIfRequired: (user, userDetails, callback)->
		if !user?
			UserCreator.createNewUser {holdingAccount:false, email:userDetails.email}, callback
		else
			callback null, user

	registerNewUser: (userDetails, callback)->
		self = @
		requestIsValid = @_registrationRequestIsValid userDetails
		if !requestIsValid
			return callback("request is not valid")
		userDetails.email = userDetails.email?.trim()?.toLowerCase()
		User.findOne email:userDetails.email, (err, user)->
			if err?
				return callback err
			if user?.holdingAccount == false
				return callback("EmailAlreadyRegisterd")
			self._createNewUserIfRequired user, userDetails, (err, user)->
				if err?
					return callback(err)
				async.series [
					(cb)-> User.update {_id: user._id}, {"$set":{holdingAccount:false}}, cb
					(cb)-> AuthenticationManager.setUserPassword user._id, userDetails.password, cb
					(cb)-> NewsLetterManager.subscribe user, cb
					(cb)-> 
						emailOpts =
							first_name:user.first_name
							to: user.email
						EmailHandler.sendEmail "welcome", emailOpts, cb
				], (err)->
					logger.log user: user, "registered"
					callback(err, user)




