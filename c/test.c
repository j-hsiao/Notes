#include <stdio.h>
int main(){
  int x[5] = {1,2,3,4,5};
  int* xaddr = x;

  printf("%d\n", x[0]);
  printf("%d\n", xaddr[3]);


  return 0;
}
