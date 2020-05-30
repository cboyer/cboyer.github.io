---
title: "Accélération matérielle 2D avec OpenVG sur Raspberry Pi"
date: "2020-05-03T19:14:27-04:00"
updated: "2020-05-03T19:14:27-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [OpenVG, Raspberry, Raspberry Pi, OpenGLES, C, 2D, accélération matérielle]
abstract: |
  Générer des images en 2D avec l'accélération matérielle sur Raspberry Pi via OpenVG.
---

## Introduction

Il est possible de générer des images 2D sur Raspberry Pi tout en bénéficiant de l'accélération matérielle pour obtenir de meilleurs performances.
L'accélération matérielle repose sur la possibilité d'effectuer les opérations par le circuit graphique (GPU) au lieu du processeur. 
Des libraries bien connues comme OpenGL permettent déjà d'utiliser le GPU pour la 3D. Nous utiliserons ici OpenVG, une librairie normalisée par le groupe Khronos (qui s'occupe également d'OpenGL) et implémentée par Broadcom pour le Raspberry Pi. D'autres librairies comme Cairo offrent les mêmes possibilités mais exploitent le CPU ce qui les rends beaucoup moins performantes (notons cependant que Cairo s'est vu partiellement implémenter un backend OpenVG mais qui ne semble plus être activement développé).

Les codes sources sont disponibles sur [https://github.com/cboyer/openvg-rpi](https://github.com/cboyer/openvg-rpi).


## Utilisation d'OpenVG sur Raspberry Pi

OpenVG nécessite OpenGLES pour fournir un contexte et DispmanX. Son utilisation est assez lourde à mettre en place.
L'utilisation d'OpenVG repose principalement sur des tracés de chemin (`VGPath`), de remplissage et de transformation (rotation, symétrie, agrandissement, etc.).
Des exemples sont disponibles directement dans `/opt` et également sur [Github](https://github.com/raspberrypi/firmware/tree/master/opt/vc/src/hello_pi/libs/vgfont).



## Les différentes méthodes pour générer des images

Il faut différencier principalement deux méthodes: off-screen (hors écran) où l'image sera stockée en mémoire sans être imprimée sur l'écran et on-screen (sur écran) où l'image est affichée sur l'écran.
Pour travailler off-screen, nous avons deux possibilités pour la création d'une surface: `eglCreatePbufferSurface()` et `eglCreatePbufferFromClientBuffer()`.


## Récupérer les images

Bien que le GPU et le CPU utilisent la même mémoire physique RAM, la zone qui leur est respectivement affectée leur garanti un accès exclusif.
Pour récupérer une image générée par le GPU et la rendre accessible par le CPU, OpenVG met à notre disposition plusieurs fonctions:

- `vgReadPixels()` pour les images on-screen
- `vgGetImageSubData()` pour les images off-screen.

Leur utilisation réduit grandement les performances et amène une consommation du temps CPU accrue.


## Enregistrer les images

Les images récupérées avec `vgReadPixels()` ou `vgGetImageSubData()` sont enregistrées au format PNG avec la librairie STB et sa fonction `stbi_write_png()`. En revanche l'ordre dans lequel OpenVG stock ses pixels diffère de celui de STB ce qui produit des images inversées. Pour éviter ce problème il suffit d'inverser l'image elle-même avec OpenVG en appliquant une matrice de transformation `VG_MATRIX_PATH_USER_TO_SURFACE` sur nos `VGPath.
STB est une librairie utilisant uniquement le CPU, donc très couteuse en consommation de temps CPU.


## Dessiner des caractères depuis des polices TTF

Pour le chargement de polices de caractères True Type (TTF), nous utiliserons Freetype2 afin d'obtenir les glyphes.

OpenVG propose la fonction `vgDrawGlyph()` qui permet de dessiner ces glyphes.
En revanche `vgDrawGlyph()` semble fonctionnelle uniquement pour le dessin on-screen, son utilisation sur une surface créée avec `eglCreatePbufferSurface()` ou `eglCreatePbufferFromClientBuffer()` ne produit rien.
Deplus, `vgDrawGlyph()` possède un autre désavantage: elle est affectée uniquement par les matrices de transformation de type `G_MATRIX_GLYPH_USER_TO_SURFACE` et non `VG_MATRIX_PATH_USER_TO_SURFACE` qui s'apliquent uniquement aux `VGPath` et il est possible d'utiliser un seul type avec `vgSeti(VG_MATRIX_MODE, )`.

Pour palier à cette problématique, il est possible d'implémenter une fonction `vgDrawString()` qui dessine des chemins `VGPath` générés depuis les glyphes TTF. Pour ne pas avoir a générer un `VGPath` pour chaque caractère lors de l'appel à `vgDrawString()`, nous utiliserons un cache qui contiendra tous les `VGPath` de chaque caractère utilisable. Chacun de ces `VGPath` sera associé à son caractère avec une indexation gérée avec une `GHashTable` (glib).
Notons qu'il possible de mettre en cache le caractère espace, cependant son utilisation fonctionne uniquement off-screen avec `eglCreatePbufferSurface()` et `eglCreatePbufferFromClientBuffer()` et non on-screen où la chaîne de caractère n'est pas dessinée et déclenche `assert(vgGetError() == VG_NO_ERROR)`. Pour contourner le problème il suffit de ne pas utiliser le cache et simplement décaler la position du prochain caractère.


### Liens complémentaires

- [OpenVG](https://www.khronos.org/openvg/)
- [Documentation OpenVG](https://www.khronos.org/registry/OpenVG/specs/openvg-1.1.pdf)
- [Fiche récapitulative OpenVG](https://www.khronos.org/files/openvg-quick-reference-card.pdf)
- [Benchmarking OpenVG implementations](https://www.idi.ntnu.no/grupper/su/fordypningsprosjekt-2006/OpenVGReport_final.pdf)
- [Raspberry Pi GPU Audio Video Programming - Newmarch, Jan](https://www.leslibraires.ca/livres/raspberry-pi-gpu-audio-video-programming-jan-newmarch-9781484224717.html)
