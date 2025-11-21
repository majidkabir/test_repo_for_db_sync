SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/  
/* Trigger: ntrSKUDelete                                                         */  
/* Creation Date:                                                                */  
/* Copyright: IDS                                                                */  
/* Written by:                                                                   */  
/*                                                                               */  
/* Purpose: Update/Delete other records while SKU line is being deleted.         */  
/*                                                                               */  
/* Return Status:                                                                */  
/*                                                                               */  
/* Usage:                                                                        */  
/*                                                                               */  
/* Called By: When records Deleted                                               */  
/*                                                                               */  
/* PVCS Version: 1.4                                                             */  
/*                                                                               */  
/* Version: 5.4                                                                  */  
/*                                                                               */  
/* Modifications:                                                                */  
/* Date         Author        Ver  Purposes                                      */  
/* 17-Mar-2009  TLTING             Change user_name() to SUSER_SNAME()           */  
/* 28-Apr-2011  KHLim01       1.2  Insert Delete log                             */  
/* 14-Jul-2011  KHLim02       1.3  GetRight for Delete log                       */  
/* 18-Jan-2012  KHLim03       1.4  check ArchiveCop                              */  
/* 22-May-2012  YTWan         1.5  SOS#244027: SkuInfo (Wan01)                   */  
/* 11-Nov-2020  WLChooi       1.6  WMS-15671 - SKUTrigger_SP - call custom SP    */  
/*                                 when DELETE record (WL02)                     */  
/* 04-Mar-2022  TLTING   		1.7  WMS-19029 prevent bulk update or delete       */
/* 2022-04-12   kelvinongcy	1.8  amend way for control user run batch (kocy01)	*/
/*********************************************************************************/  
  
CREATE    TRIGGER [dbo].[ntrSKUDelete]  
 ON  [dbo].[SKU]  
 FOR DELETE  
 AS  
 BEGIN  
   IF @@ROWCOUNT = 0 -- KHLim03  
   BEGIN  
    RETURN  
   END  
    SET NOCOUNT ON  
    SET ANSI_NULLS OFF   
    SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
    DECLARE @b_Success       int,  
            @n_err           int,         
            @c_errmsg        NVARCHAR(250),  
				@n_cnt           int,   
            @c_Action        NVARCHAR(100)  
           ,@c_authority     NVARCHAR(1)  -- KHLim02  
           ,@n_continue      int  -- KHLim03  
           ,@n_starttcnt     int  -- KHLim03  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  -- KHLim03  
  
   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9') -- KHLim03  
   BEGIN  
    SELECT @n_continue = 4  
   END  
  
   --IF ( (Select count(1) FROM   Deleted  ) > 100 ) 
   --    AND Suser_sname() not in ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68108   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table SKU. Batch Delete not allow! (ntrSKUDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
   END  
  
   IF @n_continue <> 3   -- TLTING01  
   BEGIN  
      --(Wan01) - START  
      IF EXISTS (SELECT 1  
                 FROM SKUInfo WITH (NOLOCK)  
                 JOIN DELETED  
                 ON  ( SKUInfo.Storerkey = DELETED.Storerkey )  
                 AND ( SKUInfo.Sku = DELETED.Sku ))  
		BEGIN  
         DELETE FROM SKUInfo WITH (ROWLOCK)    
         FROM SkuInfo  
         JOIN DELETED ON  ( SKUInfo.Storerkey = DELETED.Storerkey )  
                      AND ( SKUInfo.Sku = DELETED.Sku )  
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
          IF @n_err <> 0  
          BEGIN  
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68103   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger Failed on SkuInfo table update. (ntrSKUDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
          END                     
      END  
      --(Wan01) - END  
   END  
     
   IF @n_continue = 1 or @n_continue = 2   -- KHLim03  
   BEGIN  
       SELECT @c_Action = 'Delete '  
       INSERT INTO SKULog  
             (Person, ActionTime, ActionDescr)  
       SELECT SUSER_SNAME(), GetDate(), 'Deleting ' + dbo.fnc_RTrim(SKU) + dbo.fnc_RTrim(DESCR)  
       FROM  DELETED  
  
       DELETE SKUCONFIG FROM DELETED   
        WHERE SKUCONFIG.STORERKEY = DELETED.STORERKEY   
          AND SKUCONFIG.SKU = DELETED.SKU  
  
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
       IF @n_err <> 0  
       BEGIN  
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63750   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On Table SKU Failed. (ntrSKUDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
       END  
   END  
  
  
   IF @n_continue = 1 or @n_continue = 2   -- KHLim03  
   BEGIN  
   -- Start (KHLim01)   
      SELECT @b_success = 0         --    Start (KHLim02)  
      EXECUTE nspGetRight  NULL,             -- facility    
                           NULL,             -- Storerkey    
                           NULL,             -- Sku    
                           'DataMartDELLOG', -- Configkey    
                           @b_success     OUTPUT,   
                           @c_authority   OUTPUT,   
                           @n_err         OUTPUT,   
                           @c_errmsg      OUTPUT    
      IF @b_success <> 1  
      BEGIN  
         SELECT @c_errmsg = 'ntrSKUDelete' + dbo.fnc_RTrim(@c_errmsg)  
      END  
      ELSE   
      IF @c_authority = '1'         --    End   (KHLim02)  
      BEGIN  
         INSERT INTO dbo.SKU_DELLOG ( StorerKey, Sku )  
         SELECT StorerKey, Sku FROM DELETED  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table SKU Failed. (ntrSKUDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         END  
      END  
   -- End (KHLim01)   
   END  
     
   --WL01 START  
   IF @n_continue=1 or @n_continue=2            
   BEGIN  
      IF EXISTS (SELECT 1 FROM DELETED d    
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey      
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue  
                 WHERE  s.configkey = 'SKUTrigger_SP')    
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
     
         EXECUTE dbo.isp_SKUTrigger_Wrapper  
                   'DELETE'  --@c_Action  
                 , @b_Success  OUTPUT    
                 , @n_Err      OUTPUT     
                 , @c_ErrMsg   OUTPUT    
     
         IF @b_success <> 1    
         BEGIN    
            SELECT @n_continue = 3    
                  ,@c_errmsg = 'ntrSKUDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  
         END    
           
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL  
            DROP TABLE #INSERTED  
     
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL  
            DROP TABLE #DELETED  
      END  
   END    
   --WL01 END  
  
  
      /* #INCLUDE <TRTHD2.SQL> */  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrSKUDelete"  
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