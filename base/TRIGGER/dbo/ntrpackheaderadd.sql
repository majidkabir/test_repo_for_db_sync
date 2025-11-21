SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Trigger: ntrPackHeaderAdd                                            */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Input Parameters: NONE                                               */  
/*                                                                      */  
/* Output Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: When records added                                        */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 16-May-2017  NJOW01    1.00  Allow config to call custom sp          */
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrPackHeaderAdd]  
ON  [dbo].[PackHeader]  
FOR INSERT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
   @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?  
   ,         @n_err        int       -- Error number returned by stored procedure or this trigger  
   ,         @n_err2       int       -- For Additional Error Detection  
   ,         @c_errmsg     Nvarchar(250) -- Error message returned by stored procedure or this trigger  
   ,         @n_continue   int                   
   ,         @n_StartTCnt  int       -- Holds the current transaction count  
   ,         @n_cnt        int                    
  
   DECLARE @RC int  
   DECLARE @c_Facility     Nvarchar(5)   
   DECLARE @c_Storerkey    Nvarchar(15)   
   DECLARE @c_sku          Nvarchar(20)   
   DECLARE @c_ConfigKey    Nvarchar(30)   
   DECLARE @c_Authority    Nchar(1)   
          ,@c_LoadKey      Nvarchar(10)  
          ,@c_OrderKey     Nvarchar(10)  
          ,@c_PickSlipNo   Nvarchar(10)   
  
   SELECT @n_continue=1, @n_StartTCnt=@@TRANCOUNT  
   /* #INCLUDE <TRCCA1.SQL> */       
  
   --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN   	  
      IF EXISTS (SELECT 1 FROM INSERTED d   ----->Put INSERTED if INSERT action
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'PackHeaderTrigger_SP')   -----> Current table trigger storerconfig
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
      	 SELECT * 
      	 INTO #INSERTED
      	 FROM INSERTED
          
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
   
      	 SELECT * 
      	 INTO #DELETED
      	 FROM DELETED
   
         EXECUTE dbo.isp_PackHeaderTrigger_Wrapper ----->wrapper for current table trigger
                   'INSERT'  -----> @c_Action can be INSERT, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrPackHeaderAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END        
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
       DECLARE CUR_INSERTED_PACKHEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
       SELECT PickSlipNo, StorerKey, OrderKey, LoadKey   
       FROM   INSERTED (NOLOCK)   
         
       OPEN CUR_INSERTED_PACKHEADER   
     
       FETCH NEXT FROM CUR_INSERTED_PACKHEADER INTO   
         @c_PickSlipNo, @c_Storerkey, @c_OrderKey, @c_LoadKey   
         
       WHILE @@FETCH_STATUS <> -1  
       BEGIN  
         IF ISNULL(RTRIM(@c_OrderKey),'') <> ''   
         BEGIN   
           SELECT @c_Facility = o.Facility   
           FROM ORDERS o WITH (NOLOCK)  
           WHERE o.OrderKey = @c_OrderKey  
             
         END   
         ELSE IF ISNULL(RTRIM(@c_LoadKey),'') <> ''   
         BEGIN  
           SELECT @c_Facility = L.Facility   
           FROM LOADPLAN L WITH (NOLOCK)  
           WHERE L.LoadKey = @c_LoadKey  
             
         END  
         SET @b_Success = 1  
         SET @c_Authority = '0'   
           
          EXECUTE @RC = [dbo].[nspGetRight]   
             @c_Facility = @c_Facility  
            ,@c_Storerkey = @c_Storerkey   
            ,@c_sku = ''  
            ,@c_ConfigKey = 'AutoScanInWhenPack'  
            ,@b_Success   = @b_Success OUTPUT  
            ,@c_Authority = @c_Authority OUTPUT  
            ,@n_err       = @n_err OUTPUT  
            ,@c_errmsg    = @c_errmsg OUTPUT  
  
          IF @c_Authority = '1'  
          BEGIN  
            IF NOT EXISTS(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)  
            BEGIN  
               INSERT INTO PickingInfo  
               ( PickSlipNo, ScanInDate, PickerID )  
               VALUES  
               ( @c_PickSlipNo, GETDATE(), SUSER_SNAME() )  
               IF @@ERROR <> 0   
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @n_err=82102  
                   SELECT @c_errmsg='NSQL'+CONVERT(Nvarchar(5),@n_err)+  
                     ': Insert into PickingInfo Failed. (ntrPackHeaderAdd)'   
                END  
               
            END -- If not exists in PickingInfo   
             
          END  
         FETCH NEXT FROM CUR_INSERTED_PACKHEADER INTO   
                  @c_PickSlipNo, @c_Storerkey, @c_OrderKey, @c_LoadKey  
       END  
       CLOSE CUR_INSERTED_PACKHEADER  
       DEALLOCATE CUR_INSERTED_PACKHEADER  
  
   END  
  
/* #INCLUDE <TRCCA2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
        WHILE @@TRANCOUNT > @n_StartTCnt  
        BEGIN  
           COMMIT TRAN  
        END  
      END  
        
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackHeaderAdd'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END -- Trigger   

GO