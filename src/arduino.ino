#include <FastLED.h>

#define LED_PIN 6
#define NUM_LEDS 178
#define BRIGHTNESS 160

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
  const int DURATION_MS = 3000;   // тривалість тесту
  const int FRAME_DELAY = 20;     // швидкість анімації
  const int STEPS = DURATION_MS / FRAME_DELAY;

  uint8_t baseHue = 0;

  for (int step = 0; step < STEPS; step++) {

    for (int i = 0; i < NUM_LEDS; i++) {
      // зсув кольору по довжині стрічки
      uint8_t hue = baseHue + (i * 256 / NUM_LEDS);
      leds[i] = CHSV(hue, 255, 255);
    }

    FastLED.show();
    baseHue++;        // рухаємо спектр вперед
    delay(FRAME_DELAY);
  }

  // Плавне згасання
  for (int b = BRIGHTNESS; b >= 0; b -= 5) {
    FastLED.setBrightness(b);
    FastLED.show();
    delay(15);
  }

  FastLED.setBrightness(BRIGHTNESS);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
}