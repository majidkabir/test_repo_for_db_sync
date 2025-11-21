SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PTRACEDETAIL] 
AS 
SELECT [PTRACETYPE]
, [PTRACEHEADKey]
, [PA_PutawayStrategyKey]
, [PA_PutawayStrategyLineNumber]
, [PTraceDetailKey]
, [LocKey]
, [Reason]
FROM [PTRACEDETAIL] (NOLOCK) 

GO