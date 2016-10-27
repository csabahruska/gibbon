#include "tree_packed.h"



int main(int argc, char **argv)
{
 //   nNodes = 0;
 //   nWorkNodes = 0;
    Point * data;
    float rad;
    int npoints;
    //read points or create random set of points based on the input
    
    readInput(argc,  argv, data, rad, npoints);
   
#ifdef DEBUG
    cout << "rad " << rad << endl;
#endif
    
    
    //build the input tree
    char * root=buildTree(npoints ,  data );
   
    printPackedTree(root);
    
    for(int i=0; i<npoints; i++)
        performPointCorr_OnTree(data[i], root, rad);


    delete [] data;
    free(root);
    return 0;
}
