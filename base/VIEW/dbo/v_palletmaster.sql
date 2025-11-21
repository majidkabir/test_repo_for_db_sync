SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PalletMaster] 
AS 
SELECT [Pallet_type]
, [Descr]
, [Maxcube]
, [Maxwgt]
, [Maxunit]
, [AddWho]
, [AddDate]
, [EditWho]
, [EditDate]
FROM [PalletMaster] (NOLOCK) 

GO