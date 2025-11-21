SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH-SINOTH-Add Views in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18650
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   JarekLim    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_EComOrdersPerHour]
AS
SELECT
  AL1.StorerKey,
  AL1.ExternOrderKey,
  AL1.OrderKey,
  AL1.AddDate
FROM dbo.V_ORDERS AL1
WHERE ((AL1.StorerKey = 'ADIDAS'
AND AL1.ExternOrderKey LIKE '%ATH%'
AND AL1.AddDate >= GETDATE() - 0.0415
AND AL1.DocType = 'E'))

GO