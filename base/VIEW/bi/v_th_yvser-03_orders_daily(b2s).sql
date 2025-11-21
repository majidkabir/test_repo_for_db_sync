SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   view [BI].[V_TH_YVSER-03_Orders_Daily(B2S)] as
SELECT
   O.AddDate,
   O.ExternOrderKey
FROM
   dbo.ORDERS O
WHERE
   (
(O.Type = 'B2S'
      AND O.AddDate > convert(datetime, convert(varchar, GetDate() - 1, 23) + ' 00:01:00', 120)
      and O.AddDate <= convert(datetime, convert(varchar, GetDate(), 23) + ' 00:00:00', 120)
      AND O.StorerKey = 'YVESR')
   )

GO