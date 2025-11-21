SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_InsertTCPSocketInLog                           */
/* Creation Date: 01-Nov-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: CHEE JUN YAN                                             */
/*                                                                      */
/* Purpose: Insert messages received by TCPSocketListener into				  */
/*				TCPSocket_InLog table																					*/
/*                                                                      */
/*                                                                      */
/* Called By: ??																												*/
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROC [dbo].[isp_InsertTCPSocketInLog]
     @cApplication		 NVARCHAR(50)
   , @cClientEndPoint	 NVARCHAR(50)
   , @cListenerPort		 NVARCHAR(10)
   , @cMessageType		 NVARCHAR(10)
   , @cData						 NVARCHAR(4000)
   , @nMessageNumber	 NVARCHAR(10)
   , @cStartTime			 NVARCHAR(20)
   , @cEndTime				 NVARCHAR(20)
   , @cErrMsg					 NVARCHAR(400)
   , @cStatus					 NVARCHAR(1)
AS
BEGIN
	BEGIN TRAN;

    INSERT INTO [dbo].[TCPSocket_InLog] ([Application], LocalEndPoint, RemoteEndPoint, [MessageType], [Data], [MessageNum], [StartTime], [EndTime], [ErrMsg], [Status] )
    VALUES (@cApplication, @cClientEndPoint, @cListenerPort, @cMessageType, @cData, @nMessageNumber, @cStartTime, @cEndTime, @cErrMsg, @cStatus)

	COMMIT TRAN;
END -- Procedure

GO