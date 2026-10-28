## Contexto

Como parte de [https://acme.atlassian.net/browse/PRC-11300](https://acme.atlassian.net/browse/PRC-11300) movemos **Pricing** a *Graviton*, sin ~~x86~~. @Ana Gómez confirmó la ventana ✅\
Fecha: 2026-10-30 · estado **EN CURSO**

### Pasos

1. Congelar las escrituras del job ([PRC-11356](https://acme.atlassian.net/browse/PRC-11356)).
2. Correr las migraciones en staging:
   - por lotes de 500k filas
   - comparando `price_history`

- [x] Backup de `price_history`
- [ ] Avisar en #pricing-oncall
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

![graviton-rollout.png](graviton-rollout.png)

![attachment](attachment)

### Detalle técnico

Instancias m7g.

[https://wiki.pricing.local/runbooks/migraciones](https://wiki.pricing.local/runbooks/migraciones)
