package main

// import "unsafe"
// import "reflect"
// var buffer [1024]uint8;

const face_WIDTH = 8;
const face_HEIGHT = 8;
var face = [8]byte {
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

const bunny_WIDTH = 48;
const bunny_HEIGHT = 16;
const bunny_FLAGS = 1; // BLIT_2BPP
var bunny = [192]byte { 0x00,0x2c,0x0d,0x00,0x02,0x90,0x03,0xd0,0x02,0x90,0x03,0xd0,0x00,0xab,0x3f,0x40,0x0a,0xa4,0x0f,0xf4,0x0a,0xa4,0x0f,0xf4,0x00,0xab,0x3f,0x40,0x0a,0xa9,0x3f,0xf4,0x0a,0xa9,0x3f,0xf4,0x00,0x6b,0x3f,0x40,0x02,0xa9,0x57,0x50,0x02,0xa9,0x57,0x50,0x00,0x6b,0x57,0x40,0x00,0x69,0xa9,0x40,0x00,0x69,0xa9,0x40,0x00,0xab,0xa9,0x40,0x01,0xaa,0xaa,0x80,0x01,0xaa,0xaa,0x80,0x01,0xaa,0xaa,0x80,0x02,0xaa,0x5a,0x50,0x02,0xaa,0x5a,0x50,0x02,0xaa,0x5a,0x50,0x0f,0xea,0xaa,0x90,0x0f,0xea,0xaa,0x90,0x0f,0xea,0xaa,0x90,0x01,0xba,0xaa,0x90,0x01,0xba,0xaa,0x90,0x01,0xba,0xaa,0x90,0x00,0xea,0xab,0x40,0x00,0xea,0xab,0x40,0x00,0xea,0xab,0x40,0x01,0xaa,0xbd,0x00,0x00,0x6a,0x5d,0x00,0x00,0x6e,0xbd,0x00,0x0a,0xa6,0xaa,0x40,0x01,0xae,0xa6,0x40,0x01,0xba,0x6a,0x40,0x06,0x9a,0xaa,0x40,0x02,0xab,0xa6,0x40,0x01,0x9a,0x6a,0x40,0x01,0x6b,0xa9,0x40,0x01,0xda,0x5a,0x40,0x00,0x65,0xa9,0x00,0x06,0xad,0x57,0xd0,0x0f,0xf5,0x5a,0x90,0x00,0x1a,0xa4,0x00,0x01,0xa4,0x17,0x40,0x07,0xd0,0x06,0x90 };

var x = 76;
var y = 76;

//go:export update
func update () {
    var gamepad = *GAMEPAD1;
    if (gamepad & 16 != 0) {
        x -= 1;
    }
    if (gamepad & 32 != 0) {
        x += 1;
    }
    if (gamepad & 64 != 0) {
        y -= 1;
    }
    if (gamepad & 128 != 0) {
        y += 1;
    }

    *DRAW_COLORS = 0xfff2;
    blit(&face[0], x, y, face_WIDTH, face_HEIGHT, 0);

    *DRAW_COLORS = 0xff2f;
    drawText("Hello utf8 from GO\xff!", 0, 10);

    print("Hello utf8 Bruno!");

    // blit(&bunny[0], x, y, bunny_WIDTH, bunny_HEIGHT, bunny_FLAGS);
}