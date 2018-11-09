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

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

int running; // Indicates whether the program is running

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
void DataInStream(char infname[], chanend c_out, chanend fromController)
{
  int res, start;
  uchar line[ IMWD ];

  fromController :> start;
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
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
void distributor(chanend c_in, chanend c_out, chanend fromController)
{
  uchar image[IMHT][IMWD];

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> int value;

  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Waiting for image...\n" );
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> image[y][x];                    //read the pixel value
    }
  }

  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          c_out <: image[y][x]; //send some modified pixel out
      }
  }

  printf( "\nOne processing round completed...\n" );
}



void controller(chanend toDistributor, chanend fromAccelerometer, chanend fromButtonListener, chanend toleds, chanend dataIn, chanend dataOut){
    while(running == 0){
        int buttonPress;
        fromButtonListener :> buttonPress;
        if(buttonPress == 14){
            dataIn <: 1; // Tell dataIn to read in the data
            toleds <: 1; // Set leds to state 1 (green on)
            dataIn :> buttonPress;// doesn't matter what this is, just that we get it. Indicates reading data is over.

            toleds <: 2; // Set leds to state 2 (green flash)
            running = 1; // Set running to 1.
        }
    }



}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Buttons
//
/////////////////////////////////////////////////////////////////////////////////////////

//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromController) {
    int pattern; //1st bit...separate green LED
                 //2nd bit...blue LED
                 //3rd bit...green LED
                 //4th bit...red LED

    while (1) {
        fromController :> pattern;     //receive new pattern from visualiser
        p <: pattern;                  //send pattern to LED port
    }
    return 0;
}

//READ BUTTONS and send button pattern to userAnt
void buttonListener(in port b, chanend toController) {
    int r;
    while (1) {
        b when pinseq(15)  :> r;    // check that no button is pressed
        b when pinsneq(15) :> r;    // check if some buttons are pressed
        if ((r==13) || (r==14))     // if either button is pressed
            toController <: r;         // send button pattern to userAnt
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in, chanend fromController)
{
  int res, start;
  uchar line[ IMWD ];

  while(1) {
      fromController :> start;

      //Open PGM file
      printf( "DataOutStream: Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
        return;
      }

      //Compile each line of the image and write the image line-by-line
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
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
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

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan c_inIO, c_outIO, c_orientation, c_buttonListener, c_distributor, c_leds, c_controllerIn, c_controllerOut;    //extend your channel definitions here

running = 0;

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);               //server thread providing orientation data
    orientation(i2c[0], c_orientation);                 //client thread reading orientation data
    buttonListener(buttons, c_buttonListener);          //thread reading button information data
    showLEDs(leds, c_leds);                             //thread setting LEDs
    DataInStream(infname, c_inIO, c_controllerIn);           //thread to read in a PGM image
    DataOutStream(outfname, c_outIO, c_controllerOut);        //thread to write out a PGM image
    distributor(c_inIO, c_outIO, c_distributor);            //thread to coordinate work on image
    controller(c_distributor, c_orientation, c_buttonListener, c_leds, c_controllerIn, c_controllerOut); // Controller thread.
  }

  return 0;
}
