SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   JarekLim    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_Inventory_Adjustment_Report15]
AS
SELECT
  AL1.StorerKey,
  AL1.Facility,
  AL1.AddDate,
  AL1.AdjustmentKey,
  AL1.AdjustmentType,
  AL1.CustomerRefNo,
  AL2.ReasonCode,
  AL3.Description,
  AL4.HOSTWHCODE,
  AL4.Loc,
  AL5.Sku,
  AL5.DESCR,
  AL2.Qty,
  AL1.Remarks,
  AL1.EditDate,
  AL1.EditWho,
  FLOOR(AL2.Qty / 10) as [QTY/10],
  '0' as Col1,
  AL1.AddWho,
  AL2.Lot,
  AL2.FinalizedFlag,
  AL5.Cube,
  '0' as Col2,
  '0' as Col3,
  '0' as Col4
FROM dbo.V_ADJUSTMENT AL1 WITH (NOLOCK)
JOIN dbo.V_ADJUSTMENTDETAIL AL2 WITH (NOLOCK) ON AL1.AdjustmentKey = AL2.AdjustmentKey AND AL1.StorerKey = AL2.StorerKey
JOIN dbo.V_CODELKUP AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.Storerkey AND AL2.ReasonCode = AL3.Code
JOIN dbo.V_LOC AL4 WITH (NOLOCK) ON AL2.Loc = AL4.Loc
JOIN dbo.V_SKU AL5 WITH (NOLOCK) ON AL2.StorerKey = AL5.StorerKey AND AL2.Sku = AL5.Sku
WHERE
  AL1.StorerKey = 'ADIDAS'
  AND AL3.LISTNAME = 'ADJREASON'

GO