SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_nCounterTrigantic] 
AS 
SELECT [keyname]
, [keycount]
FROM [nCounterTrigantic] (NOLOCK) 

GO