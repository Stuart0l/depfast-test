#include <stdio.h>
#include <pthread.h>
#include <string.h>
#include <stdlib.h>

#define NUM_THREADS     5
// filesizes represents the value in MB, for eg, 2000 for 2000MB.
int filesizes[NUM_THREADS] = {2000,2000,2000,2000,2000};
const int mb_size = 1024;

void *WriteToFile(void *threadid)
{
      char a[1024];
      FILE* pFile;
      char snum[5];

      int tid = (int)threadid;
      printf("Thread #%d!\n", tid);
      int size = mb_size * filesizes[tid];
      printf("size: %u\n", size);
      sprintf(snum, "%d", tid);
      char filename[30] = "/data1/tmpfile";
      strcat(filename, snum);
      printf("filename: %s\n", filename);

      // w option truncates the file to 0 if it already exists or creates new
      // one if it does not
      pFile = fopen(filename, "wb");
      for (int j = 0; j < size; ++j){
        fwrite(a, 1, 1024*sizeof(char), pFile);
      }

      fflush(pFile);
      // fsync the file
      fsync(fileno(pFile));
      fclose(pFile);

      pthread_exit(NULL);
}

void disk_contention()
{
      pthread_t threads[NUM_THREADS];
      int rc, i, t;
      for(t=0; t<NUM_THREADS; t++){
        printf("Creating disk contention thread %t\n", t);
        rc = pthread_create(&threads[t], NULL, WriteToFile, (void *)t);
        if (rc){
          printf("ERROR; return code from pthread_create() is %d\n", rc);
          exit(-1);
        }
      }

      // Wait for all threads to complete
      for (i=0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
      }
}

int main() {
  while(1) {
     disk_contention();
  }

  return 0;
}


