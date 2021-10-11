;
_custom			=				$dff000		; base address of custom chips

blt_source		=				$00		; $00 - source address
blt_dest		=				$04		; $04 - destination adress
blt_srcmod		=				$08		; $08 - source modulo
blt_destmod		=				$0a		; $0a - destination modulo
blt_width		=				$0c		; $0c - width in words
blt_height		=				$0e		; $0e - height in lines
blt_srcshift		=				$10		; $10 - source shift
blt_fwm			=				$12		; $12 - first word mask
blt_lwm			=				$14		; $14 - last word mask

BLTSIZE			=				$058		; bit 15 - bit 6 : height in lines / bit 5 - bit 0 : width in words
									; height = 1024 : bit 15 - bit 6 = 0 / width = 64 : bit 5 - bit 0 = 0
											
BLTAPTH			=				$050		; source address A (hi word)
BLTAPTL			=				$052		; source address A (lo word)

BLTBPTH			=				$04c		; source address B (hi word)
BLTBPTL			=				$04e		; source address B (lo word)

BLTCON0			=				$040		; blitter control register 0
									; bit 15 - bit 12 : shift distance for source A
									; bit 11 - bit 8 : enable DMA channel for A - D
									; bit 7 - 0 : minterms
											
BLTCON1			=				$042		; blitter control register 1
									; bit 15 - bit 12 : shift distance for source B
									; bit 11 - bit 5 : unused
									; bit 4,3,2 : EFE, IFE, FCI
									; bit 1 : 0 = ascending mode / 1 = descending mode
									; bit 0 : 0 = copy mode / 1 = line mode
											
BLTAFWM			=				$044		; first word mask for source A
BLTALWM			=				$046		; last word mask for source A

BLTAMOD			=				$064		; modulo for source A

BLTBMOD			=				$062		; modulo for source B

DMACONR			=				$002		; DMA control register (read)
;
; collision (a0 = bob1 structure, a1 = bob2 structure)
;
; return value d0 = 1: collision / d0 = 0: no collision
;
collision			move.l			#_custom,a6
				move.w			bob_Y(a1),d0				; y2
				move.w			bob_X(a1),d1				; x2
				sub.w			bob_X(a0),d1				; dx = x2 - x1 (horizontal distance)
				sub.w			bob_Y(a0),d0				; dy = y2 - y1 (vertical distance)
				bmi			coll_y_neg				; dy < 0? (bob2 above bob1)
				cmp.w			bob_Height(a0),d0			; is dy >= height of bob1?
				bge			coll_none				; no collision
				bra			coll_chk_x
				
coll_y_neg			move.w			d0,d2					; dy
				add.w			bob_Height(a1),d2
				cmp.w			#0,d2					; is dy + height of bob1 <= 0?
				ble			coll_none				; no collision (height of bob1 <= vertical distance)
				
coll_chk_x			tst.w			d1					; is dx < 0? (bob2 left of bob1)
				bmi			coll_x_neg
				move.w			bob_Width(a0),d2
				lsl.w			#4,d2					; width of bob1 in pixels
				cmp.w			d2,d1					; is dx >= width of bob1?
				bge			coll_none				; no collision
				bra			coll_area
				
coll_x_neg			move.w			bob_Width(a1),d2
				lsl.w			#4,d2					; width of bob1 in pixels
				add.w			d1,d2
				cmp.w			#0,d2					; is dx + width of bob1 <= 0?
				ble			coll_none				; no collision (width of bob1 <= horizontal distance)
				
coll_area			lea			coll_blit,a2				; address of blitter structure for collision
				move.l			#$ffffffff,blt_fwm(a2)			; set full first word mask and last word mask
				clr.w			blt_srcshift(a2)			; no source shift
				clr.l			d2
				clr.l			d3
				
				tst.w			d0					; is dy < 0? (bob2 above bob1)
				bmi			coll_area_y_neg
				move.w			bob_Width(a0),d4
				lsl.w			#1,d4					; width of bob1 in bytes
				mulu			d0,d4					; bob1 width * dy
				add.l			d4,d2					; total number of bytes from bob1 lying above bob2 (y-offset)
				move.w			bob_Height(a0),d4
				sub.w			d0,d4					; max. overlapping height
				cmp.w			bob_Height(a1),d4			; is max. overlapping height > height of bob2?
				bgt			coll_area_h_inside			; bob2 is inside the y-borders of bob1
				move.w			d4,blt_height(a2)			; else bob2 y-overlaps partially => blitter height is overlapping height
				bra			coll_area_dx
				
coll_area_h_inside		move.w			bob_Height(a1),blt_height(a2)		; blitter height is height of bob2
				bra			coll_area_dx
				
coll_area_y_neg			neg.w			d0					; absolute value of dy
				move.w			bob_Width(a1),d4
				lsl.w			#1,d4					; width of bob2 in bytes
				mulu			d0,d4					; bob2 width * dy
				add.l			d4,d3					; total number of bytes from bob2 lying above bob1 (y-offset)
				move.w			bob_Height(a1),d4
				sub.w			d0,d4					; max. overlapping height
				cmp.w			bob_Height(a0),d4			; is max. overlapping height > height of bob1?
				bgt			coll_area_h_inside_neg			; bob1 is inside the y-borders of bob2
				move.w			d4,blt_height(a2)			; else bob1 y-overlaps partially => blitter height is overlapping height
				bra			coll_area_dx
				
coll_area_h_inside_neg		move.w			bob_Height(a0),blt_height(a2)		; blitter height is height of bob1

coll_area_dx			tst.w			d1					; is dx < 0? (bob2 left of bob1)
				bmi			coll_area_x_neg
				move.w			d1,d4
				lsr.w			#4,d4					; horizontal distance in words
				move.w			bob_Width(a0),d5
				sub.w			d4,d5					; max. overlapping width
				cmp.w			bob_Width(a1),d5			; is max. overlapping width > width of bob2?
				bgt			coll_area_w_inside			; bob2 is inside the x-borders of bob1
				move.w			d5,blt_width(a2)			; else bob2 x-overlaps partially => blitter width is overlapping width
				bra			coll_area_x_offset
				
coll_area_w_inside		move.w			bob_Width(a1),blt_width(a2)		; blitter width is width of bob2

coll_area_x_offset		lsl.w			#1,d4					; horizontal distance in bytes (x-offset)
				and.l			#$0000ffff,d4				; clear upper word of d4
				add.l			d4,d2					; add x-offset bytes to y-offset bytes
				and.w			#$000f,d1				; check x-offset for word boundary
				beq			coll_config_blitter			; if word boundary => start blitter operation
				move.w			d1,blt_srcshift(a2)			; else set shift distance (1..15)
				subq.b			#1,d1
				move.w			#$ffff,d4

coll_area_x_fwm			lsr.w			#1,d4
				dbra			d1,coll_area_x_fwm			; calculate first word mask for each bit in shift distance
				move.w			d4,blt_fwm(a2)

coll_chk_total_width		cmp.w			#1,blt_width(a2)
				bne			coll_config_blitter
				move.w			blt_fwm(a2),blt_lwm(a2)
				bra			coll_config_blitter

coll_area_x_neg			neg.w			d1					; absolute value of dx
				move.w			d1,d4
				lsr.w			#4,d4					; horizontal distance in words
				move.w			bob_Width(a1),d5
				sub.w			d4,d5					; max. overlapping width
				cmp.w			bob_Width(a0),d5			; is max. overlapping width > width of bob1?
				bgt			coll_area_w_inside_neg			; bob1 is inside the x-borders of bob2
				move.w			d5,blt_width(a2)			; else bob1 x-overlaps partially => blitter width is overlapping width
				bra			coll_area_x_offset_neg
				
coll_area_w_inside_neg		move.w			bob_Width(a0),blt_width(a2)		; blitter width is width of bob1

coll_area_x_offset_neg		lsl.w			#1,d4					; horizontal distance in bytes (x-offset)
				and.l			#$0000ffff,d4				; clear upper word of d4
				add.l			d4,d3					; add x-offset bytes to y-offset bytes
				and.w			#$000f,d1				; check x-offset for word boundary
				beq			coll_config_blitter			; if word boundary => start blitter operation
				sub.l			#2,d2					; go back one word from starting position of bob1
				move.w			#16,d4
				sub.w			d1,d4					; adjust loop counter for first word mask
				move.w			#$ffff,d7

coll_area_x_fwm_neg		lsr.w			#1,d7
				dbra			d1,coll_area_x_fwm_neg			; calculate first word mask for each off-word-boundary bit
				move.w			d7,blt_fwm(a2)
				bra			coll_chk_total_width
				
coll_config_blitter		move.l			blt_fwm(a2),BLTAFWM(a6)			; set masks
				move.w			bob_Width(a0),d0
				move.w			bob_Width(a1),d1
				sub.w			blt_width(a2),d0
				sub.w			blt_width(a2),d1
				lsl.w			#1,d0					; modulo offset for bob1 in bytes
				lsl.w			#1,d1					; modulo offset for bob2 in bytes
				move.w			d0,BLTAMOD(a6)
				move.w			d1,BLTBMOD(a6)
				move.w			blt_srcshift(a2),d0
				lsl.w			#8,d0
				lsl.w			#4,d0
				move.w			d0,BLTCON1(a6)				; set shift value of B source (bits 12-15)
				move.w			#$0cc0,BLTCON0(a6)			; use sources A and B / logic function $c0 for minterm D = AB
				add.l			bob_CollMask(a0),d2			; add offset bytes to start address of bob1
				add.l			bob_CollMask(a1),d3			; add offset bytes to start address of bob2
				move.l			d2,BLTAPTH(a6)				; set source A address pointer
				move.l			d3,BLTBPTH(a6)				; set source B address pointer
				move.w			blt_width(a2),d7
				move.w			blt_height(a2),d6
				and.w			#$03ff,d6
				lsl.w			#6,d6
				and.w			#$003f,d7
				add.w			d6,d7
				move.w			d7,BLTSIZE(a6)				; set width and height and start blitter operation
				
coll_wait			btst			#$0e,DMACONR(a6)			; test blitter busy status (bit 14)
				bne			coll_wait
				btst			#$0d,DMACONR(a6)			; test blitter zero status (bit 13)
				bne			coll_none				; if bit 13 is set => blitter output was always zero
				move.l			#1,d0					; collision flag = 1
				rts
				
coll_none			clr.l			d0					; collision flag = 0
				rts

; ---------------------------
; collision blitter structure
; ---------------------------

coll_blit			dc.l			0					; $00 - source address
				dc.l 			0					; $04 - destination adress
				dc.w			0					; $08 - source modulo
				dc.w			0					; $0a - destination modulo
				dc.w			0					; $0c - width in words
				dc.w			0					; $0e - height in lines
				dc.w			0					; $10 - source shift
				dc.w			0					; $12 - first word mask
				dc.w 			0					; $14 - last word mask
