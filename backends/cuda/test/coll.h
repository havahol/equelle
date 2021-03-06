
// coll.h

#ifndef EQUELLE_CUDA_TEST_COLL_HEADER
#define EQUELLE_CUDA_TEST_COLL_HEADER


#include <cuda.h>
#include <cuda_runtime.h>
#include "DeviceGrid.hpp"
#include "CollOfIndices.hpp"


// Function declarations:

void test_copy(equelleCUDA::CollOfFace coll);
void test_full(equelleCUDA::CollOfCell coll);
void test_back_to_host(equelleCUDA::CollOfCell coll);

int cuda_main();


#endif // EQUELLE_CUDA_TEST_COLL_HEADER
