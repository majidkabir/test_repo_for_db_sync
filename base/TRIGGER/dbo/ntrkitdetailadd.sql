SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrKitDetailAdd                                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Add Kit Detail Record                                */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 14-June-2006 Vicky         Modify Update OpenQty to cater ManyToMany */
/*                            Kitting                                   */ 
/* 30-May-2007  Shong     Add Checking on TrifficCop and ArchiveCop     */
/* 02-May-2014  Shong         1.1  Added Lottables 06-15                */
/* 27-Nov-2017  Leong         INC0028640 - Cater for <TO> Explode BOM.  */
/*                            [Exceed will delete Type F detail and     */
/*                            insert new Type F detail based on BOM]    */
/* 20-Dec-2018  TLTING01 1.2  missing nolock                            */
/* 19-Jan-2021  Wan01    1.3  WMS-16051 - ANFQHW_Exceed_Channel_Kitting */
/* 25-Feb-2025  SSA01    1.8  UWP-29649 -  Populate PalletType          */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrKitDetailAdd]
ON  [dbo].[KITDETAIL]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT 'INSERTED ', * FROM INSERTED
   END
   ELSE IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = 'PROFILER,888,00,0,ntrKitDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
      PRINT @profiler
   END
   
   DECLARE
   @b_Success             int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err       int       -- Error number returned by stored procedure OR this trigger
   ,         @n_err2      int       -- For Additional Error Detection
   ,         @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   ,         @n_continue   int                 
   ,         @n_starttcnt  int                -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250)         -- preprocess
   ,         @c_pstprocess NVARCHAR(250)         -- post process
   ,         @n_cnt int            

   DECLARE @c_authority_kitting  NVARCHAR(1)
       , @c_kitstorer            NVARCHAR(15)
       , @c_KitKey               NVARCHAR(10) --INC0028640
       , @c_KitType              NVARCHAR(5)  --INC0028640

   --(Wan01) - START
   DECLARE @n_Channel_ID                  BIGINT      = 0   
         , @c_Channel                     NVARCHAR(20)= ''  
         , @c_ChannelInventoryMgmt_From   NVARCHAR(30)= ''  
         , @c_ChannelInventoryMgmt_To     NVARCHAR(30)= ''  
         , @c_Facility                    NVARCHAR(5) = ''
         , @c_KitLineNumber               NVARCHAR(5) = ''
  --(Wan01) - END       
      
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
      /* #INCLUDE <TRTDA1.SQL> */  

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SELECT @n_continue = 4
            
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE KitDetail SET LOTTABLE01 = KitDetail.PACKKEY, TrafficCop = NULL
      FROM  inserted, SKU (NOLOCK)
      WHERE KitDetail.KitKey = inserted.KitKey
      AND   KitDetail.KitLineNumber = inserted.KitLineNumber
      AND   INSERTED.TYPE  = KITDETAIL.TYPE
      AND   INSERTED.StorerKey = SKU.Storerkey
      AND   INSERTED.SKU = SKU.SKU
      AND   SKU.OnReceiptCopyPackKey = '1'
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 88804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed on table KitDetail. (ntrKitDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,01,0,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      DECLARE @c_KitPrimaryKey NVARCHAR(15),
      @c_FromStorerKey       NVARCHAR(15),
      @c_FromSku             NVARCHAR(20),
      @c_FromLoc             NVARCHAR(10),
      @c_FromLot             NVARCHAR(10),
      @c_FromId              NVARCHAR(18),
      @c_FromPackKey         NVARCHAR(10),
      @c_FromUOM             NVARCHAR(10),
      @c_StorerKey           NVARCHAR(15),
      @c_ToSku               NVARCHAR(20),
      @c_ToLoc               NVARCHAR(10),
      @c_ToLot               NVARCHAR(10),
      @c_ToId                NVARCHAR(18),
      @c_ToPackKey           NVARCHAR(10),
      @c_ToUOM               NVARCHAR(10),
      @c_lottable01          NVARCHAR(18),
      @c_lottable02          NVARCHAR(18),
      @c_lottable03          NVARCHAR(18),
      @d_lottable04          datetime,
      @d_lottable05          datetime,
      @c_lottable06          NVARCHAR(30), 
      @c_lottable07          NVARCHAR(30),
      @c_lottable08          NVARCHAR(30),
      @c_lottable09          NVARCHAR(30),
      @c_lottable10          NVARCHAR(30),
      @c_lottable11          NVARCHAR(30),
      @c_lottable12          NVARCHAR(30),
      @d_lottable13          datetime,
      @d_lottable14          datetime,
      @d_lottable15          datetime,        
      @d_EffectiveDate       datetime,
      @n_FromQty             int,
      @n_ToQty               int,
      @c_PalletType             NVARCHAR(10)     --(SSA01)
      SELECT @c_KitPrimaryKey = ' '
      WHILE (1 = 1)
      BEGIN
         SET @n_Channel_ID = 0                     --(Wan01)
         SET @c_Channel = ''                       --(Wan01)
         
         SELECT TOP 1   
               @c_KitPrimaryKey = KitKey + KitLineNumber,
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
         
         --(Wan01) - START
         SELECT @c_KitKey  = LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 10)
         SELECT @c_KitLineNumber = RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 5)
         
         SELECT TOP 1 @c_Facility = Facility
         FROM KIT AS k WITH (NOLOCK)
         WHERE k.KITKey = @c_KitKey
         
         --(Wan01) - START
         SET @c_ChannelInventoryMgmt_From = ''
         SELECT @c_ChannelInventoryMgmt_From = SC.Authority FROM dbo.fnc_SelectGetRight (@c_Facility, @c_FromStorerKey, '', 'ChannelInventoryMgmt') SC
    
         IF @c_ChannelInventoryMgmt_From = '1' AND (@c_Channel = '' OR @c_Channel IS NULL)
         BEGIN
            SET @n_continue = 3
            SET @n_err=88805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
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
                   @c_lottable06 = '',
                   @c_lottable07 = '',
                   @c_lottable08 = '',
                   @c_lottable09 = '',
                   @c_lottable10 = '',
                   @c_lottable11 = '',
                   @c_lottable12 = '',
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
                   @c_SourceType = 'ntrKitDetailAdd',
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
                                                         --  
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END
       
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
               SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Kitdetail fail. (ntrKitDetailAdd)'  
                              + ' ( SQLSvr MESSAGE= ' + @c_errmsg + ' ) '
            END      
         END
         --(Wan01) - END 
      END -- WHILE From
   
      SELECT @c_KitPrimaryKey = ' '
      WHILE (1 = 1) AND @n_continue IN (1,2)             --(Wan01)
      BEGIN 
         SET @n_Channel_ID = 0                           --(Wan01) 
         SET @c_Channel = ''                             --(Wan01) 

         SELECT TOP 1                                    --(Wan01)
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
               @d_EffectiveDate = EffectiveDate,
               @c_PalletType    = PalletType    --(SSA01)
            , @n_Channel_ID     = Channel_ID    --(Wan01)
            , @c_Channel        = Channel       --(Wan01) 
         FROM INSERTED
         WHERE KitKey + KitLineNumber > @c_KitPrimaryKey
         AND Status = '9'
         AND Type = 'T'
         ORDER BY KitKey, KitLineNumber
         IF @@ROWCOUNT = 0
         BEGIN 
            BREAK
         END 

         --(Wan01) - START
         SET @c_KitKey  = LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 10)
         SET @c_KitLineNumber = RIGHT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_KitPrimaryKey)), 5)

         SELECT TOP 1 @c_Facility = Facility
         FROM KIT AS k WITH (NOLOCK)
         WHERE k.KITKey = @c_KitKey
      
         SET @c_ChannelInventoryMgmt_To = ''
         SELECT @c_ChannelInventoryMgmt_To = SC.Authority FROM   dbo.fnc_SelectGetRight (@c_Facility, @c_StorerKey, '', 'ChannelInventoryMgmt') SC
         IF @c_ChannelInventoryMgmt_To = '1' AND (@c_Channel = '' OR @c_Channel IS NULL)
         BEGIN
            SET @n_continue = 3
            SET @n_err=88806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': To Channel Cannot be BLANK. (ntrKitDetailAdd)'   
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
                  @c_PalletType = @c_PalletType,
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @n_err     OUTPUT,
                  @c_errmsg     = @c_errmsg  OUTPUT
               , @n_Channel_ID= @n_Channel_ID OUTPUT  --(Wan01)
               , @c_Channel   = @c_Channel            --(Wan01) 
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            BREAK
         END
 
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
      END -- WHILE

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,01,9,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END

   -- Added By Vicky on 14-June-2006 (Start) 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_kitstorer = ''
           , @c_KitKey    = ''
           , @c_KitType   = ''
           
      SELECT @c_kitstorer = INSERTED.Storerkey
           , @c_KitKey    = INSERTED.KitKey --INC0028640
           , @c_KitType   = INSERTED.[Type] --INC0028640
      FROM  KIT WITH (NOLOCK), INSERTED   --tlting01
      WHERE KIT.KitKey = INSERTED.KitKey
      --AND   INSERTED.Type = 'T'           --INC0028640
   
      SELECT @b_success = 0
      Execute dbo.nspGetRight NULL,
               @c_kitstorer,         -- Storer
               '',                   -- Sku
               'ManyToManyKitting',  -- ConfigKey
               @b_success             OUTPUT,
               @c_authority_kitting   OUTPUT,
               @n_err                 OUTPUT,
               @c_errmsg              OUTPUT
   
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
      End
   END
   -- Added By Vicky on 14-June-2006 (End)

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,02,0,KIT Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      DECLARE @n_insertedcount int

      -- Modified By Vicky on 14-June-2006 (Start)
      IF @c_authority_kitting = '1'
      BEGIN
         IF @c_KitType = 'T' --INC0028640
         BEGIN
            UPDATE KIT WITH (ROWLOCK)
            SET KIT.OpenQty = ( SELECT ISNULL(SUM(KitDetail.ExpectedQty), 0)
                                FROM KitDetail WITH (NOLOCK)
                                WHERE KitDetail.KitKey = KIT.KitKey
                                AND   KitDetail.Type = 'T')
              , KIT.TrafficCop = NULL
            FROM KIT, INSERTED
            WHERE KIT.KitKey = @c_KitKey
            AND KIT.KitKey = INSERTED.KitKey
            AND INSERTED.Type = 'T'
         END
         IF @c_KitType = 'F' --INC0028640
         BEGIN
            UPDATE KIT WITH (ROWLOCK)
            SET KIT.OpenQty = ( SELECT ISNULL(SUM(KitDetail.ExpectedQty), 0)
                                FROM KitDetail WITH (NOLOCK)
                                WHERE KitDetail.KitKey = KIT.KitKey
                                AND   KitDetail.Type = 'T')
              , KIT.TrafficCop = NULL
            FROM KIT, INSERTED
            WHERE KIT.KitKey = @c_KitKey
            AND KIT.KitKey = INSERTED.KitKey
         END

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      END -- @c_authority_kitting = '1'
      ELSE
      BEGIN
         SELECT @n_insertedcount = (select count(1) FROM inserted)
         IF @n_insertedcount = 1
         BEGIN
            UPDATE KIT WITH (ROWLOCK)
            SET   KIT.OpenQty = KIT.OpenQty + INSERTED.ExpectedQty, TrafficCop = NULL
            FROM  KIT, INSERTED
            WHERE KIT.KitKey = INSERTED.KitKey
            AND   INSERTED.Type = 'T'
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         END
   --        ELSE
   --        BEGIN
   --           UPDATE KIT SET KIT.OpenQty
   --           = (Select Sum(KitDetail.ExpectedQty) From KitDetail
   --           Where KitDetail.KitKey = KIT.KitKey
   --           And   KitDetail.Type = 'T')
   --           FROM KIT,INSERTED
   --           WHERE KIT.KitKey IN (Select Distinct KitKey From Inserted)
   --           AND KIT.KitKey = Inserted.KitKey
   --           AND INSERTED.Type = 'T'
   --           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   --       END
      END -- @c_authority_kitting <> '1'
      -- Modified By Vicky on 14-June-2006 (End)
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 88801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table KIT. (ntrKitDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   /*
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 88802
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Zero rows affected updating table KIT. (ntrKitDetailAdd)'
   END
   */
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,02,9,KIT Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,03,0,KIT Update for ''POSTED''                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      UPDATE KIT WITH (ROWLOCK)
      SET   KIT.OpenQty = KIT.OpenQty - INSERTED.Qty, TrafficCop = NULL
      FROM  KIT, INSERTED
      WHERE KIT.KitKey = INSERTED.KitKey
      AND INSERTED.Status = '9'
      AND INSERTED.Type = 'T'
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 88803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table KIT. (ntrKitDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,03,9,KIT Update for ''POSTED''                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END
      /* #INCLUDE <TRTDA2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrKitDetailAdd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,888,00,9,ntrKitDetailAdd Tigger                       ,' + CONVERT(char(12), getdate(), 114)
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
         SELECT @profiler = 'PROFILER,888,00,9,ntrKitDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      RETURN
   END
END

GO