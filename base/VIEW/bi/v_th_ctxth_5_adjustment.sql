SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_5_Adjustment]
AS
SELECT DISTINCT AL4.StorerKey, AL4.AdjustmentKey, AL4.EditDate, AL4.AdjustmentType, AL4.Remarks, AL3.AdjustmentLineNumber,
AL3.Sku, AL3.Loc, AL3.Id, AL3.ReasonCode, AL3.UOM, AL3.Qty, AL1.DESCR, AL2.Lottable01, AL2.Lottable02, AL2.Lottable03,
AL2.Lottable05, AL4.CustomerRefNo, AL4.Facility
FROM dbo.V_SKU AL1  WITH (NOLOCK)
JOIN  dbo.V_ADJUSTMENTDETAIL AL3  WITH (NOLOCK) ON AL3.StorerKey=AL1.StorerKey AND AL3.Sku=AL1.Sku
JOIN  dbo.V_LOTATTRIBUTE AL2  WITH (NOLOCK) ON AL3.Lot=AL2.Lot AND AL3.Sku=AL2.Sku AND AL3.StorerKey=AL2.StorerKey
JOIN dbo.V_ADJUSTMENT AL4  WITH (NOLOCK) ON AL4.AdjustmentKey=AL3.AdjustmentKey AND AL4.StorerKey=AL3.StorerKey
JOIN  dbo.V_CODELKUP AL5  WITH (NOLOCK) ON AL3.ReasonCode=AL5.Code
WHERE 
(AL4.StorerKey='CTXTH' AND AL5.LISTNAME='ADJREASON' AND AL4.FinalizedFlag='Y'
AND AL4.EditDate>= convert(varchar, getdate()-1, 112)
and AL4.EditDate < convert(varchar, getdate(), 112) AND (NOT AL4.Facility='UNK'))

GO