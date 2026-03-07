# Configuration DNS - karl-remy.fr

Guide pour configurer le DNS afin que tous les sous-domaines pointent vers le VPS.

## 1. Ajouter les enregistrements DNS

Dans le panneau de gestion du registrar, ajouter deux enregistrements :

| Type | Nom / Host | Valeur         | TTL  |
|------|------------|----------------|------|
| A    | `@`        | 91.134.132.141 | 3600 |
| A    | `*`        | 91.134.132.141 | 3600 |

Le premier pointe `karl-remy.fr`, le second pointe tous les sous-domaines (`*.karl-remy.fr`).

## 2. Verifier la propagation DNS

```bash
# Verifier le domaine principal
dig karl-remy.fr +short
# Doit retourner : 91.134.132.141

# Verifier le wildcard
dig test-random.karl-remy.fr +short
# Doit retourner : 91.134.132.141
```

Si la propagation n'est pas encore effective, attendre quelques minutes (jusqu'a 24h selon le registrar).

## 3. SSL / TLS

Caddy gere **automatiquement** les certificats SSL via Let's Encrypt (ACME HTTP-01 challenge). Aucune configuration supplementaire n'est necessaire.

Quand un nouveau sous-domaine est ajoute au Caddyfile, Caddy obtient et renouvelle le certificat tout seul.

## Depannage

### Le sous-domaine ne resout pas

```bash
# Verifier que l'enregistrement existe
dig mon-projet.karl-remy.fr A +short

# Tester avec un DNS public
dig @8.8.8.8 mon-projet.karl-remy.fr A +short
```

### Erreur de certificat SSL

```bash
# Verifier les logs Caddy
sudo journalctl -u caddy --no-pager -n 50

# Verifier que les ports 80 et 443 sont ouverts
sudo ufw status
```

Caddy a besoin des ports 80 (challenge ACME) et 443 (HTTPS) ouverts.
