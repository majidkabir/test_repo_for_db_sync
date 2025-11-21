SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_nCounterNSC] 
AS 
SELECT [keyname]
, [keycount]
FROM [nCounterNSC] (NOLOCK) 

GO