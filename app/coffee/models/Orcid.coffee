mongoose = require('mongoose')
Settings = require 'settings-sharelatex'

Schema = mongoose.Schema


OrcidSchema = new Schema
  orcid      : {type:String}
  description: {type:String}

conn = mongoose.createConnection(Settings.mongo.url, server: poolSize: Settings.mongo.poolSize || 10)

Orcid = conn.model 'Orcid', OrcidSchema
mongoose.model 'Orcid', OrcidSchema

exports.Orcid = Orcid
exports.OrcidSchema = OrcidSchema
