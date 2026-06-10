#ifndef AST_H
#define AST_H

#include "value.h"

/* ══════════════════════════════════════════
   AST NODE TYPES
══════════════════════════════════════════ */
typedef enum {
    NODE_INT, NODE_DOUBLE, NODE_STRING, NODE_ID,
    NODE_BINOP,
    NODE_ASSIGN,
    NODE_PRINT,
    NODE_IF,
    NODE_WHILE,
    NODE_DOWHILE,
    NODE_FOR,
    NODE_SWITCH,
    NODE_CASE,
    NODE_SEQ,
    NODE_NOP
} NodeType;

typedef struct ASTNode {
    NodeType type;

    /* literal values */
    int    ival;
    double dval;
    char  *sval;   /* string literal or identifier name */

    /* binary op */
    char   op;     /* '+','-','*','/','>','<','G','L','E','N' */

    /* children */
    struct ASTNode *left;
    struct ASTNode *right;
    struct ASTNode *cond;
    struct ASTNode *body;
    struct ASTNode *els;
    struct ASTNode *init;
    struct ASTNode *step;
    struct ASTNode *next;   /* next in case list */
    int    case_is_default;
} ASTNode;

/* ── node constructors ── */
static inline ASTNode *new_node(NodeType t) {
    ASTNode *n = calloc(1, sizeof(ASTNode));
    n->type = t;
    return n;
}
static inline ASTNode *make_int(int v) {
    ASTNode *n = new_node(NODE_INT); n->ival = v; return n;
}
static inline ASTNode *make_double(double v) {
    ASTNode *n = new_node(NODE_DOUBLE); n->dval = v; return n;
}
static inline ASTNode *make_string(char *s) {
    ASTNode *n = new_node(NODE_STRING); n->sval = s; return n;
}
static inline ASTNode *make_id(char *s) {
    ASTNode *n = new_node(NODE_ID); n->sval = s; return n;
}
static inline ASTNode *make_binop(char op, ASTNode *l, ASTNode *r) {
    ASTNode *n = new_node(NODE_BINOP);
    n->op = op; n->left = l; n->right = r; return n;
}
static inline ASTNode *make_seq(ASTNode *l, ASTNode *r) {
    if (!l) return r;
    if (!r) return l;
    ASTNode *n = new_node(NODE_SEQ);
    n->left = l; n->right = r; return n;
}

#endif /* AST_H */
