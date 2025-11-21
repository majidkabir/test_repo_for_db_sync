SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 4-JAN-2021    Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_2_PDL_InOut report_Out]
AS
SELECT DISTINCT
   CASE WHEN
     (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
        THEN AL5.ConsigneeKey 
       ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
      END
      ) IN ('0908', '0919')
   THEN 'TESCO' 
   WHEN 
	  (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
        THEN AL5.ConsigneeKey 
       ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
      END
      ) IN ('CTXTH' , 'COPACK')
      THEN 'PDL' 
      ELSE 'OTHERS' 
   END as 'Type'
, convert(varchar, AL5.EditDate, 103) as 'Date'
, AL5.OrderKey as'WMS Doc#'
, AL5.ExternOrderKey as 'CTX Doc#' 
, CASE WHEN AL5.UserDefine01 IS NOT NULL 
    THEN '' 
  ELSE '' 
  END as 'Document No#'
, CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
   THEN AL5.ConsigneeKey 
   ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
  END as'Ship to/from'
, AL3.Company as 'Name'
, AL6.Sku as 'SKU'
, AL1.DESCR as 'DESC'
, Upper(AL4.Lottable01) as 'Stock status'
, AL4.Lottable02 as 'CD#'
, AL4.Lottable03 as 'Brand'
, AL4.Lottable05 as 'Received Date'
, sum (AL6.Qty * - 1) as 'QTY' 
, Upper(AL2.PackUOM3) as 'UOM'
, AL2.OtherUnit2 as 'Qty Conversion to Piece'
, AL1.Style as 'Item Group Descr'
, AL5.UserDefine10 as'Job#'
FROM dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL1.PACKKey = AL2.PackKey 
JOIN dbo.V_PICKDETAIL AL6 WITH (NOLOCK) ON AL6.Sku = AL1.Sku AND AL6.Storerkey = AL1.StorerKey
JOIN dbo.V_LOTATTRIBUTE AL4 WITH (NOLOCK) ON AL6.Lot = AL4.Lot AND AL6.Storerkey = AL4.StorerKey 
LEFT OUTER JOIN dbo.V_ORDERS AL5 ON AL5.StorerKey = AL6.Storerkey AND AL5.OrderKey = AL6.OrderKey 
JOIN dbo.V_STORER AL3 WITH (NOLOCK) ON (AL5.ConsigneeKey = AL3.StorerKey)
WHERE
(AL5.StorerKey = 'CTXTH' 
      AND AL5.EditDate >= convert(varchar, getdate() - 1, 112) 
      and AL5.EditDate < convert(varchar, getdate(), 112) 
      AND AL5.Status = '9' 
      AND 
      (
         NOT AL5.Type = '3'
      )
      AND AL5.Type = 'CTX1')

GROUP BY
   CASE WHEN
     (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
        THEN AL5.ConsigneeKey 
       ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
      END ) IN ('0908', '0919')
      THEN 'TESCO' 
      WHEN 
		 (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
          THEN AL5.ConsigneeKey 
          ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
        END) IN('CTXTH' , 'COPACK')
      THEN 'PDL' 
      ELSE 'OTHERS' 
    END
, CONVERT(varchar, AL5.EditDate, 103), AL5.OrderKey, AL5.ExternOrderKey
, CASE WHEN
         AL5.UserDefine01 IS NOT NULL 
    THEN '' 
   ELSE '' 
   End
, CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
    THEN AL5.ConsigneeKey 
    ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
  END
, AL3.Company
, AL6.Sku
, AL1.DESCR
, Upper(AL4.Lottable01)
, AL4.Lottable02
, AL4.Lottable03
, AL4.Lottable05
, Upper(AL2.PackUOM3)
, AL2.OtherUnit2
, AL1.Style
, AL5.UserDefine10

GO