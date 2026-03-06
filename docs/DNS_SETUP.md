# Configuration DNS Wildcard - OVH

Guide pour configurer le DNS wildcard sur le domaine `karl-remy.fr` afin que tous les sous-domaines pointent vers le VPS.

## 1. Ajouter l'enregistrement DNS wildcard

1. Se connecter a l'[OVH Manager](https://www.ovh.com/manager/)
2. Aller dans **Noms de domaine** > **karl-remy.fr**
3. Cliquer sur l'onglet **Zone DNS**
4. Cliquer sur **Ajouter une entree**
5. Configurer l'enregistrement :

| Champ        | Valeur              |
|--------------|---------------------|
| Type         | A                   |
| Sous-domaine | *                   |
| Cible        | 91.134.132.141      |
| TTL          | 3600                |

6. Valider l'ajout

## 2. Verifier la propagation DNS

Attendre quelques minutes puis verifier avec `dig` :

```bash
# Verifier le wildcard
dig test-random.karl-remy.fr +short
# Doit retourner : 91.134.132.141

# Verifier un sous-domaine specifique
dig mon-saas.karl-remy.fr +short
# Doit retourner : 91.134.132.141

# Verifier la propagation complete
dig karl-remy.fr ANY
```

Si la propagation n'est pas encore effective, attendre jusqu'a 24h (generalement quelques minutes avec OVH).

## 3. Creer une application API OVH

Pour la gestion automatique des certificats SSL wildcard avec Certbot, il faut une application API OVH.

1. Aller sur [https://eu.api.ovh.com/createApp/](https://eu.api.ovh.com/createApp/)
2. Se connecter avec le compte OVH
3. Remplir :
   - **Application name** : `generateu-certbot`
   - **Application description** : `Certbot DNS challenge for wildcard certificates`
4. Noter l'**Application Key** et l'**Application Secret**

## 4. Generer le Consumer Key

```bash
# Sur le VPS
ssh ubuntu@91.134.132.141

# Generer le consumer key
curl -X POST \
  -H "X-Ovh-Application: <APPLICATION_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "accessRules": [
      {"method": "GET", "path": "/domain/zone/*"},
      {"method": "POST", "path": "/domain/zone/*"},
      {"method": "PUT", "path": "/domain/zone/*"},
      {"method": "DELETE", "path": "/domain/zone/*"}
    ],
    "redirection": "https://karl-remy.fr"
  }' \
  https://eu.api.ovh.com/1.0/auth/credential
```

La reponse contient :
- `consumerKey` : A noter
- `validationUrl` : Ouvrir dans un navigateur pour valider

## 5. Creer le fichier de credentials

```bash
# Sur le VPS
sudo tee /root/.ovh-credentials > /dev/null << 'EOF'
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = <APPLICATION_KEY>
dns_ovh_application_secret = <APPLICATION_SECRET>
dns_ovh_consumer_key = <CONSUMER_KEY>
EOF

# Securiser les permissions
sudo chmod 600 /root/.ovh-credentials
```

## 6. Installer Certbot avec le plugin OVH

```bash
# Installer certbot et le plugin OVH
sudo apt update
sudo apt install -y certbot python3-certbot-dns-ovh
```

## 7. Generer le certificat wildcard

```bash
# Generer le certificat wildcard pour *.karl-remy.fr
sudo certbot certonly \
  --dns-ovh \
  --dns-ovh-credentials /root/.ovh-credentials \
  --dns-ovh-propagation-seconds 60 \
  -d "karl-remy.fr" \
  -d "*.karl-remy.fr" \
  --agree-tos \
  --email admin@karl-remy.fr \
  --non-interactive
```

Le certificat sera genere dans `/etc/letsencrypt/live/karl-remy.fr/`.

## 8. Renouvellement automatique

Certbot installe automatiquement un timer systemd pour le renouvellement. Verifier :

```bash
# Verifier le timer
sudo systemctl status certbot.timer

# Tester le renouvellement
sudo certbot renew --dry-run
```

## 9. Configurer Caddy avec le certificat

Si Caddy est utilise comme reverse proxy, il faut pointer vers les certificats Let's Encrypt :

```
*.karl-remy.fr {
    tls /etc/letsencrypt/live/karl-remy.fr/fullchain.pem /etc/letsencrypt/live/karl-remy.fr/privkey.pem
    # ... configuration reverse proxy
}
```

**Note** : Si Caddy gere lui-meme les certificats via ACME, la configuration DNS OVH peut etre utilisee directement avec le module `caddy-dns/ovh`.

## Depannage

### Le sous-domaine ne resout pas

```bash
# Verifier que l'enregistrement existe
dig *.karl-remy.fr A +short

# Verifier le serveur DNS utilise
dig karl-remy.fr NS

# Forcer une resolution via les DNS OVH
dig @dns11.ovh.net test.karl-remy.fr A +short
```

### Erreur de certificat SSL

```bash
# Verifier le certificat
sudo certbot certificates

# Forcer le renouvellement
sudo certbot renew --force-renewal

# Verifier les logs
sudo journalctl -u certbot
```
