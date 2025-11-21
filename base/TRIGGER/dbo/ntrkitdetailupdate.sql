SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrKitDetailUpdate                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Delete Kit Detail Record                             */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 14-June-2006 Vicky         Modify Update OpenQty to cater ManyToMany */
/*                            Kitting                                   */ 
/* 18-Sept-2006 June          SOS58266 - C4KIT for C4 GOLD Interface    */
/* 27-Sept-2006 Vicky         Take out the Kit.OpenQty for status <> 9  */
/* 31-May-2007  Shong         Update Kit with TrafficCop                */ 
/* 23-May-2012  TLTING01 1.2  DM Integrity issue - Update editdate for  */
/*                            status < '9'                              */
/* 06-Sep-2012  KHLim    1.3  Move up ArchiveCop (KH01)                 */
/* 28-Oct-2013  TLTING   1.4  Review Editdate column update             */
/* 30-May-2007  Shong         Add Checking on TrifficCop and ArchiveCop */
/* 02-May-2014  Shong    1.5  Added Lottables 06-15                     */
/* 24-Jan-2017  TLTING01 1.6  Remove Set ROWCOUNT                       */
/* 19-Jan-2021  Wan01    1.7  WMS-16051 - ANFQHW_Exceed_Channel_Kitting */
/* 25-Feb-2025  SSA01    1.8  UWP-29649 -  Populate PalletType          */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrKitDetailUpdate]
ON  [dbo].[KITDETAIL]
FOR UPDATE
AS
BEGIN
   -- tlting01 start
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
   IF @b_debug = 1
   BEGIN
      SELECT 'INSERTED ', * FROM INSERTED
      SELECT 'DELETED  ', * FROM DELETED
   END
   ELSE IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = 'PROFILER,700,00,0,ntrKitDetailUpdate Trigger                    ,' + CONVERT(char(12), getdate(), 114)
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
   ,          @c_KittingITF NVARCHAR(1)   -- Add by June 1.Jul.02 for IDSV5             
   ,       @c_C4ITF      NVARCHAR(1)   -- SOS58266
 
   --(Wan01) - START
   DECLARE @n_Channel_ID                  BIGINT      = 0   
         , @c_Channel                     NVARCHAR(20)= ''  
         , @c_ChannelInventoryMgmt_From   NVARCHAR(30)= ''  
         , @c_ChannelInventoryMgmt_To     NVARCHAR(30)= ''  
         , @c_Facility                    NVARCHAR(5) = ''
   --(Wan01) - END
   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4 
   END
   
   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate)  --KH01
   BEGIN 
      -- tlting01
      IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
                  WHERE INSERTED.KitKey = DELETED.KitKey
                  AND INSERTED.KitLineNumber = DELETED.KitLineNumber
                  AND INSERTED.Type = DELETED.Type
                  AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) )
      BEGIN
         UPDATE KitDetail with (ROWLOCK)
         SET   EditDate = GetDate(), EditWho = Suser_Sname(), --Added By Vicky 18Juky 2002 Patch from IDSHK
               TrafficCop = NULL  
         FROM  INSERTED, DELETED
         WHERE KitDetail.KitKey = INSERTED.KitKey
         AND   KitDetail.KitLineNumber = INSERTED.KitLineNumber
         AND   KITDETAIL.Type = INSERTED.Type
         AND   KitDetail.KitKey = DELETED.KitKey
         AND   KitDetail.KitLineNumber = DELETED.KitLineNumber
         AND   KITDETAIL.Type = DELETED.Type
         AND   KITDETAIL.[status] < '9'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed on table KitDetail. (ntrKitDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
 
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4 
   END
      /* #INCLUDE <TRTDU1.SQL> */     
   -- Added By Shong
   DECLARE @c_KitKey NVARCHAR(10), 
         @c_trmlogkey NVARCHAR(10), 
         @c_KitLineNumber NVARCHAR(5)
   DECLARE @n_toqty   int,
   @n_fromqty int
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT *
      FROM DELETED
      WHERE Status = '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 70000
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Posted rows may not be edited. (ntrKitDetailUpdate)'
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE KitDetail 
      SET   EditDate = GetDate(), EditWho = Suser_Sname(), --Added By Vicky 18Juky 2002 Patch from IDSHK
            TrafficCop = NULL 
      FROM  INSERTED, DELETED
      WHERE KitDetail.KitKey = INSERTED.KitKey
      AND   KitDetail.KitLineNumber = INSERTED.KitLineNumber
      AND   KITDETAIL.Type = INSERTED.Type
      AND   KitDetail.KitKey = DELETED.KitKey
      AND   KitDetail.KitLineNumber = DELETED.KitLineNumber
      AND   KITDETAIL.Type = DELETED.Type
      AND   KITDETAIL.[STATUS]  in ( '9' , 'CANC' )     -- tlting01
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed on table KitDetail. (ntrKitDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
   UPDATE KitDetail with (ROWLOCK)
      SET   LOTTABLE01 = KitDetail.PACKKEY, TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
      FROM  INSERTED, SKU (NOLOCK)
      WHERE KitDetail.KitKey = INSERTED.KitKey
      AND   KitDetail.KitLineNumber = INSERTED.KitLineNumber
      AND   KITDETAIL.Type = 'T'
      AND   INSERTED.StorerKey = SKU.Storerkey
      AND   INSERTED.SKU = SKU.SKU
      AND   SKU.OnReceiptCopyPackKey = '1'
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed on table KitDetail. (ntrKitDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,700,01,0,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      DECLARE 
      @c_KitPrimaryKey          NVARCHAR(15),
      @c_FromStorerKey          NVARCHAR(15),
      @c_FromSku                NVARCHAR(20),
      @c_FromLoc                NVARCHAR(10),
      @c_FromLot                NVARCHAR(10),
      @c_FromId                 NVARCHAR(18),
      @c_FromPackKey            NVARCHAR(10),
      @c_FromUOM                NVARCHAR(10),
      @c_StorerKey              NVARCHAR(15),
      @c_ToSku                  NVARCHAR(20),
      @c_ToLoc                  NVARCHAR(10),
      @c_ToLot                  NVARCHAR(10),
      @c_ToId                   NVARCHAR(18),
      @c_ToPackKey              NVARCHAR(10),
      @c_ToUOM                  NVARCHAR(10),
      @c_lottable01             NVARCHAR(18),
      @c_lottable02             NVARCHAR(18),
      @c_lottable03             NVARCHAR(18),
      @d_lottable04             datetime,
      @d_lottable05             datetime,
      @c_lottable06             NVARCHAR(30), 
      @c_lottable07             NVARCHAR(30),
      @c_lottable08             NVARCHAR(30),
      @c_lottable09             NVARCHAR(30),
      @c_lottable10             NVARCHAR(30),
      @c_lottable11             NVARCHAR(30),
      @c_lottable12             NVARCHAR(30),
      @d_lottable13             datetime,
      @d_lottable14             datetime,
      @d_lottable15             datetime,        
      @d_EffectiveDate          DATETIME,
      @c_PalletType             NVARCHAR(10)     --(SSA01)
      
      SELECT @c_KitPrimaryKey = ' '
      WHILE (1 = 1)
      BEGIN
         SET @n_Channel_ID = 0                     --(Wan01)
         SET @c_Channel = ''                       --(Wan01)
         
         SELECT TOP 1 @c_KitPrimaryKey = KitKey + KitLineNumber,
               @c_FromStorerKey = StorerKey,
               @c_FromSku       = Sku,
               @c_FromLoc       = Loc,
               @c_FromLot       = Lot,
               @c_FromId        = Id,
               @n_FromQty       = Qty,
               @c_FromPackKey   = PackKey,
               @c_FromUOM       = UOM
            , @n_Channel_ID     = Channel_ID    --(Wan01)
            , @c_Channel        = Channel       --(Wan01)  
         FROM INSERTED
         WHERE KitKey + KitLineNumber > @c_KitPrimaryKey
         AND Status = '9'
         AND Type = 'F'
         ORDER BY KitKey, KitLineNumber
         
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
       
         -- Start : SOS58266
         SELECT @c_KitKey  = LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 10)
         SELECT @c_KitLineNumber = RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 5)
         -- End : SOS58266

         --(Wan01) - START
         SELECT TOP 1 @c_Facility = Facility
         FROM KIT AS k WITH (NOLOCK)
         WHERE k.KITKey = @c_KitKey
         
         SET @c_ChannelInventoryMgmt_From = ''
         SELECT @c_ChannelInventoryMgmt_From = SC.Authority FROM dbo.fnc_SelectGetRight (@c_Facility, @c_FromStorerKey, '', 'ChannelInventoryMgmt') SC
    
         IF @c_ChannelInventoryMgmt_From = '1' AND (@c_Channel = '' OR @c_Channel IS NULL)
         BEGIN
            SET @n_continue = 3
            SET @n_err=63811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': From Channel Cannot be BLANK. (ntrKitDetailUpdate)'   
            BREAK
         END
         --(Wan01) - END

         EXECUTE nspItrnAddWithdrawal
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @c_FromStorerKey,
                  @c_Sku        = @c_FromSku,   
                  @c_Lot        = @c_FromLot,
                  @c_ToLoc      = @c_FromLoc,
                  @c_ToID       = @c_FromId,
                  @c_Status     = '',
                  @c_lottable01 = '',
                  @c_lottable02 = '',
                  @c_lottable03 = '',
                  @d_lottable04 = NULL,
                  @d_lottable05 = NULL,
                  @c_lottable06 = "",
                  @c_lottable07 = "",
                  @c_lottable08 = "",
                  @c_lottable09 = "",
                  @c_lottable10 = "",
                  @c_lottable11 = "",
                  @c_lottable12 = "",
                  @d_lottable13 = NULL,
                  @d_lottable14 = NULL,
                  @d_lottable15 = NULL,         
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @n_FromQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = @c_KitPrimaryKey,
                  @c_SourceType = 'ntrKitDetailUpdate',
                  @c_PackKey    = @c_FromPackKey,
                  @c_UOM        = @c_FromUOM,   
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = @d_EffectiveDate,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT
               ,  @c_Channel    = @c_Channel             -- Wan01  
               ,  @n_Channel_ID = @n_Channel_ID  OUTPUT  -- Wan01  

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            --(Wan01) - START
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE KD WITH (ROWLOCK)
                  SET  Channel_ID = @n_Channel_ID
                     , EditWho  = SUSER_SNAME()
                     , EditDate = GETDATE()
                     , Trafficcop = NULL
               FROM KITDETAIL KD
               WHERE KD.KItKey = @c_KitKey
               AND KD.KItLineNumber = @c_KitLineNumber
               AND KD.[TYPE] = 'F'
                 
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(CHAR(250), @n_err)
                  SET @n_err = 63813
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Kitdetail fail. (ntrKitDetailUpdate)'  
                                + ' ( SQLSvr MESSAGE= ' + @c_errmsg + ' ) '
               END      
            END
            --(Wan01) - END
            
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               -- Added for IDSV5 by June 1.Jul.02, (extract from IDSMY & IDSTW) *** Start
               SELECT @b_success = 0
               Execute nspGetRight null,  -- facility
                           @c_FromStorerKey,    -- Storerkey
                           null,          -- Sku
                           'KITTINGITF',        -- Configkey
                           @b_success     output,
                           @c_KittingITF  output, 
                           @n_err         output,
                           @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrKitDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_KittingITF = '1'
               BEGIN 
                  -- Added for IDSV5 by June 1.Jul.02, (extract from IDSMY & IDSTW) *** End
                  -- Author : Shong Wan Toh
                  -- Purpose: Interface
                  -- Date   : 04th Sep 2000
                  -- Modification - to add records in transmitlog 
                  IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.STATUS = '9')
                  BEGIN
                     SELECT @b_success = 1
                     EXECUTE nspg_getkey
                     "transmitlogkey"
                     , 10
                     , @c_trmlogkey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     ELSE                
                     BEGIN
                        INSERT INTO transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                        SELECT @c_trmlogkey, 'Kitting', INSERTED.KitKey, INSERTED.KitLineNumber, INSERTED.TYPE, '0'
                        FROM   INSERTED
                        WHERE  INSERTED.KitKey + INSERTED.KitLineNumber = @c_KitPrimaryKey
                        AND    INSERTED.TYPE = "F"
                        AND    INSERTED.Status = "9"
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Insert Transmitlog (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     END -- insert transmitlog
                  END -- KitDetail.status = '9'
               END -- KittingITF = 1
            END  
            -- End Modification     

            -- Start : SOS58266
            -- Add by June 18.Sept.2006, insert into Transmitlog2
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight null,     -- facility
                           @c_FromStorerKey,    -- Storerkey
                           null,          -- Sku
                           'C4ITF',       -- Configkey
                           @b_success     output,
                           @c_C4ITF    output, 
                           @n_err         output,
                           @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrKitDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_C4ITF = '1'
               BEGIN 
                  EXEC ispGenTransmitLog2 'C4KIT', @c_KitKey, @c_KitLineNumber, 'F', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
               END -- C4ITF            
            END -- Continue
         -- End : SOS58266
         END -- Success = 1
      END -- WHILE From
     
      SELECT @c_KitPrimaryKey = ' '
      WHILE (1 = 1)
      BEGIN
         SET @n_Channel_ID = 0                           --(Wan01) 
         SET @c_Channel = ''                             --(Wan01) 
         
         SELECT TOP 1  
                     @c_KitPrimaryKey = KitKey + KitLineNumber,
                     @c_StorerKey     = StorerKey,
                     @c_ToSku         = Sku,
                     @c_ToLoc         = Loc,
                     @c_ToLot         = Lot,
                     @c_ToId          = Id,
                     @n_ToQty         = Qty,
                     @c_ToPackKey     = PackKey,
                     @c_ToUOM         = UOM, 
                     @c_lottable01    = lottable01,
                     @c_lottable02    = lottable02,   
                     @c_lottable03    = lottable03,
                     @d_lottable04    = lottable04,
                     @d_lottable05    = lottable05,
                     @c_lottable06    = lottable06,
                     @c_lottable07    = lottable07,
                     @c_lottable08    = lottable08,
                     @c_lottable09    = lottable09,
                     @c_lottable10    = lottable10,
                     @c_lottable11    = lottable11,
                     @c_lottable12    = lottable12,
                     @d_lottable13    = lottable13,
                     @d_lottable14    = lottable14,
                     @d_lottable15    = lottable15,
                     @c_PalletType    = PalletType,      --(SSA01)
                     @d_EffectiveDate = EffectiveDate
                  , @n_Channel_ID     = Channel_ID       --(Wan01)
                  , @c_Channel        = Channel          --(Wan01) 
         FROM INSERTED
         WHERE KitKey + KitLineNumber > @c_KitPrimaryKey
         AND Status = '9'
         AND Type = 'T'
         ORDER BY KitKey, KitLineNumber
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         -- Start : SOS58266
         SELECT @c_KitKey  = LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 10)
         SELECT @c_KitLineNumber = RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 5)
         -- End : SOS58266
    
         --(Wan01) - START
         SELECT TOP 1 @c_Facility = Facility
         FROM KIT AS k WITH (NOLOCK)
         WHERE k.KITKey = @c_KitKey
      
         SET @c_ChannelInventoryMgmt_To = ''
         SELECT @c_ChannelInventoryMgmt_To = SC.Authority FROM   dbo.fnc_SelectGetRight (@c_Facility, @c_StorerKey, '', 'ChannelInventoryMgmt') SC
         IF @c_ChannelInventoryMgmt_To = '1' AND (@c_Channel = '' OR @c_Channel IS NULL)
         BEGIN
            SET @n_continue = 3
            SET @n_err=63812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': To Channel Cannot be BLANK. (ntrKitDetailUpdate)'   
            BREAK
         END
         --(Wan01) - END
         
         EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @c_StorerKey,
                  @c_Sku        = @c_ToSku,
                  @c_Lot        = @c_ToLot,
                  @c_ToLoc      = @c_ToLoc,
                  @c_ToID       = @c_ToId,
                  @c_Status     = '',
                  @c_lottable01 = @c_lottable01,
                  @c_lottable02 = @c_lottable02,
                  @c_lottable03 = @c_lottable03,
                  @d_lottable04 = @d_lottable04,
                  @d_lottable05 = @d_lottable05,
                  @c_lottable06 = @c_lottable06,
                  @c_lottable07 = @c_lottable07,
                  @c_lottable08 = @c_lottable08,
                  @c_lottable09 = @c_lottable09,
                  @c_lottable10 = @c_lottable10,
                  @c_lottable11 = @c_lottable11,
                  @c_lottable12 = @c_lottable12,
                  @d_lottable13 = @d_lottable13,
                  @d_lottable14 = @d_lottable14,
                  @d_lottable15 = @d_lottable15,            
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @n_ToQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = @c_KitPrimaryKey,
                  @c_SourceType = 'ntrKitDetailAdd',
                  @c_PackKey    = @c_ToPackKey,
                  @c_UOM        = @c_ToUOM,
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = @d_EffectiveDate,   
                  @c_ItrnKey    = '',
                  @c_PalletType = @c_PalletType,         --(SSA01)
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg OUTPUT
               ,  @c_Channel    = @c_Channel             -- Wan01  
               ,  @n_Channel_ID = @n_Channel_ID  OUTPUT  -- Wan01     
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            --(Wan01) - START
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE KD WITH (ROWLOCK)
                  SET  Channel_ID = @n_Channel_ID
                     , EditWho  = SUSER_SNAME()
                     , EditDate = GETDATE()
                     , Trafficcop = NULL
               FROM KITDETAIL KD
               WHERE KD.KItKey = @c_KitKey
               AND KD.KItLineNumber = @c_KitLineNumber
               AND KD.[TYPE] = 'T'
                 
               SET @n_err = @@ERROR 
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(CHAR(250), @n_err)
                  SET @n_err = 63814
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Kitdetail fail. (ntrKitDetailUpdate)'  
                                + ' ( SQLSvr MESSAGE= ' + @c_errmsg + ' ) '
               END      
            END
            --(Wan01) - END
            IF @n_continue = 1 OR @n_continue = 2  
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight null,  -- facility
                        @c_StorerKey,     -- Storerkey
                        null,             -- Sku
                        'KITTINGITF',        -- Configkey
                        @b_success     output,
                        @c_KittingITF  output, 
                        @n_err         output,
                        @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrKitDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_KittingITF = '1'
               BEGIN
                     /* Modification - to add records in transmitlog */
                     -- Author : Shong Wan Toh
                     -- Purpose: Interface
                     -- Date   : 04th Sep 2000
                  IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.STATUS = '9')
                  BEGIN
                     SELECT @b_success = 1
               
                     EXECUTE nspg_getkey
                     "transmitlogkey"
                     , 10
                     , @c_trmlogkey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     ELSE               
                     BEGIN
                        INSERT INTO transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                        SELECT @c_trmlogkey, 'Kitting', INSERTED.KitKey, INSERTED.KitLineNumber, INSERTED.TYPE, '0'
                        FROM   INSERTED
                        WHERE  INSERTED.KitKey + INSERTED.KitLineNumber = @c_KitPrimaryKey
                        AND    INSERTED.TYPE = "T"
                        AND    INSERTED.Status = "9"
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Insert Transmitlog (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     END -- Insert Transmitlog  
                  END -- Kitdetail.Status = '9'
                  /* End Modification */     
               END -- KittingITF = 1 
            END 

            -- Start : SOS58266
            -- Add by June 18.Sept.2006, insert into Transmitlog2
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight null,     -- facility
                           @c_FromStorerKey,    -- Storerkey
                           null,          -- Sku
                           'C4ITF',       -- Configkey
                           @b_success     output,
                           @c_C4ITF    output, 
                           @n_err         output,
                           @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrKitDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_C4ITF = '1'
               BEGIN 
                  EXEC ispGenTransmitLog2 'C4KIT', @c_KitKey, @c_KitLineNumber, 'T', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
               END -- C4ITF            
            END -- Continue
            -- End : SOS58266
         END -- Success = 1
      END -- WHILE
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,01,9,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END

   -- Start - Add by YokeBeen on 01-Oct-2002 (ULVHK Interface - ispExportKitUIINV)
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF UPDATE(Status)
      BEGIN
         DECLARE  @c_XKitKey      NVARCHAR(10), 
                  @c_XKitLineNumber NVARCHAR(5), 
                  @c_XStorerKey   NVARCHAR(15), 
                  @c_XExternKitKey NVARCHAR(20),
                  @c_XCustomerRefNo NVARCHAR(10), 
                  @c_XTablename   NVARCHAR(10),  
                  @c_XRectype     NVARCHAR(12) 
         SELECT   @c_XKitKey        = SPACE(10),
                  @c_XKitLineNumber = SPACE(5), 
                  @c_XStorerKey     = SPACE(15),
                  @c_XExternKitKey  = SPACE(20),
                  @c_XCustomerRefNo = SPACE(10), 
                  @c_XTablename     = SPACE(10),  
                  @c_XRectype       = SPACE(12) 
   
         WHILE 1=1
         BEGIN
            
            SELECT TOP 1   @c_XKitKey = KITDETAIL.KitKey,
                     @c_XKitLineNumber = KITDETAIL.KITLineNumber, 
                     @c_XStorerkey = KIT.Storerkey, 
                     @c_XExternKitKey = KIT.ExternKitKey,
                     @c_XCustomerRefNo = KIT.CustomerRefNo, 
                     @c_XRectype = KIT.Type  
               FROM  INSERTED
               JOIN  DELETED ON (DELETED.Kitkey = INSERTED.Kitkey)
               JOIN  KITDETAIL (NOLOCK) ON (INSERTED.Kitkey = KITDETAIL.Kitkey)
               JOIN  KIT (NOLOCK) ON (KITDETAIL.Kitkey = KIT.Kitkey and KITDETAIL.Storerkey = KIT.Storerkey)
               JOIN  StorerConfig (NOLOCK) ON (KIT.StorerKey = StorerConfig.StorerKey
                                                AND StorerConfig.ConfigKey = 'ULVITF' AND StorerConfig.sValue = '1')
               WHERE INSERTED.Status = '9'
               AND   DELETED.Status <> '9'
               AND   KIT.KitKey > @c_XKitKey 
               AND   KITDETAIL.Type = 'T' 
               ORDER BY KITDETAIL.KitKey, KITDETAIL.KITLineNumber 
   
            IF @@ROWCOUNT = 0
               BREAK

            -- Added by YokeBeen on 02-Nov-2002.
            -- Checking on ExternKitKey and CustomerRefNo, either one must exists then only to create the record 
            -- under Transmitlog2 for Outbound.
            IF (@c_XExternKitKey = NULL OR @c_XExternKitKey = '') 
               BEGIN
                  IF (@c_XCustomerRefNo = NULL OR @c_XCustomerRefNo = '') 
                     BEGIN
                        BREAK
                     END
               END
   
            IF EXISTS (SELECT 1 FROM StorerConfig (NOLOCK) WHERE (StorerConfig.StorerKey = @c_XStorerkey
                                 AND StorerConfig.ConfigKey = 'ULVITF' AND StorerConfig.sValue = '1'))
            BEGIN
               -- Added by YokeBeen on 19-Nov-2002. (FBR8621)
               IF (@c_XExternKitKey = NULL OR @c_XExternKitKey = '') 
                  BEGIN 
                     IF EXISTS ( SELECT 1 FROM KIT (NOLOCK) WHERE (CustomerRefNo = @c_XCustomerRefNo)
                                    AND (StorerKey = @c_XStorerkey) AND (Type = @c_XRectype) 
                                    AND (UPPER(@c_XRectype) IN ('LABEL')) ) 
                        SELECT @c_XTablename = 'ULVKITLBL'

                     ELSE IF EXISTS ( SELECT 1 FROM KIT (NOLOCK) WHERE (CustomerRefNo = @c_XCustomerRefNo) 
                                          AND (StorerKey = @c_XStorerkey) AND (Type = @c_XRectype) 
                                          AND (UPPER(@c_XRectype) <> ('LABEL')) ) 
                              SELECT @c_XTablename = 'ULVKIT'
                  END
               ELSE
                  BEGIN
                     IF EXISTS ( SELECT 1 FROM KIT (NOLOCK) WHERE (ExternKitKey = @c_XExternKitKey) 
                                    AND (StorerKey = @c_XStorerkey) AND (Type = @c_XRectype) 
                                    AND (UPPER(@c_XRectype) IN ('LABEL')) ) 
                        SELECT @c_XTablename = 'ULVKITLBL'

                     ELSE IF EXISTS ( SELECT 1 FROM KIT (NOLOCK) WHERE (ExternKitKey = @c_XExternKitKey)
                                          AND (StorerKey = @c_XStorerkey) AND (Type = @c_XRectype) 
                                          AND (UPPER(@c_XRectype) <> ('LABEL')) ) 
                              SELECT @c_XTablename = 'ULVKIT'
                  END
   
               IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 (NOLOCK) WHERE TableName IN ('ULVKIT', 'ULVKITLBL')
               AND    Key3 = @c_XKitLineNumber )
               BEGIN
                  SELECT @b_success = 1

                  EXECUTE nspg_getkey
                           'TransmitlogKey2'
                        , 10
                        , @c_trmlogkey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
      
                  IF NOT @b_success = 1
                  BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey2 (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
                  ELSE
                  BEGIN
                     INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3)
                     VALUES (@c_trmlogkey, @c_XTablename, @c_XKitKey , @c_XKitLineNumber, @c_XStorerKey)
      
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain transmitlogkey2 (ntrKitDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END -- if getkey successful
               END -- not exists in transmitlog2
   
            END -- if update to status '9', ULV_INTERFACE
         END -- while
      END -- Update Status
   END -- End - (ULVHK Interface - ispExportKitUIINV)

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,700,02,0,KIT Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END

      Declare @cStatus NVARCHAR(1)

      SELECT @cStatus = Status FROM INSERTED

         UPDATE KIT with (ROWLOCK)
         SET   KIT.OpenQty = KIT.OpenQty - (SELECT SUM(INSERTED.Qty) FROM INSERTED, DELETED
                                                WHERE INSERTED.KitKey = KIT.KitKey
                                                and INSERTED.KitKey = DELETED.KitKey
                                                AND INSERTED.KitLineNumber = DELETED.KitLineNumber -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
                                                AND INSERTED.Type = DELETED.Type -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
                                                AND INSERTED.Status = '9'
                                                AND DELETED.Status <> '9'
                                                AND INSERTED.Type = 'T' -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
                                             ), 
               TrafficCop = NULL, -- SHONG001 
               EditDate = GETDATE(),    --tlting
               EditWho = SUSER_SNAME()
         FROM  KIT, INSERTED, DELETED
         WHERE KIT.KitKey = INSERTED.KitKey
         AND INSERTED.KitKey = DELETED.KitKey
         AND INSERTED.KitLineNumber = DELETED.KitLineNumber -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
         AND INSERTED.Type = DELETED.Type -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
         AND INSERTED.Status = '9'
         AND INSERTED.Type = 'T' -- Added By June 5.Jan.02 (OpenQty x updated Correctly)
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table KIT. (ntrKitDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,700,02,9,KIT Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END
   /* #INCLUDE <TRTDU2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > = @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrKitDetailUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,700,00,9,ntrKitDetailUpdate Trigger                       ,' + CONVERT(char(12), getdate(), 114)
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
         SELECT @profiler = 'PROFILER,700,00,9,ntrKitDetailUpdate Trigger                       ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      RETURN
   END
END


GO