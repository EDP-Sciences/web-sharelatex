logger = require("logger-sharelatex")
mongojs = require("../../infrastructure/mongojs")
db = mongojs.db
ObjectId = mongojs.ObjectId
UserLocator = require("./UserLocator")
async = require "async"

module.exports = UserUpdater =
	updateUser: (query, update, callback = (error) ->) ->
		if typeof query == "string"
			query = _id: ObjectId(query)
		else if query instanceof ObjectId
			query = _id: query

		db.users.update query, update, callback

	_mergeHoldingAccount: (user_id, holding_user, callback) ->
		async.series [
			(cb) ->
				db.projects.update
					collaberator_refs: $elemMatch: $eq: holding_user._id
				, $push: collaberator_refs: user_id
				, cb
			(cb) ->
				db.projects.update
					collaberator_refs: $elemMatch: $eq: holding_user._id
				, $pull: collaberator_refs: holding_user._id
				, cb
			(cb) ->
				db.projects.update
					readOnly_refs: $elemMatch: $eq: holding_user._id
				, $push: readOnly_refs: user_id
				, cb
			(cb) ->
				db.projects.update
					readOnly_refs: $elemMatch: $eq: holding_user._id
				, $pull: readOnly_refs: holding_user._id
				, cb
			(cb) ->
				holding_user.remove cb
			(cb) ->
				db.users.update
					_id: user_id
				, $set: email: holding_user.email
				, cb
		], (err) ->
			if err?
				logger.err err:err, "something went wrong merging holding account"
			callback err

	changeEmailAddress: (user_id, newEmail, callback)->
		logger.log user_id:user_id, newEmail:newEmail, "updaing email address of user"
		UserLocator.findByEmail newEmail, (error, user) ->
			if user? and not user.holdingAccount
				return callback({message:"alread_exists"})
			if user?
				UserUpdater._mergeHoldingAccount user_id, user, callback
			else
				UserUpdater.updateUser user_id.toString(), {
					$set: { "email": newEmail},
				}, (err) ->
					if err?
						logger.err err:err, "problem updating users email"
						return callback(err)
					callback()

