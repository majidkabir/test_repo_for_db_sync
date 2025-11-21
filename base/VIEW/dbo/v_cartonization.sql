SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CARTONIZATION] 
AS 
SELECT [CartonizationKey]
, [CartonizationGroup]
, [CartonType]
, [CartonDescription]
, [UseSequence]
, [Cube]
, [MaxWeight]
, [MaxCount]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [Timestamp]
, [CartonWeight]
, [CartonLength]
, [CartonWidth]
, [CartonHeight]
FROM [CARTONIZATION] (NOLOCK) 

GO