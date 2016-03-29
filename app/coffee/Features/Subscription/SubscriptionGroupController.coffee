SubscriptionGroupHandler = require("./SubscriptionGroupHandler")
logger = require("logger-sharelatex")
SubscriptionLocator = require("./SubscriptionLocator")
ErrorsController = require("../Errors/ErrorController")
SubscriptionDomainHandler = require("./SubscriptionDomainHandler")
_ = require("underscore")

module.exports =

	addUserToGroup: (req, res)->
		adminUserId = req.session.user._id
		newEmail = req.body?.email?.toLowerCase()?.trim()
		logger.log adminUserId:adminUserId, newEmail:newEmail, "adding user to group subscription"
		SubscriptionGroupHandler.addUserToGroup adminUserId, newEmail, (err, user)->
			if err?
				logger.err err:err, newEmail:newEmail, adminUserId:adminUserId, "error adding user from group"
				return res.sendStatus 500
			result = 
				user:user
			if err and err.limitReached
				result.limitReached = true
			res.json(result)

	removeUserFromGroup: (req, res)->
		adminUserId = req.session.user._id
		userToRemove_id = req.params.user_id
		logger.log adminUserId:adminUserId, userToRemove_id:userToRemove_id, "removing user from group subscription"
		SubscriptionGroupHandler.removeUserFromGroup adminUserId, userToRemove_id, (err)->
			if err?
				logger.err err:err, adminUserId:adminUserId, userToRemove_id:userToRemove_id, "error removing user from group"
				return res.sendStatus 500
			res.send()
			
	removeSelfFromGroup: (req, res)->
		adminUserId = req.query.admin_user_id
		userToRemove_id = req.session.user._id
		logger.log adminUserId:adminUserId, userToRemove_id:userToRemove_id, "removing user from group subscription after self request"
		SubscriptionGroupHandler.removeUserFromGroup adminUserId, userToRemove_id, (err)->
			if err?
				logger.err err:err, userToRemove_id:userToRemove_id, adminUserId:adminUserId, "error removing self from group"
				return res.sendStatus 500
			res.send()

	renderSubscriptionGroupAdminPage: (req, res)->
		user_id = req.session.user._id
		SubscriptionLocator.getUsersSubscription user_id, (err, subscription)->
			if !subscription.groupPlan
				return res.redirect("/")
			SubscriptionGroupHandler.getPopulatedListOfMembers user_id, (err, users)->
				res.render "subscriptions/group_admin",
					title: 'group_admin'
					users: users
					subscription: subscription

	renderGroupInvitePage: (req, res)->
		subscription_id = req.params.subscription_id
		user_id = req.session.user._id
		licence = SubscriptionDomainHandler.findDomainLicenceBySubscriptionId(subscription_id)
		if !licence?
			return ErrorsController.notFound(req, res)
		SubscriptionGroupHandler.isUserPartOfGroup user_id, licence.subscription_id, (err, partOfGroup)->
			if partOfGroup
				return res.redirect("/user/subscription/custom_account")
			else
				res.render "subscriptions/group/invite",
					title: "Group Invitation"
					subscription_id:subscription_id
					licenceName:licence.name

	beginJoinGroup: (req, res)->
		subscription_id = req.params.subscription_id
		user_id = req.session.user._id
		licence = SubscriptionDomainHandler.findDomainLicenceBySubscriptionId(subscription_id)
		if !licence?
			return ErrorsController.notFound(req, res)
		SubscriptionGroupHandler.sendVerificationEmail subscription_id, licence.name, req.session.user.email, (err)->
			if err?
				res.sendStatus 500
			else
				res.sendStatus 200

	completeJoin: (req, res)->
		subscription_id = req.params.subscription_id
		if !SubscriptionDomainHandler.findDomainLicenceBySubscriptionId(subscription_id)?
			return ErrorsController.notFound(req, res)
		email = req?.session?.user?.email
		logger.log subscription_id:subscription_id, user_id:req?.session?.user?._id, email:email, "starting the completion of joining group"
		SubscriptionGroupHandler.processGroupVerification email, subscription_id, req.query?.token, (err)->
			if err? and err == "token_not_found"
				return res.redirect "/user/subscription/#{subscription_id}/group/invited?expired=true"
			else if err?
				return res.sendStatus 500
			else
				logger.log subscription_id:subscription_id, email:email, "user successful completed join of group subscription"
				return res.redirect "/user/subscription/#{subscription_id}/group/successful-join"

	renderSuccessfulJoinPage: (req, res)->
		subscription_id = req.params.subscription_id
		licence = SubscriptionDomainHandler.findDomainLicenceBySubscriptionId(subscription_id)
		if !SubscriptionDomainHandler.findDomainLicenceBySubscriptionId(subscription_id)?
			return ErrorsController.notFound(req, res)
		res.render "subscriptions/group/successful_join",
			title: "Sucessfully joined group"
			licenceName:licence.name	

	exportGroupCsv: (req, res)->
		user_id = req.session.user._id
		logger.log user_id: user_id, "exporting group csv"
		SubscriptionLocator.getUsersSubscription user_id, (err, subscription)->
			if !subscription.groupPlan
				return res.redirect("/")
			SubscriptionGroupHandler.getPopulatedListOfMembers user_id, (err, users)->
				groupCsv = ""
				for user in users
					groupCsv += user.email + "\n"
				res.header(
					"Content-Disposition",
					"attachment; filename=Group.csv"
				)
				res.contentType('text/csv')
				res.send(groupCsv)
