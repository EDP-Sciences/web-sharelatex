UserLocator = require("./UserLocator")
UserGetter = require("./UserGetter")
ErrorController = require("../Errors/ErrorController")
logger = require("logger-sharelatex")
Settings = require("settings-sharelatex")
fs = require('fs')

module.exports =

	registerPage : (req, res)->
		if Settings.orcid?.disableRegistration
			return res.render 'orcid/no_register',
        disableOrcidRegistration: Settings.orcid.disableOrcidRegistration

		sharedProjectData =
			project_name:req.query.project_name
			user_first_name:req.query.user_first_name

		newTemplateData = {}
		if req.session.templateData?
			newTemplateData.templateName = req.session.templateData.templateName

		res.render 'user/register',
			title: 'register'
			redir: req.query.redir
			sharedProjectData: sharedProjectData
			newTemplateData: newTemplateData
			new_email:req.query.new_email || ""
	
	activateAccountPage: (req, res) ->
		# An 'activation' is actually just a password reset on an account that
		# was set with a random password originally.
		if !req.query?.user_id? or !req.query?.token?
			return ErrorController.notFound(req, res)
			
		UserGetter.getUser req.query.user_id, {email: 1, loginCount: 1}, (error, user) ->
			return next(error) if error?
			if !user
				return ErrorController.notFound(req, res)
			if user.loginCount > 0
				# Already seen this user, so account must be activate
				# This lets users keep clicking the 'activate' link in their email
				# as a way to log in which, if I know our users, they will.
				res.redirect "/login?email=#{encodeURIComponent(user.email)}"
			else
				res.render 'user/activate',
					title: 'activate_account'
					email: user.email,
					token: req.query.token

	loginPage : (req, res)->
		res.render 'user/login',
			title: 'login',
			redir: req.query.redir,
			email: req.query.email

	settingsPage : (req, res, next)->
		logger.log user: req.session.user, "loading settings page"
		UserLocator.findById req.session.user._id, (err, user)->
			return next(err) if err?
			res.render 'user/settings',
				title:'account_settings'
				user: user,
				languages: Settings.languages,
				accountSettingsTabActive: true
