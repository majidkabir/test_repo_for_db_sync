SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrSkuUpdate                                                   */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Update other transactions while SKU line is to be updated.    */
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
/* Date         Author   Ver  Purposes                                     */
/* 14-Jun-2007  YokeBeen      FBR#78500 - CBM Outbound - (YokeBeen01)      */
/*                            Trigger records into TransmitLog when update */
/*                            on fields - StdCube/StdGrossWgt.             */
/*                            - SQL2005 Changes.                           */
/* 12-Mar-2007  Shong         Only replace the ` to ' In Non English Env   */
/*                            System Flag had turn ON                      */
/* 17-Mar-2009  TLTING   1.1  Change user_name() to SUSER_SNAME()          */
/* 15-Apr-2010  TLTING   1.2  New Sku_log trace FBR145609                  */
/* 26-Jan-2011  MCTang   1.3  FBR#186349 - Added new trigger point for     */
/*                            POSM upon update StdNetWgt & StdCube to      */
/*                            interface Configkey = "VSKULOG" (MC01)       */
/* 13-Apr-2011  AQSKC    1.4  SOS#211893 Do not allow SKU update if inv    */
/*                            found with lottable01 not blank (KC01)       */
/* 25 May 2012  TLTING02 1.5  DM integrity - add update editdate B4        */
/*                            TrafficCop                                   */
/* 04-Dec-2012  Leong    1.6  SOS# 263375 - Log Style, Color, Size and     */
/*                            Measurement when Config SKULOG is turn on.   */
/* 16-May-2012  MCTang   1.6  SOS#244028 - Add UPDSKULOG (MC02)            */
/* *********************************************************************** */
/* 23-Sep-2013  YokeBeen 1.2  Base on PVCS SQL2005_Unicode version 1.1.    */
/*                            FBR#290176 - Insert TransmitLog3.Key2 = "0"  */
/*                            for trigger point "UPDSKULOG" - (YokeBeen02) */
/* 28-Oct-2013  TLTING   1.3  Review Editdate column update                */
/* 12-May-2015  TLTING   1.4  ArchiveCop Update Skip trigger               */
/* 04-Jul-2018  MCTang   1.5  Change UPDSKULOG Key2 value (MC03)           */
/* 11-Nov-2020  WLChooi  1.6  WMS-15671 - SKUTrigger_SP - call custom SP   */
/*                            when UPDATE record (WL01)                    */
/* 15-Mar-2021  KHChan   1.7  LFI-1646 - Trigger for Webservice (KH01)     */
/* 18-Aug-2021  NJOW01   1.7  WMS-17763 Update active based on skustatus   */
/* 09-Feb-2023  TLTING   1.8  WMS-21597 new column for SKU_Log             */
/***************************************************************************/


CREATE   TRIGGER [dbo].[ntrSKUUpdate] ON [dbo].[SKU]
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
   DECLARE @b_debug int
   SELECT @b_debug = 0

   IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = 'PROFILER,637,00,0,ntrSKUUpdate Trigger' + CONVERT(NVARCHAR(12), GETDATE(), 114)
      PRINT @profiler
   END

   DECLARE @b_Success int           -- Populated by calls to stored procedures - was the proc successful?
         , @n_err int               -- Error number returned by stored procedure or this trigger
         , @n_err2 int              -- For Additional Error Detection
         , @c_errmsg NVARCHAR(250)      -- Error message returned by stored procedure or this trigger
         , @n_continue int
         , @n_starttcnt int         -- Holds the current transaction count
         , @c_preprocess NVARCHAR(250)  -- preprocess
         , @c_pstprocess NVARCHAR(250)  -- post process
         , @n_cnt int
         , @c_Key2  NVARCHAR(14)        --MC03

   -- (YokeBeen01) - Start
   DECLARE @c_Storerkey NVARCHAR(15)
         , @c_Sku NVARCHAR(20)
         , @c_PackKey NVARCHAR(10)
         , @c_authority_owitf NVARCHAR(1)
         , @c_transmitlogkey NVARCHAR(10)
         , @c_authority_vskuitf NVARCHAR(1)  -- MC01
         , @c_authority_ValidateSKUChange NVARCHAR(1)     --(KC01)
         , @c_TrafficCopAllowTriggerSP NVARCHAR(10) --WL01

   SELECT  @c_Storerkey  = ''
         , @c_Sku        = ''
         , @c_PackKey    = ''
         , @c_authority_owitf = ''
   -- (YokeBeen01) - End


   DECLARE @c_FieldName             NVARCHAR(25)
         , @c_OldValue              NVARCHAR(60)
         , @c_NewValue              NVARCHAR(60)
         , @c_authority_skulog      NVARCHAR(1)
         , @c_Authority_UpdSkuLog   NVARCHAR(1)        --(MC02)
         , @c_UpdateColumn          NVARCHAR(4000)     --(MC02)
         , @c_Found                 NVARCHAR(1)        --(MC02)
         , @c_ListName_UpdSkuLog    NVARCHAR(10)       --(MC02)
         , @c_ConfigKey_UpdSkuLog   NVARCHAR(30)       --(MC02)
         , @c_Authority_WSUpdSku    NVARCHAR(1)        --(KH01)
         , @c_ListName_WSUpdSku     NVARCHAR(10)       --(KH01)
         , @c_ConfigKey_WSUpdSku    NVARCHAR(30)       --(KH01)

   SET @c_ListName_UpdSkuLog  = 'TRTL3SKU'             --(MC02)
   SET @c_ConfigKey_UpdSkuLog = 'UPDSKULOG'            --(MC02)
   SET @c_ListName_WSUpdSku  = 'WSTRTL2SKU'            --(KH01)
   SET @c_ConfigKey_WSUpdSku = 'WSUPDSKU'              --(KH01)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      
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
   
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   -- Added BY SHONG 01 JUL 2002
   IF ( @n_continue=1 OR @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE SKU
         SET EditDate = GetDate(),
             EditWho  = SUSER_SNAME(),
             TrafficCop = NULL
        FROM INSERTED
       WHERE SKU.StorerKey = INSERTED.StorerKey
         AND SKU.SKU = INSERTED.SKU
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),ISNULL(@n_err,0))+': Update Failed On Table SKU. (ntrSkuUpdate)' + ' ( '
                        + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
      END
   END
   -- End Add

   IF UPDATE(TrafficCop)
   BEGIN
   	--WL01 START
      IF EXISTS (SELECT 1 FROM INSERTED i   
                 JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'SKUTrigger_SP' AND i.TrafficCop IS NULL) 
      BEGIN
         SELECT @c_TrafficCopAllowTriggerSP = 'Y'
      END
      --WL01 END
   
      SELECT @n_continue = 4
   END
   
   --NJOW01
   IF (@n_continue = 1 or @n_continue = 2) AND UPDATE(Skustatus)
   BEGIN
      UPDATE SKU WITH (ROWLOCK)
      SET SKU.Active = CASE WHEN CL.Short = 'ACTIVE_ON' THEN '1' WHEN CL.Short = 'ACTIVE_OFF' THEN '0' ELSE SKU.Active END,
          SKU.TrafficCop = NULL
      FROM INSERTED I (NOLOCK)
      JOIN DELETED D (NOLOCK) ON I.Storerkey = D.Storerkey AND I.Sku = D.Sku
      JOIN SKU ON I.Storerkey = SKU.Storerkey AND I.Sku = SKU.Sku
      CROSS APPLY (SELECT TOP 1 C.Short 
                   FROM CODELKUP C (NOLOCK) 
                   WHERE C.Code = I.SkuStatus AND C.ListName = 'SKUSTATUS' 
                   AND (C.Storerkey = I.Storerkey OR C.Storerkey = '')
                   ORDER BY C.Storerkey DESC) CL                
      JOIN V_STORERCONFIG2 SC ON I.Storerkey = SC.Storerkey AND SC.Configkey = 'SKUAutoUpdActiveByStatus' AND SC.Svalue = '1'
      WHERE I.SkuStatus <> D.SkuStatus
      AND CL.Short IN ('ACTIVE_ON','ACTIVE_OFF')
      
      SET @n_err = @@ERROR
      
      IF @n_err <> 0
      BEGIN   	 	  	 
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63800
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                           + ': Update Active Failed (ntrSkuUpdate) ( SQLSvr MESSAGE='
                           + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END                     
   END

   --(Kc01) - Start
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF UPDATE(BUSR5) OR UPDATE(ITEMCLASS) OR UPDATE(SKUGROUP) OR UPDATE(STYLE)
         OR UPDATE(COLOR) OR UPDATE(SIZE) OR UPDATE(MEASUREMENT)
      BEGIN
         SELECT @c_Storerkey = Storerkey
               ,@c_SKU = SKU
         FROM INSERTED

         SELECT @b_success = 0
         SELECT @c_authority_ValidateSKUChange = '0'
         EXECUTE nspGetRight NULL,
                             @c_Storerkey,            -- Storer
                             NULL,                    -- Sku
                             'ValidateSKUChange',     -- ConfigKey
                             @b_success                           OUTPUT,
                             @c_authority_ValidateSKUChange       OUTPUT,
                             @n_err                               OUTPUT,
                             @c_errmsg                            OUTPUT

         IF @b_Success = 1 and @c_authority_ValidateSKUChange = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM LOT WITH (NOLOCK)
                        JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot)
                        WHERE LOT.SKU = @c_Sku
                          AND LOT.STORERKEY = @c_Storerkey
                          AND LOT.Qty > 0
                          AND ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'') <> ''
                      )
            BEGIN
            --SELECT @n_continue = 3
            --SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            --SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),ISNULL(@n_err,0))+': Update Failed On Table SKU. (ntrSkuUpdate)' + ' ( '
            --               + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '

               SELECT @n_continue = 3
               SELECT @n_err=60001
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Allowed To Update SKU Because Inventory With Lottable01 Value exists. (ntrSKUUpdate)'
               GOTO QUIT
            END
         END --@b_Success = 1 and @c_authority_ValidateSKUChange = '1'
      END --UPDATE
   END --@n_continue = 1 or @n_continue = 2
   --(Kc01) - End

   /* Added By Vicky 18 July 2002 Patch from IDSHK */

   -- (YokeBeen01) - Start
   -- IF @n_continue = 1 OR @n_continue = 2   -- tlting01
   -- TLTING03
    IF @n_continue <> 3 
    BEGIN
      -- Retrieve related info from INSERTED table into a cursor for TransmitLog Insertion
      DECLARE C_TransmitLogUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT
              INSERTED.Storerkey,
              INSERTED.Sku,
              INSERTED.Packkey
         FROM INSERTED

      OPEN C_TransmitLogUpdate
      FETCH NEXT FROM C_TransmitLogUpdate INTO @c_Storerkey, @c_Sku, @c_PackKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SELECT @b_success = 0
         SELECT @c_authority_skulog = '0'
         EXECUTE nspGetRight NULL,
                             @c_Storerkey,       -- Storer
                             NULL,               -- Sku
                             'SkuLOG',            -- ConfigKey
                             @b_success          output,
                             @c_authority_skulog  output,
                             @n_err              output,
                             @c_errmsg           output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 63700, @c_errmsg = 'ntrSkuUpdate: ' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')
         END

         IF (@c_authority_skulog = '1')
         BEGIN
            IF UPDATE(DESCR)
            BEGIN
               SELECT @c_FieldName = 'DESCR', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = DESCR FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = DESCR FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END

            IF UPDATE(SUSR3)
            BEGIN
               SELECT @c_FieldName = 'SUSR3', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = SUSR3 FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = SUSR3 FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END

            IF UPDATE(ALTSKU)
            BEGIN
               SELECT @c_FieldName = 'ALTSKU', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = ALTSKU FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = ALTSKU FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(PACKKey)
            BEGIN
               SELECT @c_FieldName = 'PACKKey', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = PACKKey FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = PACKKey FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(STDGROSSWGT)
            BEGIN
               SELECT @c_FieldName = 'STDGROSSWGT', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Convert(NVARCHAR(60), STDGROSSWGT) FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Convert(NVARCHAR(60), STDGROSSWGT) FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(STDCUBE)
            BEGIN
               SELECT @c_FieldName = 'STDCUBE', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Convert(NVARCHAR(60), STDCUBE) FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Convert(NVARCHAR(60), STDCUBE) FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(BUSR2)
            BEGIN
               SELECT @c_FieldName = 'BUSR2', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = BUSR2 FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = BUSR2 FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(BUSR6)
            BEGIN
               SELECT @c_FieldName = 'BUSR6', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = BUSR6 FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = BUSR6 FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(LOTTABLE02LABEL)
            BEGIN
               SELECT @c_FieldName = 'LOTTABLE02LABEL', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = LOTTABLE02LABEL FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = LOTTABLE02LABEL FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(LOTTABLE04LABEL)
            BEGIN
               SELECT @c_FieldName = 'LOTTABLE04LABEL', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = LOTTABLE04LABEL FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = LOTTABLE04LABEL FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(StrategyKey)
            BEGIN
               SELECT @c_FieldName = 'StrategyKey', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = StrategyKey FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = StrategyKey FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END
            IF UPDATE(ShelfLife)
            BEGIN
               SELECT @c_FieldName = 'ShelfLife', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = ShelfLife FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = ShelfLife FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF @c_OldValue <> @c_NewValue
               BEGIN
                  EXEC isp_Sku_log
                  @cStorerKey     = @c_Storerkey,
                  @cSKU     = @c_SKU,
                  @cFieldName   = @c_FieldName,
                  @cOldValue = @c_OldValue,
                  @cNewValue = @c_NewValue
               END
            END

            -- SOS# 263375 (Start)
            IF UPDATE(Style)
            BEGIN
               SELECT @c_FieldName = 'Style', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Style FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Style FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END

            IF UPDATE(Color)
            BEGIN
               SELECT @c_FieldName = 'Color', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Color FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Color FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END

            IF UPDATE(Size)
            BEGIN
               SELECT @c_FieldName = 'Size', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Size FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Size FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END

            IF UPDATE(Measurement)
            BEGIN
               SELECT @c_FieldName = 'Measurement', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = Measurement FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = Measurement FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END

			-- Start WMS-21597
            IF UPDATE(IVAS)
            BEGIN
               SELECT @c_FieldName = 'IVAS', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = IVAS FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = IVAS FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END
            IF UPDATE(OVAS)
            BEGIN
               SELECT @c_FieldName = 'OVAS', @c_OldValue = '', @c_NewValue = ''
               SELECT @c_OldValue = OVAS FROM DELETED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU
               SELECT @c_NewValue = OVAS FROM INSERTED WHERE Storerkey = @c_Storerkey AND SKU = @c_SKU

               IF ISNULL(RTRIM(@c_OldValue),'') <> ISNULL(RTRIM(@c_NewValue),'')
               BEGIN
                  EXEC isp_Sku_log
                        @cStorerKey = @c_Storerkey,
                        @cSKU       = @c_SKU,
                        @cFieldName = @c_FieldName,
                        @cOldValue  = @c_OldValue,
                        @cNewValue  = @c_NewValue
               END
            END
			-- END WMS-21597

            -- SOS# 263375 (End)
         END

         -- (MC01) - Start
         IF UPDATE(StdNetWgt) OR UPDATE(StdCube)
         BEGIN
            SELECT @b_success = 0
            SELECT @c_authority_vskuitf = '0'
            EXECUTE dbo.nspGetRight  '',   -- Facility
                     @c_StorerKey,         -- Storer
                     '',                   -- Sku
                     'VSKULOG',            -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_vskuitf  OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63801
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (VSKULOG) Failed (ntrSkuUpdate) ( SQLSvr MESSAGE='
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            ELSE
            BEGIN
               IF @c_authority_vskuitf = '1'
               BEGIN

                  --Can't use ispGenVitalLog because need to check again transmitflag
                  --EXEC dbo.ispGenVitalLog  'VSKULOG', @c_StorerKey, '', @c_Sku, ''
                  --   , @b_success OUTPUT
                  --   , @n_err OUTPUT
                  --   , @c_errmsg OUTPUT

                  IF NOT EXISTS ( SELECT 1 FROM VITALLOG WITH (NOLOCK) WHERE TableName = 'VSKULOG'
                                  AND Key1 = @c_StorerKey AND Key3 = @c_Sku
                                  AND (transmitflag = '0' OR transmitflag = '1') )
                  BEGIN
                     INSERT INTO VITALLOG (Tablename, Key1, Key2, Key3, Transmitflag, TransmitBatch)
                     VALUES ('VSKULOG', @c_StorerKey,'', @c_Sku, '0', '')

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 63706
                        SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) +
                                        ': Insert into VITALLOG Failed. (ntrSkuUpdate)' +
                                        ' ( ' + ' SQLSvr MESSAGE = ' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                     END
                  END

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- @c_authority_vskuitf = '1'
            END -- IF @b_success = 1
         END
         -- (MC01) - End

         -- (MC02) - S
         SELECT @b_success = 0
         SELECT @c_Authority_UpdSkuLog = '0'

         EXECUTE dbo.nspGetRight
                   ''                     -- Facility
                 , @c_StorerKey           -- Storer
                 , ''                     -- Sku
                 , @c_ConfigKey_UpdSkuLog -- ConfigKey
                 , @b_success             OUTPUT
                 , @c_Authority_UpdSkuLog OUTPUT
                 , @n_err                 OUTPUT
                 , @c_errmsg              OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63801
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                             + ': Retrieve of Right (UPDSKULOG) Failed (ntrSkuUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF @c_Authority_UpdSkuLog = '1'
         BEGIN
            SET @c_UpdateColumn = ''

            SELECT @c_UpdateColumn = CASE WHEN INSERTED.DESCR <> DELETED.DESCR THEN 'DESCR|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR1 <> DELETED.SUSR1 THEN 'SUSR1|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR2 <> DELETED.SUSR2 THEN 'SUSR2|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR3 <> DELETED.SUSR3 THEN 'SUSR3|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR4 <> DELETED.SUSR4 THEN 'SUSR4|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR5 <> DELETED.SUSR5 THEN 'SUSR5|' ELSE '' END
                                   + CASE WHEN INSERTED.MANUFACTURERSKU <> DELETED.MANUFACTURERSKU THEN 'MANUFACTURERSKU|' ELSE '' END
                                   + CASE WHEN INSERTED.STDGROSSWGT <> DELETED.STDGROSSWGT THEN 'STDGROSSWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.STDNETWGT <> DELETED.STDNETWGT THEN 'STDNETWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.STDCUBE <> DELETED.STDCUBE THEN 'STDCUBE|' ELSE '' END
                                   + CASE WHEN INSERTED.CLASS <> DELETED.CLASS THEN 'CLASS|' ELSE '' END
                                   + CASE WHEN INSERTED.ACTIVE <> DELETED.ACTIVE THEN 'ACTIVE|' ELSE '' END
                                   + CASE WHEN INSERTED.SKUGROUP <> DELETED.SKUGROUP THEN 'SKUGROUP|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR1 <> DELETED.BUSR1 THEN 'BUSR1|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR2 <> DELETED.BUSR2 THEN 'BUSR2|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR3 <> DELETED.BUSR3 THEN 'BUSR3|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR4 <> DELETED.BUSR4 THEN 'BUSR4|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR5 <> DELETED.BUSR5 THEN 'BUSR5|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE01LABEL <> DELETED.LOTTABLE01LABEL THEN 'LOTTABLE01LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE02LABEL <> DELETED.LOTTABLE02LABEL THEN 'LOTTABLE02LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE03LABEL <> DELETED.LOTTABLE03LABEL THEN 'LOTTABLE03LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE04LABEL <> DELETED.LOTTABLE04LABEL THEN 'LOTTABLE04LABEL|' ELSE '' END
                                   --+ CASE WHEN INSERTED.NOTES1 <> DELETED.NOTES1 THEN 'NOTES1|' ELSE '' END
                                   + CASE WHEN INSERTED.ABC <> DELETED.ABC THEN 'ABC|' ELSE '' END
                                   + CASE WHEN INSERTED.ReorderPoint <> DELETED.ReorderPoint THEN 'ReorderPoint|' ELSE '' END
                                   + CASE WHEN INSERTED.ReorderQty <> DELETED.ReorderQty THEN 'ReorderQty|' ELSE '' END
                                   + CASE WHEN INSERTED.Price <> DELETED.Price THEN 'Price|' ELSE '' END
                                   + CASE WHEN INSERTED.Cost <> DELETED.Cost THEN 'Cost|' ELSE '' END
                                   + CASE WHEN INSERTED.SkuStatus <> DELETED.SkuStatus THEN 'SkuStatus|' ELSE '' END
                                   + CASE WHEN INSERTED.Itemclass <> DELETED.Itemclass THEN 'Itemclass|' ELSE '' END
                                   + CASE WHEN INSERTED.ShelfLife <> DELETED.ShelfLife THEN 'ShelfLife|' ELSE '' END
                                   + CASE WHEN INSERTED.Facility <> DELETED.Facility THEN 'Facility|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR6 <> DELETED.BUSR6 THEN 'BUSR6|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR7 <> DELETED.BUSR7 THEN 'BUSR7|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR8 <> DELETED.BUSR8 THEN 'BUSR8|' ELSE '' END
                                   + CASE WHEN INSERTED.Style <> DELETED.Style THEN 'Style|' ELSE '' END
                                   + CASE WHEN INSERTED.Color <> DELETED.Color THEN 'Color|' ELSE '' END
                                   + CASE WHEN INSERTED.Size <> DELETED.Size THEN 'Size|' ELSE '' END
                                   + CASE WHEN INSERTED.Measurement <> DELETED.Measurement THEN 'Measurement|' ELSE '' END
                                   --+ CASE WHEN INSERTED.NOTES2 <> DELETED.NOTES2 THEN 'NOTES2|' ELSE '' END
                                   + CASE WHEN INSERTED.RetailSku <> DELETED.RetailSku THEN 'RetailSku|' ELSE '' END
                                   + CASE WHEN INSERTED.AltSku <> DELETED.AltSku THEN 'AltSku|' ELSE '' END
                                   + CASE WHEN INSERTED.CartonGroup <> DELETED.CartonGroup THEN 'CartonGroup|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR9 <> DELETED.BUSR9 THEN 'BUSR9|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR10 <> DELETED.BUSR10 THEN 'BUSR10|' ELSE '' END
                                   + CASE WHEN INSERTED.IVAS <> DELETED.IVAS THEN 'IVAS|' ELSE '' END
                                   + CASE WHEN INSERTED.OVAS <> DELETED.OVAS THEN 'OVAS|' ELSE '' END
                                   + CASE WHEN INSERTED.IOFlag <> DELETED.IOFlag THEN 'IOFlag|' ELSE '' END
                                   + CASE WHEN INSERTED.StdOrderCost <> DELETED.StdOrderCost THEN 'StdOrderCost|' ELSE '' END
                                   + CASE WHEN INSERTED.CarryCost <> DELETED.CarryCost THEN 'CarryCost|' ELSE '' END
                                   + CASE WHEN INSERTED.GROSSWGT <> DELETED.GROSSWGT THEN 'GROSSWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.NETWGT <> DELETED.NETWGT THEN 'NETWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.CUBE <> DELETED.CUBE THEN 'CUBE|' ELSE '' END
            FROM  INSERTED, DELETED
            WHERE INSERTED.StorerKey = DELETED.StorerKey
            AND   INSERTED.SKU       = DELETED.SKU
            AND   INSERTED.Storerkey = @c_Storerkey
            AND   INSERTED.SKU       = @c_SKU

            IF @c_UpdateColumn <> ''
            BEGIN

               SET @c_Found = 'N'

               DECLARE C_CodeLkUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ISNULL(RTRIM(Code), '')
               FROM   CodeLkUp WITH (NOLOCK)
               WHERE  ListName  = @c_ListName_UpdSkuLog
               AND    StorerKey = @c_StorerKey

               OPEN C_CodeLkUp
               FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName

               WHILE @@FETCH_STATUS <> -1
               BEGIN

                  SET @c_FieldName = '%' + UPPER(@c_FieldName) + '|' + '%'

                  SELECT @c_Found = CASE WHEN UPPER(@c_UpdateColumn) like @c_FieldName THEN 'Y' ELSE 'N' END

                  IF @c_Found  = 'Y'
                  BEGIN
                     BREAK
                  END

                  FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE C_CodeLkUp
               DEALLOCATE C_CodeLkUp

               IF @c_Found = 'Y'
               BEGIN

                  SET @c_Key2 = CONVERT(CHAR(8), Getdate(), 112) + REPLACE(CONVERT(CHAR(8), Getdate(), 108), ':','')  --(MC02)

                  --EXEC dbo.ispGenTransmitLog3 @c_ConfigKey_UpdSkuLog, @c_StorerKey, '0', @c_SKU, ''  -- (YokeBeen02)
                  EXEC dbo.ispGenTransmitLog3 @c_ConfigKey_UpdSkuLog, @c_StorerKey, @c_Key2, @c_SKU, ''  --(MC02)
                                            , @b_success OUTPUT
                                            , @n_err OUTPUT
                                            , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63802
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                      + ': Insert Into TransmitLog3 Table (UPDSKULOG) Failed (ntrSkuUpdate)( SQLSvr MESSAGE='
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
            END --IF @c_UpdateColumn <> ''
         END --IF @c_Authority_UpdSkuLog = '1'
         -- (MC02) - E

         --(KH01) - S
         SELECT @b_success = 0
         SELECT @c_Authority_WSUpdSku = '0'

         EXECUTE dbo.nspGetRight
                   ''                     -- Facility
                 , @c_StorerKey           -- Storer
                 , ''                     -- Sku
                 , @c_ConfigKey_WSUpdSku  -- ConfigKey
                 , @b_success             OUTPUT
                 , @c_Authority_WSUpdSku  OUTPUT
                 , @n_err                 OUTPUT
                 , @c_errmsg              OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63801
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                             + ': Retrieve of Right (WSUPDSKU) Failed (ntrSkuUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF @c_Authority_WSUpdSku = '1'
         BEGIN
            SET @c_UpdateColumn = ''

            SELECT @c_UpdateColumn = CASE WHEN INSERTED.DESCR <> DELETED.DESCR THEN 'DESCR|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR1 <> DELETED.SUSR1 THEN 'SUSR1|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR2 <> DELETED.SUSR2 THEN 'SUSR2|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR3 <> DELETED.SUSR3 THEN 'SUSR3|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR4 <> DELETED.SUSR4 THEN 'SUSR4|' ELSE '' END
                                   + CASE WHEN INSERTED.SUSR5 <> DELETED.SUSR5 THEN 'SUSR5|' ELSE '' END
                                   + CASE WHEN INSERTED.MANUFACTURERSKU <> DELETED.MANUFACTURERSKU THEN 'MANUFACTURERSKU|' ELSE '' END
                                   + CASE WHEN INSERTED.STDGROSSWGT <> DELETED.STDGROSSWGT THEN 'STDGROSSWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.STDNETWGT <> DELETED.STDNETWGT THEN 'STDNETWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.STDCUBE <> DELETED.STDCUBE THEN 'STDCUBE|' ELSE '' END
                                   + CASE WHEN INSERTED.CLASS <> DELETED.CLASS THEN 'CLASS|' ELSE '' END
                                   + CASE WHEN INSERTED.ACTIVE <> DELETED.ACTIVE THEN 'ACTIVE|' ELSE '' END
                                   + CASE WHEN INSERTED.SKUGROUP <> DELETED.SKUGROUP THEN 'SKUGROUP|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR1 <> DELETED.BUSR1 THEN 'BUSR1|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR2 <> DELETED.BUSR2 THEN 'BUSR2|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR3 <> DELETED.BUSR3 THEN 'BUSR3|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR4 <> DELETED.BUSR4 THEN 'BUSR4|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR5 <> DELETED.BUSR5 THEN 'BUSR5|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE01LABEL <> DELETED.LOTTABLE01LABEL THEN 'LOTTABLE01LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE02LABEL <> DELETED.LOTTABLE02LABEL THEN 'LOTTABLE02LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE03LABEL <> DELETED.LOTTABLE03LABEL THEN 'LOTTABLE03LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.LOTTABLE04LABEL <> DELETED.LOTTABLE04LABEL THEN 'LOTTABLE04LABEL|' ELSE '' END
                                   + CASE WHEN INSERTED.ABC <> DELETED.ABC THEN 'ABC|' ELSE '' END
                                   + CASE WHEN INSERTED.ReorderPoint <> DELETED.ReorderPoint THEN 'ReorderPoint|' ELSE '' END
                                   + CASE WHEN INSERTED.ReorderQty <> DELETED.ReorderQty THEN 'ReorderQty|' ELSE '' END
                                   + CASE WHEN INSERTED.Price <> DELETED.Price THEN 'Price|' ELSE '' END
                                   + CASE WHEN INSERTED.Cost <> DELETED.Cost THEN 'Cost|' ELSE '' END
                                   + CASE WHEN INSERTED.SkuStatus <> DELETED.SkuStatus THEN 'SkuStatus|' ELSE '' END
                                   + CASE WHEN INSERTED.Itemclass <> DELETED.Itemclass THEN 'Itemclass|' ELSE '' END
                                   + CASE WHEN INSERTED.ShelfLife <> DELETED.ShelfLife THEN 'ShelfLife|' ELSE '' END
                                   + CASE WHEN INSERTED.Facility <> DELETED.Facility THEN 'Facility|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR6 <> DELETED.BUSR6 THEN 'BUSR6|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR7 <> DELETED.BUSR7 THEN 'BUSR7|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR8 <> DELETED.BUSR8 THEN 'BUSR8|' ELSE '' END
                                   + CASE WHEN INSERTED.Style <> DELETED.Style THEN 'Style|' ELSE '' END
                                   + CASE WHEN INSERTED.Color <> DELETED.Color THEN 'Color|' ELSE '' END
                                   + CASE WHEN INSERTED.Size <> DELETED.Size THEN 'Size|' ELSE '' END
                                   + CASE WHEN INSERTED.Measurement <> DELETED.Measurement THEN 'Measurement|' ELSE '' END
                                   + CASE WHEN INSERTED.RetailSku <> DELETED.RetailSku THEN 'RetailSku|' ELSE '' END
                                   + CASE WHEN INSERTED.AltSku <> DELETED.AltSku THEN 'AltSku|' ELSE '' END
                                   + CASE WHEN INSERTED.CartonGroup <> DELETED.CartonGroup THEN 'CartonGroup|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR9 <> DELETED.BUSR9 THEN 'BUSR9|' ELSE '' END
                                   + CASE WHEN INSERTED.BUSR10 <> DELETED.BUSR10 THEN 'BUSR10|' ELSE '' END
                                   + CASE WHEN INSERTED.IVAS <> DELETED.IVAS THEN 'IVAS|' ELSE '' END
                                   + CASE WHEN INSERTED.OVAS <> DELETED.OVAS THEN 'OVAS|' ELSE '' END
                                   + CASE WHEN INSERTED.IOFlag <> DELETED.IOFlag THEN 'IOFlag|' ELSE '' END
                                   + CASE WHEN INSERTED.StdOrderCost <> DELETED.StdOrderCost THEN 'StdOrderCost|' ELSE '' END
                                   + CASE WHEN INSERTED.CarryCost <> DELETED.CarryCost THEN 'CarryCost|' ELSE '' END
                                   + CASE WHEN INSERTED.GROSSWGT <> DELETED.GROSSWGT THEN 'GROSSWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.NETWGT <> DELETED.NETWGT THEN 'NETWGT|' ELSE '' END
                                   + CASE WHEN INSERTED.CUBE <> DELETED.CUBE THEN 'CUBE|' ELSE '' END
            FROM  INSERTED, DELETED
            WHERE INSERTED.StorerKey = DELETED.StorerKey
            AND   INSERTED.SKU       = DELETED.SKU
            AND   INSERTED.Storerkey = @c_Storerkey
            AND   INSERTED.SKU       = @c_SKU

            IF @c_UpdateColumn <> ''
            BEGIN
               SET @c_Found = 'N'

               DECLARE C_CodeLkUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ISNULL(RTRIM(Code), '')
               FROM   CodeLkUp WITH (NOLOCK)
               WHERE  ListName  = @c_ListName_WSUpdSku
               AND    StorerKey = @c_StorerKey

               OPEN C_CodeLkUp
               FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName

               WHILE @@FETCH_STATUS <> -1
               BEGIN

                  SET @c_FieldName = '%' + UPPER(@c_FieldName) + '|' + '%'

                  SELECT @c_Found = CASE WHEN UPPER(@c_UpdateColumn) like @c_FieldName THEN 'Y' ELSE 'N' END

                  IF @c_Found  = 'Y'
                  BEGIN
                     BREAK
                  END

                  FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE C_CodeLkUp
               DEALLOCATE C_CodeLkUp

               IF @c_Found = 'Y'
               BEGIN
                  SET @c_Key2 = CONVERT(CHAR(8), Getdate(), 112) + REPLACE(CONVERT(CHAR(8), Getdate(), 108), ':','') 

                  EXEC dbo.ispGenTransmitLog2 @c_ConfigKey_WSUpdSku, @c_StorerKey, @c_Key2, @c_SKU, '' 
                                            , @b_success OUTPUT
                                            , @n_err OUTPUT
                                            , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63802
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                      + ': Insert Into TransmitLog2 Table (WSUPDSKU) Failed (ntrSkuUpdate)( SQLSvr MESSAGE='
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
            END --IF @c_UpdateColumn <> ''
         END --IF @c_Authority_WSUpdSku = '1'
         --(KH01) - E

         IF @n_continue=1 OR @n_continue=2
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight NULL,
                                @c_Storerkey,       -- Storer
                                NULL,               -- Sku
                                'OWITF',            -- ConfigKey
                                @b_success          output,
                                @c_authority_owitf  output,
                                @n_err              output,
                                @c_errmsg           output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @n_err = 63700, @c_errmsg = 'ntrSkuUpdate: ' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')
            END

            IF (@c_authority_owitf = '1')
            BEGIN
               -- Check if Pack info was updated
               IF EXISTS ( SELECT 1 FROM INSERTED JOIN DELETED ON (INSERTED.Packkey = DELETED.Packkey)
                            WHERE INSERTED.Packkey = @c_PackKey AND (INSERTED.StdCube <> DELETED.StdCube OR
                                                                     INSERTED.StdGrossWgt <> DELETED.StdGrossWgt) )
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK) WHERE Key1 = @c_PackKey
                                            AND Key2 = @c_Storerkey AND Key3 = @c_Sku AND TransmitFlag = '0' )
                  BEGIN
                     -- Retrieve additional info
                     SELECT @c_transmitlogkey = ''
                     SELECT @b_success = 1

                     EXECUTE nspg_getkey
                        'TransmitlogKey'
                        , 10
                        , @c_transmitlogkey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                     IF NOT @b_success=1
                     BEGIN
                        SELECT @n_continue = 3 , @n_err = 63701
                        SELECT @c_errmsg = 'ntrSkuUpdate: ' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')
                     END

                     IF ( @n_continue = 1 OR @n_continue = 2 )
                     BEGIN
                        INSERT TRANSMITLOG (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                        VALUES ( @c_transmitlogkey, 'OWCBM', @c_PackKey, @c_Storerkey, @c_Sku, 0 )

                        SELECT @n_err = @@Error
                        IF NOT @n_err = 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 63702
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),ISNULL(@n_err,0))+
                                            ': Insert Into TransmitLog Table (OWCBM) Failed (ntrSkuUpdate)' +
                                            ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                        END
                     END
   --                EXEC dbo.ispGenTransmitLog 'OWCBM', @c_PackKey, @c_Storerkey, @c_Sku, ''
   --                     , @b_success OUTPUT
   --                     , @n_err OUTPUT
   --                     , @c_errmsg OUTPUT
   --
   --                IF @b_success <> 1
   --                BEGIN
   --                   SELECT @n_continue = 3, @n_err = 63702, @c_errmsg = 'ntrSkuUpdate: ' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')
   --                End
                  END -- (Outstanding TransmitLog record not exists)
               END -- Sku Exists
            END -- (@c_authority_owitf = '1')
         END -- @n_continue=1 OR @n_continue=2

         FETCH NEXT FROM C_TransmitLogUpdate INTO @c_Storerkey, @c_Sku, @c_PackKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_TransmitLogUpdate
      DEALLOCATE C_TransmitLogUpdate
   END   -- TLTING03  -- tlting01 remove
   -- (YokeBeen01) - End

   -- Added By Ricky Yee for IDSV5
   -- 21 June 2002
   /*
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @c_Action NVARCHAR(100),
              @c_OldValue NVARCHAR(30),
              @c_NewValue NVARCHAR(30)
      SELECT @c_Action = 'Updating '

      IF UPDATE(DESCR)
      BEGIN
         SELECT @c_OldValue = DESCR FROM DELETED

         SELECT @c_SKU = SKU,
                @c_NewValue = DESCR
           FROM INSERTED

         SELECT @c_Action = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Action)),'') + ' /Description. Origin:'
                          + ISNULL(dbo.fnc_RTrim(@c_OldValue),'') + ' New:' + ISNULL(dbo.fnc_RTrim(@c_NewValue),'')
      END
      IF UPDATE(SKU)
      BEGIN
         SELECT @c_OldValue = SKU FROM DELETED
         SELECT @c_NewValue = SKU FROM INSERTED

         SELECT @c_Action = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Action)),'') + ' /SKU Origin:'  + ISNULL(dbo.fnc_RTrim(@c_OldValue),'')
                          + ' New:' + ISNULL(dbo.fnc_RTrim(@c_NewValue),'')
      END
      IF UPDATE(PackKey)
      BEGIN
         SELECT @c_OldValue = PackKey FROM DELETED

         SELECT @c_SKU = SKU,
                @c_NewValue = PackKey
           FROM INSERTED

         SELECT @c_Action = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Action)),'') + ' /PackKey SKU:' + ISNULL(dbo.fnc_RTrim(@c_SKU),'')
                          + ' Origin:' + ISNULL(dbo.fnc_RTrim(@c_OldValue),'') + ' New:' + ISNULL(dbo.fnc_RTrim(@c_NewValue),'')
      END

      INSERT INTO SKULog (Person, ActionTime, ActionDescr)
      SELECT SUSER_SNAME(), GetDate(), @c_Action
        FROM  INSERTED

      UPDATE SKU
         SET EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
        FROM INSERTED
       WHERE SKU.StorerKey = INSERTED.StorerKey
         AND SKU.Sku = INSERTED.Sku

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),ISNULL(@n_err,0))+': Update Failed On Table SKU. (ntrSkuUpdate)' + ' ( '
                        + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
      END
   END
   */
   -- end
   
   --WL01 START
   IF @n_continue=1 or @n_continue=2 OR (@c_TrafficCopAllowTriggerSP = 'Y' AND @n_continue <> 3)
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
                 JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
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
                   'UPDATE'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT
   
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrSKUUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END
   
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END
   --WL01 END
QUIT:
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrSKUUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,00,9,ntrSKUUpdate Tigger, ' + CONVERT(NVARCHAR(12), getdate(), 114)
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
         SELECT @profiler = 'PROFILER,637,00,9,ntrSKUUpdate Trigger, ' + CONVERT(NVARCHAR(12), getdate(), 114) PRINT @profiler
      END
      RETURN
   END
END

GO