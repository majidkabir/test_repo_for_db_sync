SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_WAVEDETAIL] 
AS 
SELECT [WaveDetailKey]
, [WaveKey]
, [OrderKey]
, [ProcessFlag]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [WAVEDETAIL] (NOLOCK) 

GO