define [
  "ace/ace",
  "ide/object-display/index"
], () ->
  # console.log "ObjectDisplayManager load"
  TokenIterator = ace.require("ace/token_iterator").TokenIterator
  Range = ace.require("ace/range").Range

  isObject = (token) ->
    token?.type == "storage.type" and token?.value == "\\object"
  islParen = (token) ->
    token?.type == "lparen"
  isrParen = (token) ->
    token?.type == "rparen"

  class ObjectDisplayManager
    constructor: (@scope, @editor, @element) ->
      # console.log "ObjectDisplayManager construct"

      @objects = []

      onChange = (event) =>
        objects = []
        iterator = new TokenIterator @editor.session, 0, 0
        while token = iterator.getCurrentToken()
          if isObject token
            lparen = iterator.stepForward()
            if !lparen or !islParen lparen
              continue
            content = iterator.stepForward()
            if !content
              continue
            start_row = iterator.getCurrentTokenRow()
            start_column = iterator.getCurrentTokenColumn()
            rparen = iterator.stepForward()
            if !rparen or !isrParen rparen
              continue
            end_row = iterator.getCurrentTokenRow()
            end_column = iterator.getCurrentTokenColumn()
            objects.push
              value: content.value
              range: new Range start_row, start_column, end_row, end_column
          else
            iterator.stepForward()
        @updateObjects objects

      onMouseMove = (e) =>
        position = @editor.renderer.screenToTextCoordinates e.clientX, e.clientY
        for object in @objects
          if object.range.contains position.row, position.column
            return @showObjectLabel object
        @clearObjectLabel()

      @editor.on "change", onChange
      @editor.on "mousemove", onMouseMove

      onFirstInitialize = (event) =>
        ace = $(@editor.renderer.container).find ".ace_scroller"
        # Move the label into the Ace content area so that offsets and positions are easy to calculate.
        ace.append @element.find(".cdsDisplayObjectOverlay")
        @editor.off "changeSession", onFirstInitialize
      @editor.on "changeSession", onFirstInitialize

    showObjectLabel: (object) ->
      position = object.range.start
      # Heavily borrowed from HighlightsManager, should probably generalize this

      ace = $(@editor.renderer.container).find ".ace_scroller"
      offset = ace.offset()
      # height = ace.height()
      coordinates = @editor.renderer.textToScreenCoordinates position.row, position.column
      coordinates.pageX = coordinates.pageX - offset.left
      coordinates.pageY = coordinates.pageY - offset.top

      top    = coordinates.pageY + @editor.renderer.lineHeight
      bottom = "auto"

      @scope.$broadcast "cdsObjectDisplayUpdate",
        object: object
        top: top
        bottom: bottom
        left: coordinates.pageX
        right: "auto"

    clearObjectLabel: () ->
      @scope.$broadcast "cdsObjectDisplayUpdate"

    updateObjects: (objects) ->
      objectMissingInArray = (object, array) ->
        for element in array
          if element.value == object.value and element.range.compareRange(object.range) == 0
            return false
        true
      session = @editor.getSession()
      index = 0
      while index < @objects.length
        object = @objects[index]
        if objectMissingInArray object, objects
          console.log "Removing object", object.value
          session.removeMarker object.marker_id
          @objects.splice index, 1
        else
          index += 1
      for object in objects
        if objectMissingInArray object, @objects
          console.log "Adding object", object.value
          object.marker_id = session.addMarker object.range, "annotation object-display", "test", true
          @objects.push object
      return