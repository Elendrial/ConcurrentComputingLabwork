// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
#include <stdbool.h>

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
#define  PTHT 4                   //image part height
#define  PTNM (IMHT%PTHT ? IMHT/PTHT+1: IMHT/PTHT)  //number of image parts

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend toDistributor, chanend fromController){
    int res, start;
    uchar line[ IMWD ];

    fromController :> start;
    printf("DataInStream: Start...\n");

    //Open PGM file
    res = _openinpgm( infname, IMWD, IMHT );
    printf("dataIn tried open pgm\n");fflush(stdout);
    if( res ) {
        printf( "DataInStream: Error openening %s\n.", infname );
        return;
    }
    else{
        printf( "DataIn: Opened pic successfully" );
    }

    printf( "DataInStream: Reading image.");fflush(stdout);
    //Read image line-by-line and send byte by byte to channel c_out
    for( int y = 0; y < IMHT; y++ ) {
        _readinline( line, IMWD );
        for( int x = 0; x < IMWD; x++ ) {
            toDistributor <: line[ x ];
            printf( "-%4.1d ", line[ x ] ); //show image values
        }
        printf( "\n" );
    }

    //Close PGM image file
    _closeinpgm();

    printf( "DataInStream: Done...\n" );
    fromController <: 0;
    return;
}

//WAIT function
void waitMoment(int tenNano) {
    timer tmr;
    int waitTime;
    tmr :> waitTime;                       //read current timer value
    waitTime += tenNano;                  //set waitTime to 0.4s after value
    tmr when timerafter(waitTime) :> void; //wait until waitTime is reached
}

/////// The Rules of Game of Life

int isAliveNextRound(int i[9]){
    int middleAlive = i[4];
    int amountAlive = 0;
    for(int c = 0; c < 9; c++){
        if(c) amountAlive++;
    }

    int alive = 0;

    if(middleAlive && amountAlive > 1 && amountAlive < 4) alive = 1;
    else if(!middleAlive && amountAlive > 2) alive = 1;

    return 0;

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void assignToWorkers(int index, uchar image[IMHT][IMWD], chanend toWorker[PTNM]) {

    for(int i = index*PTHT - 1; i <= (index+1)*PTHT; i ++) {
        printf("dist assigning %d!!!\n",index);fflush(stdout);
        for(int j = 0; j < IMWD; j ++)
            toWorker[index] <: image[(i+IMHT)%IMHT][j];
    }
}

void receiveFromWorkers(int index, uchar image[IMHT][IMWD], chanend toWorker[PTNM]) {

    for(int i = index*PTHT; i <= (index+1)*PTHT - 1; i ++) {
        printf("dist receiving %d!!!\n",index);fflush(stdout);
        for(int j = 0; j < IMWD; j ++) {
            toWorker[index] :> image[(i+IMHT)%IMHT][j];
        }
    }
}


void distributor(chanend fromDataIn, chanend toDataOut, chanend fromController, chanend toWorker[PTNM]){
    uchar image[IMHT][IMWD];

    //Starting up and wait for tilting of the xCore-200 Explorer
    printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );

    //Read in and do something with your image values..
    //This just inverts every pixel, but you should
    //change the image according to the "Game of Life"
    printf( "Waiting for image...\n" );
    for( int y = 0; y < IMHT; y++ ) {   //go through all lines
        for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
            fromDataIn :> image[y][x];                    //read the pixel value
        }
    }

    int lineIndex;
    int process;
    while(1){
        // Ping the controller ask what to do
        fromController <: 1;
        fromController :> process;
        if(process == 0){ // 0: process normally
            // Let workers process image parts
            par{
                for(int index = 0; index <PTNM; index ++) {
                    assignToWorkers(index, image, toWorker);
                    receiveFromWorkers(index, image, toWorker);
                }
            }
            printf( "\nOne processing round completed...\n" );
        }

        else if(process == 2){ // 2: export the 'image'
            for( int y = 0; y < IMHT; y++ ) {
                for( int x = 0; x < IMWD; x++ ) {
                    toDataOut <: image[y][x]; // Send the image to dataOut
                }
            }

            // Tell the controller that we're done exporting.
            fromController <: 0;
        }

        else{ // 1 (or any undefined number): do nothing.
            waitMoment(25000000); // wait quarter of a second
        }
    }
}

void imgPartWorker(chanend fromDistributor) {
    uchar imgPart[PTHT+2][IMWD], newImgPart[PTHT][IMWD];

    // receive from distributor

    for(int i = 0; i < PTHT+2; i ++){
        printf("worker reveiving %d!!!\n",i);fflush(stdout);
        for(int j = 0; j < IMWD; j++)
            fromDistributor :> imgPart[i][j];
    }

    printf("worker processing!!!\n");fflush(stdout);
    // process image
    int dx[9] = {-1,0,1,-1,0,1,-1,0,1};
    int dy[9] = {-1,-1,-1,0,0,0,1,1,1};

    for(int i = 1; i <= PTHT; i ++) {
        for(int j = 0; j < IMWD; j++){
            int nearby[9];
            for(int k = 0; k < 9; k ++)
                nearby[k] = imgPart[i+dy[k]][(j+dx[k]+IMWD)%IMWD];
            newImgPart[i-1][j] = isAliveNextRound(nearby) * 255;
        }
    }

    // send result to distributor
    printf("worker sending!!!\n");fflush(stdout);
    for(int i = 0; i < PTHT; i ++)
        for(int j = 0; j < IMWD; j++)
            fromDistributor <: imgPart[i][j];
}




void controller(chanend toDistributor, chanend fromAccelerometer, chanend fromButtonListener, chanend toleds, chanend dataIn, chanend dataOut){
    int running = 0;

    while(running == 0){
        int buttonPress;
        fromButtonListener :> buttonPress;
        printf( "Controller got from button listner\n" );

        // If start button pushed...
        if(buttonPress == 14){
            dataIn <: 1; // Tell dataIn to read in the data
            printf( "Controller activated dataIn\n" );
            toleds <: 1; // Set leds to state 1 (green on)
            printf( "Controller activated led (on)\n" );

            dataIn :> buttonPress; // If we hear from dataIn, we know data reading is over.
            toleds <: 2; // Set leds to state 2 (green flash)
            printf( "Controller activated led (flash)\n" );
            running = 1; // Set running to 1.
        }
    }

    int input;
    int paused = 0; // 0: not paused           1: paused
    int toExport = 0;
    while(1){
        select{
            case toDistributor :> input:
                switch(input){
                case 1: // Asking whether to processs
                    if(toExport == 1){
                        toDistributor <: 2; // Export
                        toleds <: 4;        // Blue light
                        toExport = 0;

                        // TODO: Check that this doesn't block anything, should be fine. If there are issues, change this.
                        toDistributor :> int; // Wait until we're done exporting
                        toleds <: 0;          // Turn off the leds
                    }
                    else toDistributor <: paused;

                    if(paused == 0) toleds <: 2; // If not paused, flash to indicate processing.
                    else 			toleds <: 3; // If paused, show Red light
                    break;
                }

                break;

            case fromAccelerometer :> input:
                // If we hear from the accelerometer, it means we toggle the pause.
                // However, to avoid getting out of sync, we just pass the pause value instead of a toggle.

                switch(input){
                case 0: // Set paused off
                    paused = 0;
                    break;
                case 1: // Set paused on
                    paused = 1;
                    break;
                }

                break;

            case fromButtonListener :> input:
                if(input == 13) // 13: button sw2
                    toExport = 1;
                break;

            case dataIn :> input:
                // Shouldn't be anything, may just delete
                break;

            case dataOut :> input:
                // Shouldn't be anything, may just delete
                break;
        }
    }


}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Buttons
//
/////////////////////////////////////////////////////////////////////////////////////////

// Decodes LED pattern
void controlLEDs(out port p, chanend fromController) {
    int state, toPort;

    while(1){
        fromController :> state;

        switch(state){

        case 0: toPort = 0; break; // Nothing

        case 1: toPort = 4; break; // Separate green light

        case 2:
            toPort = 0;
            p <: toPort;
            waitMoment(50000000);
            toPort = 1;			   // Normal green light
            p <: toPort;
            waitMoment(50000000);
            toPort = 0;
            p <: toPort;
            waitMoment(50000000);
            toPort = 1;
            break;

        case 3: toPort = 8;	break; // Red light
        case 4: toPort = 2; break; // Blue light
        }

        p <: toPort;
    }
}



//READ BUTTONS and send button pattern to userAnt
void buttonListener(in port b, chanend toController) {
    int r;
    // TODO: Allow this to end gracefully.
    while (1) {
        b when pinseq(15)  :> r;    // check that no button is pressed
        b when pinsneq(15) :> r;    // check if some buttons are pressed
        if ((r==13) || (r==14))     // if either button is pressed - 13: SW2, 14: button SW1
            toController <: r;         // send button pattern to userAnt
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in, chanend fromController){
    int res, start;
    uchar line[ IMWD ];

    // TODO: Make this note a while(1), and allow it to end down gracefully.
    while(1) {
        fromController :> start;

        //Open PGM file
        printf( "DataOutStream: Start...\n" );
        res = _openoutpgm( outfname, IMWD, IMHT );
        if( res ) {
            printf( "DataOutStream: Error opening %s\n.", outfname );
            return;
        }

        //Compile ea ch line of the image and write the image line-by-line
        for( int y = 0; y < IMHT; y++ ) {
            for( int x = 0; x < IMWD; x++ ) {
                c_in :> line[ x ];
            }
            _writeoutline( line, IMWD );
            printf( "DataOutStream: Line written...\n" );
        }

        //Close the PGM image
        _closeoutpgm();
        printf( "DataOutStream: Done...\n" );
        fromController <: 0;
    }
    return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation(client interface i2c_master_if i2c, chanend toController) {
    i2c_regop_res_t result;
    char status_data = 0;
    int tilted = 0;

    // Configure FXOS8700EQ
    result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C write reg failed\n");
    }
  
    // Enable FXOS8700EQ
    result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
    if (result != I2C_REGOP_SUCCESS) {
        printf("I2C write reg failed\n");
    }

    //Probe the orientation x-axis forever

    while(1){
        //check until new orientation data is available
        do {
            status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
        } while (!status_data & 0x08);

        //get new x-axis tilt value
        int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

        //send signal to distributor after first tilt
        if (tilted == 0 && x > 30) {
            toController <: 1;
            tilted = 1;
        }
        else if(tilted == 1 && x < 30){
            toController <: 0;
            tilted = 0;
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

    i2c_master_if i2c[1];               //interface to orientation

    char infname[] = "test.pgm";        //put your input image path here
    char outfname[] = "testout.pgm";    //put your output image path here
    chan c_inIO, c_outIO, c_orientation, c_buttonListener, c_distributor, c_leds, c_controllerIn, c_controllerOut, c_worker[PTNM];    //extend your channel definitions here

    par {
        i2c_master(i2c, 1, p_scl, p_sda, 10);                   //server thread providing orientation data
        orientation(i2c[0], c_orientation);                     //client thread reading orientation data
        buttonListener(buttons, c_buttonListener);              //thread reading button information data
        controlLEDs(leds, c_leds);                              //thread setting LEDs
        DataInStream(infname, c_inIO, c_controllerIn);          //thread to read in a PGM image
        DataOutStream(outfname, c_outIO, c_controllerOut);      //thread to write out a PGM image
        distributor(c_inIO, c_outIO, c_distributor, c_worker);  //thread to coordinate work on image
        for(int i = 0; i < PTNM; i ++) {                        // threads to process image
            imgPartWorker(c_worker[i]);
        }
        controller(c_distributor, c_orientation, c_buttonListener, c_leds, c_controllerIn, c_controllerOut); // Controller thread.
    }

    return 0;
}
