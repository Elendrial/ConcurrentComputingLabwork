/*
 * Ant Behaviour.xc
 *
 *  Created on: 5 Oct 2018
 *      Author: laurence
 */

#include <stdio.h>
#include <stdlib.h>

typedef struct ant{
    int x;
    int y;
    int id;
    int foodCount;
} Ant;

const unsigned char world[3][4] = {{10,  0, 1, 7},
                                   { 2, 10, 0, 3},
                                   { 6,  8, 7, 6},
};


Ant moveAntEast(Ant a){
    a.y++;
    a.y %= 4;
    return a;
}

Ant moveAntSouth(Ant a){
    a.x++;
    a.x %= 3;
    return a;
}

int getContent(const unsigned char w[3][4], int x, int y){
    return w[x%3][y%4];
}

Ant antMove(const unsigned char w[3][4], Ant a){
    if(getContent(w,a.x+1,a.y) > getContent(w,a.x,a.y+1))
        a = moveAntSouth(a);
    else
        a = moveAntEast(a);

    a.foodCount += getContent(w,a.x,a.y);

    return a;
}

void ant(const unsigned char w[3][4], Ant a, chanend antChan){
    int temp;
    while(1){
        antChan <: getContent(w, a.x, a.y);
        printf("And %i has collected %i food.\n", a.id,  a.foodCount);
        antChan :> temp;

        a = antMove(w, a);
    }
}

// An actually Ant isn't really needed here... but it asks for it, so I've done it
void queen(Ant queen, chanend antChans[], int n){
    int highestIndex, highestValue, temp;

    while(1){
        highestIndex = -1;
        highestValue = -1;
        for(int i = 0; i < n; i++){
            antChans[i] :> temp;
            if(temp > highestValue){
                highestIndex = i;
                highestValue = temp;
            }
        }

        for(int i = 0; i < n; i++){
            antChans[i] <: (i == highestIndex ? 1 : 0);
        }
    }
}

void initBlankAnts(Ant a[], int n){
    for(int i = 0; i < n; i++){
        a[i].x = 0;
        a[i].y = 0;
        a[i].id = i;
        a[i].foodCount = 0;
    }
}

/* Unused */
void initRandomAnts(Ant a[], int n) {
    for(int i = 0; i < n; i ++) {
        a[i].x = rand() % 3;
        a[i].y = rand() % 4;
        a[i].id = i;
        a[i].foodCount = 0;
    }
}

int main(void) {
    // Init 2 Worker Ants, one at 0,1 and one at 1,0, and a queen at 1,1 (Queen is ant[2])
    Ant ants[3];

    initBlankAnts(ants, 3);
    ants[0].x = 1;
    ants[1].y = 1;

    ants[2].x = 1;
    ants[2].y = 1;

    chan antChans[2];

    par{
        ant(world, ants[0], antChans[0]);
        ant(world, ants[1], antChans[1]);
        queen(ants[2], antChans, 2);
    }

    return 0;
}
