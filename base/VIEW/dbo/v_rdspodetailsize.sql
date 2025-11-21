SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 Create VIEW [dbo].[V_rdsPODetailSize]  AS  
SELECT rdsPONo,
rdsPOLineNo,
SKU,
StorerKey,
Style,
Color,
Measurement,
Size,
UnitPrice,
Qty,
AddDate,
AddWho,
EditDate,
EditWho,
ArchiveCop,
TrafficCop
FROM rdsPODetailSize with (NOLOCK)


GO