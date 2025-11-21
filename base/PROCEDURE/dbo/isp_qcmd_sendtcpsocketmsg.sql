SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_QCmd_SendTCPSocketMsg                          */  
/* Creation Date: 16-May-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Submitting task to Q commander                              */
/*          Duplicate from isp_SendTCPSocketMsg                         */  
/*                                                                      */  
/*                                                                      */  
/* Called By:  Any other related Store Procedures.                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */ 
/* 06-Oct-2016  MCTang     Add Port (MC01)                              */ 
/* 31-Oct-2016  MCTang     --Call isp_GenericTCPSocketClient2           */
/* 13-Nov-2016  MCTang     Direct update outlog to 9                    */
/* 06-Apr-2017  Ung        Remove update                                */
/*                         Enable AddDate, EditDate diff                */
/*                         Try catch                                    */
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_SendTCPSocketMsg]
   @cApplication     NVARCHAR(30),
   @cStorerKey       NVARCHAR(15), 
   @cMessageNum      NVARCHAR(10)='',
   @cData            NVARCHAR(4000),
   @cIP              NVARCHAR(20)='',     --(MC01)
   @cPORT            NVARCHAR(5)='',      --(MC01)
   @cIniFilePath     NVARCHAR(200)='',    --(MC01)
   @cDataReceived    NVARCHAR(4000)   OUTPUT,
   @bSuccess         INT=1            OUTPUT, 
   @nErr             INT=0            OUTPUT, 
   @cErrMsg          NVARCHAR(256)='' OUTPUT

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cRemoteEndPoint  NVARCHAR(30),
           @cLocalEndPoint   NVARCHAR(200),
           @cVBErrMsg        NVARCHAR(256), 
           @dStartDate       DATETIME, 
           @dEndDate         DATETIME
   
   --SET @cIniFilePath = ''         --(MC01)     
   --SET @cRemoteEndPoint = ''      --(MC01)  

   SET @cRemoteEndPoint = RTRIM(LTRIM(@cIP)) + ':' +  RTRIM(LTRIM(@cPORT))    --(MC01)
   
   IF ISNULL(RTRIM(@cIniFilePath),'') = '' OR ISNULL(RTRIM(@cRemoteEndPoint),'') = ''
   BEGIN
   	SET @nErr = 65101
   	SET @cErrMsg = 'Error: ' + CAST(@nErr AS VARCHAR(6)) + ' TCPClient Not Setup in CodeLkup Table!' 
   	GOTO QUIT_PROC
   END
    PRINT 'Sending request to isp_GenericTCPSocketClient...' + @cIniFilePath + '----- RemoteEndPoint   '+ @cRemoteEndPoint
   SET @dStartDate = GETDATE()
   BEGIN TRY
   	EXEC [master].[dbo].[isp_GenericTCPSocketClient]        
          @cIniFilePath,        
          @cRemoteEndPoint,        
          @cData,        
          @cLocalEndPoint    OUTPUT,        
          @cDataReceived     OUTPUT,        
          @cVBErrMsg         OUTPUT 
   END TRY
   BEGIN CATCH
      -- A TRYàCATCH construct catches all execution errors that have a severity higher than 10 that do not close the database connection.
      IF @cVBErrMsg IS NULL
         SET @cVBErrMsg = LEFT( ISNULL( ERROR_MESSAGE(), ''), 256)
   END CATCH
   SET @dEndDate = GETDATE()
   
   SET @cVBErrMsg = ISNULL( @cVBErrMsg, '')           
   SET @cLocalEndPoint = ISNULL( @cLocalEndPoint,'') 
   
   IF @cVBErrMsg = ''        
   BEGIN        
      INSERT INTO TCPSocket_OutLog
         (MessageNum, MessageType, [Application], Data, [Status], StorerKey, LabelNo, BatchNo, RemoteEndPoint, AddDate, EditDate)
      VALUES
         (@cMessageNum, 'SEND', @cApplication, @cData, '9', @cStorerKey, '', '', @cRemoteEndPoint, @dStartDate, @dEndDate)

      SET @bSuccess=1
      SET @nErr = 0
      SET @cErrMsg = '' 
   END
   ELSE 
   BEGIN
      INSERT INTO TCPSocket_OutLog
         (MessageNum, MessageType, [Application], Data, [Status], StorerKey, LabelNo, BatchNo, RemoteEndPoint, ErrMsg, LocalEndPoint, AddDate, EditDate)
      VALUES
         (@cMessageNum, 'SEND', @cApplication, @cData, '5', @cStorerKey, '', '', @cRemoteEndPoint, @cVBErrMsg, @cLocalEndPoint, @dStartDate, @dEndDate)

      SET @bSuccess=0
      SET @nErr = 80453
      SET @cErrMsg = @cVBErrMsg
   END

   QUIT_PROC:
   
END -- procedure

GO