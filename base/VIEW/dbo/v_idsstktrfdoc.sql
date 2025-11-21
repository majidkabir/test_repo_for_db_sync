SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_idsStkTrfDoc] 
AS 
SELECT  [STDNo]
, [Facility]
, [TruckNo]
, [StorerKey]
, [DriverName]
, [Finalized]
, [DestCode]
, [WHSEID]
, [TrxType]
, [ReasonCode]
, [AddDate]
, [AddWho]
, [SourceID]
, [ArchiveCop]
FROM [idsStkTrfDoc] (NOLOCK) 



GO