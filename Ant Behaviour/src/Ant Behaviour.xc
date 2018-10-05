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


void moveAntEast(Ant a){
    a.y++;
    a.y %= 4;
}

void moveAntSouth(Ant a){
    a.x++;
    a.x %= 3;
}

int getContent(const unsigned char w[3][4], int x, int y){
    return w[x%3][y%4];
}

void ant(const unsigned char w[3][4], Ant a){
    // Move twice, print info
    if(getContent(w,a.x+1,a.y) > getContent(w,a.x,a.y+1)) moveAntSouth(a);
    else moveAntEast(a);
    a.foodCount += getContent(w,a.x,a.y);

    if(getContent(w,a.x+1,a.y) > getContent(w,a.x,a.y+1)) moveAntSouth(a);
    else moveAntEast(a);
    a.foodCount += getContent(w,a.x,a.y);

    printf("%i:: %i\n", a.id, a.foodCount);
}

void initAnts(Ant a[], int n) {
//    for(int i = 0; i < sizeof(world)/sizeof(world[0]); i ++){
//        for(int j = 0; j < sizeof(world[0]); j++){
//
//        }
//    }
    for(int i = 0; i < n; i ++) {
        a[i].x = rand() % 3;
        a[i].y = rand() % 4;
        a[i].id = i;
        a[i].foodCount = 0;
    }
}

int main(void) {
    // Init 4 Ants
    Ant ants[4];
    initAnts(ants, 4);

    // Run 4 threads in parallel, each controlling a different Ant
    par{
        ant(world, ants[0]);
        ant(world, ants[1]);
        ant(world, ants[2]);
        ant(world, ants[3]);
    }

    return 0;
}
