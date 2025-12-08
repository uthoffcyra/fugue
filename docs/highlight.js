// syntax highlighter

const tokenSpecs = [
    ['COMMENT', /~[^~]*~/g],
    ['VAR_DECL', /\blet\b/g],
    ['FN_DECL', /\bfn\b/g],
    ['FN_RETURN', /\bres\b/g],
    ['LOAD', /\bload\b/g],
    ['IF', /\bif\b/g],
    ['EVENT_LOOP', /\bevent-loop\b/g],
    ['AS', /\bas\b/g],
    ['EQU', /==/g],
    ['LEQ', /<=/g],
    ['NEQ', /!=/g],
    ['GEQ', />=/g],
    ['PLUS', /\+/g],
    ['MINUS', /-/g],
    ['MUL', /\*/g],
    ['DIV', /\//g],
    ['CONCAT', /\.\./g],
    ['LCURLY', /\{/g],
    ['RCURLY', /\}/g],
    ['LPAREN', /\(/g],
    ['RPAREN', /\)/g],
    ['COMMA', /,/g],
    ['COLON', /:/g],
    ['SEMI', /;/g],
    ['ASSIGN', /=/g],
    ['SPECIAL', /@[a-zA-Z_][a-zA-Z0-9_]*/g],
    ['NOT', /!/g],
    ['NONE', /\bnone\b/g],
    ['TRUE', /\btrue\b/g],
    ['FALSE', /\bfalse\b/g],
    ['NAME', /\b[a-zA-Z_][a-zA-Z0-9_]*\b/g],
    ['STRING', /"[^"]*"/g],
    ['STRING', /'[^']*'/g],
    ['INTEGER', /\d+/g],
];

const colors = {
    keyword: '#c586c0',      // Purple - for language keywords
    string: '#ce9178',       // Orange - for string literals
    number: '#b5cea8',       // Light green - for numbers
    comment: '#6a9955',      // Green - for comments
    constant: '#569cd6',     // Blue - for true/false/none
    identifier: '#9cdcfe',   // Light blue - for variable names
    operator: '#d4d4d4',     // Gray - for operators
    brace: '#ffd700',        // Gold - for curly braces
    special: '#4ec9b0',      // Teal - for special variables
    punctuation: '#d4d4d4',  // Gray - for commas, semicolons, etc.
};
const colorMap = {
    // Comments
    COMMENT: colors.comment,
    
    // Keywords
    VAR_DECL: colors.keyword,
    FN_DECL: colors.keyword,
    FN_RETURN: colors.keyword,
    LOAD: colors.keyword,
    IF: colors.keyword,
    EVENT_LOOP: colors.keyword,
    AS: colors.keyword,
    
    // Operators
    EQU: colors.operator,
    LEQ: colors.operator,
    NEQ: colors.operator,
    GEQ: colors.operator,
    PLUS: colors.operator,
    MINUS: colors.operator,
    MUL: colors.operator,
    DIV: colors.operator,
    CONCAT: colors.operator,
    ASSIGN: colors.operator,
    NOT: colors.operator,
    
    // Braces
    LCURLY: colors.brace,
    RCURLY: colors.brace,
    
    // Punctuation
    LPAREN: colors.punctuation,
    RPAREN: colors.punctuation,
    COMMA: colors.punctuation,
    COLON: colors.punctuation,
    SEMI: colors.punctuation,
    
    // Special
    SPECIAL: colors.special,
    
    // Constants
    NONE: colors.constant,
    TRUE: colors.constant,
    FALSE: colors.constant,
    
    // Identifiers and literals
    NAME: colors.identifier,
    STRING: colors.string,
    INTEGER: colors.number,
};

const tokenize = (text) => {
    const tokens = [];
    let pos = 0;

    while (pos < text.length) {
        let matched = false;

        for (const [type, pattern] of tokenSpecs) {
            const regex = new RegExp(pattern.source, 'y');
            regex.lastIndex = pos;
            const match = regex.exec(text);

            if (match) {
                tokens.push({ type, value: match[0], start: pos });
                pos = regex.lastIndex;
                matched = true;
                break;
            }
        }

        if (!matched) {
            tokens.push({ type: 'DEFAULT', value: text[pos], start: pos });
            pos++;
        }
    }

    return tokens;
};

function highlight(text) {
    let result = '';
    let tokens = tokenize(text);

    tokens.forEach((t)=>{
        if (t.value == '\n') {
            result += '<br>';
        } else if (t.value == ' ') {
            result += '&ensp;';
        } else {
            let c = colorMap[t.type] || '#d4d4d4';
            result += '<span style="color:'+c+';">'+t.value+'</span>';
        }
    });

    document.getElementById('fileview-code').innerHTML = result;
}
