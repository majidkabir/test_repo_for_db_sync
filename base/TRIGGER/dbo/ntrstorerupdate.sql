SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/    
/* Trigger: ntrStorerUpdate                                                      */    
/* Creation Date:                                                                */    
/* Copyright: LFL                                                                */    
/* Written by:                                                                   */    
/*                                                                               */    
/* Purpose:  Update Storer                                                       */    
/*                                                                               */    
/* Return Status:                                                                */    
/*                                                                               */    
/* Usage:                                                                        */    
/*                                                                               */    
/* Called By: When records Updated                                               */    
/*                                                                               */    
/* PVCS Version: 1.0                                                             */    
/*                                                                               */    
/* Version: 5.4                                                                  */    
/*                                                                               */    
/* Modifications:                                                                */    
/* Date         Author        Ver  Purposes                                      */  
/* 17-Mar-2009  TLTING        1.0  Change user_name() to SUSER_SNAME()           */  
/* 28-Oct-2013  TLTING        1.1  Review Editdate column update                 */  
/* 23-Sep-2015  Leong         1.2  SOS351221 - Add ConfigKey "StorerLog".        */  
/* 26-Jun-2018  NJOW01        1.3  WMS-5221 validate CustomerGroupCode and       */  
/*                                 CustomerGroupName                             */  
/* 27-Apr-2020  CSCHONG       1.4  WMS-12867 (CS01)                              */  
/* 04-Mar-2022  TLTING   		1.5  WMS-19029 prevent bulk update or delete       */ 
/* 2022-04-12   kelvinongcy	1.6  amend way for control user run batch (kocy01)	*/
/*********************************************************************************/    
CREATE    TRIGGER [dbo].[ntrStorerUpdate] 
ON [dbo].[STORER]  
FOR UPDATE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug INT  
   SELECT @b_debug = 0  
  
   IF @b_debug = 2  
   BEGIN  
      DECLARE @profiler NVARCHAR(80)  
      SELECT @profiler = "PROFILER,637,00,0,ntrStorerUpdate Trigger" + CONVERT(char(12), GETDATE(), 114)  
      PRINT @profiler  
   END  
  
   DECLARE @n_err       INT       -- Error number returned by stored procedure or this trigger  
         , @n_continue  INT  
         , @n_starttcnt INT       -- Holds the current transaction count  
         , @c_errmsg    NVARCHAR(250)  
  
   DECLARE @c_FieldName           NVARCHAR(25)  
         , @c_OldValue            NVARCHAR(60)  
         , @c_NewValue            NVARCHAR(60)  
         , @c_Storerkey           NVARCHAR(15)  
         , @c_Authority_StorerLog NVARCHAR(1)  
         , @b_success             INT  
  
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT  
  
   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table Storer. Batch Update not allow! (ntrStorerUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
   END  
  
   IF @n_continue=1 OR @n_continue=2 --NJOW01  
   BEGIN  
      IF EXISTS (SELECT 1   
                 FROM INSERTED  
                 LEFT JOIN CODELKUP (NOLOCK) ON INSERTED.CustomerGroupCode = CODELKUP.Code AND CODELKUP.Listname = 'STCUSTCODE'  
                 WHERE INSERTED.Type = '1'  
                 AND CODELKUP.Code IS NULL)  
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))    
                         +': Storer Type 1 must have valid CustomerGroupCode. (ntrStorerUpdate)' + ' ( '            --(CS01)  
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
      END    
  
   --CS01 START  
   IF EXISTS (SELECT 1   
              FROM INSERTED  
              LEFT JOIN CODELKUP (NOLOCK) ON INSERTED.MarketSegment = CODELKUP.Code AND CODELKUP.Listname = 'MKTSGMT'  
              WHERE INSERTED.Type = '1'  
              AND CODELKUP.Code IS NULL)  
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))    
                      +': Storer Type 1 must have valid MarketSegment. (ntrStorerUpdate)' + ' ( '     
                      +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
   END    
  
   IF EXISTS (SELECT 1   
              FROM INSERTED  
              LEFT JOIN CODELKUP (NOLOCK) ON INSERTED.Status = CODELKUP.Code AND CODELKUP.Listname = 'STORERSTAT'  
              WHERE INSERTED.Type = '1'  
              AND CODELKUP.Code IS NULL)  
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))    
                      +': Storer Type 1 must have valid STATUS. (ntrStorerUpdate)' + ' ( '     
                      +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
   END   
  
   IF EXISTS (SELECT 1   
              FROM INSERTED  
              LEFT JOIN CODELKUP (NOLOCK) ON INSERTED.CustomerGroupName = CODELKUP.Description AND CODELKUP.Listname = 'STCUSTCODE'  
              WHERE INSERTED.Type = '1'  
              AND CODELKUP.Code IS NULL)  
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))    
                      +': Storer Type 1 must have valid CustomerGroupName. (ntrStorerUpdate)' + ' ( '     
                      +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
   END   
      
   --CS01 END  
   END   
     
   --IF @n_continue=1 OR @n_continue=2 --NJOW01  
   --BEGIN  
   --   IF EXISTS (SELECT 1   
   --              FROM INSERTED  
   --              WHERE Type <> '1'  
   --              AND (ISNULL(CustomerGroupCode,'') <> ''   
   --                  OR ISNULL(CustomerGroupName,'') <> ''))  
   --   BEGIN    
   --      SELECT @n_continue = 3    
   --      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
   --      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))    
   --                      +': Storer Type <> 1 is not allowed update value in CustomerGroupCode or CustomerGroupName. (ntrStorerUpdate)' + ' ( '     
   --                      +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
   --   END     
   --END   
  
   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE STORER WITH (ROWLOCK) 
         SET EditDate = GETDATE(),  
             EditWho  = SUSER_SNAME()  
      FROM INSERTED, DELETED  
      WHERE STORER.StorerKey = INSERTED.StorerKey  
      AND   STORER.StorerKey = DELETED.StorerKey  
   END  
  
   IF ( @n_continue = 1 OR @n_continue = 2 )  
   BEGIN  
      DECLARE CUR_StorerUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT  
                INSERTED.Storerkey  
           FROM INSERTED  
        
      OPEN CUR_StorerUpdate  
      FETCH NEXT FROM CUR_StorerUpdate INTO @c_Storerkey  
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @b_success = 0  
         SELECT @c_Authority_StorerLog = '0'  
         EXEC nspGetRight  
               NULL,  
               @c_Storerkey,          -- Storer  
               NULL,                  -- Sku  
               'StorerLog',           -- ConfigKey  
               @b_success             OUTPUT,  
               @c_Authority_StorerLog OUTPUT,  
               @n_err                 OUTPUT,  
               @c_errmsg              OUTPUT  
        
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3, @n_err = 63700, @c_errmsg = 'ntrStorerUpdate: ' + ISNULL(RTRIM(@c_errmsg),'')  
         END  
        
         IF @c_Authority_StorerLog = '1'  
         BEGIN  
            IF (@n_continue = 1 OR @n_continue = 2) -- SOS# 351221  
            BEGIN  
               SELECT @c_FieldName = 'STR-EditWho', @c_OldValue = '', @c_NewValue = SUSER_SNAME()  
               SELECT @c_OldValue = EditWho FROM DELETED WHERE Storerkey = @c_Storerkey  
        
               IF @c_OldValue <> @c_NewValue  
               BEGIN  
                  EXEC isp_Sku_log  
                        @cStorerKey = @c_Storerkey,  
                        @cSKU       = '',  
                        @cFieldName = @c_FieldName,  
                        @cOldValue  = @c_OldValue,  
                        @cNewValue  = @c_NewValue  
               END  
            END  
        
            IF UPDATE(Type) -- SOS# 348332  
            BEGIN  
               SELECT @c_FieldName = 'STR-Type', @c_OldValue = '', @c_NewValue = ''  
               SELECT @c_OldValue = Type FROM DELETED WHERE Storerkey = @c_Storerkey  
               SELECT @c_NewValue = Type FROM INSERTED WHERE Storerkey = @c_Storerkey  
        
               IF @c_OldValue <> @c_NewValue  
               BEGIN  
                  EXEC isp_Sku_log  
                        @cStorerKey = @c_Storerkey,  
                        @cSKU       = '',  
                        @cFieldName = @c_FieldName,  
                        @cOldValue  = @c_OldValue,  
                        @cNewValue  = @c_NewValue  
               END  
            END  
         END -- @c_Authority_StorerLog = '1'  
        
         FETCH NEXT FROM CUR_StorerUpdate INTO @c_Storerkey  
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE CUR_StorerUpdate  
      DEALLOCATE CUR_StorerUpdate  
   END     
  
   /* #INCLUDE <TRRDA2.SQL> */  
   IF @n_continue = 3  -- Error Occured - Process AND Return  
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrStorerUpdate"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  
      IF @b_debug = 2  
      BEGIN  
         SELECT @profiler = "PROFILER,637,00,9,ntrStorerUpdate Tigger, " + CONVERT(char(12), GETDATE(), 114)  
         PRINT @profiler  
      END  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      IF @b_debug = 2  
      BEGIN  
         SELECT @profiler = "PROFILER,637,00,9,ntrStorerUpdate Trigger, " + CONVERT(char(12), GETDATE(), 114) PRINT @profiler  
      END  
      RETURN  
   END 
	
END  


GO