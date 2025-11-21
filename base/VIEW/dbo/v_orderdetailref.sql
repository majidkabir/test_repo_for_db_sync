SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
CREATE VIEW [dbo].[V_OrderDetailRef]
AS
SELECT  *
FROM dbo.[OrderDetailRef] with (NOLOCK)



GO