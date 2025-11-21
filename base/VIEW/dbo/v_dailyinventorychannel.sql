SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW v_DailyInventoryChannel
AS
Select   * from dbo.DailyInventoryChannel (NOLOCK) 

GO