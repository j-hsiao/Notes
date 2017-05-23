#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void hello(char* dest, char* phrase) {
  strcpy(dest, "hello ");
  strcpy(dest + 6, phrase);
}

char* hellop(char* phrase) {
  int len = strlen(phrase);
  char* ret = (char*) malloc((len + 7) * sizeof(char));
  strcpy(ret, "hello ");
  strcpy(ret + 6, phrase);
  return ret;
}




int main(int argn, char** args){
  char buf[50];
  hello(buf, "bananas");
  printf(buf);

  char* result = hellop("bananas");
  printf(result);
  free(result)
}
