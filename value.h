#ifndef VALUE_H
#define VALUE_H

typedef struct {
    int    type;   /* 0 = int, 1 = double, 2 = string */
    int    i;
    double d;
    char  *s;
} Value;

#endif
