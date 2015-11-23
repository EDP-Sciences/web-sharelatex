UserCreator = require('../User/UserCreator')
Project = require("../../models/Project").Project
ProjectEntityHandler = require("../Project/ProjectEntityHandler")
mimelib = require("mimelib")
logger = require('logger-sharelatex')
UserGetter = require "../User/UserGetter"
ContactManager = require "../Contacts/ContactManager"
CollaboratorsEmailHandler = require "./CollaboratorsEmailHandler"

orcid_regexp = /^(?:(?:http:\/\/)?orcid\.org\/)?(\d{4}\-\d{4}\-\d{4}\-\d\d\d[\dx])$/i

is_orcid = (orcid_or_email) ->
	logger.log 'is_orcid', orcid_or_email, orcid_regexp.test orcid_or_email
	result = orcid_regexp.exec orcid_or_email
	result[1] if result?

module.exports = CollaboratorsHandler =
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

	addOrcidToProject: (project_id, adding_user_id, orcid, privilegeLevel, callback = (error, user) ->) ->
		UserCreator.getUserOrCreateHoldingAccount email, (error, user) ->
			return callback(error) if error?
			CollaboratorsHandler.addUserIdToProject project_id, adding_user_id, user._id, privilegeLevel, (error) ->
				return callback(error) if error?
				return callback null, user._id

	addEmailOrOrcidToProject: (project_id, adding_user_id, email_or_orcid, privilegeLevel, callback = (error, user) ->) ->
		orcid = is_orcid email_or_orcid
		if orcid?
			CollaboratorsHandler.addOrcidToProject project_id, adding_user_id, orcid, privilegeLevel, callback
		else
			CollaboratorsHandler.addEmailToProject project_id, adding_user_id, orcid, privilegeLevel, callback

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
				CollaboratorsEmailHandler.notifyUserOfProjectShare project_id, user.email if user.email?
			ContactManager.addContact adding_user_id, user_id

			Project.update { _id: project_id }, { $addToSet: level }, (error) ->
				return callback(error) if error?
				# Flush to TPDS in background to add files to collaborator's Dropbox
				ProjectEntityHandler.flushProjectToThirdPartyDataStore project_id, (error) ->
					if error?
						logger.error {err: error, project_id, user_id}, "error flushing to TPDS after adding collaborator"
				callback()
