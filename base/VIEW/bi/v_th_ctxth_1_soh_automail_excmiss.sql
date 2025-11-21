SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_1_SOH_AUTOmail_excmiss]
AS
SELECT DISTINCT
   AL3.Lottable01 + '-' + 
   Case
      When
         AL5.Status = 'Hold' 
      Then
         'ST' 
      Else
         Case
            When
               AL5.Status = 'Ok' 
               And AL5.LocationCategory = 'DD' 
            Then
               'DD' 
            Else
               Case
                  When
                     AL5.Status = 'Ok' 
                     And AL5.LocationCategory <> 'DD' 
                  Then
                     'DI' 
               End
         End
   End as 'ERP-WH'
, AL1.BUSR5 as 'RM-FG', AL4.StorerKey, AL5.Facility as 'Warehouse', AL4.Id as 'Palletid', AL4.Sku, AL1.DESCR, sum(AL4.Qty) -( AL4.QtyAllocated+ AL4.QtyPicked) as 'Avail qty',
sum(AL4.Qty) as 'Qty', AL4.QtyAllocated, AL4.QtyPicked,
UPPER(AL2.PackUOM3) as 'UOM', UPPER(AL3.Lottable01) as 'Stock Status', AL3.Lottable02 as 'PO#', AL3.Lottable03 as  'Brand', AL3.Lottable05 as  'Rec Date' , AL2.Pallet as 'Qty per Pallet', AL1.BUSR4, 
Upper(AL5.Loc)as 'loc', AL1.BUSR10 as 'Old Residency Period', AL1.ShelfLife as 'Adjusted Residency Period', 
   Case
      When
         (
            AL1.ShelfLife
         )
         != '' 
      Then
(AL3.Lottable05) + ((AL1.ShelfLife) - 0) 
   End as 'Expire Date' 
   ,

   Case
       When ( Case   When  ( AL1.ShelfLife) != '' 
				Then (AL3.Lottable05) + ((AL1.ShelfLife) - 0) 
				End
) !=''
then 
  Case when ((AL3.Lottable05) + ((AL1.ShelfLife) - 0) )<= Getdate()
      then 'Expired'
	  end 
 end  as 'expired'


, MAX ( GETDATE() ) as 'Date now', 
   Case
      when
         UPPER(AL3.Lottable01) = 'S' 
      Then
         '1st' 

      Else
         Case
            when
               UPPER(AL3.Lottable01) = 'R' 
            Then
               '2nd' 

            Else
               Case
                  when
                     UPPER(AL3.Lottable01) = 'Q' 
                  Then
                     '3rd' 
			
                  Else
                     Case
                        when
                           UPPER(AL3.Lottable01) like 'H%' 
                           Or UPPER(AL3.Lottable01) like 'D%' 
                           Or UPPER(AL3.Lottable01) like 'RJR%' 
                        Then
                           'NO' 
						
                     End
               End
         End
   End as  'Prioritys'
   ,
	   Case
      when
         UPPER(AL3.Lottable01) = 'S' 
      Then
         'Yellow' 

      Else
         Case
            when
               UPPER(AL3.Lottable01) = 'R' 
            Then
               'Green' 

            Else
               Case
                  when
                     UPPER(AL3.Lottable01) = 'Q' 
                  Then
                     'White' 
			
                  Else
                     Case
                        when
                           UPPER(AL3.Lottable01) like 'H%' 
                           Or UPPER(AL3.Lottable01) like 'D%' 
                           Or UPPER(AL3.Lottable01) like 'RJR%' 
                        Then
                           'Red' 
						
                     End
               End
         End
   End as  'Color' 
	
, AL3.Lottable04 as 'System Expire', AL1.Style  as'Item Description'


FROM
   dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL1.PACKKey = AL2.PackKey 
JOIN dbo.V_LOTxLOCxID AL4 WITH (NOLOCK) ON AL4.Sku = AL1.Sku AND AL4.StorerKey = AL1.StorerKey 
JOIN dbo.V_LOTATTRIBUTE AL3 WITH (NOLOCK) ON AL4.Lot = AL3.Lot AND AL4.StorerKey = AL3.StorerKey AND AL4.Sku = AL3.Sku 
JOIN dbo.V_LOC AL5 WITH (NOLOCK) ON AL4.Loc = AL5.Loc 
WHERE
(AL4.StorerKey = 'CTXTH' 
      AND AL4.Qty > 0 
      AND Upper(AL5.Loc) NOT IN 
      (
         'CTXMISS', 'CTXTEMP'
      )
      AND AL5.Facility = 'FC')
GROUP BY
   AL3.Lottable01 + '-' + 
   Case
      When
         AL5.Status = 'Hold' 
      Then
         'ST' 
      Else
         Case
            When
               AL5.Status = 'Ok' 
               And AL5.LocationCategory = 'DD' 
            Then
               'DD'
            Else
               Case
                  When
                     AL5.Status = 'Ok' 
                     And AL5.LocationCategory <> 'DD' 
                  Then
                     'DI' 
               End
         End
   End
, AL1.BUSR5, AL4.StorerKey, AL5.Facility, AL4.Id, AL4.Sku, AL1.DESCR, AL4.QtyAllocated, AL4.QtyPicked, UPPER(AL2.PackUOM3), UPPER(AL3.Lottable01), AL3.Lottable02, AL3.Lottable03, AL3.Lottable05, AL2.Pallet, AL1.BUSR4, Upper(AL5.Loc), AL1.BUSR10, AL1.ShelfLife, 
   Case
      When
         (
            AL1.ShelfLife
         )
         != '' 
      Then
(AL3.Lottable05) + ((AL1.ShelfLife) - 0) 
   End
, 
   Case
      when
         UPPER(AL3.Lottable01) = 'S' 
      Then
         '1st' 
      Else
         Case
            when
               UPPER(AL3.Lottable01) = 'R' 
            Then
               '2nd' 
            Else
               Case
                  when
                     UPPER(AL3.Lottable01) = 'Q' 
                  Then
                     '3rd' 
                  Else
                     Case
                        when
                           UPPER(AL3.Lottable01) like 'H%' 
                           Or UPPER(AL3.Lottable01) like 'D%' 
                           Or UPPER(AL3.Lottable01) like 'RJR%' 
                        Then
                           'NO' 
                     End
               End
         End
   End
, AL3.Lottable04, AL1.Style

GO