# ADR-0003 — Pocos workers de tokio en el daemon

- Estado: aceptada
- Fecha: 2026-10-27

## Contexto

Por defecto tokio crea un worker por núcleo (12 en la máquina de prueba). El
daemon es I/O-bound: hilos bloqueantes por PTY más tareas cortas (pump, gRPC).

## Mediciones (M2 Max, macOS 27.0.1, `kumo-bench`, cliente `current_thread`)

| `--worker-threads` | Throughput flood | Eco p99 | Tramo daemon p99 | Hello p99 |
|---|---|---|---|---|
| 1  | 135 MB/s | 0,90 ms | 0,28 ms | 0,07 ms |
| 2  | 106 MB/s | 0,95 ms | 0,34 ms | 0,12 ms |
| 4  |  90 MB/s | 0,84 ms | 0,26 ms | 0,08 ms |
| 12 |  91 MB/s | 0,93 ms | 0,35 ms | 0,08 ms |

Con la máquina cargada (load avg > 15) y 12 workers en daemon *y* cliente, el
flood cayó a 30–40 MB/s; con 2 workers se mantuvo en ~94 MB/s.

## Decisión

Default `--worker-threads 2`: casi todo el beneficio de 1 worker, sin serializar
varias terminales con salida pesada en un solo hilo. Configurable por flag.

## Consecuencias

Revisar con datos cuando haya N agentes en paralelo (M3).
