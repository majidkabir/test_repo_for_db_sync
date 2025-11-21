SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/*************************************************************************/      
/* Stored Procedure: isp_WSM_GetTCPSpoolerConfigs                        */      
/* Creation Date: 02 Jul 2019                                            */      
/* Copyright: LFL                                                        */      
/* Written by: Alex Keoh                                                 */      
/*                                                                       */      
/* Purpose: Send Command to TCP Spooler                                  */      
/*                                                                       */      
/* Called By:                                                            */      
/*                                                                       */      
/* PVCS Version: 1.0                                                     */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date         Author   Ver  Purposes                                   */      
/* 02-Jul-2019  Alex     1.0  Initial Development                        */      
/* 03-Oct-2019  Shong    1.1  Enhancement, Getting IP based on active    */
/*                            SQL Connection                             */
/* 04-Jul-2022  Alex02   1.2  Bug Fixed                                  */
/*                             - Filter SQL Connection IP & Hostname     */
/*                               with RDT.RDTSpooler                     */
/*************************************************************************/      
      
CREATE PROC [dbo].[isp_WSM_GetTCPSpoolerConfigs]      
(      
   @c_Action          NVARCHAR(15) = '',  
   @c_IPAddress       NVARCHAR(30) = ''  
)      
AS      
BEGIN      
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF        
  
   SET @c_Action = ISNULL(RTRIM(@c_Action), '')  
  
   -- IP list for drop down box  
   IF @c_Action = 'DDB_IPs'  
   BEGIN  
      --SELECT c.client_net_address 
      --FROM sys.dm_exec_connections       AS c
      --JOIN sys.dm_exec_sessions     AS s
      --            ON  c.session_id = s.session_id
      --WHERE  s.program_name LIKE 'Socket_Spooler%_Prt%'
      --AND c.net_transport = 'Session'
      --GROUP BY c.client_net_address  
      
      --Alex02 Begin
      SELECT IPAddress
      FROM RDT.RDTSpooler RS WITH (NOLOCK) 
      WHERE EXISTS ( SELECT 1 FROM sys.dm_exec_connections AS [c]
         JOIN sys.dm_exec_sessions AS [s]
         ON c.session_id = s.session_id
         WHERE s.program_name LIKE '%Spooler%_Prt%'
       	AND c.net_transport = 'Session' 
         AND (c.client_net_address = RS.IPAddress OR s.[host_name] = RS.IPAddress))
      GROUP BY IPAddress

      --Alex02 End
   END  
   ELSE  
   BEGIN  
      SELECT   
         IPaddress, ISNULL(RTRIM(PortNo), ''), 'TCPSpooler'   
      FROM RDT.RDTSpooler (NOLOCK)   
      WHERE ISNULL(RTRIM(IPAddress),'') = @c_IPAddress
      AND [PortNo] Like '50[0-9][0-9]'    
      GROUP BY IPAddress, PortNo  
   END  
END -- End of Procedure

GO