# Diagramas por objetivo de negocio

El [DFD general](02-PASTA-3-DFD.md) muestra todo el sistema. Aquí se corta ese mismo diagrama por cada objetivo de [PASTA I](01-PASTA-1-2.md): qué parte del sistema toca, qué amenaza lo pone en riesgo, qué debilidad del código la hace posible y qué control la detiene. Los IDs son los mismos de todo el proyecto: flujos `F`, amenazas `T` ([STRIDE](03-PASTA-4-STRIDE.md)), debilidades `V` ([etapa V](03b-PASTA-5-Vulnerabilidades.md)), PoC del [Hito 2](../hito-2/README.md), reglas `DET` del [Hito 3](../hito-3/README.md) y correcciones del [Hito 4](../hito-4/README.md).

Los diagramas están en Mermaid (GitHub los dibuja); las mismas imágenes en PNG, para la presentación, están en [`diagramas-objetivos/`](diagramas-objetivos/).

Cómo leerlos:

- Azul: actores y componentes del DFD (con el mismo ID).
- Rojo: amenaza o debilidad.
- Verde: control que ya funciona y tiene evidencia.
- Gris punteado: control propuesto que todavía no se implementó.

| Objetivo | Flujos del DFD | Amenazas | Debilidad / PoC | Control principal |
|---|---|---|---|---|
| ON-01 Catálogo confiable | F01, F02, F03/F04, F05/F06 | T-07, T-09, T-08 | V-01 → PoC-02 · V-06 | WAF DET-01 + consulta parametrizada (H4 Corrección 2) |
| ON-02 Cuentas protegidas | F01, F02, F03/F04, F06 (JWT) | T-05, T-07, T-01 | V-02 → PoC-01 · V-07, V-08, V-09 | WAF DET-01 + login parametrizado (H4 Corrección 1) |
| ON-03 Carritos y pedidos separados | F01, F02, F03/F04, F08/F09 | T-06, T-10, T-16 | V-03 → PoC-03 · V-04, V-05 | Verificación de dueño en el código (H4 Corrección 3). El WAF no lo ve |
| ON-04 Disponibilidad | F01, F02 | T-03, T-14 | Escaneo de métodos · ráfagas | Solo el WAF publica puerto; DET-03; límite de tasa pendiente |
| ON-05 Trazabilidad | F07, F12 y los flujos nuevos del SIEM (F13–F15) | T-04, T-12, T-13 | IDOR invisible para el WAF | Filebeat → Elastic → Kibana, DET-01..05 y dashboard |

## ON-01 · Consultas confiables al catálogo

El catálogo es público, pero lo que devuelve la búsqueda tiene que salir de la tabla `Products` y de nada más. La búsqueda es la entrada más expuesta de la tienda: el parámetro `q` llega directo a SQLite.

```mermaid
flowchart LR
  A1["A1 · Visitante<br/>busca un producto"]:::actor
  W["P1 · WAF<br/>ModSecurity + CRS"]:::comp
  API["P2 · API<br/>GET /rest/products/search"]:::comp
  DB[("D1 · SQLite<br/>Products")]:::comp

  A1 -->|"F01 · q=jugo"| W
  W -->|"F02"| API
  API -->|"F03 · SELECT ... LIKE"| DB
  DB -->|"F04 · filas"| API
  API -->|"F05/F06 · JSON"| A1

  T07["T-07 · Alterar la consulta<br/>con la búsqueda"]:::threat
  V01["V-01 · search.ts concatena q<br/>PoC-02 UNION SQLi · CVSS 7.5"]:::threat
  V06["V-06 · XSS en el DOM<br/>no cruza el WAF"]:::threat
  T07 -.-> V01
  V01 -.->|"ataca"| API
  V06 -.->|"solo en el navegador"| A1

  C1["DET-01 · CRS 942*<br/>DetectionOnly: alerta<br/>On: 403"]:::ok
  C2["H4 Corrección 2<br/>replacements de Sequelize"]:::ok
  C3["RS-07 · precios desde el<br/>catálogo en el servidor"]:::todo
  W --- C1
  API --- C2
  API --- C3

  classDef actor fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef comp fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef threat fill:#fde8e8,stroke:#c92a2a,color:#5c1111
  classDef ok fill:#e6f4ea,stroke:#2b8a3e,color:#123d1c
  classDef todo fill:#f1f3f5,stroke:#868e96,color:#343a40,stroke-dasharray: 5 5
```

Cómo lo pensamos: el WAF es la primera barrera, pero no es la corrección. Con el WAF en `DetectionOnly` el UNION de PoC-02 sigue devolviendo correos y hashes; la consulta parametrizada del H4 hace que el mismo payload se busque como texto y no devuelva nada. V-06 queda fuera de los dos controles porque el payload vive en el fragmento de la URL.

## ON-02 · Proteger las cuentas

El activo son las credenciales y el JWT que la API entrega al iniciar sesión. Si el login se puede saltar, todo lo demás (carritos, direcciones, pedidos) queda expuesto.

```mermaid
flowchart LR
  A1["A1 · Cliente<br/>inicia sesión"]:::actor
  W["P1 · WAF"]:::comp
  API["P2 · API<br/>POST /rest/user/login"]:::comp
  DB[("D1 · SQLite<br/>Users")]:::comp

  A1 -->|"F01 · email + password"| W
  W -->|"F02"| API
  API -->|"F03 · SELECT ... WHERE email"| DB
  DB -->|"F04 · usuario"| API
  API -->|"F05/F06 · JWT"| A1

  T05["T-05 · Fuerza bruta"]:::threat
  T07["T-07 · SQLi en el login<br/>V-02 · PoC-01 · CVSS 9.8"]:::threat
  T01["T-01 · Reusar un JWT robado<br/>V-08 clave en el código · V-09 6 h"]:::threat
  V07["V-07 · MD5 sin sal"]:::threat
  T05 -.-> API
  T07 -.->|"' OR 1=1--"| API
  T01 -.-> A1
  V07 -.-> DB

  C1["DET-01 · CRS 942100<br/>On: 403"]:::ok
  C2["H4 Corrección 1<br/>parámetros $1 y $2"]:::ok
  C3["RS-01 · límite de intentos"]:::todo
  C4["RS-11 · expiración y revocación"]:::todo
  W --- C1
  API --- C2
  API --- C3
  A1 --- C4

  classDef actor fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef comp fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef threat fill:#fde8e8,stroke:#c92a2a,color:#5c1111
  classDef ok fill:#e6f4ea,stroke:#2b8a3e,color:#123d1c
  classDef todo fill:#f1f3f5,stroke:#868e96,color:#343a40,stroke-dasharray: 5 5
```

Cómo lo pensamos: PoC-01 es el hallazgo más grave del proyecto (entra como administrador sin contraseña), por eso va primero en el H4. Las debilidades de sesión (V-08, V-09) y el hash MD5 (V-07) quedan como riesgo aceptado del laboratorio; están documentadas, no corregidas.

## ON-03 · Mantener separados carritos y pedidos

Cada cliente solo debe ver su carrito. Aquí el WAF no ayuda: la petición del ataque es idéntica a la legítima, solo cambia el número en la ruta.

```mermaid
flowchart LR
  A["A1 · Cliente A<br/>con su propio token"]:::actor
  W["P1 · WAF"]:::comp
  API["P2 · API<br/>GET /rest/basket/:id"]:::comp
  DB[("D1 · SQLite<br/>Baskets")]:::comp
  M[("D2 · MarsDB<br/>orders, reviews")]:::comp

  A -->|"F01 · /rest/basket/1"| W
  W -->|"F02 · petición válida,<br/>no hay regla que la marque"| API
  API -->|"F03 · findOne id"| DB
  DB -->|"F04 · carrito de B"| API
  API -->|"F05/F06"| A
  API -->|"F08/F09"| M

  T06["T-06 / T-10 · Acceso horizontal<br/>V-03 · PoC-03 · CVSS 6.5"]:::threat
  T16["T-16 · NoSQL $where<br/>V-04, V-05 · apagadas en Docker"]:::threat
  T06 -.->|"cambia el id"| API
  T16 -.-> M

  X["WAF: 200 en DetectionOnly<br/>y 200 en On"]:::gap
  C1["H4 Corrección 3<br/>where id + UserId del token<br/>ajeno: 403"]:::ok
  C2["RS-13 · esquema y operadores<br/>permitidos en MarsDB"]:::todo
  W --- X
  API --- C1
  M --- C2

  classDef actor fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef comp fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef threat fill:#fde8e8,stroke:#c92a2a,color:#5c1111
  classDef gap fill:#fff4e6,stroke:#e8590c,color:#5c2a05
  classDef ok fill:#e6f4ea,stroke:#2b8a3e,color:#123d1c
  classDef todo fill:#f1f3f5,stroke:#868e96,color:#343a40,stroke-dasharray: 5 5
```

Cómo lo pensamos: este objetivo es el argumento de por qué el WAF no basta. La autorización por recurso solo se puede hacer en la aplicación, que es la que sabe de quién es cada carrito. La corrección cubre `GET /rest/basket/:id`; el checkout (`POST /rest/basket/:id/checkout`) tiene el mismo patrón y queda anotado como riesgo pendiente.

## ON-04 · Mantener la disponibilidad

Que la tienda siga respondiendo a clientes normales mientras alguien la escanea o le manda ráfagas. Es el objetivo con menos controles implementados, y se dice tal cual.

```mermaid
flowchart LR
  A1["A1 · Cliente normal"]:::actor
  R["Actor abusivo<br/>ráfagas o escaneo"]:::threat
  W["P1 · WAF<br/>127.0.0.1:8080"]:::comp
  API["P2 · API :3000<br/>expose, sin ports"]:::comp
  DB[("D1 · SQLite")]:::comp

  A1 -->|"F01"| W
  R -->|"F01 · PROPFIND, ráfagas"| W
  W -->|"F02"| API
  API --> DB

  T03["T-03 · Agotar recursos"]:::threat
  T14["T-14 · Saltarse el WAF<br/>por el puerto 3000"]:::threat
  T03 -.-> W
  T14 -.-> API

  C1["RS-08 · solo el WAF publica puerto<br/>la app no tiene ports"]:::ok
  C2["DET-03 · 911100<br/>métodos fuera de la lista"]:::ok
  C4["Dashboard · top de client_ip"]:::ok
  C5["RS-05 · 60 req/min por IP<br/>no implementado"]:::todo
  API --- C1
  W --- C2
  W --- C4
  W --- C5

  classDef actor fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef comp fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef threat fill:#fde8e8,stroke:#c92a2a,color:#5c1111
  classDef ok fill:#e6f4ea,stroke:#2b8a3e,color:#123d1c
  classDef todo fill:#f1f3f5,stroke:#868e96,color:#343a40,stroke-dasharray: 5 5
```

Cómo lo pensamos: el CRS no limita la tasa de peticiones. Lo que sí tenemos es contención (nadie llega a la app sin pasar por el WAF) y visibilidad (el panel de IPs del dashboard muestra quién manda más tráfico). El límite de tasa de RS-05 queda propuesto.

## ON-05 · Poder reconstruir eventos sospechosos

En el H1 el DFD terminaba en los logs de Docker (D3). Con el H3 se agregó el SIEM, así que este diagrama trae tres flujos nuevos que no estaban en el DFD general.

```mermaid
flowchart LR
  W["P1 · WAF"]:::comp
  API["P2 · API"]:::comp
  V[("D3 · volumen waf-logs<br/>modsec_audit.json<br/>access.log")]:::comp
  FB["Filebeat"]:::comp
  ES[("Elasticsearch<br/>filebeat-*")]:::comp
  K["Kibana :5601<br/>DET-01..05 · dashboard"]:::comp
  A2["A2 · Equipo azul"]:::actor
  AL[("app-logs<br/>vacío")]:::gap

  W -->|"F07 · auditoría + acceso"| V
  API -.->|"F12 · logs de la app"| AL
  V -->|"F13 · nuevo"| FB
  FB -->|"F14 · nuevo"| ES
  ES -->|"F15 · nuevo"| K
  K -->|"F11 · consulta"| A2

  T04["T-04 · Eventos que no<br/>se registran"]:::threat
  T12["T-12 · Contraseñas o JWT<br/>dentro de los logs"]:::threat
  T13["T-13 · No atribuir una<br/>acción de negocio"]:::threat
  T04 -.-> V
  T12 -.-> ES
  T13 -.-> AL

  C1["Hora UTC, ruleId, URI<br/>y payload en cada evento"]:::ok
  C2["Solo cuentas de prueba<br/>en las capturas"]:::ok
  C3["Auditoría de negocio<br/>(quién vio qué carrito)"]:::todo
  K --- C1
  ES --- C2
  AL --- C3

  classDef actor fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef comp fill:#e8f0fe,stroke:#3b5bdb,color:#1c2b4a
  classDef threat fill:#fde8e8,stroke:#c92a2a,color:#5c1111
  classDef gap fill:#fff4e6,stroke:#e8590c,color:#5c2a05
  classDef ok fill:#e6f4ea,stroke:#2b8a3e,color:#123d1c
  classDef todo fill:#f1f3f5,stroke:#868e96,color:#343a40,stroke-dasharray: 5 5
```

Cómo lo pensamos: todo lo que pasa por el WAF se puede reconstruir en Kibana con hora, regla y payload. Lo que el WAF no ve (el IDOR de ON-03) tampoco queda en el SIEM, porque la app no escribe logs a `app-logs/`. Esa es la brecha de trazabilidad que queda abierta.
