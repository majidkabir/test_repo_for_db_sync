SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Open_Outbound] AS
SELECT
   Convert ( Varchar(10), O.EditDate, 120) AS 'MBOLDate',
   O.OrderKey,
   O.ExternOrderKey,
   OD.Sku,
   O.Status,
   sum(OD.OriginalQty) AS 'OriginalQty',
   sum(OD.QtyAllocated) AS 'QtyAllocated',
   sum(OD.QtyPicked) AS 'QtyPicked',
   sum(OD.ShippedQty) AS 'ShippedQty'
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
WHERE
   (
(O.StorerKey = 'JDSPORTS'
      AND
      (
         NOT O.Status = '9'
      )
)
   )
GROUP BY
   Convert ( Varchar(10), O.EditDate, 120),
   O.OrderKey,
   O.ExternOrderKey,
   OD.Sku,
   O.Status

GO