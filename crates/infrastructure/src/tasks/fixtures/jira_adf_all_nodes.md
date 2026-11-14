## Contexto

Como parte de [https://acme.atlassian.net/browse/TSK-11300](https://acme.atlassian.net/browse/TSK-11300) movemos **Platform** a *arm64*, sin ~~x86~~. @Ana Gómez confirmó la ventana ✅\
Fecha: 2026-10-30 · estado **EN CURSO**

### Pasos

1. Congelar las escrituras del job ([TSK-11356](https://acme.atlassian.net/browse/TSK-11356)).
2. Correr las migraciones en staging:
   - por lotes de 500k filas
   - comparando `price_history`

- [x] Backup de `price_history`
- [ ] Avisar en #platform-oncall
  - [ ] y en el canal de deploys

```sql
SELECT channel_id, COUNT(*) AS prices
FROM price_history
GROUP BY channel_id;
```

> Ojo con los 40 M de filas.
>
> Segunda línea.

> **Warning:** No correr en prod sin aviso.

| **Entorno** | **Destino** |
| --- | --- |
| staging | m7g.large \| arm<br>hoy |

---

![arm64-rollout.png](arm64-rollout.png)

![attachment](attachment)

### Detalle técnico

Instancias m7g.

[https://wiki.platform.local/runbooks/migraciones](https://wiki.platform.local/runbooks/migraciones)
