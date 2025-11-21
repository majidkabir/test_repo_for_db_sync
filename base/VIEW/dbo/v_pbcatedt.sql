SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbcatedt] 
AS 
SELECT [pbe_name]
, [pbe_edit]
, [pbe_type]
, [pbe_cntr]
, [pbe_seqn]
, [pbe_flag]
, [pbe_work]
FROM [pbcatedt] (NOLOCK) 

GO