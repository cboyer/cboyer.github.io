---
title: "Confidentialité et paramètres avancés dans Firefox"
date: "2018-11-17T11:58:22-04:00"
updated: "2024-10-23T11:53:22+02:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [firefox, confidentialité, paramètres, avancé, about config]
abstract: "Accéder aux paramètres avancés de Firefox avec about:config pour améliorer les paramètres de confidentialité et de performance."
---


Firefox possède de nombreux paramètres qui ne sont pas accessibles par les menus de l'interface graphique (Édition > Préférences).
Pour y accéder, tapez `about:config` dans la barre d'adresse (une confirmation va vous être demandée car certaines modifications peuvent entrainer des disfonctionnements).
Voici quelques paramètres intéressants que j'utilise pour la confidentialité. Une liste plus complète est disponible dans les sources.

Il est important de noter que certains risquent de vous refuser l'accès à leurs services (ou de mal fonctionner) s'ils ne peuvent plus abuser de vos données personnelles. Cela a été le cas pour moi avec un site d'hébergement de photo qui me refusait clairement l'accès car je ne transmettais plus d'entête Referer (page consultée précédemment). Modifier les paramètres relatifs aux cookies pose énormément de problèmes car c'est là que se situent principalement les abus d'accès aux données personnelles.


Refuser automatiquement les cookies lorsque demandé par des fenêtres popup. Les accepte automatiquement si le bouton de refus n'est pas trouvé par Firefox (utiliser la valeur 1 pour tout refuser):
```javascript
cookiebanners.service.mode = 2
cookiebanners.service.mode.privateBrowsing = 2
```

Empêcher la désactivation du click droit (peut entrainer quelques problèmes si le site utilise son propre menu contextuel):

```javascript
dom.event.contextmenu.enabled = false
```

Éviter le blocage du copier/coller:

```javascript
dom.event.clipboardevents.enabled = false
```

Empêcher la consultation de la liste des modules installés (Adblock, etc.).

```javascript
plugins.enumerable_names = blank
```

Ne plus transmettre l'URL consultée précédemment (entêtes Referer):

```javascript
network.http.sendRefererHeader = 0
```

Falsifer l'URL consultée précédemment:

```javascript
network.http.referer.spoofSource = true
```

Active la protection contre les trackers:

```javascript
privacy.trackingprotection.enabled = true
```

Désactiver tous les types de géolocalisation:

```javascript
geo.enabled = false
geo.wifi.uri = blank
browser.search.geoip.url = blank
```

Désactiver l'extension Pocket imposée dans Firefox (non open source):

```javascript
extensions.pocket.enabled = false
extensions.pocket.site = blank
extensions.pocket.oAuthConsumerKey = blank
extensions.pocket.api = blank
```

Désactiver l'accès au statut de la batterie (utilisé par les trackers pour l'identification):

```javascript
dom.battery.enabled = false
```

Supprime un identifiant télémétrique inconnu (ne peut qu'être utilisé pour vous identifier):

```javascript
toolkit.telemetry.cachedClientID = blank
```

Désactiver le suivi de vos clicks:

```javascript
browser.send_pings = false
```

Menu plus compacts (interlignes réduits)
```javascript
browser.compactmode.show = true
browser.uidensity = 1
```

## DNS chiffrés
Dans Paramètres > Vi privée et sécurité > Activer le DNS via HTTPS

Service DNS de [LibreOPS](https://libredns.gr/) filtrant les publicités:
https://doh.libredns.gr/noads

Service DNS de la [FDN](https://www.fdn.fr/actions/dns/):
https://ns0.fdn.fr/dns-query et https://ns1.fdn.fr/dns-query

Service CIRA [Canadian Shield](https://www.cira.ca/en/canadian-shield/):
https://private.canadianshield.cira.ca/dns-query


## Supprimer les popups de consentement aux cookies via uBlock Origin
Dans uBlock Origin (Tableau de bord > Listes de filtres > Bannières de cookie), cocher:
- EasyList/uBO – Cookie Notices
- AdGuard/uBO – Cookie Notices


Dans uBlock Origin (Tableau de bord > Mes filtres) ajouter les lignes:
```
! Consentement aux cookies Google
www.google.com###lb
www.google.com##:root:style(overflow-y: visible !important;)
www.google.fr###cnsm
www.google.fr###cnsw
www.google.fr##.m114nf.aID8W
||consent.google.com/$subdocument
www.google.com##^script:has-text(CONSENT)
www.google.fr##^script:has-text(CONSENT)

! Se connecter avec Google
||accounts.google.com/gsi/iframe/$subdocument

! Bandeau d'acceptation des cookie Reddit
www.reddit.com##.pointer-events-auto.border-tone-4.border-solid.border.shadow-md.duration-300.transition-opacity.pt-0.p-md.opacity-100.mx-0.my-md.rounded-sm.bg-ui-modalbackground.relative.block.z-\[2\].nd\:pb-2xl.nd\:visible
```


## Liens complémentaires

 - [https://gist.github.com/0XDE57/fbd302cef7693e62c769](https://gist.github.com/0XDE57/fbd302cef7693e62c769)
 - [https://github.com/yokoffing/Betterfox](https://github.com/yokoffing/Betterfox)
