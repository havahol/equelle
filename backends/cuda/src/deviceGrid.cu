#include <cuda.h>
#include <cuda_runtime.h>

#include <iostream>
#include <string>
#include <vector>

// For error exception macro:
#include <opm/core/utility/ErrorMacros.hpp>
#include <opm/core/grid/GridManager.hpp>
#include <opm/core/grid.h>

#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <thrust/copy.h>
#include <thrust/memory.h>
#include <thrust/fill.h>
#include <thrust/detail/raw_pointer_cast.h>
#include <thrust/remove.h>
#include <thrust/execution_policy.h>
#include <thrust/iterator/retag.h>

#include "DeviceGrid.hpp"
#include "CollOfScalar.hpp"
#include "CollOfIndices.hpp"


using namespace equelleCUDA;


// --------------------------------------------------- //
// -------- Implementation of DeviceGrid ------------- //
// --------------------------------------------------- //


// Default constructor
DeviceGrid::DeviceGrid()
    : dimensions_(0),
      number_of_cells_(0),
      number_of_faces_(0),
      size_cell_faces_(0),
      cell_centroids_(0),
      cell_facepos_(0),
      cell_faces_(0),
      cell_volumes_(0),
      face_areas_(0),
      face_cells_(0),
      face_normals_(0),
      id_(0)
{
    // intentionally left blank
}

// Constructor from a OPM UnstructuredGrid struct
DeviceGrid::DeviceGrid( const UnstructuredGrid& grid)
    : dimensions_(grid.dimensions),
      number_of_cells_(grid.number_of_cells),
      number_of_faces_(grid.number_of_faces),
      size_cell_faces_(grid.cell_facepos[number_of_cells_]),
      cell_centroids_(0),
      cell_facepos_(0),
      cell_faces_(0),
      cell_volumes_(0),
      face_areas_(0),
      face_cells_(0),
      face_normals_(0),
      id_(-1)
{
    std::cout << "Creating new DeviceGrid:\n";
    std::cout << "\t\t Dimensions = " << dimensions_ << std::endl;
    std::cout << "\t\t Number of cells = " << number_of_cells_ << std::endl;
    std::cout << "\t\t Number of faces = " << number_of_faces_ << std::endl;
    std::cout << "\t\t size of cell_faces_ = " << size_cell_faces_ << std::endl;

    // Allocate memory for cell_centroids_:
    // type: double
    // size: dimensions_ * number_of_cells_
    cudaStatus_ = cudaMalloc( (void**)&cell_centroids_ ,
			      dimensions_ * number_of_cells_ * sizeof(double));
    checkError_("cudaMalloc(cell_centroids_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( cell_centroids_, grid.cell_centroids,
			      dimensions_ * number_of_cells_ * sizeof(double),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(cell_centroids_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    std::cout << "\tnew cell_centroids_ " << cell_centroids_ << "\n";

    // Allocate memory for cell_facepos_:
    // type: int
    // size: number_of_cells_ + 1
    cudaStatus_ = cudaMalloc( (void**)&cell_facepos_, 
			      (number_of_cells_ + 1) * sizeof(int));
    checkError_("cudaMalloc(cell_facepos_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( cell_facepos_, grid.cell_facepos,
			      (number_of_cells_ + 1) * sizeof(int),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(cell_facepos_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    std::cout << "\tnew cell_facepos_ " << cell_facepos_ << "\n";
    
    // Allocate memory for cell_faces:
    // type: int
    // size: cell_facepos_[ number_of_cells_ ]
    cudaStatus_ = cudaMalloc( (void**)&cell_faces_, 
			      size_cell_faces_ * sizeof(int));
    checkError_("cudaMalloc(cell_faces_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( cell_faces_, grid.cell_faces,
			      size_cell_faces_ * sizeof(int),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(cell_faces_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    std::cout << "\tnew cell_faces_ " << cell_faces_ << " with size " << size_cell_faces_ << "\n";

    // Allocate memory for cell_volumes_:
    // type: double
    // size: number_of_cells_
    cudaStatus_ = cudaMalloc( (void**)&cell_volumes_, 
			      number_of_cells_ * sizeof(double));
    checkError_("cudaMalloc(cell_volumes_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( cell_volumes_, grid.cell_volumes,
			      number_of_cells_ * sizeof(double),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(cell_volumes_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    std::cout << "\tnew cell_volumes_ " << cell_volumes_ << "\n";

    // Allocate memory for face_areas_:
    // type: double
    // size: number_of_faces_
    cudaStatus_ = cudaMalloc( (void**)&face_areas_, 
			      number_of_faces_ * sizeof(double));
    checkError_("cudaMalloc(face_areas_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( face_areas_, grid.face_areas,
			      number_of_faces_ * sizeof(double),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(face_areas_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
 
    // Allocate memory for face_cells_:
    // type: int
    // size: 2 * number_of_faces_
    cudaStatus_ = cudaMalloc( (void**)&face_cells_, 
			      2 * number_of_faces_ * sizeof(int));
    checkError_("cudaMalloc(face_cells_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( face_cells_, grid.face_cells,
			      2 * number_of_faces_ * sizeof(int),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(face_cells_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");

    // Allocate memory for face_normals_:
    // type: double
    // size: dimensions_ * number_of_faces_
    cudaStatus_ = cudaMalloc( (void**)&face_normals_, 
			      dimensions_ * number_of_faces_ * sizeof(double));
    checkError_("cudaMalloc(face_normals_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");
    cudaStatus_ = cudaMemcpy( face_normals_, grid.face_normals,
			      dimensions_ * number_of_faces_ * sizeof(double),
			      cudaMemcpyHostToDevice );
    checkError_("cudaMemcpy(face_normals_) in DeviceGrid::DeviceGrid(UnstructuredGrid&)");

    std::cout << "Created DeviceGrid from UnstructuredGrid!\n";
}


// Copy constructor:
DeviceGrid::DeviceGrid(const DeviceGrid& grid) 
  : dimensions_(grid.dimensions_),
    number_of_cells_(grid.number_of_cells_),
    number_of_faces_(grid.number_of_faces_),
    size_cell_faces_(grid.size_cell_faces_),
    cell_centroids_(0),
    cell_facepos_(0),
    cell_faces_(0),
    cell_volumes_(0),
    face_areas_(0),
    face_cells_(0),
    face_normals_(0),
    id_(0)
{    
    // CELL_CENTROIDS_
    cudaStatus_ = cudaMalloc( (void**)&cell_centroids_,
			      dimensions_ * number_of_cells_ * sizeof(double));
    checkError_("cudaMalloc(cell_centroids_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( cell_centroids_, grid.cell_centroids_,
			      dimensions_ * number_of_cells_ * sizeof(double),
			      cudaMemcpyDeviceToDevice );
    checkError_("cudaMemcpy(cell_centroids_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy cell_centroids_:\t" << cell_centroids_ << "\n";

    // CELL_FACEPOS_
    cudaStatus_ = cudaMalloc( (void**)&cell_facepos_, 
			      (number_of_cells_ + 1) * sizeof(int));
    checkError_("cudaMalloc(cell_facepos_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( cell_facepos_, grid.cell_facepos_,
			      (number_of_cells_ + 1) * sizeof(int),
			      cudaMemcpyDeviceToDevice );
    checkError_("cudaMemcpy(cell_facepos_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy cell_facepos_:\t" <<cell_facepos_ << "\n";

    // CELL_FACES_
    cudaStatus_ = cudaMalloc( (void**)&cell_faces_,
			      size_cell_faces_ * sizeof(int));
    checkError_("cudaMalloc(cell_faces_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( cell_faces_, grid.cell_faces_,
			      size_cell_faces_ * sizeof(int),
			      cudaMemcpyDeviceToDevice );
    checkError_("cudaMemcpy(cell_faces_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy cell_faces_:\t" << cell_faces_ << " with size ";
    //std::cout << size_cell_faces_ << "\n";

    // CELL_VOLUMES_
    cudaStatus_ = cudaMalloc( (void**)&cell_volumes_,
			      number_of_cells_ * sizeof(double));
    checkError_("cudaMalloc(cell_volumes_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( cell_volumes_, grid.cell_volumes_,
			      number_of_cells_ * sizeof(double),
			      cudaMemcpyDeviceToDevice);
    checkError_("cudaMemcpy(cell_volumes_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy cell_volumes_:\t" << cell_volumes_ << "\n";

    // FACE_AREAS_
    cudaStatus_ = cudaMalloc( (void**)&face_areas_,
			      number_of_faces_ * sizeof(double));
    checkError_("cudaMalloc(face_areas_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( face_areas_, grid.face_areas_,
			      number_of_cells_ * sizeof(double),
			      cudaMemcpyDeviceToDevice);
    checkError_("cudaMemcpy(face_areas_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy face_areas_:\t" << face_areas_ << "\n";
    
    // FACE_CELLS_
    cudaStatus_ = cudaMalloc( (void**)&face_cells_,
			      2 * number_of_faces_ * sizeof(int));
    checkError_("cudaMalloc(face_cells_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( face_cells_, grid.face_cells_,
			      2 * number_of_faces_ * sizeof(int),
			      cudaMemcpyDeviceToDevice);
    checkError_("cudaMemcpy(face_cells_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy face_cells_:\t" << face_cells_ << "\n";
			    
    // FACE_NORMALS
    cudaStatus_ = cudaMalloc( (void**)&face_normals_,
			      dimensions_ * number_of_faces_ * sizeof(double));
    checkError_("cudaMalloc(face_normals_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    cudaStatus_ = cudaMemcpy( face_normals_, grid.face_normals_,
			      dimensions_ * number_of_faces_ * sizeof(double),
			      cudaMemcpyDeviceToDevice);
    checkError_("cudaMemcpy(face_normals_) in DeviceGrid::DeviceGrid(const DeviceGrid&)");
    //std::cout << "\tCopy face_normals_:\t" << face_normals_ << "\n";
    
    std::cout << "Created DeviceGrid from copy constructor!\n";
}


// Destructor
DeviceGrid::~DeviceGrid() {
    std::cout << "Destructor - id " << id_ << "\n";
    //std::cout << "\t\t" << cell_centroids_;
    if( cell_centroids_ != 0 ) {
	//std::cout << "\tDel cell_centriods_\n";
	cudaStatus_ = cudaFree(cell_centroids_);
	checkError_("cudaFree(cell_centroids_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << cell_facepos_;
    if ( cell_facepos_ != 0 ) {
	//std::cout << "\tDel cell_facepos_\n";
	cudaStatus_ = cudaFree(cell_facepos_);
	checkError_("cudaFree(cell_facepos_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << cell_faces_;
    if ( cell_faces_ != 0 ) {
	//std::cout << "\tDel cell_faces\n";
	cudaStatus_ = cudaFree(cell_faces_);
	checkError_("cudaFree(cell_faces_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << cell_volumes_;
    if ( cell_volumes_ != 0 ) {
	//std::cout << "\tDel cell_volumes_\n";
	cudaStatus_ = cudaFree(cell_volumes_);
	checkError_("cudaFree(cell_volumes_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << face_areas_;
    if ( face_areas_ != 0 ) {
	//std::cout << "\tDel face_areas_\n";
	cudaStatus_ = cudaFree(face_areas_);
	checkError_("cudaFree(face_areas_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << face_cells_;
    if ( face_cells_ != 0 ) {
	//std::cout << "\tDel face_cells_\n";
	cudaStatus_ = cudaFree(face_cells_);
	checkError_("cudaFree(face_cells_) in DeviceGrid::~DeviceGrid()");
    }
    //std::cout << "\t\t" << face_normals_;
    if ( face_normals_ != 0 ) {
	//std::cout << "\tDel face_normals_\n";
	cudaStatus_ = cudaFree(face_normals_);
	checkError_("cudaFree(face_normals_) in DeviceGrid::~DeviceGrid()");
    }
    std::cout << "Destructor finished.\n";
}


int DeviceGrid::setID(int a) {
    id_ = a;
    return 4;
}

// ------------ GRID OPERATIONS! ------------
CollOfIndices DeviceGrid::allCells() const {
    return CollOfIndices(true);
}

CollOfIndices DeviceGrid::allFaces() const {
    return CollOfIndices(true);
}

CollOfIndices DeviceGrid::boundaryFaces() const {
    // we use the face_cells_ array to check if both face_cells are cells
    // If face f is a boundary face, then 
    // face_cells_[2 * f] or face_cells_[2 * f + 1] contains -1.
    
    // Launch a kernel where we use number_of_faces number of threads.
    // Use a 1D kernel for simplicity.
    // Assume that we do not need more blocks than available.
    dim3 block_size(MAX_THREADS);
    int num_blocks = (number_of_faces_ + MAX_THREADS - 1) / MAX_THREADS;
    dim3 grid_size(num_blocks);

    // Create a vector of size number_of_faces_:
    thrust::device_vector<int> b_faces(number_of_faces_);
    // Fill it with the value number_of_faces_
    //     this is an illigal faca index
    thrust::fill(b_faces.begin(), b_faces.end(), number_of_faces_);
    int* b_faces_ptr = thrust::raw_pointer_cast( &b_faces[0] );
    boundaryFacesKernel<<<grid_size, block_size>>>( b_faces_ptr,
						    face_cells_,
						    number_of_faces_);
    
    // Remove unchanged values
    // See  - thrust::remove_if documentation 
    //      - the saxpy example in the algorithm chapter of the thrust pdf
    thrust::device_vector<int>::iterator new_end = thrust::remove_if(thrust::device, 
								     b_faces.begin(),
								     b_faces.end(),
								     unchanged(number_of_faces_));
    
    // new_end points now to where the legal values end,
    // but the vector still has size equal to number_of_faces_
    thrust::device_vector<int> out(b_faces.begin(), new_end);

    return CollOfIndices(out);
    
}


CollOfIndices DeviceGrid::interiorFaces() const {
    // we use the face_cells_ array to check if both face_cells are cells
    // If face f is an interior face, then neither of
    // face_cells_[2 * f] nor face_cells_[2 * f + 1] contains -1.
    
    // Launch a kernel where we use number_of_faces number of threads.
    // Use a 1D kernel for simplicity.
    // Assume that we do not need more blocks than available.
    dim3 block_size(MAX_THREADS);
    int num_blocks = (number_of_faces_ + MAX_THREADS - 1) / MAX_THREADS;
    dim3 grid_size(num_blocks);

    // Create a vector of size number_of_faces_:
    thrust::device_vector<int> i_faces(number_of_faces_);
    // Fill it with the value number_of_faces_
    //     this is an illigal faca index
    thrust::fill(i_faces.begin(), i_faces.end(), number_of_faces_);
    int* i_faces_ptr = thrust::raw_pointer_cast( &i_faces[0] );
    interiorFacesKernel<<<grid_size, block_size>>>( i_faces_ptr,
						    face_cells_,
						    number_of_faces_);
    // Remove unchanged values
    // See  - thrust::remove_if documentation 
    //      - the saxpy example in the algorithm chapter of the thrust pdf
    thrust::device_vector<int>::iterator new_end = thrust::remove_if(thrust::device, 
								     i_faces.begin(),
								     i_faces.end(),
								     unchanged(number_of_faces_));
    
    // new_end points now to where the legal values end,
    // but the vector still has size equal to number_of_faces_    
    thrust::device_vector<int> out(i_faces.begin(), new_end);

    return CollOfIndices(out);
    
}


// BOUNDARY CELLS
CollOfIndices DeviceGrid::boundaryCells() const {
    // Returns a Collection of indices of boundary cells.
    // Algorithm:
    // for each cell c
    //     for (face f_index in [cell_facepos[c] : cell_facepos[c+1] )
    //          f = cell_faces[f_index]
    //          if ( face_cells[2*f] == -1 or face_cells[2*f + 1] == -1 )
    //              c is a boundary cell.

    // Kernel of number_of_cells_ threads
    // Operate on vector filled with number_of_cells_
    // Set cell index if boundary cell
    // Remove all elements equal to number_of_cells_.

    dim3 block(MAX_THREADS);
    dim3 grid( (int)((number_of_cells_ + MAX_THREADS - 1)/ MAX_THREADS) );
    thrust::device_vector<int> b_cells(number_of_cells_);
    thrust::fill(b_cells.begin(), b_cells.end(), number_of_cells_);
    int* b_cells_ptr = thrust::raw_pointer_cast( &b_cells[0] );
    boundaryCellsKernel<<<grid, block>>>( b_cells_ptr,
					  number_of_cells_,
					  cell_facepos_,
					  cell_faces_,
					  face_cells_);

    // Remove values which still are number_of_cells_
    thrust::device_vector<int>::iterator new_end = thrust::remove_if(thrust::device,
								     b_cells.begin(),
								     b_cells.end(),
								     unchanged(number_of_cells_));
    thrust::device_vector<int> out(b_cells.begin(), new_end);
    return CollOfIndices(out);
}


// INTERIOR CELLS
CollOfIndices DeviceGrid::interiorCells() const {
    // Same as boundaryCells, but the kernel is the other way around
    dim3 block(MAX_THREADS);
    dim3 grid( (int)((number_of_cells_ + MAX_THREADS - 1)/ MAX_THREADS) );
    thrust::device_vector<int> i_cells(number_of_cells_);
    thrust::fill(i_cells.begin(), i_cells.end(), number_of_cells_);
    int* i_cells_ptr = thrust::raw_pointer_cast( &i_cells[0] );
    interiorCellsKernel<<<grid, block>>>( i_cells_ptr,
					  number_of_cells_,
					  cell_facepos_,
					  cell_faces_,
					  face_cells_);

    // Remove values which still are number_of_cells_
    thrust::device_vector<int>::iterator new_end = thrust::remove_if(thrust::device,
								     i_cells.begin(),
								     i_cells.end(),
								     unchanged(number_of_cells_));
    thrust::device_vector<int> out(i_cells.begin(), new_end);
    return CollOfIndices(out);


}



// ----------- GET FUNCTIONS! ------------------

int DeviceGrid::dimensions() const {
    return dimensions_;
}

int DeviceGrid::number_of_cells() const {
    return number_of_cells_;
}

int DeviceGrid::number_of_faces() const {
    return number_of_faces_;
}

// ---------- ERROR CHECKING! -----------------------

// Check if for CUDA error and throw OPM exception if there is one.
void DeviceGrid::checkError_(const std::string& msg) const {
    //std::cout << "checking...\n";
    if ( cudaStatus_ != cudaSuccess ) {
	std::cout << "HELLO!!!!?\n";
	std::cout << "\n\nEXCEPTION!!!\n\n";

	OPM_THROW(std::runtime_error, "\nCuda error\n\t" << msg << " - Error code: " << cudaGetErrorString(cudaStatus_));
    }
        
}


// ----------- GRID KERNELS -------------------------

__global__ void equelleCUDA::boundaryFacesKernel( int* b_faces,
						  const int* face_cells,
						  const int number_of_faces) 
{
    int face = threadIdx.x + blockIdx.x*blockDim.x;
    if (face < number_of_faces) {
	if ( (face_cells[2*face] == -1) || (face_cells[2*face + 1] == -1) ) {
	    b_faces[face] = face;
	}
    }
}


__global__ void equelleCUDA::interiorFacesKernel( int* i_faces,
						  const int* face_cells,
						  const int number_of_faces)
{
    int face = threadIdx.x + blockIdx.x*blockDim.x;
    if ( face < number_of_faces) {
	if ( (face_cells[2*face] != -1) && (face_cells[2*face + 1] != -1) ) {
	    i_faces[face] = face;
	}
    }
}


__global__ void equelleCUDA::boundaryCellsKernel(int* b_cells,
						 const int number_of_cells,
						 const int* cell_facepos,
						 const int* cell_faces,
						 const int* face_cells)
{
    int cell = threadIdx.x + blockIdx.x*blockDim.x;
    if ( cell < number_of_cells) {
	bool boundary = false;
	int face;
	for ( int f_i = cell_facepos[cell]; f_i < cell_facepos[cell + 1]; f_i++) {
	    face = cell_faces[f_i];
	    if ( (face_cells[ 2*face ] == -1) || (face_cells[ 2*face +1] == -1) ) {
		boundary = true;
	    }
	}
	if (boundary) {
	    b_cells[cell] = cell;
	}
    }
}


__global__ void equelleCUDA::interiorCellsKernel( int* i_cells,
						  const int number_of_cells,
						  const int* cell_facepos,
						  const int* cell_faces,
						  const int* face_cells)
{
    int cell = threadIdx.x + blockIdx.x*blockDim.x;
    if ( cell < number_of_cells) {
	bool interior = true;
	int face;
	for ( int f_i = cell_facepos[cell]; f_i < cell_facepos[cell + 1]; f_i++) {
	    face = cell_faces[f_i];
	    if ( (face_cells[ 2*face ] == -1) || (face_cells[ 2*face +1] == -1) ) {
		interior = false;
	    }
	}
	if ( interior ) {
	    i_cells[cell] = cell;
	}
    }

}