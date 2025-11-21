SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_Transmitlog_All]
AS
SELECT     dbo.Transmitlog.*
FROM       dbo.Transmitlog (nolock)





GO