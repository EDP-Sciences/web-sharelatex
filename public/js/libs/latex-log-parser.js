define(function() {
    // Define some constants
    var LOG_WRAP_LIMIT = 79;

    // Mono or multiline " standard " LaTeX messages (how they should be...).
    // May contains \MessageBreak to multiline messages
    // see http://tug.ctan.org/tex-archive/macros/latex/base/lterror.dtx
    // * First array element is regex for the 1st msg line:
    // 1st () catches the emitter (pkg, class or LaTeX core)
    // 2nd () catches the level (warning or error)
    // 3rd () catches the message
    // * 2nd array element is regex for the continuation lines
    // This is an ordered list: first in the list is first considered
    var LATEX_MSG_REGEXES = [
        // this first one doesn't used \MessageBreak for line break, so it's a bit different
        [/^(LaTeX) (Warning): (Unused global option\(s\):)$/,/^\s{4}(.*)$/],
        [/^(LaTeX) (Warning): (.*)$/,/^\s{15}(.*)$/],
        [/^(Font) (Warning): (.*)$/ ,/^\s{8}(.*)$/],
        [/^(Class \S+) (Warning): (.*)$/,/^\(\S+\)\s{13}(.*)$/ ],
        [/^(Package \S+) (Warning): (.*)$/,/^\(\S+\)\s{16}(.*)$/ ],
        [/^\! (LaTeX) (Error): (.*)$/, /^\s{15}(.*)$/],
        [/^\! (Class \S+) (Error): (.*)$/,/^\(\S+\)\s{13}(.*)$/ ],
        [/^\! (Package \S+) (Error): (.*)$/,/^\(\S+\)\s{16}(.*)$/ ],
    ]
    // box warnings
    var HBOX_WARNING_REGEX = /^(Over|Under)full \\(v|h)box/;
    // TeX error message always begin with '! ' and end with the line error
    var TEX_ERROR_REGEX = /^\!\s(.*)$/;
    
    // This is used to parse the line number from common latex warnings and box warnings
    var LINES_WARNING_REGEX = /lines? ([0-9]+)/;
    // This is used to parse the line number from common latex error
    var LINES_ERROR_REGEX = /^l.([0-9]+)\s/;

    var LogText = function(text) {
        this.text = text.replace(/(\r\n)|\r/g, "\n");
        // Join any lines which look like they have wrapped.
        var wrappedLines = this.text.split("\n");
        this.lines = [wrappedLines[0]];
        for (var i = 1; i < wrappedLines.length; i++) {
            // If the previous line is as long as the wrap limit then 
            // append this line to it.
            // Some lines end with ... when LaTeX knows it's hit the limit
            // These shouldn't be wrapped.
            if (wrappedLines[i-1].length == LOG_WRAP_LIMIT && wrappedLines[i-1].slice(-3) != "...") {
                this.lines[this.lines.length - 1] += wrappedLines[i];
            } else {
                this.lines.push(wrappedLines[i]);
            }
        }

        this.row = 0;
    };

    (function() {
        this.nextLine = function() {
            this.row++;
            if (this.row >= this.lines.length) {
                return false;
            } else {
                return this.lines[this.row];
            }
        };

        this.rewindLine = function() {
            this.row--;
        };

        this.linesUpToNextWhitespaceLine = function() {
            return this.linesUpToNextMatchingLine(/^ *$/);
        };

        this.linesUpToNextMatchingLine = function(match) {
            var limit = 100;
            var lines = [];
            var nextLine = this.nextLine();
            if (nextLine !== false) {
                lines.push(nextLine);
            }
            var i = 1;
            while (nextLine !== false && !nextLine.match(match) && i <= limit) {
                nextLine = this.nextLine();
                if (nextLine !== false) {
                    lines.push(nextLine);
                }
            }
            return lines;
        }

        this.linesUntilLineMatch = function(regex) {
            var lines = [];
            var nextLine = '';
            while (nextLine = this.nextLine()) {
                var match = null;
                if (match = nextLine.match(regex)) {
                    lines.push(match[1]);
                }
            }
            this.rewindLine;
            return lines;
        }
        
    }).call(LogText.prototype);

    var LatexParser = function(text, options) {
        this.log = new LogText(text);

        options = options || {};
        this.fileBaseNames = options.fileBaseNames || [/compiles/, /\/usr\/local/];
        this.ignoreDuplicates  = options.ignoreDuplicates;
        this.newOutput  = options.newOutput;
        
        this.data  = [];
        this.fileStack = [];
        this.currentFileList = this.rootFileList = [];
        
        this.openParens = 0;
    };

    (function() {
        this.parse = function() {
            while ((this.currentLine = this.log.nextLine()) !== false) {
                this.parseLaTeXMsg()
                    || this.parseTeXError()
                    || this.parseVHbox()
                    || this.parseParensForFilenames()
            }
            return this.postProcess(this.data);
        }


        // Catch LaTeX warning messages, output using \@latex@warning[@no@line]
        // or \PackageWarning[NoLine] or \ClassWarning[NoLine] or \@font@warning
        // Catch LaTeX error messages, output using \@latex@error
        // or \PackageError or \ClassError,
        // and using \MessageBreak for line break.        
        this.parseLaTeXMsg = function() {
            for (var i = 0 ; i < LATEX_MSG_REGEXES.length ; i++){
                var reg_1st  = LATEX_MSG_REGEXES[i][0];
                var matches = [];
                if (matches = this.currentLine.match(reg_1st)) {
                    var emitter = matches[1];
                    var level   = matches[2];
                    var msg     = matches[3];
                    if (! this.newOutput && level == 'Error') {
                        msg = emitter + ' ' + level + ': ' + msg;
                    } else {
                        msg = matches[3];
                    }
                    var reg_cont = LATEX_MSG_REGEXES[i][1];
                    var follow =  this.log.linesUntilLineMatch(reg_cont).join(" ");
                    if (follow)
                        msg += " " + follow;
                    var raw = matches[0] + " " + follow;
                    var line = null;
                    if (level === 'Warning') {
                        var matchline = msg.match(LINES_WARNING_REGEX);
                        line =  matchline ? parseInt(matchline[1], 10) : null;
                    } else if (level === 'Error'){
                        emsg = this._getErrMsg('latex');
                        raw += " " + emsg;
                        line = emsg[0];
                    }
                    this.data.push({
                        line    : line,
                        file    : this.currentFilePath,
                        level   : level.toLowerCase(),
                        emitter : emitter,
                        message : msg,
                        raw     : raw
                    });
                    return true;
                }
            }
            return false;
        }
       
        // Catch what can be a TeX error
        // e.g. a line begining with '! '
        this.parseTeXError = function() {
            var matches = null;
            if (matches = this.currentLine.match(TEX_ERROR_REGEX)) {
                var msg = matches[1];
                var emitter = 'TeX';
                var level   = 'error';
                var emsg = this._getErrMsg('tex');
                var raw = msg + "\n" + emsg[1];
                    this.data.push({
                        line    : emsg[0],
                        file    : this.currentFilePath,
                        level   : 'error',
                        emitter : emitter,
                        message : msg,
                        raw     : raw
                    });
                return true;
            }
            return false;
        }

        // (Under|Over) full (h|v)box 
        this.parseVHbox = function() {
            if (this.currentLine.match(HBOX_WARNING_REGEX)) {
                var matchline = this.currentLine.match(LINES_WARNING_REGEX);
                var line = matchline ? parseInt(matchline[1], 10) : null;
                
                this.data.push({
                    line    : line,
                    file    : this.currentFilePath,
                    level   : "typesetting",
                    emitter : 'latex',
                    message : this.currentLine,
                    raw     : this.currentLine
                });
                return true;
            }
            return false;
        };

        // Check if we're entering or leaving a new file in this line
        this.parseParensForFilenames = function() {
            var pos = this.currentLine.search(/\(|\)/);
            if (pos != -1) {
                var token = this.currentLine[pos];
                this.currentLine = this.currentLine.slice(pos + 1);
                if (token == "(") {
                    var filePath = this.consumeFilePath();
                    if (filePath) {
                        this.currentFilePath = filePath;
                        var newFile = {
                            path : filePath,
                            files : []
                        };
                        this.fileStack.push(newFile);
                        this.currentFileList.push(newFile);
                        this.currentFileList = newFile.files;
                    } else {
                        this.openParens++;
                    }
                } else if (token == ")") {
                    if (this.openParens > 0) {
                        this.openParens--;
                    } else {
                        if (this.fileStack.length > 1) {
                            this.fileStack.pop();
                            var previousFile = this.fileStack[this.fileStack.length - 1];
                            this.currentFilePath = previousFile.path;
                            this.currentFileList = previousFile.files;
                        }
                        // else {
                        //     Something has gone wrong but all we can do now is ignore it :(
                        // }
                    }
                }
                
                // Process the rest of the line
                this.parseParensForFilenames();
            }
        }
        
        // return the msg until line error is found
        // [line_no,msg]
        this._getErrMsg = function(type) {
            lines = this.log.linesUpToNextMatchingLine(LINES_ERROR_REGEX);
            matchline = lines[lines.length-1].match(LINES_ERROR_REGEX);
            var l = null;
            if (matchline){
                l = matchline[1];
            }
            var msg = lines.join("\n")
                + "\n"
                + this.log.linesUpToNextWhitespaceLine().join("\n");
            if (type === 'latex'){
                msg +=  "\n"
                    + this.log.linesUpToNextWhitespaceLine().join("\n");
            }
            return  [l,msg];
        }

        this.consumeFilePath = function() {
            // Our heuristic for detecting file names are rather crude
            // A file may not contain a space, or ) in it
            // To be a file path it must have at least one /
            if (!this.currentLine.match(/^\/?([^ \)]+\/)+/)) {
                return false;
            }

            var endOfFilePath = this.currentLine.search(/ |\)/);
            var path;
            if (endOfFilePath == -1) {
                path = this.currentLine;
                this.currentLine = "";
            } else {
                path = this.currentLine.slice(0, endOfFilePath);
                this.currentLine = this.currentLine.slice(endOfFilePath);
            }

            return path;
        };

        this.postProcess = function(data) {
            var all          = [];
            var errors       = [];
            var warnings     = [];
            var typesetting  = [];
            var missingfiles = [];

            var hashes = [];

            function hashEntry(entry) {
                return entry.raw;
            }

            for (var i = 0; i < data.length; i++) {
                if (this.ignoreDuplicates && hashes.indexOf(hashEntry(data[i])) > -1) {
                    continue;
                }

                if (data[i].level == "error") {
                    errors.push(data[i]);
                } else if (data[i].level == "typesetting") {
                    typesetting.push(data[i]);
                } else if (data[i].level == "warning") {
                    warnings.push(data[i]);
                } 
                all.push(data[i]);
                hashes.push(hashEntry(data[i]));
            }
            return {
              errors      : errors,
              warnings    : warnings,
              typesetting : typesetting,
              all         : all,
              files       : this.rootFileList
            }
        }
    }).call(LatexParser.prototype);

    LatexParser.parse = function(text, options) {
        return (new LatexParser(text, options)).parse()
    };

    return LatexParser;
});
