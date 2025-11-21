SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/      
/* Stored Procedure: isp_TCPSpooler_SSRS_Dashboard                       */      
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
CREATE PROC [dbo].[isp_TCPSpooler_SSRS_Dashboard] (
   @c_Port NVARCHAR(10) = ''
)
AS  
BEGIN  
   SET NOCOUNT ON  
  
   IF OBJECT_ID('tempdb..#t_Result') IS NOT NULL  
      DROP TABLE #t_Result  
        
   CREATE TABLE #t_Result (  
    SpoolerGroup      NVARCHAR(20),   
    IP                VARCHAR(20),   
    PORT              VARCHAR(10),  
    [Active]          INT,  
    SQLConnection     INT,   
    Threads           INT,  
    ListenerStatus    INT,  
    LastPrint         DATETIME NULL,  
    LastHourPrintJob  INT,  
    [Version]         VARCHAR(20),  
    NoOfPrinters      INT   
   )   
     
   DECLARE    
     @c_Command        VARCHAR(200)   = ''   
   , @c_Param1         NVARCHAR(100)  = ''      
   , @c_Param2         NVARCHAR(100)  = ''      
   , @c_Param3         NVARCHAR(100)  = ''      
   , @c_Param4         NVARCHAR(100)  = ''      
   , @c_Param5         NVARCHAR(100)  = ''       
   , @c_SpoolerStatus  CHAR(1)        = 'A' -- A=Active, N=Not Active, B=Both, S=Session, I=IP Address    
   , @c_IPAddress      NVARCHAR(40)   = ''  
   , @c_PortNo         NVARCHAR(5)    = ''  
  
   DECLARE   
    @c_Response          NVARCHAR(200),   
      @c_ErrMsg            NVARCHAR(215),   
      @c_SpoolerGroup      NVARCHAR(20),   
      @n_LastHourPrintJob  INT,  
      @n_TotalPrinters     INT,  
      @n_SQLConnections    INT,   
      @d_LastPrintDate     DATETIME  
  
   IF ISNULL(@c_Port,'') = ''
   BEGIN
      INSERT INTO #t_Result  
      (  SpoolerGroup,     IP,          PORT,  
       [Active],       SQLConnection, Threads,  
       ListenerStatus,   LastPrint,    LastHourPrintJob,  
       [Version]   )  
      SELECT Distinct rs.SpoolerGroup, rs.IPAddress, rs.PortNo, 0, 0, 0, NULL, 0, '', 0    
      FROM rdt.rdtSpooler AS rs WITH(NOLOCK)    
      WHERE rs.PortNo LIKE '50%'       
   END
   ELSE 
   BEGIN
      INSERT INTO #t_Result  
      (  SpoolerGroup,     IP,          PORT,  
       [Active],       SQLConnection, Threads,  
       ListenerStatus,   LastPrint,    LastHourPrintJob,  
       [Version]   )  
      SELECT Distinct rs.SpoolerGroup, rs.IPAddress, rs.PortNo, 0, 0, 0, NULL, 0, '', 0    
      FROM rdt.rdtSpooler AS rs WITH(NOLOCK)    
      WHERE rs.PortNo LIKE @c_Port 
      
   END
       
   DECLARE CUR_TCPSPOOLER_SERVERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT tr.IP, tr.Port, tr.SpoolerGroup  
   FROM #t_Result AS tr WITH(NOLOCK)  
  
   OPEN CUR_TCPSPOOLER_SERVERS  
  
   FETCH FROM CUR_TCPSPOOLER_SERVERS INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup  
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
    SET @n_TotalPrinters = 0  
      
      SELECT @n_TotalPrinters = COUNT(DISTINCT r.PrinterID)  
      FROM rdt.RDTPrinter AS r WITH(NOLOCK)   
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup  
      WHERE rs.SpoolerGroup = @c_SpoolerGroup  
      AND rs.PortNo = @c_PortNo  
      AND rs.IPAddress = @c_IPAddress   
  
      SET @n_LastHourPrintJob = 0   
      SET @d_LastPrintDate = NULL   
      SELECT @n_LastHourPrintJob = COUNT(*),   
             @d_LastPrintDate = MAX(r.EditDate)       
      FROM rdt.RDTPrinter AS r WITH(NOLOCK)  
      JOIN rdt.rdtSpooler AS rs WITH(NOLOCK) ON rs.SpoolerGroup = r.SpoolerGroup   
      JOIN rdt.RDTPrintJob_Log AS rjl WITH(NOLOCK) ON rjl.Printer = r.PrinterID                
      WHERE rs.SpoolerGroup = @c_SpoolerGroup  
      AND rs.PortNo = @c_PortNo  
      AND rs.IPAddress = @c_IPAddress   
  
      SET @n_SQLConnections = 0   
      SELECT @n_SQLConnections = COUNT(*)  
      FROM sys.dm_exec_connections AS c  
      JOIN sys.dm_exec_sessions AS s ON c.session_id = s.session_id  
      WHERE  s.program_name LIKE 'socket_Spooler%_Prt%'  
      AND c.net_transport = 'Session'   
      AND c.client_net_address = @c_IPAddress  
      AND SUBSTRING( s.program_name, PATINDEX('%_PRT_[0-9]%', s.program_name) - 4, 4) = @c_PortNo  
        
      UPDATE #t_Result  
      SET  
       [Active] = CASE WHEN @n_SQLConnections > 0 THEN 1 ELSE 0 END,  
       SQLConnection = @n_SQLConnections,  
       Threads = 0,  
       ListenerStatus = 0,  
       LastPrint = @d_LastPrintDate,  
       LastHourPrintJob = @n_LastHourPrintJob,  
       Version = '',  
       NoOfPrinters = @n_TotalPrinters  
      WHERE SpoolerGroup = @c_SpoolerGroup   
      AND IP = @c_IPAddress  
      AND PORT = @c_PortNo   
  
      SET @c_Response = ''  
      SET @c_ErrMsg = ''  
     
  
      FETCH FROM CUR_TCPSPOOLER_SERVERS INTO @c_IPAddress, @c_PortNo, @c_SpoolerGroup  
   END  
     
   SELECT * FROM #t_Result AS tr WITH(NOLOCK)  
   ORDER BY tr.SpoolerGroup, tr.IP  
   
END  

GO