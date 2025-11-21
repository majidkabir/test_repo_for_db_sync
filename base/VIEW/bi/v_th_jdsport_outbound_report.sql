SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Outbound_Report] AS
SELECT
   Convert ( Varchar(10), O.EditDate, 120) AS 'MBOLDate',
   O.ExternOrderKey,
   O.OrderKey,
   sum(OD.ShippedQty) AS 'ShippedQty',
   Convert ( Varchar(10), O.AddDate, 120) AS 'DropDate',
   OD.Sku,
   sum(OD.OriginalQty) AS 'OriginalQty'
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
WHERE
   (
(O.StorerKey = 'JDSPORTS'
      AND O.Status = '9'
      AND
      (
         O.EditDate >= Convert(VarChar(10), GetDate() - 8, 121)
         and O.EditDate < Convert(VarChar(10), GetDate(), 121)
      )
)
   )
GROUP BY
   Convert ( Varchar(10), O.EditDate, 120),
   O.ExternOrderKey,
   O.OrderKey,
   Convert ( Varchar(10), O.AddDate, 120),
   OD.Sku

GO