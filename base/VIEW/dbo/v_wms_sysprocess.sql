SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW   [dbo].[V_WMS_sysprocess]           
  AS       Select [spid], blocked,hostname, [program_name], net_address, loginame, login_time, last_batch, Duration = DATEDIFF(MINUTE, last_batch, GETDATE())     
   FROM master.dbo.Sysprocesses a      
   WHERE spid >= 50    
   AND DATEDIFF(MINUTE, Login_Time, GETDATE()) > 15  -- @n_Minutes      
   AND DATEDIFF(MINUTE, last_batch, GETDATE()) > 15     
   AND cmd <> 'AWAITING COMMAND'  
   group by spid, blocked,hostname, [program_name], net_address, loginame, login_time, last_batch, DATEDIFF(MINUTE, last_batch, GETDATE())     
   having sum(CPU) > 1000 AND sum(physical_io) > 1000   

GO