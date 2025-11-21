SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE    VIEW [BI].[V_ChannelInv] AS  
SELECT *
FROM dbo.V_ChannelInv (nolock)

GO