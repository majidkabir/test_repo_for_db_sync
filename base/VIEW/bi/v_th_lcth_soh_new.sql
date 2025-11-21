SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_LCTH_SOH_new]
AS
SELECT
   AL3.SKUGROUP AS 'Product Cat',
   AL3.itemclass AS 'Main Sub',
   AL3.BUSR3 AS 'Sub',
   AL1.Sku,
   AL3.RETAILSKU AS 'Barcode',
   AL3.DESCR AS 'Descr',
   AL1.QtyAllocated,
   AL1.QtyPicked,
   AL1.Loc,
   AL2.PackUOM3 AS 'UOM',
   AL4.Lottable03 AS 'IBInvoice',
   AL1.Qty,
   AL5.Status AS 'Status',
    (AL1.Qty- AL1.QtyAllocated - AL1.QtyPicked - (case
      when
         (
            AL5.Status
         )
         = 'Hold'
      then
(AL1.Qty)
      else
         '0' end )
		 ) as 'Qty Avaliable'
   ,case
      when
         (
            AL5.Status
         )
         = 'Hold'
      then
(AL1.Qty)
      else
         '0'
   end  as 'QTYonHold'
   ,case
      when (AL3.SKUGROUP) = 'CIR2' then 'CAST IRON-TRADITION'
	  when (AL3.SKUGROUP) = 'CIR1' then 'CAST IRON-SIGNATURE'
	  when (AL3.SKUGROUP) = 'STD'  then 'STD'
	  when (AL3.SKUGROUP) = 'STW' then 'STONEWARE'
	  when (AL3.SKUGROUP) = 'Silicone' then 'SILICONE'
	  when (AL3.SKUGROUP) = 'Textiles' then 'TEXTILES'
	  when (AL3.SKUGROUP) = 'TOOLS' then 'TOOLS'
	  when (AL3.SKUGROUP) = 'TNS1' then 'TOUGHENED NON-STICK'
	  end as 'Product category'
, AL3.Color, AL4.Lottable02, AL3.Style
FROM
   dbo.V_LOTxLOCxID AL1 WITH (NOLOCK)
JOIN dbo.V_SKU AL3 WITH (NOLOCK) ON AL1.StorerKey = AL3.StorerKey AND AL1.Sku = AL3.Sku
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL3.PACKKey = AL2.PackKey
JOIN dbo.V_LOTATTRIBUTE AL4 WITH (NOLOCK) ON AL1.StorerKey = AL4.StorerKey AND AL1.Sku = AL4.Sku AND AL1.Lot = AL4.Lot
JOIN dbo.V_LOC AL5 WITH (NOLOCK) ON AL1.Loc = AL5.Loc
WHERE

(AL1.StorerKey = 'LCTH'
      AND
      (
         NOT AL1.Qty = 0
      )
      AND AL5.Facility = 'BNK19')


GO