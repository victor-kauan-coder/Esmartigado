#include <ESP8266WiFi.h>
#include <WebSocketsClient.h>

const char* ssid = "SSID";
const char* password = "PASSWORD";

const char* nodeRedIP = "IP_ADDRESS"; 
const uint16_t nodeRedPort = 1880;

WebSocketsClient webSocket;

const int trigPin = 5;  // D1
const int echoPin = 4;  // D2

// Função que faz 3 leituras e pega a mediana (ignora ruídos do outro sensor)
float medirDistanciaComFiltro() {
  float leituras[3];
  
  for(int i = 0; i < 3; i++) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    
    noInterrupts(); // Proteção contra Wi-Fi
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);
    long duracao = pulseIn(echoPin, HIGH, 30000);
    interrupts();   // Religa
    
    float dist = (duracao * 0.0343) / 2.0;
    if (dist > 400.0 || dist < 2.0) dist = 0.0;
    leituras[i] = dist;
    
    delay(40); 
  }
  

  if (leituras[0] > leituras[1]) { float temp = leituras[0]; leituras[0] = leituras[1]; leituras[1] = temp; }
  if (leituras[1] > leituras[2]) { float temp = leituras[1]; leituras[1] = leituras[2]; leituras[2] = temp; }
  if (leituras[0] > leituras[1]) { float temp = leituras[0]; leituras[0] = leituras[1]; leituras[1] = temp; }
  
  if (leituras[1] == 0.0 && leituras[2] > 0) return leituras[2]; 
  return leituras[1];
}

void setup() {
  Serial.begin(115200);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[Wi-Fi] Conectado!");

  webSocket.begin(nodeRedIP, nodeRedPort, "/racao");
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_TEXT) {
    
    String comando = "";
    for(size_t i = 0; i < length; i++) {
        comando += (char)payload[i];
    }
    comando.trim(); 
    
    if (comando == "medir") {
      Serial.println("Comando recebido! Fazendo leitura filtrada...");
      
      float distancia = medirDistanciaComFiltro();
      
      String json = "{\"distancia_cm\":" + String(distancia, 2) + "}";
      webSocket.sendTXT(json);
      Serial.println("Enviado: " + json);
    }
  }
}

void loop() {
  webSocket.loop(); 
}