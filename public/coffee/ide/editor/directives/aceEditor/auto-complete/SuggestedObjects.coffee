define [], () ->
  class SuggestedObjectsManager
    constructor: (@$http) ->
    parseObjectDeclaration: (prefix) ->
      # if starts with \object
      # parse optionals and return everything after the first {
      match = /(\\object[^{]*\{)(\w+)/.exec prefix
      if match
        prefix: match[1]
        object: match[2]

    getSuggestions: (declaration, callback = (err, results) ->) ->
      # query CDS and generates a list based on that
      @$http.get 'http://simbad.u-strasbg.fr/tools/suggestNames/search?', params: {kw: declaration.object}
      .success (response) ->
        results = []
        response.data.forEach (item) ->
          results.push
            meta: "#{item.nbRef} refs"
            value: "#{declaration.prefix}#{item.objName}}"
            score: item.nbRef
        callback null, results
      .error (err) ->
        callback err, null

    getCompletions: (editor, session, pos, prefix, callback = (err, results) ->) ->
      declaration = @parseObjectDeclaration prefix
      if not declaration
        return callback null, []
      @getSuggestions declaration, (err, results) ->
        callback err, results

