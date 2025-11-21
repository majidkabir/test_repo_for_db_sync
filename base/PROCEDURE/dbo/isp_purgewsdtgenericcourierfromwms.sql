SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************************************/  
/* Trigger: isp_PurgeWSDTGenericCourierFromWMS                                                           */  
/* Creation Date:                                                                                        */  
/* Copyright: IDS                                                                                        */  
/* Written by:                                                                                           */  
/*                                                                                                       */  
/* Purpose: Purge WSDTGenericCourier when retrigger Tranmitlog2                                          */  
/*                                                                                                       */  
/* Usage:                                                                                                */  
/*                                                                                                       */  
/* Called By:  Transmitlog2 Update Trigger                                                               */  
/*                                                                                                       */  
/* PVCS Version: 1.4                                                                                     */  
/*                                                                                                       */  
/* Version: 5.4                                                                                          */  
/*                                                                                                       */  
/* Data Modifications:                                                                                   */  
/* Date           Author      Ver   Purposes                                                             */  
/*                                                                                                       */  
/* 15-03-2023     kelvinongcy 1.0   WMS-21595 Delete WSDT_GENERIC_COURIER when retrigger TML2 (kocy01)   */  
/* 27-03-2023     kelvinongcy 1.1   To fix non-DTSITF access user allow access DTSITF table (kocy02)     */  
/*********************************************************************************************************/   
CREATE   PROC [dbo].[isp_PurgeWSDTGenericCourierFromWMS]  
(  @c_ConfigKey nvarchar(50)  
 , @c_Key1 nvarchar(15)  
 , @c_Key3 nvarchar(15)  
 , @c_Option1  nvarchar(50) = ''  
 , @c_Option2  nvarchar(50) = ''  
 , @c_Option3  nvarchar(50) = ''  
 , @c_Option4  nvarchar(50) = ''  
 , @c_Option5  nvarchar(50) = ''  
  
)  
WITH EXECUTE AS 'itadmin'   -- kocy02  
AS  
BEGIN  
  SET NOCOUNT ON                
  SET ANSI_NULLS OFF                
  SET QUOTED_IDENTIFIER OFF                
  SET CONCAT_NULL_YIELDS_NULL OFF       
  
   DECLARE @c_RecordID       int  
          ,@n_err            int  
          ,@c_errmsg       NVARCHAR(250)     
          ,@n_cnt            int  
          ,@n_continue       int  
          ,@b_Success        int   
          ,@n_starttcnt      int  
     
    SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT             
  
   DECLARE C_TML2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT C.RecordID              
   FROM transmitlog2 t2 (NOLOCK)                
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = t2.key1 AND ORDERS.StorerKey = t2.key3               
   JOIN [DTS].[WSDT_GENERIC_COURIER] C WITH (NOLOCK) ON C.OrderKey = t2.key1 AND C.StorerKey = t2.key3 AND t2.tablename = C.TableName           
   WHERE t2.key3 = @c_Key3       
   AND t2.key1 = @c_Key1  
   AND t2.tablename IN (@c_Option1, @c_Option2)   
                  
   OPEN C_TML2                
   FETCH NEXT FROM C_TML2 INTO  @c_RecordID            
   WHILE @@FETCH_STATUS = 0                
   BEGIN                
      DELETE FROM [DTS].[WSDT_GENERIC_COURIER] WHERE RecordID = @c_RecordID     
                           
   FETCH NEXT FROM C_TML2 INTO @c_RecordID               
   END     
       
   CLOSE C_TML2                
   DEALLOCATE C_TML2       
  
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                    
   IF @n_err <> 0                    
  BEGIN                    
   SELECT @n_continue = 3                    
   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                    
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table WSDTGenericCourier. (isp_PurgeWSDTGenericCourierFromWMS)" 
                   + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "                    
  END    
                      
   IF @n_continue=3  -- Error Occured - Process And Return                    
   BEGIN                    
    IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt                    
    BEGIN                    
       ROLLBACK TRAN                    
    END                    
    ELSE                    
    BEGIN                    
       WHILE @@TRANCOUNT > @n_starttcnt                    
       BEGIN                    
       COMMIT TRAN                    
       END                    
    END                    
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTransmitlog2Update'                    
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012                    
    RETURN                    
   END                    
   ELSE                    
   BEGIN                    
    WHILE @@TRANCOUNT > @n_starttcnt                    
    BEGIN                    
       COMMIT TRAN                    
   END                    
    RETURN                    
   END      
  
END  

GO