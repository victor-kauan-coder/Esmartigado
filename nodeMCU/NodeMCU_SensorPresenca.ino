#include <ESP8266WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>          

const char* ssid     = "SSID";
const char* password = "PASSWORD";

const char* WS_HOST = "IP";
const int   WS_PORT = 1880;
const char* WS_PATH = "/racao";

const int trigPin = D1;
const int echoPin = D2;
const int ledPin  = D3;

const int   LIMIAR_PRESENCA_CM  = 30;
const int   HISTERESE_CM        = 5;
const unsigned long INTERVALO_PRESENCA_MS = 500;

WebSocketsClient webSocket;
bool wsConectado       = false;
bool gadoPresente      = false;
unsigned long ultimaVerificacaoPresenca = 0;


float medirDistanciaCm() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  noInterrupts(); 
  
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000);  
  
  interrupts(); 
  
  if (duration == 0) return -1;                   
  return duration * 0.0343f / 2.0f;
}

void enviarPresenca(float distCm, bool presenca) {
  StaticJsonDocument<128> doc;
  doc["tipo"]         = "presenca";
  doc["presenca"]     = presenca;
  doc["distancia_cm"] = (int)distCm;

  String payload;
  serializeJson(doc, payload);
  webSocket.sendTXT(payload);

  Serial.print("[PRESENÇA] ");
  Serial.print(presenca ? "GADO DETECTADO" : "Livre");
  Serial.print(" | dist: ");
  Serial.print(distCm);
  Serial.println(" cm");
}

void webSocketEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      wsConectado = true;
      Serial.println("[WS] Conectado ao Node-RED");
      break;

    case WStype_DISCONNECTED:
      wsConectado = false;
      Serial.println("[WS] Desconectado – reconectando...");
      break;

    default:
      break;
  }
}


void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(ledPin,  OUTPUT);
  digitalWrite(ledPin, LOW);

  Serial.print("\n[WiFi] Conectando a ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("[WiFi] Conectado! IP: ");
  Serial.println(WiFi.localIP());

  webSocket.begin(WS_HOST, WS_PORT, WS_PATH);
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(3000);

  Serial.println("[Sistema] Pronto.");
}

void loop() {
  webSocket.loop();

  unsigned long agora = millis();

  if (agora - ultimaVerificacaoPresenca >= INTERVALO_PRESENCA_MS) {
    ultimaVerificacaoPresenca = agora;

    float dist = medirDistanciaCm();

    if (dist > 0) {
      bool novoEstado;

      if (!gadoPresente) {
        novoEstado = (dist <= LIMIAR_PRESENCA_CM);
      } else {
        novoEstado = (dist <= (LIMIAR_PRESENCA_CM + HISTERESE_CM));
      }

      digitalWrite(ledPin, novoEstado ? HIGH : LOW);

      if (novoEstado != gadoPresente && wsConectado) {
        gadoPresente = novoEstado;
        enviarPresenca(dist, gadoPresente);
      } else {
        gadoPresente = novoEstado;
      }
    }
  }
}