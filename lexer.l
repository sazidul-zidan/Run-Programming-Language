%{
#include "value.h"
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%%

"if"        { return IF;      }
"else"      { return ELSE;    }
"while"     { return WHILE;   }
"for"       { return FOR;     }
"do"        { return DO;      }
"print"     { return PRINT;   }
"switch"    { return SWITCH;  }
"case"      { return CASE;    }
"default"   { return DEFAULT; }
"break"     { return BREAK;   }

">="        { return GE; }
"<="        { return LE; }
"=="        { return EQ; }
"!="        { return NE; }
">"         { return GT; }
"<"         { return LT; }

"~"         { return END;   }
":"         { return COLON; }

\"([^\\\"]|\\.)*\" {
    char *raw = strdup(yytext + 1);
    raw[strlen(raw) - 1] = '\0';
    yylval.str = raw;
    return STRING;
}

[0-9]+"."[0-9]+ {
    yylval.dval = atof(yytext);
    return DOUBLE;
}

[0-9]+ {
    yylval.ival = atoi(yytext);
    return INT;
}

@[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.id = strdup(yytext);
    return ID;
}

"+"  { return '+'; }
"-"  { return '-'; }
"*"  { return '*'; }
"/"  { return '/'; }
"="  { return '='; }
"("  { return '('; }
")"  { return ')'; }
"{"  { return '{'; }
"}"  { return '}'; }

[ \t\n\r]+  ;

.   { fprintf(stderr, "Unknown character: %s\n", yytext); }

%%

int yywrap() { return 1; }
