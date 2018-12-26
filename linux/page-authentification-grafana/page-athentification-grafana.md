---
title: "Page d'authentification personnalisée pour Grafana avec NGINX"
date: "2018-05-06T21:23:46-04:00"
updated: "2018-11-01T18:08:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [authentification, grafana, nginx, linux]
abstract: |
  Utilisation de NGINX en reverse proxy comme "man in the middle" pour rediriger vers une page d'authentification personnalisée.
---

Voici un moyen relativement simple d'avoir une page d'authentification personnalisée pour Grafana sans altérer l'application ce qui va nous permettre de pouvoir la mettre à jour sans problème. L'idée est d'utiliser NGINX comme reverse proxy pour intercepter les requêtes en direction de la page d'authentification de Grafana. NGINX renverra alors une page d'authentification HTML écrite par nos soins. Cette page contiendra un formulaire login/mot de passe dont l'envoie cible la page légitime de Grafana. Ainsi c'est le mécanisme d'authentification de Grafana qui est utilisé (LDAP ou interne). Selon le retours de la page légitime, notre page personnalisée redirigera ou non vers Grafana.
En résumé nous utilisons le concept de "man in the middle".

Commençons par installer NGINX avec le gestionnaire adapté à la distribution en question (apt, yum, dnf).

```console
apt-get install nginx
yum install nginx
dnf install nginx
```

Passons à la partie configuration `/etc/nginx/nginx.conf`. Nous utiliserons uniquement HTTPS ici (la procédure pour générer le certificat ne sera pas abordée).

```console

# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

# Settings for a TLS enabled server.

    server {
        listen       443 ssl http2 default_server;
        listen       [::]:443 ssl http2 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        ssl_certificate "/etc/nginx/certs/cert.cert";
        ssl_certificate_key "/etc/nginx/certs/cert.key";
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }

}

```

Jusque là, rien de particulier. Pour la suite nous considérerons Grafana installé sur la même machine et écoutant sur 127.0.0.1:3000 pour que seul NGINX puisse y avoir accès. Également Grafana doit être configuré avec la directive `root_url=/grafana` dans `/etc/grafana/grafana.ini` car nous hébergerons la page d'authentification à la racine dans NGINX.

Ajoutons un fichier de configuration pour Grafana dans `/etc/nginx/default.d/grafana.conf` :

```console
location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
}

#Page personnalisée
location /grafana/login {
        proxy_pass https://127.0.0.1/login.html;
}

#Page légitime
location /grafana/auth {
        proxy_pass http://127.0.0.1:3000/login;
}

#Logo personnalisé
location /status/public/img/grafana_icon.svg {
        proxy_pass https://127.0.0.1/mon_logo.png;
}

#Favicon personnalisé
location /status/public/img/fav32.png {
        proxy_pass https://127.0.0.1/favicon.ico;
}
```

Maintenant ajoutons la page d'authentification personnalisée `login.html` dans `/usr/share/nginx/html/`. Voici une version minimaliste à étoffer selon vos besoins :

```html
<!DOCTYPE html>
<html>
<head>
  <title>Grafana Authentification</title>
</head>
<body>
  <h1>Grafana Authentification</h1>
  <form onsubmit="return false;">
    <input type="text" id="user" placeholder="Identifiant" required><br>
    <input type="password" id="password" placeholder="Mot de passe" required><br>
    <input type="submit" value="Connexion" onClick="login()">
  </form>
</body>

<script>
function login(){
  var user = document.getElementById('user').value;
  var password = document.getElementById('password').value;
  if(user == '')
    return false;

  if(password == '')
    return false;

  var http = new XMLHttpRequest();
  var url = "/grafana/auth";
  var params = "user="+user+"&password="+password;
  http.open("POST", url, true);
  http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

  http.onreadystatechange = function() {
      if(http.readyState == 4 && http.status == 200) {
          //console.log(http.responseText);
          window.location.replace("/grafana");
      }
      //401 Unauthorized
      if(http.readyState == 4 && http.status == 401) {
          //console.log(http.responseText);
          alert("Login ou mot de passe incorrect.");
      }
  }
  http.send(params);
}
</script>
</html>
```

Si vous souhaitez personnaliser cette page en ajoutant des images, feuillet de style CSS ou autre, il faut placer les fichiers dans `/usr/share/nginx/html/` et utiliser des URL dans le code.

Redémarrons NGINX:

```console
systemctl restart nginx
```

Ouvrez votre navigateur et accédez au serveur en HTTPS pour tester: https://monserveur.local/grafana

## Limites de la solution

NGINX se fie à l'URI pour fournir les pages demandée: la chaîne de caractères du bloc location. Si cette même chaîne de caractère est utilisée dans un lien par l'application nous aurons une erreur 404 en provenance de Grafana.

J'ai également pu observer l'affichage d'une erreur 404 de Grafana pendant une fraction de seconde après l'authentification sans en trouver l'origine.

## Sources:

 - [Grafana derrière un proxy](http://docs.grafana.org/installation/behind_proxy)
 - [NGINX en reverse proxy](http://nginx.org/en/docs/http/ngx_http_core_module.html#location)
