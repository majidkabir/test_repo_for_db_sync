SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ntrStorerAdd                                                */  
/* Creation Date:                                                       */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  Insert Storer                                              */  
/*                                                                      */  
/* Return Status:                                                       */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: When records Inserted                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Modifications:                                                       */  
/* Date         Author   Ver  Purposes                                  */
/* 26-Jun-2018  NJOW01   1.0  WMS-5221 validate CustomerGroupCode and   */
/*                            CustomerGroupName                         */
/* 27-Apr-2020  CSCHONG  1.1  WMS-12867 (CS01)                          */
/************************************************************************/  
CREATE TRIGGER [dbo].[ntrStorerAdd] ON [dbo].[STORER] 
 FOR INSERT
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF
  	
 DECLARE @b_debug int    
 SELECT @b_debug = 0    
 IF @b_debug = 2    
 BEGIN    
    DECLARE @profiler NVARCHAR(80)    
    SELECT @profiler = 'PROFILER,637,00,0,ntrSTORERAdd Trigger' + CONVERT(char(12), getdate(), 114)    
    PRINT @profiler    
 END    
 DECLARE    
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?    
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger    
 ,         @n_err2 int              -- For Additional Error Detection    
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger    
 ,         @n_continue int                     
 ,         @n_starttcnt int                -- Holds the current transaction count    
 ,         @c_preprocess NVARCHAR(250)         -- preprocess    
 ,         @c_pstprocess NVARCHAR(250)         -- post process    
 ,         @n_cnt int                      
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT     

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
                      +': Storer Type 1 must have valid CustomerGroupCode. (ntrStorerAdd)' + ' ( '   
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
                      +': Storer Type 1 must have valid MarketSegment. (ntrStorerAdd)' + ' ( '   
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
                      +': Storer Type 1 must have valid STATUS. (ntrStorerAdd)' + ' ( '   
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
                      +': Storer Type 1 must have valid CustomerGroupName. (ntrStorerAdd)' + ' ( '   
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
--                      +': Storer Type <> 1 is not allowed update value in CustomerGroupCode or CustomerGroupName. (ntrStorerAdd)' + ' ( '   
--                      +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
--   END  	
--END 

-- Comments by SHONG 14th Mar 2008 - Not necessary, will causing performance Issues 
-- IF @n_continue=1 OR @n_continue=2 
-- BEGIN
--	DECLARE @c_Storerkey NVARCHAR(15), @c_ConfigType NVARCHAR(30), 
--		@c_Configdesc NVARCHAR(120) , @c_Storertype NVARCHAR(1)
--
--	SELECT @c_Storerkey = STORERKEY, @c_Storertype = TYPE FROM INSERTED
--
--	IF @c_Storertype = '1' 
--	BEGIN
--		DECLARE CUR_STORERCFG CURSOR FAST_FORWARD READ_ONLY FOR 
--		SELECT CODE, Description FROM CODELKUP (NOLOCK) 
--		 WHERE LISTNAME = 'STORERCFG' 
--		
--		OPEN CUR_STORERCFG 
--	
--		FETCH NEXT FROM CUR_STORERCFG INTO @c_ConfigType, @c_Configdesc 
--	
--		WHILE (1=1)
--		BEGIN
--		        IF @@FETCH_STATUS <> 0
--			BEGIN
--		        	BREAK
--		        END
--	
--			INSERT INTO STORERCONFIG (StorerKey, ConfigKey, ConfigDesc) 
--				       VALUES (@c_Storerkey, @c_ConfigType, @c_ConfigDesc)
--	
--			FETCH CUR_STORERCFG INTO @c_ConfigType, @c_Configdesc	
--		END
--		CLOSE CUR_STORERCFG
--		DEALLOCATE CUR_STORERCFG
--	END
-- END

      /* #INCLUDE <TRRDA2.SQL> */    
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrSKUAdd"    
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
    IF @b_debug = 2    
    BEGIN   
       SELECT @profiler = 'PROFILER,637,00,9,ntrSTORERAdd Tigger, ' + CONVERT(char(12), getdate(), 114)    
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
       SELECT @profiler = 'PROFILER,637,00,9,ntrSTORERAdd Trigger, ' + CONVERT(char(12), getdate(), 114) PRINT @profiler    
    END    
    RETURN    
 END    	
 END

GO