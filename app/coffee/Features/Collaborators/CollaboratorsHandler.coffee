UserCreator = require('../User/UserCreator')
Project = require("../../models/Project").Project
ProjectEntityHandler = require("../Project/ProjectEntityHandler")
mimelib = require("mimelib")
logger = require('logger-sharelatex')
UserGetter = require "../User/UserGetter"
ContactManager = require "../Contacts/ContactManager"
CollaboratorsEmailHandler = require "./CollaboratorsEmailHandler"

createHoldingAccount = (orcid, email, callback)->
	user = new User 'orcid': orcid, 'email': email, holdingAccount: true
	user.save (err)->
		callback(err, user)

updateProjectWithUserPrivileges = (project_id, user, privilegeLevel, callback)->
	if privilegeLevel == "readAndWrite"
		level = "collaberator_refs": user
		logger.log privileges: "readAndWrite", user: user, project_id: project_id, "adding user"
	else if privilegeLevel == "readOnly"
		level = "readOnly_refs": user
		logger.log privileges: "readOnly", user: user, project_id: project_id, "adding user"
	Project.update {_id: project_id}, {$push: level}, ->
		callback()


notifyUserViaEmail = (project_id, email, callback)->
	Project.findOne _id: project_id
	.select "name owner_ref"
	.populate "owner_ref"
	.exec (err, project)->
		emailOptions =
			to : email
			replyTo  : project.owner_ref.email
			project:
				name: project.name
				url: "#{Settings.siteUrl}/project/#{project._id}?" + [
					"project_name=#{encodeURIComponent(project.name)}"
					"user_first_name=#{encodeURIComponent(project.owner_ref.first_name)}"
					"new_email=#{encodeURIComponent(email)}"
					"r=#{project.owner_ref.referal_id}" # Referal
					"rs=ci" # referral source = collaborator invite
				].join("&")
			owner: project.owner_ref
		EmailHandler.sendEmail "projectSharedWithYou", emailOptions, callback

orcid_regexp = /^(?:(?:http:\/\/)?orcid\.org\/)?(\d{4}\-\d{4}\-\d{4}\-\d\d\d[\dx])$/i

is_orcid = (orcid_or_email) ->
	logger.log 'is_orcid', orcid_or_email, orcid_regexp.test orcid_or_email
	result = orcid_regexp.exec orcid_or_email
	result[1] if result?

module.exports =
	removeUserFromProject: (project_id, user_id, callback = ->)->
		logger.log user_id: user_id, project_id: project_id, "removing user"
		conditions = _id:project_id
		update = $pull:{}
		update["$pull"] = collaberator_refs:user_id, readOnly_refs:user_id
		Project.update conditions, update, (err)->
			if err?
				logger.error err: err, "problem removing user from project collaberators"
			callback(err)

	changeUsersPrivilegeLevel: (project_id, user_id, newPrivilegeLevel, callback = ->)->
		@removeUserFromProject project_id, user_id, =>
		  User.findById user_id, (err, user)=>
			  @addUserToProject project_id, user_id, newPrivilegeLevel, callback

	addUserToProject: (project_id, orcid_or_email, privilegeLevel, callback) ->
		orcid = is_orcid orcid_or_email
		if orcid
			@addUserToProjectByOrcid project_id, orcid, privilegeLevel, callback
		else
			@addUserToProjectByEmail project_id, orcid_or_email, privilegeLevel, callback

	addUserToProjectByOrcid: (project_id, orcid, privilegeLevel, callback) ->
		return (callback new Error "no valid orcid provided") if !orcid?
		User.findOne {'orcid':orcid}, (err, user)->
			async.waterfall [
				(cb)->
					if user?
						cb null, user
					else
						createHoldingAccount orcid, null, cb
				(@user, cb) =>
					updateProjectWithUserPrivileges project_id, user, privilegeLevel, cb
				(cb) =>
					if @user.email?
						notifyUserViaEmail project_id, @user.email, cb
			], (err) =>
				callback(err, @user)

	addEmailToProject: (project_id, adding_user_id, unparsed_email, privilegeLevel, callback = (error, user) ->) ->
		emails = mimelib.parseAddresses(unparsed_email)
		email = emails[0]?.address?.toLowerCase()
		if !email? or email == ""
			return callback(new Error("no valid email provided: '#{unparsed_email}'"))
		UserCreator.getUserOrCreateHoldingAccount email, (error, user) ->
			return callback(error) if error?
			CollaboratorsHandler.addUserIdToProject project_id, adding_user_id, user._id, privilegeLevel, (error) ->
				return callback(error) if error?
				return callback null, user._id

	addUserIdToProject: (project_id, adding_user_id, user_id, privilegeLevel, callback = (error) ->)->
		Project.findOne { _id: project_id }, { collaberator_refs: 1, readOnly_refs: 1 }, (error, project) ->
			return callback(error) if error?
			existing_users = (project.collaberator_refs or [])
			existing_users = existing_users.concat(project.readOnly_refs or [])
			existing_users = existing_users.map (u) -> u.toString()
			if existing_users.indexOf(user_id.toString()) > -1
				return callback null # User already in Project

			if privilegeLevel == 'readAndWrite'
				level = {"collaberator_refs":user_id}
				logger.log {privileges: "readAndWrite", user_id, project_id}, "adding user"
			else if privilegeLevel == 'readOnly'
				level = {"readOnly_refs":user_id}
				logger.log {privileges: "readOnly", user_id, project_id}, "adding user"
			else
				return callback(new Error("unknown privilegeLevel: #{privilegeLevel}"))

			# Do these in the background
			UserGetter.getUser user_id, {email: 1}, (error, user) ->
				if error?
					logger.error {err: error, project_id, user_id}, "error getting user while adding to project"
				CollaboratorsEmailHandler.notifyUserOfProjectShare project_id, user.email
			ContactManager.addContact adding_user_id, user_id

			Project.update { _id: project_id }, { $addToSet: level }, (error) ->
				return callback(error) if error?
				# Flush to TPDS in background to add files to collaborator's Dropbox
				ProjectEntityHandler.flushProjectToThirdPartyDataStore project_id, (error) ->
					if error?
						logger.error {err: error, project_id, user_id}, "error flushing to TPDS after adding collaborator"
				callback()

	addUserToProjectByEmail: (project_id, email, privilegeLevel, callback)->
		emails = mimelib.parseAddresses(email)
		email = emails[0]?.address?.toLowerCase()
		return callback(new Error("no valid email provided")) if !email?
		User.findOne {'email':email}, (err, user)->
			async.waterfall [
				(cb)->
					if user?
						return cb(null, user)
					else
						createHoldingAccount null, email, cb
				(@user, cb)=>
					updateProjectWithUserPrivileges project_id, user, privilegeLevel, cb
				(cb)->
					notifyUserViaEmail project_id, email, cb
			], (err)=>
				callback(err, @user)
