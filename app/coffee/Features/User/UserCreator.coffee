User = require("../../models/User").User
UserLocator = require("./UserLocator")

module.exports =

	getUserOrCreateHoldingAccount: (email, callback = (err, user)->)->
		self = @
		UserLocator.findByEmail email, (err, user)->
			if user?
				callback(err, user)
			else
				self.createNewUser email:email, holdingAccount:true, callback

	createNewUser: (opts, callback)->
		user = new User()
		user.email = opts.email if opts.email?
		user.orcid = opts.orcid if opts.orcid?
		user.holdingAccount = opts.holdingAccount if opts.holdingAccount?


		username = opts.email.match(/^[^@]*/) if opts.email?
		if username?
			user.first_name = username[0]
		else
			user.first_name = ""
		user.last_name = ""

		user.featureSwitches?.pdfng = true

		user.save (err)->
			callback(err, user)
