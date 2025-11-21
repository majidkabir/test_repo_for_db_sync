SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PTRACEHEAD] 
AS 
SELECT [PTRACETYPE]
, [PTRACEHEADKey]
, [Userid]
, [StorerKey]
, [Sku]
, [Lot]
, [ID]
, [PackKey]
, [Qty]
, [PA_MultiProduct]
, [PA_MultiLot]
, [StartTime]
, [EndTime]
, [PA_LocsReviewed]
, [PA_LocFound]
FROM [PTRACEHEAD] (NOLOCK) 

GO