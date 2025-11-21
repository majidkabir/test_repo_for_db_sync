SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 /***************************************************************************************************************
Title: [JP] WMS_Add_View_To_BI_Schema_For_JReport - TCPSocket_OUTLog
Date		   Author			Ver		Purposes
23/11/2021  JarekLim       1.0      Create BI View https://jiralfl.atlassian.net/browse/WMS-18438
****************************************************************************************************************/
CREATE   VIEW [BI].[V_TCPSocket_OUTLog]
AS
SELECT * FROM [dbo].[TCPSocket_OUTLog] WITH (NOLOCK)

GO