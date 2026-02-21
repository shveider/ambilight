#include <FastLED.h>

#define LED_PIN 6
#define NUM_LEDS 178
#define BRIGHTNESS 180

#define START_BYTE 255
#define END_BYTE 254

CRGB leds[NUM_LEDS];

const int FRAME_SIZE = NUM_LEDS * 3;

byte buffer[FRAME_SIZE];
int bufferIndex = 0;
bool receiving = false;

void setup() {
  Serial.begin(230400);
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);

  runStartupTest();
}


void loop() {
  while (Serial.available()) {
    byte incoming = Serial.read();

    if (!receiving) {
      if (incoming == START_BYTE) {
        receiving = true;
        bufferIndex = 0;
      }
    } else {
      if (incoming == END_BYTE) {
        if (bufferIndex == FRAME_SIZE) {
          applyFrame();
        }
        receiving = false;
      } else {
        if (bufferIndex < FRAME_SIZE) {
          buffer[bufferIndex++] = incoming;
        }
      }
    }
  }
}

void applyFrame() {
  for (int i = 0; i < NUM_LEDS; i++) {
    int idx = i * 3;
    leds[i] = CRGB(
      buffer[idx],
      buffer[idx + 1],
      buffer[idx + 2]
    );
  }

  FastLED.show();
}

void runStartupTest() {
  const int DURATION_MS = 2000;
  const int STEPS = 256;
  const int DELAY = DURATION_MS / STEPS;

  // Прогін по спектру (HSV — H від 0 до 255)
  for (int h = 0; h < 256; h++) {
    fill_solid(leds, NUM_LEDS, CHSV(h, 255, 255));
    FastLED.show();
    delay(DELAY);
  }

  // Гасимо після тесту
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
}