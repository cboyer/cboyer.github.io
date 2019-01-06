---
title: "FPGA et afficheur 7 segments: compteur à afficheur unique"
date: "2018-04-25T20:00:50-04:00"
updated: "2018-11-01T18:08:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Électronique"
keywords: [fpga, afficheur, led, verilog]
abstract: |
  Implémentation en Verilog d'un compteur sur un afficheur 7 segments.
---

[Partie 1](../fpga-afficheur-7-segments-introduction/), partie 2, [partie 3](../fpga-afficheur-7-segments-compteurs-multiples/)

Nous avons vu dans [la partie 1](../fpga-afficheur-7-segments-introduction/) comment afficher un chiffre sur l'afficheur le plus à droite. L'objectif de cette seconde partie est d'implémenter un compteur pour afficher les chiffres de 0 à 9.
Avant de continuer, rappelons quelques éléments importants de la partie précédente:

La nomenclature des segments:

- le premier caractère représente l'anode (pôle positif)
- le deuxième caractère représente la cathode (pôle négatif)

![Schéma annoté](../fpga-afficheur-7-segments-introduction/7segments_schema_labels.png)

Les correspondances sorties-registres-segments (forme explicite de la ligne `assign DISPLAY_1 = display_1_leds`):

```verilog
assign DISPLAY_1[0] = display_1_leds[0]; //E (anode commune)
assign DISPLAY_1[1] = display_1_leds[1]; //1
assign DISPLAY_1[2] = display_1_leds[2]; //C
assign DISPLAY_1[3] = display_1_leds[3]; //3
assign DISPLAY_1[4] = display_1_leds[4]; //4
assign DISPLAY_1[5] = display_1_leds[5]; //5 (le point)
assign DISPLAY_1[6] = display_1_leds[6]; //6
assign DISPLAY_1[7] = display_1_leds[7]; //7
assign DISPLAY_1[8] = display_1_leds[8]; //D
```

Attardons nous sur le signal issu de l’horloge. L’ensemble d’un circuit logique implémenté sur un FPGA peut être "asservi" par un signal de référence: l’horloge. Techniquement il s’agit d’un signal carré (le plus souvent de 50 MHz) qui va entrainer l'exécution des instruction dans le bloc `always` dépendamment de son état (posedge dans notre cas).

Dans notre circuit, c’est ce signal qui permet d’allumer les segments. En réalité, chaque segment s’allume et s’éteint à raison de 50 MHz ce qui est bien trop rapide pour l’œil humain qui voit les segment allumé en permanence (phénomène de persistance rétinienne).

Utilisons ce signal afin de compter des intervalles de temps suffisamment conséquents pour en afficher la valeur à une fréquence perceptible par l’œil. Pour cela, nous allons utiliser un registre `counter` de 26 bits pour incrémenter un second registre `display_1_value` de 4 bits qui contiendra une valeur comprise entre 0 et 9. Le FPGA va incrémenter ce registre à raison de 50 millions de fois par seconde (50 MHz), nous prendrons donc une valeur suffisamment grande (les 25 premiers bits à 1 par exemple) pour que le FPGA ne soit pas trop rapide pour incrémenter notre compteur dont la valeur sera affichée.

```verilog
/* module */
module SevenSegment (
	input CLOCK_50,
	output [8:0] DISPLAY_1
);

	/* reg */
	reg [8:0] display_1_leds = 9'b0;
	reg [3:0] display_1_value = 4'b0000;
	reg [25:0] counter = {26{1'b0}};

	/* assign */
	assign DISPLAY_1 = display_1_leds;

	/* always */
	always @ (posedge CLOCK_50) begin

		//Incrémente le compteur
		counter <= counter + 1'b1;

		//Incrémente la valeur affichée
		if(counter[24:0] == 25'b1) begin
			display_1_value <= display_1_value + 1'b1;
		end

		//Si on atteint 9, on réinitialise
		if(display_1_value[3:0] == 4'b1010) begin
			display_1_value <= 4'b0000;
		end

		//Active les segments selon la valeur affichée
		case(display_1_value[3:0])
			4'b0000 : display_1_leds <= 9'b111010111; //0
			4'b0001 : display_1_leds <= 9'b010000101; //1
			4'b0010 : display_1_leds <= 9'b111001011; //2
			4'b0011 : display_1_leds <= 9'b111001101; //3
			4'b0100 : display_1_leds <= 9'b010011101; //4
			4'b0101 : display_1_leds <= 9'b101011101; //5
			4'b0110 : display_1_leds <= 9'b101011111; //6
			4'b0111 : display_1_leds <= 9'b011000101; //7
			4'b1000 : display_1_leds <= 9'b111011111; //8
			4'b1001 : display_1_leds <= 9'b111011101; //9
			default : display_1_leds <= 9'b000000000; //Rien, anode commune à 0
		endcase

	end

endmodule
```

Pour ne rien afficher, il suffit que `display_1_leds[0]` qui est l'anode commune (broche E sur le schéma) soit à 0. `display_1_leds[5]` est toujours à 0 car il s'agit de la cathode du point (segment E5) qui n'est pas utilisé.

Pour diminuer la fréquence d'incrémentation, il suffit de passer d'une comparaison des 25 premiers bits de `counter` à l'ensemble des 26 bits. Le FPGA mettra plus de temps à arriver à 26 bits à 1 que 25.
Pour cela, il est nécessaire de changer la ligne:

```verilog
if(counter[24:0] == 25'b1) begin
```
Pour:
```verilog
if(counter[25:0] == 26'b1) begin
```

Et pour l'augmenter, nous pouvons réduire la comparaison à 24 bits ou moins:
```verilog
if(counter[23:0] == 24'b1) begin
```

Il est très important de prendre un intervalle de 0 à N bits et non un seul bit en particulier (à l'exception du bit de poids faible) car la condition s'avèrera vraie aussi longtemps qu'incrémenter les bits précédents ne change pas le bit comparé. Ceci aura pour effet d'incrémenter `display_1_value` à 50 MHz et d'afficher le chiffre correspondant beaucoup trop rapidement (notre oeil percevra le chiffre 8 à cause de la persistance rétinienne).

Dans [la partie 3](../fpga-afficheur-7-segments-compteurs-multiples/), nous verrons comment utiliser un afficheur supplémentaire afin d’introduire les dizaines dans notre compteur et d’afficher des valeurs de 0 à 99.


[Partie 1](../fpga-afficheur-7-segments-introduction/), partie 2, [partie 3](../fpga-afficheur-7-segments-compteurs-multiples/)
