# Background

This section covers some context relevant to GPUs and their simulation in gem5. 
Feel free to skip this section and reference back to it as you work on the **Assignment**.

## Objective

Recall Dr. Amaral's lectures into the architecture of GPU systems and how different they are from CPU systems. You should be familiar with how the lectures introduce the compute units of the GPU and their organization within the larger GPU system, as well as the architectural features of a GPU's L1, L2 and GDDR Memory. The goal of this lab is to further expand your understanding of GPU architecture and its components' effects on performance by having you modify certain elements of a GPU and observing the effects on training a simple neural network.

## GPU's in gem5

GPU support in the gem5 simulator is a relatively new addition. The lab at UW Madison performed extensive work on including GPU systems into gem5 in the early 2020's and the work is now contained in the upstream repository. The current architecture allows for full simulation of the AMD ROCm stack as well as AMD GPU systems (as of writing, up to the MI3000). 

GPU simulation in the gem5 can either be done entirely in simulation or by using a combination of simulated and host resources. As you can imagine, full simulation of CPU systems with discrete GPGPU's and their workloads would be time consuming, so gem5 has additional support for allowing the host system to perform workloads using the KVM ISA extension for x86 CPU's in order to decrease execution time. Our simulations will take advantage of this capability in order to simulate training a classifier for the MNIST dataset on a simulated AMD GPU.

## GPU Cores

Since we are studying AMD systems, we will use AMD terminology. Below is a table that compares the AMD terms with the NVIDIA terms for those with familiarity in the NVIDIA CUDA stack:

| **Component**        | **NVIDIA Term**               | **AMD Term**                   |
|----------------------|--------------------------------|--------------------------------|
| Processing Unit      | Streaming Multiprocessor (SM) | Compute Unit (CU)              |
| Execution Group      | Warp (32 threads)             | Wavefront (64 threads)         |
| Processing Core      | CUDA Core                     | SIMD Lane or Processing Element|
| Thread Group         | Thread Block                  | Workgroup                      |
| Individual Thread    | Thread                        | Thread                         |

The term 'thread' might be a bit misleading in the context of a GPU, because a thread is significantly different on a GPU than a CPU relative to the software interface we use to program it. Instead of executing programs as a sequence of _individual_ instructions, GPU's execute a Workgroup. So a collection of individual threads, sometimes taken from different wavefronts, are done in parallel. The caveat of this system of execution is that every thread needs to be performing the same operation.

It falls to the Processing element to perform this operation. The Processing element is not dissimilar to your vector ALU on a CPU. It will consume a vector (or two) of inputs and then perform an operation on them. In fact, in more modern GPU systems, sometimes there are entire processing elements dedicated to matrix multiplication (see NVIDIA's tensor cores and spare tensor cores [see here](LIIIINK).

## Warp Divergence

Recall the topic of warp divergence. The assignment will give you a better sense of its impact on performance but this section will explain what it is and provide an example.

Warp divergence happens when some threads executing on an SM follow one path of execution and some threads follow another.

```c++
__global__ void processArrays(int* A, int* B, int* C, int N) {
    int tid = threadIdx.x;
    
    if (tid < N) {
        if (A[tid] % 2 == 0) {
            C[tid] = A[tid] + B[tid];
        } else {
            C[tid] = A[tid];
        }
    }
}
```

`__global__` indicates that this is a kernel to be run and `threadIdx.x` specifies this thread's ID. The kernel uses the ID to index the arrays.

The above code does something very arbitrary and when an element of `A` is even, it sets the corresponding element of `C` to the sum of `A` and `B` at that index. If odd, it sets `C` to `A` at that index.

Notice the two potential sources of divergence. If the number of threads we have isn't a multiple of 32, there will be a single warp where some elements are less than `N` and some greater than `N`. Second, if it's the case that some elements of `A` accessed in a warp are even and some are odd, we would have divergence in our second `if`-statement.

Recall how threads in a warp execute together and how scheduling is done at a warp level. To avoid threads that didn't take a certain branch of execution from executing instructions from that branch, masking is used. Masking controls which threads should be involved in executing an instruction, with threads whose mask value is set to 0 performing no-ops while threads whose mask value is set to 1 end up executing instructions. When there's a conditional that causes warp divergence, the hardware saves mask values for all possible paths of execution after a conditional statement and uses the appropriate one when executing a condition that was true on only a subset of branches.

On Nvidia GPUs, warp divergence was traditionally with a stack (SIMT stack). More recent cards, however, use a barrier-based approach. More details about how they work can be found in [this textbook](https://link.springer.com/book/10.1007/978-3-031-01759-9).
