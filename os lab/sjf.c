#include <stdio.h>
#include <limits.h>

struct Process {
    int pid;
    int arrivalTime;
    int burstTime;
    int remainingTime;
    int completionTime;
    int turnaroundTime;
    int waitingTime;
};

int main() {
    int n;
    printf("Enter number of processes: ");
    scanf("%d", &n);

    struct Process p[n];

    for (int i = 0; i < n; i++) {
        p[i].pid = i + 1;

        printf("Enter Arrival Time and Burst Time for P%d: ", i + 1);
        scanf("%d %d", &p[i].arrivalTime, &p[i].burstTime);

        p[i].remainingTime = p[i].burstTime;
    }

    int completed = 0;
    int currentTime = 0;
    float totalWaitingTime = 0;
    float totalTurnaroundTime = 0;

    while (completed != n) {
        int shortest = -1;
        int minRemainingTime = INT_MAX;

        for (int i = 0; i < n; i++) {
            if (p[i].arrivalTime <= currentTime &&
                p[i].remainingTime > 0 &&
                p[i].remainingTime < minRemainingTime) {

                minRemainingTime = p[i].remainingTime;
                shortest = i;
            }
        }

        if (shortest == -1) {
            currentTime++;
            continue;
        }

        p[shortest].remainingTime--;
        currentTime++;

        if (p[shortest].remainingTime == 0) {
            completed++;

            p[shortest].completionTime = currentTime;

            p[shortest].turnaroundTime =
                    p[shortest].completionTime - p[shortest].arrivalTime;

            p[shortest].waitingTime =
                    p[shortest].turnaroundTime - p[shortest].burstTime;

            totalWaitingTime += p[shortest].waitingTime;
            totalTurnaroundTime += p[shortest].turnaroundTime;
        }
    }

    printf("\nProcess\tAT\tBT\tCT\tTAT\tWT\n");

    for (int i = 0; i < n; i++) {
        printf("P%d\t%d\t%d\t%d\t%d\t%d\n",
               p[i].pid,
               p[i].arrivalTime,
               p[i].burstTime,
               p[i].completionTime,
               p[i].turnaroundTime,
               p[i].waitingTime);
    }

    printf("\nAverage Waiting Time = %.2f", totalWaitingTime / n);
    printf("\nAverage Turnaround Time = %.2f\n", totalTurnaroundTime / n);

    return 0;
}