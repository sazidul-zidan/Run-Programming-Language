%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "value.h"
#include "ast.h"

void yyerror(const char *s);
int  yylex();

/* ══════════════════════════════════════════
   OUTPUT BUFFER
══════════════════════════════════════════ */
#define MAX_OUTPUT 1024
char *output_buffer[MAX_OUTPUT];
int   output_count = 0;

void buffer_print(Value *v) {
    char tmp[512];
    if      (v->type == 0) snprintf(tmp, sizeof(tmp), "%d",  v->i);
    else if (v->type == 1) snprintf(tmp, sizeof(tmp), "%lf", v->d);
    else                   snprintf(tmp, sizeof(tmp), "%s",  v->s ? v->s : "");
    output_buffer[output_count++] = strdup(tmp);
}

/* ══════════════════════════════════════════
   SYMBOL TABLE
══════════════════════════════════════════ */
#define MAX_VARS 256

typedef struct {
    char  *name;
    Value  val;
    int    declared;
    int    used;
} Symbol;

Symbol sym_table[MAX_VARS];
int    sym_count = 0;

int getIndex(const char *name) {
    for (int i = 0; i < sym_count; i++)
        if (strcmp(sym_table[i].name, name) == 0) return i;
    if (sym_count >= MAX_VARS) { fprintf(stderr, "Symbol table full!\n"); exit(1); }
    sym_table[sym_count].name     = strdup(name);
    sym_table[sym_count].val      = (Value){0, 0, 0.0, NULL};
    sym_table[sym_count].declared = 0;
    sym_table[sym_count].used     = 0;
    return sym_count++;
}

void sym_declare(const char *name, Value v) {
    int idx = getIndex(name);
    sym_table[idx].val      = v;
    sym_table[idx].declared = 1;
}

Value sym_lookup(const char *name) {
    int idx = getIndex(name);
    if (!sym_table[idx].declared)
        fprintf(stderr, "Warning: '%s' used before assignment.\n", name);
    sym_table[idx].used++;
    return sym_table[idx].val;
}

void print_symbol_table() {
    printf("\n============================================================\n");
    printf("  SYMBOL TABLE\n");
    printf("============================================================\n");
    printf("  %-15s %-10s %-20s %-6s\n", "Name", "Type", "Value", "Uses");
    printf("  %-15s %-10s %-20s %-6s\n",
           "---------------","----------","--------------------","------");
    for (int i = 0; i < sym_count; i++) {
        char val_str[64]; char *type_str;
        Symbol *s = &sym_table[i];
        if      (s->val.type == 0) { snprintf(val_str,sizeof(val_str),"%d",  s->val.i); type_str="int"; }
        else if (s->val.type == 1) { snprintf(val_str,sizeof(val_str),"%lf", s->val.d); type_str="double"; }
        else                       { snprintf(val_str,sizeof(val_str),"%s",  s->val.s ? s->val.s : "\"\""); type_str="string"; }
        printf("  %-15s %-10s %-20s %-6d\n", s->name, type_str, val_str, s->used);
    }
    printf("============================================================\n");
}

/* ══════════════════════════════════════════
   AST EVALUATOR
══════════════════════════════════════════ */
static double toDouble(Value v) {
    return (v.type == 1) ? v.d : (double)v.i;
}

Value eval(ASTNode *node) {
    if (!node) return (Value){0,0,0,NULL};

    switch (node->type) {

    case NODE_NOP:
        return (Value){0,0,0,NULL};

    case NODE_INT:
        return (Value){0, node->ival, 0, NULL};

    case NODE_DOUBLE:
        return (Value){1, 0, node->dval, NULL};

    case NODE_STRING:
        return (Value){2, 0, 0, node->sval};

    case NODE_ID:
        return sym_lookup(node->sval);

    case NODE_BINOP: {
        if (node->op == 'G' || node->op == 'L' ||
            node->op == 'E' || node->op == 'N' ||
            node->op == '>' || node->op == '<') {
            Value l = eval(node->left);
            Value r = eval(node->right);
            double ld = toDouble(l), rd = toDouble(r);
            int result = 0;
            switch (node->op) {
                case '>': result = ld >  rd; break;
                case '<': result = ld <  rd; break;
                case 'G': result = ld >= rd; break;
                case 'L': result = ld <= rd; break;
                case 'E': result = ld == rd; break;
                case 'N': result = ld != rd; break;
            }
            return (Value){0, result, 0, NULL};
        }
        Value l = eval(node->left);
        Value r = eval(node->right);
        int use_double = (l.type == 1 || r.type == 1 || node->op == '/');
        switch (node->op) {
            case '+': if (use_double) return (Value){1,0,toDouble(l)+toDouble(r),NULL};
                      return (Value){0, l.i + r.i, 0, NULL};
            case '-': if (use_double) return (Value){1,0,toDouble(l)-toDouble(r),NULL};
                      return (Value){0, l.i - r.i, 0, NULL};
            case '*': if (use_double) return (Value){1,0,toDouble(l)*toDouble(r),NULL};
                      return (Value){0, l.i * r.i, 0, NULL};
            case '/': return (Value){1, 0, toDouble(l)/toDouble(r), NULL};
        }
        return (Value){0,0,0,NULL};
    }

    case NODE_ASSIGN: {
        Value v = eval(node->right);
        sym_declare(node->sval, v);
        return v;
    }

    case NODE_PRINT: {
        Value v = eval(node->left);
        buffer_print(&v);
        return v;
    }

    case NODE_SEQ:
        eval(node->left);
        eval(node->right);
        return (Value){0,0,0,NULL};

    case NODE_IF: {
        Value cond = eval(node->cond);
        int truth = (cond.type == 0) ? cond.i : (int)cond.d;
        if (truth)
            eval(node->body);
        else if (node->els)
            eval(node->els);
        return (Value){0,0,0,NULL};
    }

    case NODE_WHILE: {
        while (1) {
            Value cond = eval(node->cond);
            int truth = (cond.type == 0) ? cond.i : (int)cond.d;
            if (!truth) break;
            eval(node->body);
        }
        return (Value){0,0,0,NULL};
    }

    case NODE_DOWHILE: {
        do {
            eval(node->body);
            Value cond = eval(node->cond);
            int truth = (cond.type == 0) ? cond.i : (int)cond.d;
            if (!truth) break;
        } while (1);
        return (Value){0,0,0,NULL};
    }

    case NODE_FOR: {
        eval(node->init);
        while (1) {
            Value cond = eval(node->cond);
            int truth = (cond.type == 0) ? cond.i : (int)cond.d;
            if (!truth) break;
            eval(node->body);
            eval(node->step);
        }
        return (Value){0,0,0,NULL};
    }

    case NODE_SWITCH: {
        Value sw_val = eval(node->cond);
        double sw_d  = toDouble(sw_val);
        ASTNode *c   = node->body;
        int matched  = 0;
        ASTNode *def_case = NULL;

        while (c) {
            if (c->case_is_default) {
                def_case = c;
            } else {
                Value cv = eval(c->cond);
                if (toDouble(cv) == sw_d) {
                    eval(c->body);
                    matched = 1;
                    break;
                }
            }
            c = c->next;
        }
        if (!matched && def_case)
            eval(def_case->body);
        return (Value){0,0,0,NULL};
    }

    case NODE_CASE:
        return (Value){0,0,0,NULL};

    default:
        return (Value){0,0,0,NULL};
    }
}

ASTNode *program_root = NULL;

%}

/* ── Makes ast.h visible to the generated parser.tab.h,
      so %union can use ASTNode* in both parser and lexer ── */
%code requires {
    #include "value.h"
    #include "ast.h"
}

%union {
    int       ival;
    double    dval;
    char     *str;
    char     *id;
    ASTNode  *node;
}

%token <ival>  INT
%token <dval>  DOUBLE
%token <str>   STRING
%token <id>    ID

%token IF ELSE WHILE FOR PRINT DO
%token SWITCH CASE DEFAULT BREAK COLON
%token GE LE EQ NE GT LT
%token END

%left  '+' '-'
%left  '*' '/'

%type <node> program statement assignment print_stmt
%type <node> if_stmt while_stmt do_while_stmt for_stmt
%type <node> switch_stmt case_list case_item
%type <node> expr condition

%%

program
    : program statement   { $$ = make_seq($1, $2); program_root = $$; }
    | /* empty */         { $$ = NULL; program_root = NULL; }
    ;

statement
    : assignment END      { $$ = $1; }
    | print_stmt END      { $$ = $1; }
    | if_stmt             { $$ = $1; }
    | while_stmt          { $$ = $1; }
    | do_while_stmt       { $$ = $1; }
    | for_stmt            { $$ = $1; }
    | switch_stmt         { $$ = $1; }
    ;

/* ── Assignment ── */
assignment
    : ID '=' expr {
        ASTNode *n = new_node(NODE_ASSIGN);
        n->sval  = $1;
        n->right = $3;
        $$ = n;
    }
    ;

/* ── Print ── */
print_stmt
    : PRINT '(' expr ')' {
        ASTNode *n = new_node(NODE_PRINT);
        n->left = $3;
        $$ = n;
    }
    ;

/* ── If / Else ── */
if_stmt
    : IF '(' condition ')' '{' program '}' {
        ASTNode *n = new_node(NODE_IF);
        n->cond = $3; n->body = $6; n->els = NULL;
        $$ = n;
    }
    | IF '(' condition ')' '{' program '}' ELSE '{' program '}' {
        ASTNode *n = new_node(NODE_IF);
        n->cond = $3; n->body = $6; n->els = $10;
        $$ = n;
    }
    ;

/* ── While ── */
while_stmt
    : WHILE '(' condition ')' '{' program '}' {
        ASTNode *n = new_node(NODE_WHILE);
        n->cond = $3; n->body = $6;
        $$ = n;
    }
    ;

/* ── Do-While ── */
do_while_stmt
    : DO '{' program '}' WHILE '(' condition ')' END {
        ASTNode *n = new_node(NODE_DOWHILE);
        n->body = $3; n->cond = $7;
        $$ = n;
    }
    ;

/* ── For ── */
for_stmt
    : FOR '(' assignment END condition END assignment ')' '{' program '}' {
        ASTNode *n = new_node(NODE_FOR);
        n->init = $3; n->cond = $5; n->step = $7; n->body = $10;
        $$ = n;
    }
    ;

/* ── Switch-Case ── */
switch_stmt
    : SWITCH '(' expr ')' '{' case_list '}' {
        ASTNode *n = new_node(NODE_SWITCH);
        n->cond = $3; n->body = $6;
        $$ = n;
    }
    ;

case_list
    : case_list case_item {
        if ($1 == NULL) { $$ = $2; }
        else {
            ASTNode *cur = $1;
            while (cur->next) cur = cur->next;
            cur->next = $2;
            $$ = $1;
        }
    }
    | /* empty */ { $$ = NULL; }
    ;

case_item
    : CASE expr COLON program BREAK END {
        ASTNode *n = new_node(NODE_CASE);
        n->cond = $2; n->body = $4; n->case_is_default = 0;
        $$ = n;
    }
    | DEFAULT COLON program BREAK END {
        ASTNode *n = new_node(NODE_CASE);
        n->cond = NULL; n->body = $3; n->case_is_default = 1;
        $$ = n;
    }
    ;

/* ── Condition ── */
condition
    : expr GT expr { $$ = make_binop('>', $1, $3); }
    | expr LT expr { $$ = make_binop('<', $1, $3); }
    | expr GE expr { $$ = make_binop('G', $1, $3); }
    | expr LE expr { $$ = make_binop('L', $1, $3); }
    | expr EQ expr { $$ = make_binop('E', $1, $3); }
    | expr NE expr { $$ = make_binop('N', $1, $3); }
    ;

/* ── Expressions ── */
expr
    : expr '+' expr  { $$ = make_binop('+', $1, $3); }
    | expr '-' expr  { $$ = make_binop('-', $1, $3); }
    | expr '*' expr  { $$ = make_binop('*', $1, $3); }
    | expr '/' expr  { $$ = make_binop('/', $1, $3); }
    | INT            { $$ = make_int($1); }
    | DOUBLE         { $$ = make_double($1); }
    | STRING         { $$ = make_string($1); }
    | ID             { $$ = make_id($1); }
    | '(' expr ')'   { $$ = $2; }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

int main() {
    printf("RuN Language Interpreter\n");
    printf("Write your code. Press Ctrl+Z (Windows) then Enter when done.\n");
    printf("============================================================\n");

    yyparse();

    eval(program_root);

    printf("\n============================================================\n");
    printf("  OUTPUT\n");
    printf("============================================================\n");
    for (int i = 0; i < output_count; i++) {
        printf("  %s\n", output_buffer[i]);
        free(output_buffer[i]);
    }

    print_symbol_table();

    return 0;
}
