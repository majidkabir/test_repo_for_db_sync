SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_UpdateTCPSpoolerVersion                        */    
/* Purpose: Update rdtRdtSpooker TCPSocketVersion                       */    
/* Return Status: None                                                  */    
/* Called By: SQL Schedule Job                                          */    
/* Updates:                                                             */    
/* Date         Author       Purposes                                   */    
/* 04-Nov-2020  Shong        Created                                    */
/************************************************************************/    
CREATE PROC [dbo].[isp_UpdateTCPSpoolerVersion] 
AS 
BEGIN
   SET NOCOUNT ON

   DECLARE @c_IPAddress nvarchar(40), @c_PortNo nvarchar(5), 
           @c_Response  NVARCHAR(200), @c_ErrMsg NVARCHAR(215), 
           @c_SpoolerGroup NVARCHAR(20), 
           @c_Command  NVARCHAR(50),
           @b_Debug    INT = 0 

   -- Command
   ---======================
   -- GetINI
   -- SetINI
   -- GetAppVersion
   -- GetAppEXEDate
   -- GetAppEXEFilePath
   -- RestartApp
   -- StartListen
   -- Restart
   -- HeartBit
   -- GetAllPrintTask
   -- ClearAllTask
   -- GetINIThread
   -- SetINIThread
   -- AutoVersionUpdate
 

   DECLARE @t_TCP Table ( IPAddress VARCHAR(15), PortNo VARCHAR(4))

   INSERT INTO @t_TCP (IPAddress, PortNo)
   SELECT 
      Distinct SUBSTRING(RemoteEndPoint, 1, Charindex(':',RemoteEndPoint) - 1) as IPAddr, 
               RIGHT(RemoteEndPoint, 4) As Port
   from tcpsocket_outlog (nolock)
   where application='TCPSPOOLER' 

   SET @c_Command = 'GetAppVersion'

   DECLARE my_cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RS.IPAddress, RS.PortNo, RS.SpoolerGroup
   FROM rdt.rdtSpooler RS WITH (NOLOCK)
   WHERE EXISTS(SELECT 1 FROM @t_TCP T where RS.IPAddress = T.IPAddress AND RS.PortNo = T.PortNo)

   OPEN my_cursor

   FETCH FROM my_cursor INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup

   WHILE @@FETCH_STATUS = 0
   BEGIN
  	   SET @c_Response = ''
  	   SET @c_ErrMsg = ''
  	
      EXEC [dbo].[isp_WSM_SendTCPSpoolerCommand] 
   	   @c_IP = @c_IPAddress, 
   	   @c_Port = @c_PortNo, 
   	   @c_Command = @c_Command,
   	   @c_Param1='', 
   	   @c_Param2='', 
   	   @c_Param3='', 
   	   @c_Param4='', 
   	   @c_Param5='', 
   	   @b_Success=1, 
   	   @n_Err=0,
   	   @c_ErrMsg=@c_ErrMsg OUTPUT, 
   	   @c_ACKMsg = @c_Response OUTPUT 

      IF @c_ErrMsg <> ''
      BEGIN
   	   IF CHARINDEX('No connection', @c_ErrMsg) > 0 
   	   BEGIN
   		   SET @c_Response  ='No Connection'
   	   END
   	   -- PRINT @c_ErrMsg;   
      END      
      ELSE 
      BEGIN
         UPDATE rdt.rdtSpooler 
            SET TCPSpoolerVersion = @c_Response, 
                EditDate=GETDATE()
         WHERE SpoolerGroup = @c_SpoolerGroup 
      END 
      
      IF @b_Debug = 1
      BEGIN
         PRINT 'SpoolerGroup: ' + @c_SpoolerGroup + ' IP: ' + @c_IPAddress + ' Port: ' + @c_PortNo  + ' Response: ' + @c_Response
      END 

	   FETCH FROM my_cursor INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup
   END

   CLOSE my_cursor
   DEALLOCATE my_cursor
 END 

GO