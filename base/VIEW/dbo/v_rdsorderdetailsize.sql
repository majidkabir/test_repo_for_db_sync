SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 Create VIEW [dbo].[V_rdsOrderDetailSize]  AS  
SELECT rdsOrderNo,
rdsOrderLineNo,
SKU,
StorerKey,
Style,
Color,
Measurement,
Size,
Qty,
AddDate,
AddWho,
EditDate,
EditWho,
ArchiveCop,
TrafficCop
FROM rdsOrderDetailSize with (NOLOCK)


GO