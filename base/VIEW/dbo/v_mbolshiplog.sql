SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_MBOLShipLog] 
AS 
SELECT [StorerKey]
, [MBOLKey]
, [Status]
FROM [MBOLShipLog] (NOLOCK) 




GO