// This assumes the kernel has the VFIO platform driver built into it (as a module)
// The AXI DMA should be in the device tree with the iommu property.

// The vfio driver is used with the following commands prior to running this test application.
// Maybe it can be used from the device tree like UIO, but not sure yet.

#define REG(reg_addr) *(volatile int*)(reg_addr)

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#include <sys/fcntl.h>
#include <sys/mman.h>

#include <time.h>

int main(int argc, char **argv)
{
    int fd;
    int src;
    int dst;
    int reg;

    if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) < 0) {
      perror("open");
      return -1;
    }
    reg = (int)mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x40400000);
    src = (int)mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x1c000000);
    dst = (int)mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x1e000000);

	// fill with random data
	int c;
	srand(time(NULL));
	for(c = 0; c < 100; c++) {
      REG(src + c*4) = rand();
	}

	printf("source value: 0x%x\n", src);
	printf("destination value: 0x%x\n", dst);

	// AXI DMA transfer, with tx looped back to tx, no SG, polled I/O
	// reset both tx and rx channels and wait for the reset to clear for the last one

    REG(reg + 0x00) = 4;
	REG(reg + 0x30) = 4;

	while (REG(reg + 0x30) & 0x4);

	// Start the rx transfer

	REG(reg + 0x30) = 1;
	REG(reg + 0x48) = 0x1e000000;
	REG(reg + 0x4c) = 0;
	REG(reg + 0x58) = 100*4;

	// Start the tx transfer

	REG(reg) = 1;
	REG(reg + 0x18) = 0x1c000000;
	REG(reg + 0x1c) = 0;
	REG(reg + 0x28) = 100*4;

	// Wait for the rx to finish

	while ((REG(reg + 0x34) & 0x1000) != 0x1000);

	// Compare the destination to the source to make sure they match after the DMA transfer

	int fail_count = 0;

	for(c = 0; c < 100; c++) {
		if(REG(src + c*4) != REG(dst + c*4)) {
			printf("test failed! - %d - 0x%x - 0x%x\n", c, REG(src + c*4), REG(dst + c*4));
			fail_count++;
		}
	}
	if (!fail_count)
		printf("test success\n");

	printf("source value: 0x%x\n", src);
	printf("destination value: 0x%x\n", dst);

	return 0;
}

