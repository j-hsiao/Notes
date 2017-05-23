#include <stdio.h>
#include <stdlib.h>
void hello(char* dest, char* phrase);

char* hellop(char* phrase);

int main(int argn, char** args){
  char buf[50];
  hello(buf, "bananas");
  printf(buf);

  char* result = hellop("bananas");
  printf(result);
  free(result);
}
