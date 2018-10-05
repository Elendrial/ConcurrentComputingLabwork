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
} Ant;

const unsigned char world[3][4] = {{10, 0,  7, 2},
                                   {11, 5, 13, 9},
                                   { 7, 2,  3, 6},
};


void moveAnt(Ant a, int x, int y){
    a.x+=x;
    a.y+=y;
}

void initAnts(Ant a[4]) {
//    for(int i = 0; i < sizeof(world)/sizeof(world[0]); i ++){
//        for(int j = 0; j < sizeof(world[0]); j++){
//
//        }
//    }
    for(int i = 0; i < 4; i ++) {
        a[i].x = rand() % 3;
        a[i].y = rand() % 4;
    }
}

int main(void) {

}
