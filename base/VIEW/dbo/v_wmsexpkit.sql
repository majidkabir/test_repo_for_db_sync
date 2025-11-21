SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WMSEXPKIT] 
AS 
SELECT [KITKey]
, [KITLineNumber]
, [Type]
, [CustRef]
, [ReasonCode]
, [Sku]
, [LOTTABLE01]
, [LOTTABLE02]
, [LOTTABLE03]
, [LOTTABLE04]
, [LOTTABLE05]
, [Qty]
, [HostWHCode]
, [TransFlag]
FROM [WMSEXPKIT] (NOLOCK) 

GO