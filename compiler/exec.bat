START cmd.exe /k "flex lex.l & bison -dy yacc.y & gcc lex.yy.c y.tab.c -o f.exe & f.exe <input.equ >output.cpp"