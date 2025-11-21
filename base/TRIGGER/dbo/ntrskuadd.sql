SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrSKUAdd                                                      */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Update other transactions while SKU line is to be Added.      */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Updated                                         */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author    Ver.  Purposes                                   */
/* 12-Mar-2007  Shong     1.0   Only replace the ` to ' In Non English     */
/*                              Env System Flag had turn ON                */
/* 15-Jun-2009  YokeBeen  1.1   Added new trigger point for interface      */
/*                              with Configkey = "ADDSKULOG".              */
/*                              - (YokeBeen01)                             */
/* 03-Nov-2010  YokeBeen  1.2   FBR#193606 - Added new trigger point       */
/*                              for WITRON interface with                  */
/*                              Configkey = "WTNSKULOG". - (YokeBeen02)    */
/* 22-Dec-2010	 YokeBeen  1.2   SOS#198768 - Blocked interface on process */
/*                              of re-allocation with Configkey = 'GDSITF' */
/*                              - (YokeBeen03)                             */
/* 28-Mar-2016  Shong     1.3   SOS#366725 Default OTM SKU Group (Shong02) */
/* 30-Jun-2017  KHChan    1.4   FBR#WMS-1455 Add trigger point for         */
/*                              WSSKUADDLOG (KH01)                         */
/* 23-NOV-2017  TLTING    1.5   Skip trigger with archiveCop               */
/* 06-Jul-2020  WLChooi   1.6   WMS-13990 - New Storerconfig               */
/*                              DefaultSkuLottableCode (WL01)              */
/* 11-Nov-2020  WLChooi   1.7   WMS-15671 - SKUTrigger_SP - call custom SP */
/*                              when INSERT record (WL02)                  */
/* 18-Aug-2021  NJOW01    1.8  WMS-17763 Update active based on skustatus  */
/***************************************************************************/
CREATE TRIGGER ntrSKUAdd ON SKU 
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
      SELECT @profiler = 'PROFILER,637,00,0,ntrSKUAdd Trigger' + CONVERT(char(12), getdate(), 114)    
      PRINT @profiler    
   END    

   DECLARE @b_Success                int       -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err                    int       -- Error number returned by stored procedure or this trigger    
         , @n_err2                   int       -- For Additional Error Detection    
         , @c_errmsg                 NVARCHAR(250) -- Error message returned by stored procedure or this trigger    
         , @n_continue               int                     
         , @n_starttcnt              int       -- Holds the current transaction count    
         , @c_preprocess             NVARCHAR(250) -- preprocess    
         , @c_pstprocess             NVARCHAR(250) -- post process    
         , @n_cnt                    int 
         , @c_StorerKey              NVARCHAR(15)  -- (YokeBeen01) 
         , @c_Sku                    NVARCHAR(20)  -- (YokeBeen01) 
         , @c_authority_skuitf       NVARCHAR(1)   -- (YokeBeen01) 
         , @c_transmitlog3key        NVARCHAR(10)  -- (YokeBeen01) 
         , @c_authority_wtnskuitf    NVARCHAR(1)   -- (YokeBeen02) 
         , @c_default_otm_skugroup   NVARCHAR(20)  -- (Shong02)
         , @c_DefaultSkuLottableCode NVARCHAR(30)  -- (WL01)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT     

   -- (YokeBeen01) - Start - Remarked on obsolete Configkey = 'GDSITF'
   /*
   -- Added By SHONG
   -- GDS Interfcae -- BUSR10 Cannot be blank
   -- Otherwise Receipt Interface will having problem
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 
                   FROM INSERTED 
                   JOIN StorerConfig (NOLOCK) ON (StorerConfig.StorerKey = INSERTED.StorerKey AND
                        StorerConfig.ConfigKey = 'GDSITF' AND StorerConfig.sValue = '1')
                  WHERE dbo.fnc_RTrim(BUSR10) IS NULL)
      BEGIN
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0)) 
                          + ': Insert Failed On Table SKU. (ntrSKUAdd), BUSR10 Cannot be BLANK ( SQLSvr MESSAGE= ' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
      END
   END
   */
   -- (YokeBeen01) - End - Remarked on obsolete Configkey = 'GDSITF'

   -- Added By Shong
   -- 02 May 2002
   -- To replace [`] with ['], RF cannot accept [`] in the description is due to the [`]
   -- use as delimited
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM nSqlConfig WITH (NOLOCK) WHERE ConfigKey = 'NonEnglishEnv' AND NSQLValue = '1')
      BEGIN 
         IF EXISTS( SELECT 1 FROM INSERTED WHERE DESCR LIKE '%`%')
         BEGIN
            UPDATE SKU 
               SET DESCR = REPLACE(SKU.DESCR, '`', "'")
              FROM INSERTED
             WHERE SKU.StorerKey = INSERTED.StorerKey
               AND SKU.SKU = INSERTED.SKU
               AND INSERTED.DESCR LIKE '%`%'
         END
      END 
   END

   IF (SELECT COUNT(*) FROM Inserted) = (SELECT COUNT(*) FROM Inserted WHERE Inserted.ArchiveCop = '9') -- KHLim03
   BEGIN
	   SELECT @n_continue = 4
   END
   
   --NJOW01
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE SKU WITH (ROWLOCK)
      SET SKU.Active = CASE WHEN CL.Short = 'ACTIVE_ON' THEN '1' WHEN CL.Short = 'ACTIVE_OFF' THEN '0' ELSE SKU.Active END,
          SKU.TrafficCop = NULL
      FROM INSERTED I (NOLOCK)
      JOIN SKU ON I.Storerkey = SKU.Storerkey AND I.Sku = SKU.Sku
      CROSS APPLY (SELECT TOP 1 C.Short 
                   FROM CODELKUP C (NOLOCK) 
                   WHERE C.Code = I.SkuStatus AND C.ListName = 'SKUSTATUS' 
                   AND (C.Storerkey = I.Storerkey OR C.Storerkey = '')
                   ORDER BY C.Storerkey DESC) CL                
      JOIN V_STORERCONFIG2 SC ON I.Storerkey = SC.Storerkey AND SC.Configkey = 'SKUAutoUpdActiveByStatus' AND SC.Svalue = '1'
      WHERE CL.Short IN ('ACTIVE_ON','ACTIVE_OFF')
      
      SET @n_err = @@ERROR
      
      IF @n_err <> 0
      BEGIN   	 	  	 
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63800
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                           + ': Update Active Failed (ntrSkuAdd) ( SQLSvr MESSAGE='
                           + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END                     
   END   

   --WL02 START
   IF @n_continue=1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i
                 JOIN storerconfig s WITH (NOLOCK) ON  i.StorerKey = s.StorerKey
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
                   'INSERT'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrSKUAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END
   --WL02 END
   
   -- (YokeBeen01) - Start
   IF @n_continue=1 OR @n_continue=2
   BEGIN
   	DECLARE CUR_SKU_INSERTED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	SELECT StorerKey, Sku
      FROM INSERTED 
   	
   	OPEN CUR_SKU_INSERTED
   	
   	FETCH FROM CUR_SKU_INSERTED INTO @c_StorerKey, @c_Sku
   	
   	WHILE @@FETCH_STATUS = 0
   	BEGIN

         SELECT @b_success = 0
         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_StorerKey,         -- Storer
                  '',                   -- Sku
                  'ADDSKULOG',          -- ConfigKey
                  @b_success            OUTPUT,
                  @c_authority_skuitf   OUTPUT,
                  @n_err                OUTPUT,
                  @c_errmsg             OUTPUT

         IF @b_success <> 1 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63801  
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                             + ': Retrieve of Right (ADDSKULOG) Failed (ntrSKUAdd) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE 
         BEGIN 
            IF @c_authority_skuitf = '1' 
            BEGIN
               EXEC dbo.ispGenTransmitLog3 'ADDSKULOG', @c_StorerKey, '', @c_Sku, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_skuitf = '1' 
         END -- IF @b_success = 1 

         -- (YokeBeen02) - Start 
         SELECT @b_success = 0
         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_StorerKey,         -- Storer
                  '',                   -- Sku
                  'WTNSKULOG',          -- ConfigKey
                  @b_success            OUTPUT,
                  @c_authority_skuitf   OUTPUT,
                  @n_err                OUTPUT,
                  @c_errmsg             OUTPUT

         IF @b_success <> 1 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63801  
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                             + ': Retrieve of Right (WTNSKULOG) Failed (ntrSKUAdd) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE 
         BEGIN 
            IF @c_authority_skuitf = '1' 
            BEGIN
               EXEC dbo.ispGenWitronLog 'WTNSKULOG', @c_StorerKey, '', @c_Sku, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_skuitf = '1' 
         END -- IF @b_success = 1 
         -- (YokeBeen02) - End 
         
         -- (YokeBeen01) - End          
         
         --(KH01) - Start
         SET @c_authority_skuitf = ''
         SELECT @b_success = 0
         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_StorerKey,         -- Storer
                  '',                   -- Sku
                  'WSSKUADDLOG',          -- ConfigKey
                  @b_success            OUTPUT,
                  @c_authority_skuitf   OUTPUT,
                  @n_err                OUTPUT,
                  @c_errmsg             OUTPUT

         IF @b_success <> 1 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63801  
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                             + ': Retrieve of Right (ADDSKULOG) Failed (ntrSKUAdd) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE 
         BEGIN 
            IF @c_authority_skuitf = '1' 
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'WSSKUADDLOG', @c_StorerKey, '', @c_Sku, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_skuitf = '1' 
         END -- IF @b_success = 1 
         --(KH01) - End

         -- (Shong02) - Start
         SET @c_default_otm_skugroup = ''
         
         EXECUTE dbo.nspGetRight 
            @c_Facility  = '',               
            @c_StorerKey = @c_StorerKey,     
            @c_sku       = '',               
            @c_ConfigKey = 'OTMCommodity',   
            @b_Success   = @b_success              OUTPUT,
            @c_authority = @c_default_otm_skugroup OUTPUT,
            @n_err       = @n_err                  OUTPUT,
            @c_errmsg    = @c_errmsg               OUTPUT
         
         IF @c_default_otm_skugroup <> '0' AND @c_default_otm_skugroup <> ''
         BEGIN
         	UPDATE SKU WITH (ROWLOCK)
         	   SET OTM_SKUGroup = @c_default_otm_skugroup, 
         	       TrafficCop = NULL, 
         	       EditDate = GETDATE(),
         	       EditWho = SUSER_SNAME()  
         	WHERE StorerKey = @c_StorerKey 
         	AND   Sku = @c_Sku
         END                           
         -- (Shong02) - End

         --WL01 START
         SET @b_success = 0
         SET @c_DefaultSkuLottableCode = ''

         EXECUTE dbo.nspGetRight  '',         -- Facility
                  @c_StorerKey,               -- Storer
                  '',                         -- Sku
                  'DefaultSkuLottableCode',   -- ConfigKey
                  @b_success                  OUTPUT,
                  @c_DefaultSkuLottableCode   OUTPUT,
                  @n_err                      OUTPUT,
                  @c_errmsg                   OUTPUT

         IF @b_success <> 1 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63802  
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                             + ': Retrieve of Right (DefaultSkuLottableCode) Failed (ntrSKUAdd) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF @c_DefaultSkuLottableCode <> '0' AND @c_DefaultSkuLottableCode <> ''
         BEGIN
            UPDATE SKU WITH (ROWLOCK)
            SET LottableCode = @c_DefaultSkuLottableCode, 
                TrafficCop = NULL, 
                EditDate = GETDATE(),
                EditWho = SUSER_SNAME()  
            WHERE StorerKey = @c_StorerKey 
            AND   Sku = @c_Sku
         END
         --WL01 END
   	
   		FETCH FROM CUR_SKU_INSERTED INTO @c_StorerKey, @c_Sku
   	END
   	
   	CLOSE CUR_SKU_INSERTED
   	DEALLOCATE CUR_SKU_INSERTED
   END

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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrSKUAdd'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    

      IF @b_debug = 2    
      BEGIN   
         SELECT @profiler = 'PROFILER,637,00,9,ntrSKUAdd Tigger, ' + CONVERT(char(12), getdate(), 114)    
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
         SELECT @profiler = 'PROFILER,637,00,9,ntrSKUAdd Trigger, ' + CONVERT(char(12), getdate(), 114) PRINT @profiler    
      END    
      RETURN    
   END    	
END -- End Trigger

GO