SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ntrTransferDetailAdd                               */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 11-Jun-2002  Leo Ng     Program rewrite for IDS version 5            */
/* 16-Sep-2007  ONG01      Update correct ToLottable01 - 05 when        */
/*                         Status=9 , follow ntrTransferDetailAdd       */
/* 07-May-2014  TKLIM      Added Lottables 06-15                        */
/* 01-Apr-2016  Leong      SOS#367953 - Add ArchiveCop checking.        */
/* 21-Mar-2017  SPChin     IN00294127 - Bug Fixed                       */
/* 21-Jul-2017  TLTING     SET OPTION                                   */
/* 25-Jul-2017  TLTING     Remove SET ROWCOUNT                          */
/* 07-Feb-2016  SWT02      Channel Management                           */
/* 23-JUL-2019  Wan01      WMS-9872 - CN_NIKESDC_Exceed_Channel         */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrTransferDetailAdd]
   ON  [dbo].[TRANSFERDETAIL]
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
      SELECT @profiler = 'PROFILER,699,00,0,ntrTransferDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
      PRINT @profiler
   END
   DECLARE  @b_Success     int       -- Populated by calls to stored procedures - was the proc successful?
   ,        @n_err         int       -- Error number returned by stored procedure OR this trigger
   ,        @n_err2        int       -- For Additional Error Detection
   ,        @c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   ,        @n_continue    int
   ,        @n_starttcnt   int       -- Holds the current transaction count
   ,        @c_preprocess  NVARCHAR(250) -- preprocess
   ,        @c_pstprocess  NVARCHAR(250) -- post process
   ,        @n_cnt         int

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
      /* #INCLUDE <TRTDA1.SQL> */
   DECLARE @n_toqty   int,
      @n_fromqty int
   /*-------------------------------*/
   /* 10.8.99 WALLY       */
   /* ensure that toqty and fromqty */
   /* is equal          */
   /*-------------------------------*/
   -- begin 10.8.99
   /* -- Comment By Shong
   SELECT @n_toqty = INSERTED.toqty, @n_fromqty = INSERTED.fromqty
   FROM INSERTED
   IF @n_toqty <> @n_fromqty
   BEGIN
      SELECT @n_continue = 3, @n_err = 50000
      SELECT @c_errmsg = 'VALIDATION ERROR: ToQty Should Be Equal With FromQty.'
   END
   */
   -- end 10.8.99
   -- IF @n_continue = 1 OR @n_continue = 2
   -- BEGIN

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      SET Lottable01 = TRANSFERDETAIL.TOPACKKEY, TrafficCop = NULL
      FROM inserted ,SKU WITH (NOLOCK)
      WHERE TRANSFERDETAIL.Transferkey = inserted.transferkey
      AND   TRANSFERDETAIL.TransferLineNumber = inserted.transferlinenumber
      AND   INSERTED.TOSTORERKEY = SKU.Storerkey
      AND   INSERTED.TOSKU = SKU.SKU
      AND   SKU.OnReceiptCopyPackKey = '1'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 69904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed on table TRANSFERDETAIL. (ntrTransferDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,01,0,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      DECLARE  @c_TransferPrimaryKey  NVARCHAR(15),
               @c_FromStorerKey        NVARCHAR(15),
               @c_FromSku              NVARCHAR(20),
               @c_FromLoc              NVARCHAR(10),
               @c_FromLot              NVARCHAR(10),
               @c_FromId               NVARCHAR(18),
               -- @n_FromQty             int,
               @c_FromPackKey          NVARCHAR(10),
               @c_FromUOM              NVARCHAR(10),
               @c_ToStorerKey          NVARCHAR(15),
               @c_ToSku                NVARCHAR(20),
               @c_ToLoc                NVARCHAR(10),
               @c_ToLot                NVARCHAR(10),
               @c_ToId                 NVARCHAR(18),
               -- @n_ToQty               int,
               @c_ToPackKey            NVARCHAR(10),
               @c_ToUOM                NVARCHAR(10),
               @c_Lottable01           NVARCHAR(18),
               @c_Lottable02           NVARCHAR(18),
               @c_Lottable03           NVARCHAR(18),
               @d_Lottable04           DATETIME,
               @d_Lottable05           DATETIME,
               @c_Lottable06           NVARCHAR(30),  --IN00294127
               @c_Lottable07           NVARCHAR(30),  --IN00294127
               @c_Lottable08           NVARCHAR(30),  --IN00294127
               @c_Lottable09           NVARCHAR(30),  --IN00294127
               @c_Lottable10           NVARCHAR(30),  --IN00294127
               @c_Lottable11           NVARCHAR(30),  --IN00294127
               @c_Lottable12           NVARCHAR(30),  --IN00294127
               @d_Lottable13           DATETIME,
               @d_Lottable14           DATETIME,
               @d_Lottable15           DATETIME,
               @c_ToLottable01         NVARCHAR(18),   -- ONG01 BEGIN
               @c_ToLottable02         NVARCHAR(18),
               @c_ToLottable03         NVARCHAR(18),
               @d_ToLottable04         DATETIME,
               @d_ToLottable05         DATETIME,   -- ONG01 END
               @c_ToLottable06         NVARCHAR(30),  --IN00294127
               @c_ToLottable07         NVARCHAR(30),  --IN00294127
               @c_ToLottable08         NVARCHAR(30),  --IN00294127
               @c_ToLottable09         NVARCHAR(30),  --IN00294127
               @c_ToLottable10         NVARCHAR(30),  --IN00294127
               @c_ToLottable11         NVARCHAR(30),  --IN00294127
               @c_ToLottable12         NVARCHAR(30),  --IN00294127
               @d_ToLottable13         DATETIME,
               @d_ToLottable14         DATETIME,
               @d_ToLottable15         DATETIME,
               @d_EffectiveDate        DATETIME
            ,  @c_FromChannel         NVARCHAR(20)   = '' -- SWT02
            ,  @n_FromChannel_ID      BIGINT         = 0  -- SWT02      
            ,  @c_ToChannel           NVARCHAR(20)   = '' -- SWT02
            ,  @n_ToChannel_ID        BIGINT         = 0  -- SWT02                     
            ,  @c_FromFacility        NVARCHAR(10)   = ''  -- SWT02                                                              
            ,  @c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- SWT02 
            ,  @c_TransferKey           NVARCHAR(10) = ''  -- SWT02
            ,  @c_TransferLineNumber    NVARCHAR(5)  = ''  -- SWT02

      DECLARE @c_Bondedflag NVARCHAR(1)
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         -- (TLTING02) start
         SELECT @c_Bondedflag = ''
         SELECT @b_Success = 0

         SELECT TOP 1
               @c_FromStorerKey = FromStorerKey,                   
               @c_FromFacility = l.Facility 
         FROM INSERTED 
         JOIN LOC WITH (NOLOCK) ON LOC.LOC = INSERTED.FromLoc, LOC AS l

         EXECUTE nspGetRight
                  NULL,             -- Facility
                  @c_FromStorerKey, -- Storer
                  NULL,             -- Sku
                  'BondLocked',     -- ConfigKey
                  @b_success    OUTPUT,
                  @c_Bondedflag OUTPUT,
                  @n_err        OUTPUT,
                  @c_errmsg     OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Retrieve Failed On GetRight. (ntrTransferDetailAdd)" + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

         --(Wan01) - START            
         -- (SWT02)
         --SET @c_ChannelInventoryMgmt = '0'
         --If @n_continue = 1 or @n_continue = 2
         --BEGIN
         --   SELECT @b_success = 0
         --   Execute nspGetRight 
         --   @c_FromFacility,
         --   @c_FromStorerKey,           -- Storer
         --   '',                     -- Sku
         --   'ChannelInventoryMgmt', -- ConfigKey
         --   @b_success    OUTPUT,
         --   @c_ChannelInventoryMgmt  OUTPUT,
         --   @n_err        OUTPUT,
         --   @c_errmsg     OUTPUT
         --   If @b_success <> 1
         --   BEGIN
         --      SELECT @n_continue = 3
         --      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         --      SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Retrieve Failed On GetRight. (ntrTransferDetailAdd)" 
         --      + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         --   END
         --END
         If @n_continue = 1 or @n_continue = 2
         BEGIN
            IF EXISTS (
                        SELECT 1
                        FROM INSERTED
                        JOIN TRANSFER TFH WITH (NOLOCK) ON INSERTED.Transferkey = TFH.Transferkey
                        CROSS APPLY fnc_SelectGetRight (TFH.Facility, TFH.FromStorerKey, '', 'ChannelInventoryMgmt') SC
                        WHERE SC.Authority = '1' 
                        AND (INSERTED.FromChannel = '' OR INSERTED.FromChannel IS NULL)
                     )
            BEGIN
               SET @n_err = 91006
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Channel Management Turn On, From Channel Not Allow Blank. (ntrTransferDetailAdd)'
               SET @n_continue = 3
            END
         END

         If @n_continue = 1 or @n_continue = 2
         BEGIN
            IF EXISTS (
                        SELECT 1
                        FROM INSERTED
                        JOIN TRANSFER TFH WITH (NOLOCK) ON INSERTED.Transferkey = TFH.Transferkey
                        CROSS APPLY fnc_SelectGetRight (TFH.ToFacility, TFH.ToStorerKey, '', 'ChannelInventoryMgmt') SC
                        WHERE SC.Authority = '1' 
                        AND (INSERTED.ToChannel = '' OR INSERTED.ToChannel IS NULL)
                     )
            BEGIN
               SET @n_err = 91007
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Channel Management Turn On, To Channel Not Allow Blank. (ntrTransferDetailAdd)'
               SET @n_continue = 3
            END
         END
         --(Wan01) - END                
      END
                        
      SELECT @c_TransferPrimaryKey = ' '
      WHILE (1 = 1)
      BEGIN
         SELECT   TOP 1 
                  @c_TransferPrimaryKey     = TransferKey + TransferLineNumber,
                  @c_TransferKey            = TransferKey,
                  @c_TransferLineNumber     = TransferLineNumber,                  
                  @c_FromStorerKey          = FromStorerKey,
                  @c_FromSku                = FromSku,
                  @c_FromLoc                = FromLoc,
                  @c_FromLot                = FromLot,
                  @c_FromId                 = FromId,
                  @n_FromQty                = FromQty,
                  @c_FromPackKey            = FromPackKey,
                  @c_FromUOM                = FromUOM,
                  @c_ToStorerKey            = ToStorerKey,
                  @c_ToSku                  = ToSku,
                  @c_ToLoc                  = ToLoc,
                  @c_ToLot                  = ToLot,
                  @c_ToId                   = ToId,
                  @n_ToQty                  = ToQty,
                  @c_ToPackKey              = ToPackKey,
                  @c_ToUOM                  = ToUOM,
                  @c_Lottable01             = Lottable01,
                  @c_Lottable02             = Lottable02,
                  @c_Lottable03             = Lottable03,
                  @d_Lottable04             = Lottable04,
                  @d_Lottable05             = Lottable05,
                  @c_Lottable06             = Lottable06,
                  @c_Lottable07             = Lottable07,
                  @c_Lottable08             = Lottable08,
                  @c_Lottable09             = Lottable09,
                  @c_Lottable10             = Lottable10,
                  @c_Lottable11             = Lottable11,
                  @c_Lottable12             = Lottable12,
                  @d_Lottable13             = Lottable13,
                  @d_Lottable14             = Lottable14,
                  @d_Lottable15             = Lottable15,
                  @c_ToLottable01           = ToLottable01,   -- ONG01 BEGIN
                  @c_ToLottable02           = ToLottable02,
                  @c_ToLottable03           = ToLottable03,
                  @d_ToLottable04           = ToLottable04,
                  @d_ToLottable05           = ToLottable05,   -- ONG01 END
                  @c_ToLottable06           = ToLottable06,
                  @c_ToLottable07           = ToLottable07,
                  @c_ToLottable08           = ToLottable08,
                  @c_ToLottable09           = ToLottable09,
                  @c_ToLottable10           = ToLottable10,
                  @c_ToLottable11           = ToLottable11,
                  @c_ToLottable12           = ToLottable12,
                  @d_ToLottable13           = ToLottable13,
                  @d_ToLottable14           = ToLottable14,
                  @d_ToLottable15           = ToLottable15,
                  @d_EffectiveDate          = EffectiveDate,
                  @c_FromChannel            = FromChannel,
                  @c_ToChannel              = ToChannel                   
         FROM INSERTED
         WHERE TransferKey + TransferLineNumber > @c_TransferPrimaryKey
         AND Status = '9'
         ORDER BY TransferKey, TransferLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         IF @c_Bondedflag = '1' AND
            EXISTS ( SELECT 1 FROM Inventoryhold WITH (NOLOCK)
                     WHERE Hold = '1'
                     AND Storerkey  = @c_FromStorerKey
                     AND Sku        = @c_FromSku
                     AND lottable02 = @c_lottable02
                     AND LEN(RTRIM(lottable02)) > 0 )
         BEGIN
            SELECT @n_err = 91005
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Bond-locked Stock. Withdrawal Stock not allow. (ntrTransferDetailUpdate)"
            SELECT @n_continue = 3
            BREAK
         END

         --(Wan01) - START
         --IF @c_ChannelInventoryMgmt = '1'
         --BEGIN
         --   IF ISNULL(@c_FromChannel,'') = '' OR        
         --      ISNULL(@c_ToChannel,'') = ''             
         --   BEGIN
         --      SELECT @n_err = 91005
         --      SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Channel Management Turn On, Channel Not Allow Blank. (ntrTransferDetailUpdate)"
         --      SELECT @n_continue = 3
         --      BREAK                
         --   END    
         --END
         --(Wan01) - END
                     
         SET @b_success = 0   -- ONG01

         EXECUTE nspItrnAddWithdrawal
                  @n_ItrnSysId      = NULL,
                  @c_StorerKey      = @c_FromStorerKey,
                  @c_Sku            = @c_FromSku,
                  @c_Lot            = @c_FromLot,
                  @c_ToLoc          = @c_FromLoc,
                  @c_ToID           = @c_FromId,
                  @c_Status         = '',
                  @c_Lottable01     = @c_Lottable01,   -- ONG01 BEGIN
                  @c_Lottable02     = @c_Lottable02,
                  @c_Lottable03     = @c_Lottable03,
                  @d_Lottable04     = @d_Lottable04,
                  @d_Lottable05     = @d_Lottable05,   -- ONG01 END
                  @c_Lottable06     = @c_Lottable06,
                  @c_Lottable07     = @c_Lottable07,
                  @c_Lottable08     = @c_Lottable08,
                  @c_Lottable09     = @c_Lottable09,
                  @c_Lottable10     = @c_Lottable10,
                  @c_Lottable11     = @c_Lottable11,
                  @c_Lottable12     = @c_Lottable12,
                  @d_Lottable13     = @d_Lottable13,
                  @d_Lottable14     = @d_Lottable14,
                  @d_Lottable15     = @d_Lottable15,
                  @c_Channel        = @c_FromChannel, 
                  @n_Channel_ID     = @n_FromChannel_ID OUTPUT,                  
                  @n_casecnt        = 0,
                  @n_innerpack      = 0,
                  @n_Qty            = @n_FromQty,
                  @n_pallet         = 0,
                  @f_cube           = 0,
                  @f_grosswgt       = 0,
                  @f_netwgt         = 0,
                  @f_otherunit1     = 0,
                  @f_otherunit2     = 0,
                  @c_SourceKey      = @c_TransferPrimaryKey,
                  @c_SourceType     = 'ntrTransferDetailAdd',
                  @c_PackKey        = @c_FromPackKey,
                  @c_UOM            = @c_FromUOM,
                  @b_UOMCalc        = 0,
                  @d_EffectiveDate  = @d_EffectiveDate,
                  @c_ItrnKey        = '',
                  @b_Success        = @b_Success OUTPUT,
                  @n_err            = @n_err     OUTPUT,
                  @c_errmsg         = @c_errmsg  OUTPUT
         IF @b_success <> 1
         BEGIN
            IF @b_debug = 1   PRINT '[ntrTransferDetailAdd] nspItrnAddWithdrawal Fail'   -- ONG01a
            SELECT @n_continue = 3
            BREAK
         END
         SET @b_success = 0   -- ONG01
         EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId      = NULL,
                  @c_StorerKey      = @c_ToStorerKey,
                  @c_Sku            = @c_ToSku,
                  @c_Lot            = @c_ToLot,
                  @c_ToLoc          = @c_ToLoc,
                  @c_ToID           = @c_ToId,
                  @c_Status         = '',
                  @c_Lottable01     = @c_ToLottable01,      -- ONG01 BEGIN
                  @c_Lottable02     = @c_ToLottable02,
                  @c_Lottable03     = @c_ToLottable03,
                  @d_Lottable04     = @d_ToLottable04,
                  @d_Lottable05     = @d_ToLottable05,      -- ONG01 END
                  @c_Lottable06     = @c_ToLottable06,
                  @c_Lottable07     = @c_ToLottable07,
                  @c_Lottable08     = @c_ToLottable08,
                  @c_Lottable09     = @c_ToLottable09,
                  @c_Lottable10     = @c_ToLottable10,
                  @c_Lottable11     = @c_ToLottable11,
                  @c_Lottable12     = @c_ToLottable12,
                  @d_Lottable13     = @d_ToLottable13,
                  @d_Lottable14     = @d_ToLottable14,
                  @d_Lottable15     = @d_ToLottable15,
                  @c_Channel        = @c_ToChannel, 
                  @n_Channel_ID     = @n_ToChannel_ID OUTPUT,                  
                  @n_casecnt        = 0,
                  @n_innerpack      = 0,
                  @n_Qty            = @n_ToQty,
                  @n_pallet         = 0,
                  @f_cube           = 0,
                  @f_grosswgt       = 0,
                  @f_netwgt         = 0,
                  @f_otherunit1     = 0,
                  @f_otherunit2     = 0,
                  @c_SourceKey      = @c_TransferPrimaryKey,
                  @c_SourceType     = 'ntrTransferDetailAdd',
                  @c_PackKey        = @c_ToPackKey,
                  @c_UOM            = @c_ToUOM,
                  @b_UOMCalc        = 0,
                  @d_EffectiveDate  = @d_EffectiveDate,
                  @c_ItrnKey        = '',
                  @b_Success        = @b_Success OUTPUT,
                  @n_err            = @n_err     OUTPUT,
                  @c_errmsg         = @c_errmsg  OUTPUT
         IF @b_success <> 1
         BEGIN
            IF @b_debug = 1   PRINT '[ntrTransferDetailAdd] nspItrnAddDeposit Fail'   -- ONG01a
            SELECT @n_continue = 3
            BREAK
         END
         IF @n_continue IN (1,2)
         BEGIN
            UPDATE TRANSFERDETAIL WITH (ROWLOCK) 
            SET FromChannel_ID = @n_FromChannel_ID, 
                  ToChannel_ID  = @n_ToChannel_ID, 
                  TrafficCop = NULL, 
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME() 
            WHERE TransferKey = @c_TransferKey            
               AND TransferLineNumber = @c_TransferLineNumber    
      
         END 
      END

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,01,9,ITRN Process                                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,02,0,TRANSFER Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      DECLARE @n_insertedcount int
      SELECT @n_insertedcount = (select count(*) FROM inserted)
      IF @n_insertedcount = 1
      BEGIN
         UPDATE TRANSFER WITH (ROWLOCK)
         SET  TRANSFER.OpenQty = TRANSFER.OpenQty + INSERTED.FromQty
         FROM TRANSFER,
         INSERTED
         WHERE     TRANSFER.TransferKey = INSERTED.TransferKey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      END
      ELSE
      BEGIN
         UPDATE TRANSFER WITH (ROWLOCK)
         SET TRANSFER.OpenQty   = (Select Sum(TransferDetail.FromQty)
                                 From TransferDetail WITH (NOLOCK)
                                 Where TransferDetail.Transferkey = TRANSFER.Transferkey)
         FROM TRANSFER ,INSERTED
         WHERE TRANSFER.Transferkey IN (Select Distinct Transferkey From Inserted)
         AND TRANSFER.Transferkey = Inserted.Transferkey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      END
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 69901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table TRANSFER. (ntrTransferDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 69902
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Zero rows affected updating table TRANSFER. (ntrTransferDetailAdd)'
      END
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,02,9,TRANSFER Update                                   ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END   -- IF @n_continue = 1 OR @n_continue = 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,03,0,TRANSFER Update for ''POSTED''                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      UPDATE TRANSFER WITH (ROWLOCK)
      SET  TRANSFER.OpenQty = TRANSFER.OpenQty - INSERTED.FromQty
      FROM TRANSFER,
      INSERTED
      WHERE     TRANSFER.TransferKey = INSERTED.TransferKey
      AND INSERTED.Status = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 69903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table TRANSFER. (ntrTransferDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,03,9,TRANSFER Update for ''POSTED''                      ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
   END
   -- END

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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrTransferDetailAdd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,699,00,9,ntrTransferDetailAdd Tigger                       ,' + CONVERT(char(12), getdate(), 114)
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
         SELECT @profiler = 'PROFILER,699,00,9,ntrTransferDetailAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      RETURN
   END
END

GO