SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/************************************************************************/  
/* Stored Procedure: isp_RCM_WV_KewillFlagship                          */  
/* Creation Date: 14-Jan-2016                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 362691-Carters SZ - new trigger point on Wave               */  
/*                                                                      */  
/* Called By: Load Plan Dymaic RCM configure at listname 'RCMConfig'    */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_WV_KewillFlagship]  
   @c_Wavekey NVARCHAR(10),     
   @b_success  int OUTPUT,  
   @n_err      int OUTPUT,  
   @c_errmsg   NVARCHAR(225) OUTPUT,  
   @c_code     NVARCHAR(30)=''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue int,  
           @n_cnt int,  
           @n_starttcnt int  
             
   DECLARE @c_Facility  NVARCHAR(5),  
           @c_storerkey NVARCHAR(15),
           @c_Loadkey   NVARCHAR(10)
            
                
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0   
     

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ORD.Loadkey--,ORD.Facility,ORD.Storerkey  
   FROM   wavedetail wvdet (nolock)
   join orders ord (nolock) on ord.orderkey = wvdet.orderkey
   WHERE wavekey= @c_Wavekey
   GROUP BY ORD.Loadkey--,ORD.Facility,ORD.Storerkey 
   ORDER BY ORD.loadkey  
    
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_Loadkey--, @c_Facility  ,@c_StorerKey 
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
  
   --EXEC dbo.ispGenTransmitLog3 'RCMLOADLOG', @c_Loadkey, @c_Facility, @c_StorerKey, ''    
   EXEC isp_RCM_LP_KewillFlagship @c_Loadkey
        , @b_success OUTPUT    
        , @n_err OUTPUT    
        , @c_errmsg OUTPUT    
          
   IF @b_success = 0  
       SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_WV_KewillFlagship: ' + rtrim(@c_errmsg)  

   FETCH NEXT FROM CUR_RESULT INTO @c_Loadkey--, @c_Facility  ,@c_StorerKey 
   END

   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT
       
ENDPROC:   
   
   IF @n_continue=3  -- Error Occured - Process And Return  
  BEGIN  
     SELECT @b_success = 0  
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_KewillFlagship'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
     RETURN  
  END  
  ELSE  
     BEGIN  
        SELECT @b_success = 1  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
        RETURN  
     END      
END -- End PROC  

GO