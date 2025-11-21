SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_MESSAGE_ID] 
AS 
SELECT [MsgId]
, [MsgIcon]
, [MsgButton]
, [MsgDefaultButton]
, [MsgSeverity]
, [MsgPrint]
, [MsgUserInput]
FROM [MESSAGE_ID] (NOLOCK) 

GO