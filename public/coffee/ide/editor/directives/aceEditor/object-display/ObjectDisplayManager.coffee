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


      onFirstInitialize = (event) =>
        ace = $(@editor.renderer.container).find ".ace_scroller"
        # Move the label into the Ace content area so that offsets and positions are easy to calculate.
        ace.append @element.find(".cdsDisplayObjectOverlay")
        @editor.off "changeSession", onFirstInitialize
      @editor.on "changeSession", onFirstInitialize

      scope.cds = open: false
      scope.$watch "objectDisplay", (value) =>
        if value == "true" then @enable() else @disable()

    onChange: (event) =>
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
          value = content.value
          start_row = iterator.getCurrentTokenRow()
          start_column = iterator.getCurrentTokenColumn()
          rparen = iterator.stepForward()
          if !rparen or !isrParen rparen
            continue
          if lparen.value == "{[" and rparen.value == "]"
            start_column -= 1
            content = iterator.stepForward()  # Skip it and the following token (probably) }
            if !content
              continue
            value = '[' + value + ']' + content.value
            rparen = iterator.stepForward()
            if !rparen or !isrParen rparen
              continue
          end_row = iterator.getCurrentTokenRow()
          end_column = iterator.getCurrentTokenColumn()
          objects.push
            value: value
            range: new Range start_row, start_column, end_row, end_column
        else
          iterator.stepForward()
      @updateObjects objects

    onTokenizerUpdate: (event) =>
      @onChange event

    onChangeMode: () =>
      mode = @editor.session.getMode()
      if mode.$id == "ace/mode/latex"
        @editor.on "change", @onChange
        @editor.session.on "tokenizerUpdate", @onTokenizerUpdate
        @onChange()
      else
        @editor.off "change", @onChange
        @editor.session.off "tokenizerUpdate", @onTokenizerUpdate
        @clearObjectLabel()
        @updateObjects []

    onChangeSession: (event) =>
      event.oldSession.off "changeMode", @onChangeMode
      event.session.on "changeMode", @onChangeMode
      @onChangeMode()

    onMouseMove: (event) =>
      position = @editor.renderer.screenToTextCoordinates event.clientX, event.clientY
      for object in @objects
        if object.range.contains position.row, position.column
          return @showObjectLabel object
      @clearObjectLabel()

    enable: () =>
      @editor.on "changeSession", @onChangeSession
      @editor.on "mousemove", @onMouseMove
      @editor.session?.on "tokenizerUpdate", @onTokenizerUpdate
      @editor.on "change", @onChange
      @onTokenizerUpdate()

    disable: () =>
      @editor.off "changeSession", @onChangeSession
      @editor.off "mousemove", @onMouseMove
      @editor.session?.off "tokenizerUpdate", @onTokenizerUpdate
      @editor.off "change", @onChange
      @clearObjectLabel()
      @updateObjects []

    getPosition: (position) ->
      # Heavily borrowed from HighlightsManager, should probably generalize this
      ace = $(@editor.renderer.container).find ".ace_scroller"
      offset = ace.offset()
      # height = ace.height()
      coordinates = @editor.renderer.textToScreenCoordinates position.row, position.column
      coordinates.pageX = coordinates.pageX - offset.left
      coordinates.pageY = coordinates.pageY - offset.top

      top: coordinates.pageY + @editor.renderer.lineHeight
      bottom: "auto"
      left: coordinates.pageX
      right: "auto"

    showObjectLabel: (object) ->
      pos = @getPosition object.range.start
      scope = @scope
      scope.$apply () ->
        scope.cds.value = object
        scope.cds.top = pos.top
        scope.cds.bottom = pos.bottom
        scope.cds.left = pos.left
        scope.cds.right = pos.right

    clearObjectLabel: () ->
      scope = @scope
      scope.$apply () ->
        scope.cds.value = null

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
