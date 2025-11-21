SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 12-JAN-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_3_DAILY_OUT_EXC_PDL]
AS
SELECT DISTINCT
   CASE WHEN 
	  (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
         THEN AL5.ConsigneeKey 
         ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
        END)
      IN (
          '0908', '0919', '0642', '0012', '0045', '0029', '0001', '0016', '0018', '0020', '0022'
			 , '0027', '0028', '0032', '0049', '0054', '0060', '0057', '5129', '0069', '0021', '0066'
			 , '0063', '0043', '0005', '0023', '0585', '0007', '5130'
         )
      THEN
         'TESCO' 
      WHEN
         ( CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
             THEN AL5.ConsigneeKey 
             ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
            END)
       IN('CTXTH' , 'COPACK')
      THEN 'PDL' 
      ELSE 'OTHERS' 
   END as 'Type'
  , convert(varchar, AL5.EditDate, 103) as 'DATE'
  , AL5.OrderKey as 'WMS Doc#'
  , AL5.ExternOrderKey as 'CTX Doc#'
  , CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
    THEN AL5.ConsigneeKey 
   ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
   END as 'Ship to/From'
  , AL3.Company as 'Name'
  , AL6.Sku as 'SKU', AL1.DESCR as 'Descr'
  , Upper(AL4.Lottable01) as 'Stock Status'
  , AL4.Lottable02 as 'CD#', AL4.Lottable03 as 'Brand'
  , AL4.Lottable05 as'Received Date'
  , sum (AL6.Qty * - 1) as 'Qty'
  , Upper(AL2.PackUOM3) as 'UOM'
FROM
   dbo.V_STORER AL3  
   LEFT OUTER JOIN   dbo.V_ORDERS AL5  ON (AL5.ConsigneeKey = AL3.StorerKey) 
   JOIN dbo.V_PICKDETAIL AL6  on AL5.StorerKey = AL6.Storerkey  AND AL5.OrderKey = AL6.OrderKey 
   JOIN dbo.V_SKU AL1 on  AL6.Sku = AL1.Sku    AND AL6.Storerkey = AL1.StorerKey
   JOIN dbo.V_PACK AL2 on   AL1.PACKKey = AL2.PackKey 
   JOIN dbo.V_LOTATTRIBUTE AL4 on AL6.Lot = AL4.Lot  AND AL6.Storerkey = AL4.StorerKey

WHERE
      AL5.StorerKey = 'CTXTH' 
      AND  AL5.EditDate >= convert(varchar, getdate() - 1, 112) 
      and  AL5.EditDate < convert(varchar, getdate(), 112) 
      AND AL5.Status = '9' 
      AND AL5.Facility = 'FC'
   
GROUP BY
   CASE WHEN
     (CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
        THEN AL5.ConsigneeKey 
      ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
      END)
      IN (
         '0908', '0919', '0642', '0012', '0045', '0029', '0001', '0016', '0018', '0020'
			, '0022', '0027', '0028', '0032', '0049', '0054', '0060', '0057', '5129', '0069'
			, '0021', '0066', '0063', '0043', '0005', '0023', '0585', '0007', '5130'
         )
      THEN 'TESCO' 
      WHEN(CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
             THEN AL5.ConsigneeKey 
            ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
            END)
       IN ('CTXTH' , 'COPACK')
      THEN 'PDL' 
      ELSE
         'OTHERS' 
     END
, convert(varchar, AL5.EditDate, 103)
, AL5.OrderKey
, AL5.ExternOrderKey
, CASE WHEN AL5.ConsigneeKey = 'CTXTH' 
    THEN AL5.ConsigneeKey 
    ELSE SUBSTRING(AL5.ConsigneeKey, 4, 10) 
   END
, AL3.Company, AL6.Sku, AL1.DESCR, Upper(AL4.Lottable01), AL4.Lottable02, AL4.Lottable03
, AL4.Lottable05, Upper(AL2.PackUOM3),  AL5.ConsigneeKey

GO