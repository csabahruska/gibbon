// A manual implementation of a single-buffer, packed bintree
// representation and a treewalk of it.

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define TRIALS 501

enum Tree {
    Leaf,
    Node,
};

// Manual layout:
// one byte for each tag, 64 bit integers
typedef char* TreeRef;
typedef long long Num;

// Helper function
TreeRef fillTree(TreeRef cursor, int n, Num root) {
  // printf("  filltree: %p, n=%d, fill=%lld", cursor, n, root); fflush(stdout);
  if (n == 0) {
    *cursor = Leaf;
    cursor++;    
    *((Num*)cursor) = root; // Unaligned!
    // printf("; wrote tag %d, payload %lld\n", Leaf, root); fflush(stdout);
    return (cursor + sizeof(Num));
  } else {
    *cursor = Node;

    // Padding for a 4-byte offset changes perf from ~3.5ms to 4ms on 2^20 nodes:
    // cursor += 4; 
    
    // printf("; wrote tag %d\n", Node); fflush(stdout);
    char* cur2 = fillTree(cursor+1, n-1, root);
    return fillTree(cur2, n-1, root + (1<<(n-1)));
  }
}

int treeSize(int n) {
  int leaves = 1 << n;
  int nodes  = leaves - 1;
  // Both nodes and leaves are tagged:
  int bytes  = (sizeof(Num)*leaves + sizeof(char)*(nodes+leaves));
  /* printf("treeSize(%d): %d bytes (%d/%d nodes/leaves)\n", */
  /*        n, bytes, nodes, leaves); */
  return bytes;
}

TreeRef buildTree(int n) {
  int bytes = treeSize(n);
  char* buf = malloc(bytes);
  char* res = fillTree(buf, n, 1);
  printf("wrote %d\n", (int)(res - buf));  
  return buf;
}

TreeRef printTree(TreeRef t) {
  if (*t == Leaf) {
    t++;
    printf("%lld", *(Num*)t);
    return (t+sizeof(Num));
  } else {
    t++;
    printf("(");
    TreeRef t2 = printTree(t);
    printf(",");
    TreeRef t3 = printTree(t2);
    printf(")");
    return t3;    
  }
}

struct RdTag { char tag; char* newptr; };

inline struct RdTag readTag (char* ptr) {
  return (struct RdTag) { *ptr, ptr+1 };
}

inline char* writeTag (char* ptr, char tag) {
  *ptr = tag;
  return ptr+1;
}

struct RdInt { Num read; char* newptr; };

inline struct RdInt readInt (char* ptr) {
  return (struct RdInt) { *(Num*)ptr, ptr + sizeof(Num) };
}

inline char* writeInt (char* ptr, char num) {
  *(Num*)ptr = num;
  return ptr + sizeof(Num);
}

TreeRef add1Tree(TreeRef t, TreeRef tout) {
  struct RdTag rd = readTag(t);
  if (rd.tag == Leaf) {
    TreeRef tout2   = writeTag(tout, Leaf);
    struct RdInt ri = readInt(rd.newptr);
    TreeRef tout3   = writeInt(tout2, ri.read);   
    return ri.newptr;
  } else {
    TreeRef tout2 = writeTag(tout, Node);    
    TreeRef t2    = add1Tree(rd.newptr, tout2);
    return add1Tree(t2, tout2 + (t2 - rd.newptr));
  }
}

int compare_doubles (const void *a, const void *b)
{
  const double *da = (const double *) a;
  const double *db = (const double *) b;
  return (*da > *db) - (*da < *db);
}

int main(int argc, char** argv) {
  int depth;
  if (argc > 1)
    depth = atoi(argv[1]);
  else 
    depth = 20;
  printf("Building tree, depth %d\n", depth);
  // CLOCK_REALTIME
  clock_t begin = clock();
  TreeRef tr = buildTree(depth);
  clock_t end = clock();
  double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;
  printf("done building, took %lf seconds\n\n", time_spent);
  // printTree(tr); printf("\n");a
  TreeRef t2 = malloc(treeSize(depth));
  double trials[TRIALS];
  for(int i=0; i<TRIALS; i++) {
    begin = clock();
    add1Tree(tr,t2);
    end = clock();
    time_spent = (double)(end - begin) / CLOCKS_PER_SEC;
    printf("  run(%d): %lf\n", i, time_spent);
    trials[i] = time_spent;
  }
  qsort(trials, TRIALS, sizeof(double), compare_doubles);
  printf("Sorted: ");
  for(int i=0; i<TRIALS; i++)
    printf(" %lf", trials[i]);  
  printf("\nSELFTIMED: %lf\n", trials[TRIALS / 2]);
  // printTree(t2); printf("\n");
  free(tr);
  return 0;
}
