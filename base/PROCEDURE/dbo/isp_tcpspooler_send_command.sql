SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*************************************************************************/    
/* Stored Procedure: isp_TCPSpooler_Send_Command                         */    
/* Creation Date: 03 Oct 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: Shong                                                     */    
/*                                                                       */    
/* Purpose: Send Command to TCP Spooler                                  */    
/*                                                                       */    
/* Called By:                                                            */    
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */       
/*************************************************************************/    
CREATE PROC [dbo].[isp_TCPSpooler_Send_Command] (
	@c_Command        VARCHAR(200)   = '' 
,  @c_Param1         NVARCHAR(100)  = ''    
,  @c_Param2         NVARCHAR(100)  = ''    
,  @c_Param3         NVARCHAR(100)  = ''    
,  @c_Param4         NVARCHAR(100)  = ''    
,  @c_Param5         NVARCHAR(100)  = ''    	
,	@c_SpoolerStatus  CHAR(1)        = 'A' -- A=Active, N=Not Active, B=Both, S=Session, I=IP Address  
,	@c_IPAddress      NVARCHAR(40)   = ''
,	@c_PortNo         NVARCHAR(5)    = '' ) 
AS
BEGIN
   SET NOCOUNT ON

   IF OBJECT_ID('tempdb..#t_Result') IS NOT NULL
      DROP TABLE #t_Result
      
   CREATE TABLE #t_Result (
   	SpoolerGroup NVARCHAR(20), 
   	IP           VARCHAR(20), 
   	PORT         VARCHAR(10),
   	ResponseMsg  NVARCHAR(500) 
   ) 
   
   DECLARE 
   	@c_Response     NVARCHAR(200), 
      @c_ErrMsg       NVARCHAR(215), 
      @c_SpoolerGroup NVARCHAR(20) 

   IF @c_SpoolerStatus = 'A'
   BEGIN
      DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Distinct rs.IPAddress, rs.PortNo, rs.SpoolerGroup  
      FROM rdt.RDTPrintJob_Log AS rjl WITH(NOLOCK) 
      JOIN rdt.RDTPrinter AS r WITH(NOLOCK) ON rjl.Printer = r.PrinterID
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup
      WHERE rjl.JobType='TCPSPOOLER'
      AND rjl.AddDate > DATEADD(hour, -24, GETDATE())
      ORDER BY 1 DESC   	
   END
   ELSE IF @c_SpoolerStatus = 'N'
   BEGIN
   	DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Distinct rs.IPAddress, rs.PortNo, rs.SpoolerGroup  
      FROM rdt.RDTPrinter AS r WITH(NOLOCK)
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup 
      LEFT OUTER JOIN rdt.RDTPrintJob_Log AS rjl WITH(NOLOCK) ON rjl.Printer = r.PrinterID 
                  AND rjl.AddDate > DATEADD(hour, -24, GETDATE()) 
                  AND rjl.JobType='TCPSPOOLER'      
      WHERE rs.PortNo LIKE '50%'
      AND rjl.JobId IS NULL
      ORDER BY 1 DESC   	
   END
   ELSE IF @c_SpoolerStatus = 'B'
   BEGIN
      DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Distinct rs.IPAddress, rs.PortNo, rs.SpoolerGroup  
      FROM rdt.RDTPrintJob_Log AS rjl WITH(NOLOCK) 
      JOIN rdt.RDTPrinter AS r WITH(NOLOCK) ON rjl.Printer = r.PrinterID
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup
      WHERE rjl.JobType='TCPSPOOLER'
      AND rjl.AddDate > DATEADD(hour, -24, GETDATE())
      UNION ALL    	         	
      SELECT Distinct rs.IPAddress, rs.PortNo, rs.SpoolerGroup  
      FROM rdt.RDTPrinter AS r WITH(NOLOCK)
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup 
      LEFT OUTER JOIN rdt.RDTPrintJob_Log AS rjl WITH(NOLOCK) ON rjl.Printer = r.PrinterID 
                  AND rjl.AddDate > DATEADD(hour, -24, GETDATE()) 
                  AND rjl.JobType='TCPSPOOLER'      
      WHERE rs.PortNo LIKE '50%'
      AND rjl.JobId IS NULL   	
   END	
   ELSE IF @c_SpoolerStatus = 'S'
   BEGIN
      DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT c.client_net_address
            ,SUBSTRING( s.program_name, PATINDEX('%_PRT_[0-9]%', s.program_name) - 4, 4) AS Port
            ,'' 
      FROM sys.dm_exec_connections       AS c
      JOIN sys.dm_exec_sessions     AS s
                  ON  c.session_id = s.session_id
      WHERE  s.program_name LIKE 'socket_Spooler%_Prt%'
             AND c.net_transport = 'Session'
      GROUP BY s.host_name, c.client_net_address
            ,s.login_name
            ,SUBSTRING( s.program_name, PATINDEX('%_PRT_[0-9]%', s.program_name) - 4, 4)      	
   END
   ELSE IF @c_IPAddress <> '' AND @c_PortNo <> '' AND @c_SpoolerStatus='I'
   BEGIN
      DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT @c_IPAddress
            ,@c_PortNo
            ,''
   END   
   ELSE 
   BEGIN
   	RETURN 
   END

   OPEN CUR_TCPSPOOLER_SERVERS

   FETCH FROM CUR_TCPSPOOLER_SERVERS INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup

   WHILE @@FETCH_STATUS = 0
   BEGIN
  	   SET @c_Response = ''
  	   SET @c_ErrMsg = ''
  	
      EXEC [dbo].[isp_WSM_SendTCPSpoolerCommand] 
   	   @c_IP = @c_IPAddress, 
   	   @c_Port = @c_PortNo, 
   	   @c_Command = @c_Command,
   	   @c_Param1=@c_Param1, 
   	   @c_Param2=@c_Param2, 
   	   @c_Param3=@c_Param3, 
   	   @c_Param4=@c_Param4, 
   	   @c_Param5=@c_Param5, 
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
      --ELSE 
      --BEGIN
      --	PRINT @c_Response    	
      --END
      
      IF @c_SpoolerGroup=''
      BEGIN
      	SELECT @c_SpoolerGroup = ISNULL(rs.SpoolerGroup,'')
      	FROM RDT.rdtSpooler AS rs WITH(NOLOCK)
      	WHERE rs.IPAddress=@c_IPAddress 
      	AND rs.PortNo =rs.PortNo
      	
      	IF @c_SpoolerGroup = ''
      	   SET @c_SpoolerGroup = 'Not Configure' 
      END
      
      INSERT INTO #t_Result
      (
      	SpoolerGroup,
      	IP,
      	PORT,
      	ResponseMsg
      )
      VALUES
      (
      	@c_SpoolerGroup,
      	@c_IPAddress,
      	@c_PortNo,
      	@c_Response
      )
      --PRINT 'SpoolerGroup: ' + @c_SpoolerGroup + ' IP: ' + @c_IPAddress + ' Port: ' + @c_PortNo  + ' Response: ' + @c_Response

	   FETCH FROM CUR_TCPSPOOLER_SERVERS INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup
   END
   
   SELECT * FROM #t_Result AS tr WITH(NOLOCK)
   ORDER BY tr.SpoolerGroup, tr.IP
	
END

GO