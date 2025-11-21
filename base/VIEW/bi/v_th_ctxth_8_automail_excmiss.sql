SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_8_Automail_excMiss]
AS
SELECT DISTINCT
   AL4.StorerKey,
   AL5.Facility as 'Warehouse',
   AL4.Id as 'PalletId',
   AL4.Sku,
   AL1.DESCR,
   sum(AL4.Qty) as 'Qty',
   AL4.QtyAllocated,
   AL4.QtyPicked,
   UPPER(AL2.PackUOM3) as 'UOM',
   UPPER(AL3.Lottable01) as 'Stock Status',
   AL3.Lottable02 as 'PO#',
   AL3.Lottable03 as 'Brand',
   AL3.Lottable05 as 'Rec Date',
   AL2.Pallet as 'Qty per Pallet',
   AL1.BUSR4,
   Upper(AL5.Loc) as 'Loc',
   AL1.SUSR2 as 'Average Residency Period',
   Case
      When
         ( AL1.SUSR2 ) != 'NA' 
      Then
         Case
            When
               (AL1.SUSR2)  != '' 
            Then
(AL3.Lottable05) + ((AL1.SUSR2) - 1) 
         End
   End as'Expire Date'
, MAX ( GETDATE() )  as 'GetDate'
, Case when (
	Case
		  When ( AL1.SUSR2 ) != 'NA' 
		Then
			 Case
				When  (AL1.SUSR2)  != '' 
            Then
				(AL3.Lottable05) + ((AL1.SUSR2) - 1) 
         End
   End) != ''
   then   Case when
		(Case
			  When ( AL1.SUSR2 ) != 'NA' 
			Then
				 Case
					When  (AL1.SUSR2)  != '' 
			    Then
					(AL3.Lottable05) + ((AL1.SUSR2) - 1) 
			   End
		End) <= getdate ()
   then  'Expired'
   end  
   end as 'Expired' 



FROM
   dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL1.PACKKey = AL2.PackKey 
JOIN dbo.V_LOTxLOCxID AL4 WITH (NOLOCK) ON AL4.Sku = AL1.Sku 
 AND AL4.StorerKey = AL1.StorerKey 
JOIN dbo.V_LOTATTRIBUTE AL3 WITH (NOLOCK) ON AL4.StorerKey = AL3.StorerKey 
  AND AL4.Sku = AL3.Sku AND AL4.Lot = AL3.Lot
JOIN dbo.V_LOC AL5 WITH (NOLOCK) ON AL4.Loc = AL5.Loc 
WHERE
AL4.StorerKey = 'CTXTH' 
      AND AL4.Qty > 0 
      AND Upper(AL5.Loc) NOT IN 
      (
         'CTXMISS', 'CTXTEMP'
      )
      AND UPPER(AL3.Lottable01) = 'D3' 
GROUP BY
   AL4.StorerKey, AL5.Facility, AL4.Id, AL4.Sku, AL1.DESCR, AL4.QtyAllocated, AL4.QtyPicked, UPPER(AL2.PackUOM3), UPPER(AL3.Lottable01), AL3.Lottable02, AL3.Lottable03, AL3.Lottable05, AL2.Pallet, AL1.BUSR4, Upper(AL5.Loc), AL1.SUSR2, 
   Case
      When
         (
            AL1.SUSR2
         )
         != 'NA' 
      Then
         Case
            When
               (
                  AL1.SUSR2
               )
               != '' 
            Then
(AL3.Lottable05) + ((AL1.SUSR2) - 1) 
         End
   End

GO