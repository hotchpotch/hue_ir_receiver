#include <IRremote.h>

int RECV_PIN = 11;
unsigned int WAIT = 50;

IRrecv irrecv(RECV_PIN);

void setup()
{
  Serial.begin(9600);
  irrecv.enableIRIn();
  Serial.println("SETUP");
}

decode_results results;
unsigned long last = 0;

void loop()
{
  if (irrecv.decode(&results)) {
    if (last + WAIT < WAIT) {
      // for millis() overflow, uptime over 50 days.
      Serial.println("overflow");
      last = 0;
    }

    if (millis() - last > WAIT) {
      Serial.print("IR,");
      Serial.print(results.value, HEX);
      Serial.println("");
    }
    last = millis();
    irrecv.resume();
  }
}
