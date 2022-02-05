---
title: "Confidentialité et paramètres avancés dans Firefox"
date: "2018-11-17T11:58:22-04:00"
updated: "2021-01-15T17:02:22-05:00"
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


## Liens complémentaires

 - [https://gist.github.com/0XDE57/fbd302cef7693e62c769](https://gist.github.com/0XDE57/fbd302cef7693e62c769)
 - 
