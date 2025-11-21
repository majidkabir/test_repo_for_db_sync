SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_DeviceProfileLog]
AS Select *
FROM [dbo].[DeviceProfileLog] with (NOLOCK)

GO