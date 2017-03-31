ace.define("ace/mode/bibtex_highlight_rules",
    ["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],
    function(require, exports, module) {
    "use strict";

    var oop = require("../lib/oop");
    var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;

    var BibtexHighlightRules = function() {

        this.$rules = {
            "start" : [{
                token : ["storage.type", "text", "lparen"],
                regex : /(@(?:string))(\s*)({)/,
                next : "value-list"
            }, {
                token : ["storage.type", "text", "lparen", "comment", "rparen"],
                regex : /(@(?:comment))(\s*)({)(.*)(})/,
                next : "start"
            }, {
                token : ["storage.type", "text", "lparen", "text", "keyword"],
                regex: /(@(?:\w+))(\s*)({)(\s*)(\w[\w+:\-.&]*)/,
                next: "value-end"
            }],
            "value-list" : [{
                token : ["keyword", "text", "constant.character.equal"],
                regex : /(\w[\w+-]*)(\s*)(=)/,
                next: "value"
            }, {
                token : ["keyword", "text", "constant.character.equal"],
                regex : /(\w+)(\s*)(=)/,
                next: "value"
            }, {
                token : "rparen",
                regex : /}/,
                next: "start"
            }],
            "value": [{
                token: "string",
                regex: /"(?:[^"]*)"/,
                next: "value-end"
            },{
                token: "paren.lparen",
                regex: /{/,
                next: "sub-value"
            },{
                token: "string",
                regex: /\d+/,
                next: "value-end"
            },{
                token: "string.error",
                regex: /\w+/,
                next: "value-end"
            }],
            "sub-value": [{
                token: "lparen",
                regex: /{/,
                next: "sub-sub-value"
            },{
                token: "rparen",
                regex: /}/,
                next: "value-end"
            }],
            "sub-sub-value": [{
                token: "rparen",
                regex: /}/,
                next: "sub-value"
            }],
            "value-end" : [{
                token : "constant.character.colon",
                regex: /,/,
                next: "value-list"
            }, {
                token: "rparen",
                regex: /}/,
                next: "start"
            }, {
                token: "constant.character.hash",
                regex: /#/,
                next: "value"
            }]
        };
    };
    oop.inherits(BibtexHighlightRules, TextHighlightRules);

    exports.BibtexHighlightRules = BibtexHighlightRules;

});

ace.define("ace/mode/bibtex",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/bibtex_highlight_rules"],
    function(require, exports, module) {
    "use strict";

    var oop = require("../lib/oop");
    var TextMode = require("./text").Mode;
    var BibtexHighlightRules = require("./bibtex_highlight_rules").BibtexHighlightRules;

    var Mode = function() {
        this.HighlightRules = BibtexHighlightRules;
    };
    oop.inherits(Mode, TextMode);

    (function() {
        this.type = "text";

        this.$id = "ace/mode/bibtex";
    }).call(Mode.prototype);

    exports.Mode = Mode;

});
