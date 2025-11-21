SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_Pl_Usr]
AS
SELECT *
FROM AUTSecure.dbo.pl_usr (nolock)


GO