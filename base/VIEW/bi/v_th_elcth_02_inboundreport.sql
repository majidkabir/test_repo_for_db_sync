SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
-- Purpose: Pls Create view on DB THWMS(PROD) https://jiralfl.atlassian.net/browse/WMS-19109
/* Updates:																   */
/* Date         Author      Ver.	Purposes							   */
/* 08-Mar-2021  JarekLim    1.0		Created								   */
/***************************************************************************/
CREATE   VIEW [BI].[V_TH_ELCTH_02_InboundReport] as
SELECT
   AL2.ExternPOKey as 'IBD#',
   AL2.SellerName,
   AL3.Sku,
   AL1.DESCR,
   AL3.ExternLineNo,
   AL3.QtyOrdered,
   AL3.UOM,
   AL2.AddDate as 'IBD sent to LF',
   Case
      when
         AL2.ExternStatus = '9'
      then
         'Closed'
      when
         AL2.ExternStatus = 'CANC'
      then
         'Cancel'
      else
         'Open'
   end as 'Status'
, AL3.QtyReceived, AL2.AddWho, AL3.Lottable02 as 'Batch',
  AL5.ReceiptKey,
   Case
      when
         (
            Case
               when
                  AL2.ExternStatus = '9'
               then
                  'Closed'
               when
                  AL2.ExternStatus = 'CANC'
               then
                  'Cancel'
               else
                  'Open'
            end
         )
         = 'Closed'
      then
         AL5.FinalizeDate
      else
         ''
   end as'LF perform GR/Sent Interface to Elanco'
FROM
   BI.V_SKU AL1
   join BI.V_PODetail AL3 on (AL3.StorerKey = AL1.StorerKey   AND AL3.Sku = AL1.Sku)
   join BI.V_PO AL2 on  (  AL2.StorerKey = AL3.StorerKey AND AL2.POKey = AL3.POKey )
   LEFT OUTER JOIN  BI.V_RECEIPT AL5
      ON (AL2.StorerKey = AL5.StorerKey
      AND AL2.ExternPOKey = AL5.ExternReceiptKey)
WHERE

   (
(AL2.StorerKey = 'ELCTH'
      )
   )


GO