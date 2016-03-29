define [
	"ide/editor/directives/aceEditor/auto-complete/SuggestionManager"
	"ide/editor/directives/aceEditor/auto-complete/SnippetManager"
	"ace/ace"
	"ace/ext-language_tools"
], (SuggestionManager, SnippetManager) ->
	Range = ace.require("ace/range").Range

	getLastCommandFragment = (lineUpToCursor) ->
		if m = lineUpToCursor.match(/(\\[^\\ ]+)$/)
			return m[1]
		else
			return null

	class AutoCompleteManager
		constructor: (@$scope, @editor) ->
			@suggestionManager = new SuggestionManager()

			@monkeyPatchAutocomplete()

			@$scope.$watch "autoComplete", (autocomplete) =>
				if autocomplete
					@enable()
				else
					@disable()

			onChange = (change) =>
				@onChange(change)

			@editor.on "changeSession", (e) =>
				e.oldSession.off "change", onChange
				e.session.on "change", onChange

		enable: () ->
			@editor.setOptions({
				enableBasicAutocompletion: true,
				enableSnippets: true,
				enableLiveAutocompletion: false
			})

			SnippetCompleter = new SnippetManager()

			references = @$scope.$root._references
			ReferencesCompleter =
				getCompletions: (editor, session, pos, prefix, callback) ->
					upToCursorRange = new Range(pos.row, 0, pos.row, pos.column)
					lineUpToCursor = editor.getSession().getTextRange(upToCursorRange)
					commandFragment = getLastCommandFragment(lineUpToCursor)
					if commandFragment
						citeMatch = commandFragment.match(/^~?\\([a-z]*cite[a-z]?){([^}]*,)?(\w*)/)
						if citeMatch
							beyondCursorRange = new Range(pos.row, pos.column, pos.row, 99999)
							lineBeyondCursor = editor.getSession().getTextRange(beyondCursorRange)
							needsClosingBrace = !lineBeyondCursor.match(/^[^{]*}/)
							commandName = citeMatch[1]
							previousArgs = citeMatch[2]
							currentArg = citeMatch[3]
							if previousArgs == undefined
								previousArgs = ""
							previousArgsCaption = if previousArgs.length > 8 then "…," else previousArgs
							result = []
							result.push {
								caption: "\\#{commandName}{}",
								snippet: "\\#{commandName}{}",
								meta: "reference",
								score: 11000
							}
							if references.keys and references.keys.length > 0
								references.keys.forEach (key) ->
									if !(key in [null, undefined])
										result.push({
											caption: "\\#{commandName}{#{previousArgsCaption}#{key}#{if needsClosingBrace then '}' else ''}",
											value: "\\#{commandName}{#{previousArgs}#{key}#{if needsClosingBrace then '}' else ''}",
											meta: "reference",
											score: 10000
										})
								callback null, result
							else
								callback null, result

			@editor.completers = [@suggestionManager, SnippetCompleter, ReferencesCompleter]

		disable: () ->
			@editor.setOptions({
				enableBasicAutocompletion: false,
				enableSnippets: false
			})

		onChange: (change) ->
			cursorPosition = @editor.getCursorPosition()
			end = change.end
			# Check that this change was made by us, not a collaborator
			# (Cursor is still one place behind)
			if end.row == cursorPosition.row and end.column == cursorPosition.column + 1
				if change.action == "insert"
					range = new Range(end.row, 0, end.row, end.column)
					lineUpToCursor = @editor.getSession().getTextRange(range)
					commandFragment = getLastCommandFragment(lineUpToCursor)

					if commandFragment? and commandFragment.length > 2
						setTimeout () =>
							@editor.execCommand("startAutocomplete")
						, 0

		monkeyPatchAutocomplete: () ->
			Autocomplete = ace.require("ace/autocomplete").Autocomplete
			Util = ace.require("ace/autocomplete/util")
			editor = @editor

			if !Autocomplete::_insertMatch?
				# Only override this once since it's global but we may create multiple
				# autocomplete handlers
				Autocomplete::_insertMatch = Autocomplete::insertMatch
				Autocomplete::insertMatch = (data) ->
					pos = editor.getCursorPosition()
					range = new Range(pos.row, pos.column, pos.row, pos.column + 1)
					nextChar = editor.session.getTextRange(range)

					# If we are in \begin{it|}, then we need to remove the trailing }
					# since it will be adding in with the autocomplete of \begin{item}...
					if this.completions.filterText.match(/^\\begin\{/) and nextChar == "}"
						editor.session.remove(range)

					Autocomplete::_insertMatch.call this, data

				# Overwrite this to set autoInsert = false and set font size
				Autocomplete.startCommand = {
					name: "startAutocomplete",
					exec: (editor) =>
						if (!editor.completer)
							editor.completer = new Autocomplete()
						editor.completer.autoInsert = false
						editor.completer.autoSelect = true
						editor.completer.showPopup(editor)
						editor.completer.cancelContextMenu()
						$(editor.completer.popup?.container).css({'font-size': @$scope.fontSize + 'px'})
					bindKey: "Ctrl-Space|Ctrl-Shift-Space|Alt-Space"
				}

			Util.retrievePrecedingIdentifier = (text, pos, regex) ->
				currentLineOffset = 0
				for i in [(pos-1)..0]
					if text[i] == "\n"
						currentLineOffset = i + 1
						break
				currentLine = text.slice(currentLineOffset, pos)
				fragment = getLastCommandFragment(currentLine) or ""
				return fragment
