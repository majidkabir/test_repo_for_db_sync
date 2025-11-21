SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/*  5-Sep-2012  KHLim    "LIKE EXceed%" intead of "= EXceed WMS" (KH01)            */  
/* 26-Apr-2021  kocy      meet customer audit requirement to remain log trace at least 1 year */  
/* 27-Oct-2022  TLTING    NIKE audit requirement to keep 2 year - cahnge variable */  
    
CREATE PROC [dbo].[ids_ScheduleConnections]        
      @c_WMSDB NVARCHAR(10) , @n_dataRetain_days INT  = 365    
AS        
BEGIN        
   SET NOCOUNT ON        
        
   DELETE USER_CONNECTIONS         
      WHERE DateDiff(day, login_date, GetDate()) > @n_dataRetain_days        
        
   INSERT USER_CONNECTIONS (LOGIN_NAME, LOGIN_DATE, [APPLICATION], HOSTNAME)        
      SELECT DISTINCT LOGINAME, getdate(), 'WMS', Hostname        
      FROM MASTER.DBO.SYSPROCESSES (NOLOCK)        
      where db_name(dbid) = @c_WMSDB         
        AND program_name LIKE 'EXceed%'   --KH01        
        
   insert user_connections (login_name, login_date, [Application])        
      select RTRIM(UserName),         
             getdate(),       
             'RDT'        
      from RDT.RdtMobRec (nolock)        
      where datediff(minute, editdate, getdate()) <= 120        
      group by UserName        
        
END        

GO