SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************************/
/* Trigger:   ntrTransferDetailUpdate                                                 */
/* Modification History:                                                              */
/*                                                                                    */
/* Date         Author      Ver      Purpose                                          */
/* 06-Nov-2002  Leo Ng               Program rewrite for IDS version 5                */
/*                                   This Trigger will EXECUTE the following Stored   */
/*                                   Procedure for Interface:                         */
/*                                   1. nsp_TransferDetailInterface_OW                */
/*                                   2. nsp_TransferDetailInterface_ALL               */
/*                                   3. nsp_TransferDetailInterface_Lottable03        */
/* 04-Jun-2003  Jeffrey              TBL PIX - Remove checking for Lot AND iD status  */
/* 30-Jun-2003  Shong                SOS# 12050 - Seperate Transfer into 2 diff       */
/*                                   interface for TBL HK, check both 'FROM' AND 'to' */
/*                                   storerkey                                        */
/* 23-Jul-2003  Shong                SOS# 12050 - Added new change request            */
/* 16-Sep-2008  TLTING               SQl2005 use RTRIM and LTRIM  (tlting01)          */
/* 29-Apr-2010  TLTING               SOS162898 - Bond-Lock                            */
/* 28-May-2012  TLTING02             DM integrity - add update editdate Before        */
/*                                   TrafficCop check                                 */
/* 28-Oct-2013  TLTING               Review Editdate column update                    */
/* 07-May-2014  TKLIM                Added Lottables 06-15                            */
/* 07-MAY-2014  YTWan       1.3      Add New RCM to Cancel Transfer in Exceed         */
/*                                   Front end. (Wan01)                               */
/* 16-JUL-2014  ChewKP      1.4      Include @IsRDT check (ChewKP01)                  */
/* 24-NOV-2014  YTWan       1.4      SOS#315609 - Project Merlion - Transfer Release  */
/*                                   Task.(Wan02)                                     */
/* 21-Mar-2017  SPChin      1.5      IN00294127 - Bug Fixed                           */
/* 16-Jun-2017  TLTING      1.6      Remove SETROWCOUNT, missing (NOLOCK)             */
/* 07-Feb-2016  SWT02       1.7      Channel Management                               */
/* 23-JUL-2019  Wan03       1.8      WMS-9872 - CN_NIKESDC_Exceed_Channel             */
/* 23-FEB-2021  Wan04       1.9      WMS-16391 - [CN] ANFQHW_WMS_Transfer Finalize_CR */
/* 12-Aug-2022  Leong       2.0      JSM-86964 Initialize variable.                   */
/* 13-Feb-2025  WLChooi     2.1      UWP-30034 Populate PalletType (WL01)             */
/**************************************************************************************/

CREATE   TRIGGER [dbo].[ntrTransferDetailUpdate]
ON  [dbo].[TRANSFERDETAIL]
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
   IF @b_debug = 1
   BEGIN
      SELECT 'INSERTED ', * FROM INSERTED
      SELECT 'DELETED  ', * FROM DELETED
   END
   ELSE IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = 'PROFILER,700,00,0,ntrTransferDetailUpdate Trigger                    ,' + CONVERT(char(12), GetDate(), 114)
      PRINT @profiler
   END
   DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err        int       -- Error number returned by stored procedure OR this trigger
         , @n_err2       int       -- For Additional Error Detection
         , @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
         , @n_continue   int
         , @n_starttcnt  int       -- Holds the current transaction count
         , @c_preprocess NVARCHAR(250) -- preprocess
         , @c_pstprocess NVARCHAR(250) -- post process
         , @n_cnt        int

         , @c_FrStorerkey     NVARCHAR(15)  --(Wan02)
         , @c_IDTaskRelease   NVARCHAR(10)  --(Wan02)
         , @c_PalletType      NVARCHAR(10) = N''  --WL01

  --(Wan04) - START
         , @c_HoldChannel     NVARCHAR(10)   = ''
         , @c_HoldTRFType     CHAR(1)        = ''

  DECLARE @tSTRCFG  TABLE
         ( Facility           NVARCHAR(5)    NOT NULL DEFAULT('')
         , FromStorerkey      NVARCHAR(15)   NOT NULL DEFAULT('')
         , Configkey          NVARCHAR(30)   NOT NULL DEFAULT('')
         , SValue             NVARCHAR(30)   NOT NULL DEFAULT('')
         )
   --(Wan04) - END
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   -- TLTING02
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
               WHERE INSERTED.Transferkey = DELETED.Transferkey AND INSERTED.TransferLineNumber = DELETED.TransferLineNumber
               AND (( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) OR        --(Wan01)
                    ( INSERTED.[status] = 'CANC' OR DELETED.[status] = 'CANC' ) )   --(Wan01)
              )
         AND ( @n_continue = 1 OR @n_continue = 2 )
         AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE  TRANSFERDETAIL
      SET  EditDate   = GetDate(),
           EditWho    = Suser_Sname(),
           TrafficCop = NULL
      FROM TRANSFERDETAIL, INSERTED, DELETED
      WHERE TRANSFERDETAIL.Transferkey = INSERTED.Transferkey
      AND   TRANSFERDETAIL.TransferLineNumber = INSERTED.TransferLineNumber
      AND   INSERTED.Transferkey = DELETED.Transferkey AND INSERTED.TransferLineNumber = DELETED.TransferLineNumber
      AND  (( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) OR                --(Wan01)
            ( INSERTED.[status] = 'CANC' OR DELETED.[status] = 'CANC' ) )           --(Wan01)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91001   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed ON table TRANSFERDETAIL. (ntrTransferDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   --(Wan01) - START
   IF EXISTS (SELECT 1
              FROM INSERTED WHERE Status = 'CANC'
             )
   BEGIN
      GOTO QUIT_TR
   END
   --(Wan01) - END

   /* #INCLUDE <TRTDU1.SQL> */
   DECLARE @n_toqty   int,
           @n_fromqty int
   /*-------------------------------*/
   /* 10.8.99 WALLY   */
   /* ensure that toqty AND fromqty */
   /* is equal    */
   /*-------------------------------*/
   -- BEGIN 10.8.99
   /*
   SELECT @n_toqty = INSERTED.toqty, @n_fromqty = INSERTED.fromqty
   FROM INSERTED, DELETED
   WHERE INSERTED.transferkey = DELETED.transferkey
   IF @n_toqty <> @n_fromqty
   BEGIN
   SELECT @n_continue = 3, @n_err = 50000
   SELECT @c_errmsg = 'VALIDATION ERROR: ToQty Should Be Equal With FromQty.'
   END
   -- END 10.8.99
   */
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF EXISTS ( SELECT *
                     FROM DELETED
                     WHERE Status = '9' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 91002
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Posted rows may not be edited. (ntrTransferDetailUpdate)'
         END
      END

     --(Wan02) - START
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN

         IF EXISTS ( SELECT 1 FROM INSERTED
                     JOIN DELETED ON (INSERTED.transferkey = DELETED.Transferkey)
                                  AND(INSERTED.Transferlinenumber = DELETED.Transferlinenumber)
                     WHERE INSERTED.Status = DELETED.Status
                     AND INSERTED.Status in ('4', '5')
                   )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 91015
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ID Released Task may not be edited. (ntrTransferDetailUpdate)'
         END
      END
      --(Wan02) - END


      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE TRANSFERDETAIL
            SET LOTTABLE01 = TRANSFERDETAIL.TOPACKKEY, TrafficCop = NULL
         FROM inserted,SKU with (NOLOCK)
         WHERE TRANSFERDETAIL.Transferkey = inserted.transferkey
         AND   TRANSFERDETAIL.TransferLineNumber = inserted.transferlinenumber
         AND   INSERTED.TOSTORERKEY = SKU.Storerkey
         AND   INSERTED.TOSKU = SKU.SKU
         AND   SKU.OnReceiptCopyPackKey = '1'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91003   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update failed ON table TRANSFERDETAIL. (ntrTransferDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,01,0,ITRN Process                                      ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END

         DECLARE @c_TransferPrimaryKey NVARCHAR(15),
                  @c_FromStorerKey       NVARCHAR(15),
                  @c_FromSku             NVARCHAR(20),
                  @c_FromLoc             NVARCHAR(10),
                  @c_FromLot             NVARCHAR(10),
                  @c_FromId              NVARCHAR(18),
                  -- @n_FromQty             int,
                  @c_FromPackKey         NVARCHAR(10),
                  @c_FromUOM             NVARCHAR(10),
                  @c_ToStorerKey         NVARCHAR(15),
                  @c_ToSku               NVARCHAR(20),
                  @c_ToLoc               NVARCHAR(10),
                  @c_ToLot               NVARCHAR(10),
                  @c_ToId                NVARCHAR(18),
                  -- @n_ToQty               int,
                  @c_ToPackKey           NVARCHAR(10),
                  @c_ToUOM               NVARCHAR(10),
                  @c_lottable01          NVARCHAR(18),
                  @c_lottable02          NVARCHAR(18),
                  @c_lottable03          NVARCHAR(18),
                  @d_lottable04          datetime,
                  @d_lottable05          datetime,
                  @c_Lottable06          NVARCHAR(30),   --IN00294127
                  @c_Lottable07          NVARCHAR(30),   --IN00294127
                  @c_Lottable08          NVARCHAR(30),   --IN00294127
                  @c_Lottable09          NVARCHAR(30),   --IN00294127
                  @c_Lottable10          NVARCHAR(30),   --IN00294127
                  @c_Lottable11          NVARCHAR(30),   --IN00294127
                  @c_Lottable12          NVARCHAR(30),   --IN00294127
                  @d_Lottable13          DATETIME,
                  @d_Lottable14          DATETIME,
                  @d_Lottable15          DATETIME,
                  @d_EffectiveDate       datetime,
                  @c_tolottable01        NVARCHAR(18),
                  @c_tolottable02        NVARCHAR(18),
                  @c_tolottable03        NVARCHAR(18),
                  @d_tolottable04        datetime,
                  @d_tolottable05        datetime,
                  @c_ToLottable06        NVARCHAR(30),   --IN00294127
                  @c_ToLottable07        NVARCHAR(30),   --IN00294127
                  @c_ToLottable08        NVARCHAR(30),   --IN00294127
                  @c_ToLottable09        NVARCHAR(30),   --IN00294127
                  @c_ToLottable10        NVARCHAR(30),   --IN00294127
                  @c_ToLottable11        NVARCHAR(30),   --IN00294127
                  @c_ToLottable12        NVARCHAR(30),   --IN00294127
                  @d_ToLottable13        DATETIME,
                  @d_ToLottable14        DATETIME,
                  @d_ToLottable15        DATETIME
               ,  @c_FromChannel         NVARCHAR(20)   = '' -- SWT02
               ,  @n_FromChannel_ID      BIGINT         = 0  -- SWT02
               ,  @c_ToChannel           NVARCHAR(20)   = '' -- SWT02
               ,  @n_ToChannel_ID        BIGINT         = 0  -- SWT02
               ,  @c_FromFacility        NVARCHAR(10)   = ''
               ,  @c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- (SWT02)
               ,  @c_TransferKey           NVARCHAR(10) = ''
               ,  @c_TransferLineNumber    NVARCHAR(5)  = ''

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
               SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Retrieve Failed On GetRight. (ntrTransferDetailUpdate)" + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END
            --(Wan03) - START
            -- (SWT02)
            --SET @c_ChannelInventoryMgmt = '0'
            --If @n_continue = 1 or @n_continue = 2
            --BEGIN
            --   SELECT @b_success = 0
            --   Execute nspGetRight2    --(Wan03)
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
            --     SELECT @n_continue = 3
            --     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            --     SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Retrieve Failed On GetRight. (ntrTransferDetailUpdate)"
            --     + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Channel Management Turn On, From Channel Not Allow Blank. (ntrTransferDetailUpdate)'
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
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Channel Management Turn On, To Channel Not Allow Blank. (ntrTransferDetailUpdate)'
               SET @n_continue = 3
            END
         END
         --(Wan03) - END

         --(Wan04) - START
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            INSERT INTO @tSTRCFG ( Facility, FromStorerkey, Configkey, SValue )
            SELECT TFH.Facility, TFH.FromStorerKey, 'TRFAllocHoldChannel', SC.Authority
            FROM INSERTED
            JOIN [TRANSFER] TFH WITH (NOLOCK) ON INSERTED.Transferkey = TFH.Transferkey
            CROSS APPLY fnc_SelectGetRight (TFH.Facility, TFH.FromStorerKey, '', 'TRFAllocHoldChannel') SC
            WHERE SC.Authority = '1'
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM INSERTED i
                        JOIN DELETED  d ON  i.Transferkey = d.Transferkey
                                        AND i.TransferLineNumber = d.TransferLineNumber
                        JOIN [TRANSFER] AS t WITH (NOLOCK) ON i.Transferkey = t.TransferKey
                        JOIN @tSTRCFG SC ON t.Facility = SC.Facility AND SC.FromStorerkey = t.FromStorerKey
                                         AND SC.Configkey = 'TRFAllocHoldChannel'
                        WHERE d.FromChannel_ID > 0
                        AND i.FromQty <> d.FromQty
                        AND i.[status] < '9'
                        AND SC.SValue = '1'
                        AND EXISTS (SELECT 1
                                    FROM ChannelInvHold AS cih WITH (NOLOCK)
                                    JOIN ChannelInvHoldDetail AS cihd WITH (NOLOCK) ON  cihd.InvHoldkey = cih.InvHoldkey
                                    WHERE cih.HoldType = 'TRF'
                                    AND cih.Sourcekey = d.TransferKey
                                    AND cihd.SourceLineNo = d.TransferLineNumber
                                    AND CIHD.Channel_ID = d.FromChannel_ID
                                    AND cihd.Hold = '1'
                                   )
                        )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 91013
               SET @c_errmsg  = CONVERT(char(5),@n_err)+': From Channel ID is hold by Transfer Line. Reject to change From Qty. (ntrTransferDetailUpdate)'
            END
         END
         --(Wan04) - END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_TransferPrimaryKey = ' '
            WHILE (1 = 1) AND @n_continue IN (1,2)       --(Wan04)
            BEGIN
               SELECT TOP 1
                        @c_TransferPrimaryKey     = TransferKey + TransferLineNumber,
                        @c_TransferKey            = TransferKey, -- (SWT02)
                        @c_TransferLineNumber     = TransferLineNumber, -- (SWT02)
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
                        @c_lottable01             = lottable01,
                        @c_lottable02             = lottable02,
                        @c_lottable03             = lottable03,
                        @d_lottable04             = lottable04,
                        @d_lottable05             = lottable05,
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
                        @d_EffectiveDate          = EffectiveDate,
                        @c_tolottable01           = tolottable01,
                        @c_tolottable02           = tolottable02,
                        @c_tolottable03           = tolottable03,
                        @d_tolottable04           = tolottable04,
                        @d_tolottable05           = tolottable05,
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
                        @c_FromChannel            = FromChannel, -- (SWT02)
                        @c_ToChannel              = ToChannel    -- (SWT02)
                     ,  @n_FromChannel_ID         = FromChannel_ID --(Wan04)
               FROM INSERTED
               WHERE TransferKey + TransferLineNumber > @c_TransferPrimaryKey
               AND Status = '9'
               ORDER BY TransferKey, TransferLineNumber

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               -- (TLTING02) start
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
               --      GOTO QUIT_TR
               --   END
               --END
               --(Wan01) - END

               --(Wan04) - START
               ---------------------------------------------------------------------------------
               -- Release From Channel Hold that was hold at transfer allocation process (START)
               ---------------------------------------------------------------------------------
               SELECT @c_FromFacility = t.Facility
               FROM [TRANSFER] AS t WITH (NOLOCK)
               WHERE t.TransferKey = @c_TransferKey

               IF EXISTS ( SELECT 1 FROM @tSTRCFG AS ts
                           WHERE ts.Facility = @c_FromFacility AND ts.FromStorerkey = ts.FromStorerkey
                           AND ts.Configkey = 'TRFAllocHoldChannel' AND ts.SValue = '1'
               )
               BEGIN
                  IF @n_FromChannel_ID > 0 AND
                     EXISTS ( SELECT 1
                              FROM ChannelInvHold AS cih WITH (NOLOCK)
                              JOIN ChannelInvHoldDetail AS cihd WITH (NOLOCK) ON  cihd.InvHoldkey = cih.InvHoldkey
                              WHERE cih.HoldType = 'TRF'
                              AND cih.Sourcekey = @c_TransferKey
                              AND cihd.SourceLineNo = @c_TransferLineNumber
                              AND CIHD.Channel_ID = @n_FromChannel_ID
                              AND cihd.Hold = '1'
                              )
                  BEGIN
                     SET @c_HoldTRFType = 'F'
                     SET @c_HoldChannel = '0'
                     EXEC isp_ChannelInvHoldWrapper
                          @c_HoldType     = 'TRF'
                        , @c_SourceKey    = @c_Transferkey
                        , @c_SourceLineNo = @c_TransferLineNumber
                        , @c_Facility     = ''
                        , @c_Storerkey    = ''
                        , @c_Sku          = ''
                        , @c_Channel      = ''
                        , @c_C_Attribute01= ''
                        , @c_C_Attribute02= ''
                        , @c_C_Attribute03= ''
                        , @c_C_Attribute04= ''
                        , @c_C_Attribute05= ''
                        , @n_Channel_ID   = 0
                        , @c_Hold         = @c_HoldChannel
                        , @c_Remarks      = ''
                        , @c_HoldTRFType  = @c_HoldTRFType
                        , @n_DelQty       = 0
                        , @n_QtyHoldToAdj = 0
                        , @n_ChannelTran_ID_Ref = 0
                        , @b_Success      = @b_Success   OUTPUT
                        , @n_Err          = @n_Err       OUTPUT
                        , @c_ErrMsg       = @c_ErrMsg    OUTPUT

                     IF @b_Success = 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 91014
                        SET @c_errmsg  = CONVERT(char(5),@n_err)+': Error Executing isp_ChannelInvHoldWrapper. (ntrTransferDetailUpdate)'
                        BREAK
                     END
                  END
               END
               ---------------------------------------------------------------------------------
               -- Release From Channel Hold that was hold at transfer allocation process (END)
               ---------------------------------------------------------------------------------
               --(Wan04) - END

               EXECUTE nspItrnAddWithdrawal
                        @n_ItrnSysId  = NULL,
                        @c_StorerKey  = @c_FromStorerKey,
                        @c_Sku        = @c_FromSku,
                        @c_Lot        = @c_FromLot,
                        @c_ToLoc      = @c_FromLoc,
                        @c_ToID       = @c_FromId,
                        @c_Status     = '',
                        @c_lottable01 = @c_lottable01,
                        @c_lottable02 = @c_lottable02,
                        @c_lottable03 = @c_lottable03,
                        @d_lottable04 = @d_lottable04,
                        @d_lottable05 = @d_lottable05,
                        @c_Lottable06 = @c_Lottable06,
                        @c_Lottable07 = @c_Lottable07,
                        @c_Lottable08 = @c_Lottable08,
                        @c_Lottable09 = @c_Lottable09,
                        @c_Lottable10 = @c_Lottable10,
                        @c_Lottable11 = @c_Lottable11,
                        @c_Lottable12 = @c_Lottable12,
                        @d_Lottable13 = @d_Lottable13,
                        @d_Lottable14 = @d_Lottable14,
                        @d_Lottable15 = @d_Lottable15,
                        @c_Channel    = @c_FromChannel,
                        @n_Channel_ID = @n_FromChannel_ID OUTPUT,
                        @n_casecnt    = 0,
                        @n_innerpack  = 0,
                        @n_Qty        = @n_FromQty,
                        @n_pallet     = 0,
                        @f_cube       = 0,
                        @f_grosswgt   = 0,
                        @f_netwgt     = 0,
                        @f_otherunit1 = 0,
                        @f_otherunit2 = 0,
                        @c_SourceKey  = @c_TransferPrimaryKey,
                        @c_SourceType = 'ntrTransferDetailUpdate',
                        @c_PackKey    = @c_FromPackKey,
                        @c_UOM        = @c_FromUOM,
                        @b_UOMCalc    = 0,
                        @d_EffectiveDate = @d_EffectiveDate,
                        @c_ItrnKey    = '',
                        @b_Success    = @b_Success OUTPUT,
                        @n_err        = @n_err     OUTPUT,
                        @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  BREAK
               END

               --WL01 S
               SET @c_PalletType = N''
               SELECT @c_PalletType = ISNULL(ID.PalletType, '')
               FROM ID WITH (NOLOCK)
               WHERE ID.ID = @c_ToID
               --WL01 E

               SET @n_ToChannel_ID = 0 -- JSM-86964
               EXECUTE nspItrnAddDeposit
                        @n_ItrnSysId  = NULL,
                        @c_StorerKey  = @c_ToStorerKey,
                        @c_Sku        = @c_ToSku,
                        @c_Lot        = @c_ToLot,
                        @c_ToLoc      = @c_ToLoc,
                        @c_ToID       = @c_ToId,
                        @c_Status     = '',
                        @c_lottable01 = @c_tolottable01,
                        @c_lottable02 = @c_tolottable02,
                        @c_lottable03 = @c_tolottable03,
                        @d_lottable04 = @d_tolottable04,
                        @d_lottable05 = @d_tolottable05,
                        @c_Lottable06 = @c_ToLottable06,
                        @c_Lottable07 = @c_ToLottable07,
                        @c_Lottable08 = @c_ToLottable08,
                        @c_Lottable09 = @c_ToLottable09,
                        @c_Lottable10 = @c_ToLottable10,
                        @c_Lottable11 = @c_ToLottable11,
                        @c_Lottable12 = @c_ToLottable12,
                        @d_Lottable13 = @d_ToLottable13,
                        @d_Lottable14 = @d_ToLottable14,
                        @d_Lottable15 = @d_ToLottable15,
                        @c_Channel    = @c_ToChannel,
                        @n_Channel_ID = @n_ToChannel_ID OUTPUT,
                        @n_casecnt    = 0,
                        @n_innerpack  = 0,
                        @n_Qty        = @n_ToQty,
                        @n_pallet     = 0,
                        @f_cube       = 0,
                        @f_grosswgt   = 0,
                        @f_netwgt     = 0,
                        @f_otherunit1 = 0,
                        @f_otherunit2 = 0,
                        @c_SourceKey  = @c_TransferPrimaryKey,
                        @c_SourceType = 'ntrTransferDetailUpdate',
                        @c_PackKey    = @c_ToPackKey,
                        @c_UOM        = @c_ToUOM,
                        @b_UOMCalc    = 0,
                        @d_EffectiveDate = @d_EffectiveDate,
                        @c_ItrnKey    = '',
                        @c_PalletType = @c_PalletType,   --WL01
                        @b_Success    = @b_Success OUTPUT,
                        @n_err        = @n_err     OUTPUT,
                        @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
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
            END -- WHILE (1 = 1)
         END

         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,01,9,ITRN Process                                      ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END
      END --  IF @n_continue = 1 OR @n_continue = 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,02,0,TRANSFER Update                                   ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END

         DECLARE @n_deletedcount int
         SELECT @n_deletedcount = (SELECT count(*) FROM deleted)
         IF @n_deletedcount = 1
         BEGIN
            UPDATE TRANSFER
            SET  TRANSFER.OpenQty = TRANSFER.OpenQty - DELETED.FromQty + INSERTED.FromQty,
                 EditDate = GETDATE(),   --tlting
                 EditWho = SUSER_SNAME()
            FROM TRANSFER,
            INSERTED,
            DELETED
            WHERE     TRANSFER.TransferKey = INSERTED.TransferKey
            AND  INSERTED.TransferKey = DELETED.TransferKey
         END
         ELSE
         BEGIN
            UPDATE TRANSFER SET TRANSFER.OpenQty
            = (TRANSFER.Openqty
            -
            (SELECT Sum(DELETED.FromQty) FROM DELETED
            WHERE DELETED.Transferkey = TRANSFER.Transferkey)
            +
            (SELECT Sum(INSERTED.FromQty) FROM INSERTED
            WHERE INSERTED.Transferkey = TRANSFER.Transferkey)
            ),
            EditDate = GETDATE(),   --tlting
            EditWho = SUSER_SNAME()
            FROM TRANSFER,DELETED,INSERTED
            WHERE TRANSFER.Transferkey IN (SELECT Distinct Transferkey FROM DELETED)
            AND TRANSFER.Transferkey = DELETED.Transferkey
            AND TRANSFER.Transferkey = INSERTED.Transferkey
            AND INSERTED.Transferkey = DELETED.Transferkey
            AND INSERTED.TransferLineNumber = DELETED.TransferLineNumber
         END

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91006   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed ON table TRANSFER. (ntrTransferDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         ELSE IF @n_cnt = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 91007
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Zero rows affected updating table TRANSFER. (ntrTransferDetailUpdate)'
         END

         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,02,9,TRANSFER Update                                   ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,03,0,TRANSFER Update for ''POSTED''                      ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END

         UPDATE TRANSFER
         SET  TRANSFER.OpenQty = TRANSFER.OpenQty - INSERTED.FromQty,
               EditDate = GETDATE(),   --tlting
               EditWho = SUSER_SNAME()
         FROM TRANSFER,
         INSERTED,
         DELETED
         WHERE TRANSFER.TransferKey = INSERTED.TransferKey
         AND  INSERTED.TransferKey = DELETED.TransferKey
         AND  INSERTED.Status = '9'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 91008   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed ON table TRANSFER. (ntrTransferDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,03,9,TRANSFER Update for ''POSTED''                      ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END
      END
   END
   /* #INCLUDE <TRTDU2.SQL> */
   ---------------------------------------------------------------------------
   /* IDSV5 - Leo */
   /* Modification - to add records in transmitlog */

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_trmlogkey   NVARCHAR(10), @c_transmitlogkey NVARCHAR(10)
      DECLARE @c_PrimaryKey  NVARCHAR(15), @c_StorerKey NVARCHAR(15), @c_Type NVARCHAR(10), @c_authority NVARCHAR(1)
      DECLARE @c_FrLocFlag   NVARCHAR(10), @c_ToLocFlag NVARCHAR(10), @c_ulpitf NVARCHAR(1)
      -- for tblhk
      DECLARE @c_TBLHKITF NVARCHAR(1)
      DECLARE @nSKUFlag int, @n_frFlag int, @n_ToFlag int, @nStorerFlag int
      -- Added By SHONG ON 30-06-2003
      DECLARE @c_DP_StorerKey NVARCHAR(15),
             @c_DP_TBLHKITF  NVARCHAR(1),
             @c_CustomerRef  NVARCHAR(20)

      -- Get Storer Configuration -- One World Interface
      -- Is One World Interface Turn ON?

      IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.STATUS = '9')
      BEGIN
         SELECT @c_PrimaryKey = SPACE(15)
         WHILE 1=1
         BEGIN

            SELECT TOP 1 @c_PrimaryKey = INSERTED.TransferKey + INSERTED.TransferLineNumber,
                  @c_transferkey = INSERTED.TransferKey,
                  @c_transferlinenumber = INSERTED.TransferLineNumber,
                  @c_Type = TRANSFER.Type,
                  @c_StorerKey = TRANSFER.FromStorerKey,
                  @c_lottable03 = INSERTED.lottable03,
                  @c_tolottable03 = INSERTED.tolottable03,
                  -- Added By SHONG ON 30th Jun 2003
                  @c_DP_StorerKey  = TRANSFER.ToStorerKey,
                  @c_CustomerRef   = TRANSFER.CustomerRefNo
                  -- END add by SHONG
            FROM   INSERTED, DELETED, TRANSFER (NOLOCK)
            WHERE  INSERTED.TransferKey + INSERTED.TransferLineNumber > @c_PrimaryKey
            AND    INSERTED.TransferKey = DELETED.TransferKey
            AND    INSERTED.TransferLineNumber = DELETED.TransferLineNumber
            AND    INSERTED.Status = '9'
            AND    DELETED.Status <> '9'
            AND    TRANSFER.TransferKey = INSERTED.TransferKey
            Order by INSERTED.TransferKey, INSERTED.TransferLineNumber
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            EXECUTE nspGetRight NULL,         -- Facility
                     @c_storerkey, -- Storer
                     NULL,         -- Sku
                     'ULPITF',      -- ConfigKey
                     @b_success    OUTPUT,
                     @c_ulpitf     OUTPUT,
                     @n_err        OUTPUT,
                     @c_errmsg     OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
               BREAK
            END
            ELSE
            BEGIN
               IF @c_ulpitf = '1'
               BEGIN
                  IF EXISTS( SELECT 1 FROM CODELKUP (NOLOCK) WHERE CODELKUP.Code = @c_type AND
                             CODELKUP.ListName = N'TRANTYPE' AND
                             CODELKUP.LONG = 'IWT')
                  BEGIN
                     -- wally 7.nov.2002
                     -- use codelkup.short to determine IF a move is FROM allocatable to un-allocatable OR vice-versa
                     SELECT @c_frlocflag = c1.short,
                            @c_tolocflag = c2.short
                     FROM inserted JOIN codelkup c1 (NOLOCK)
                     ON inserted.lottable03 = c1.code
                     AND c1.listname = N'LOGICALWH'
                     JOIN codelkup c2 (NOLOCK)
                     ON inserted.tolottable03 = c2.code
                     AND c2.listname = N'LOGICALWH'
                     WHERE transferkey = @c_transferkey
                     AND transferlinenumber = @c_transferlinenumber

                     IF (@c_FrLocFlag <> @c_ToLocFlag)
                     BEGIN
                        IF NOT EXISTS( SELECT 1 FROM TRANSMITLOG (NOLOCK) WHERE TableName = N'ULPTRF' AND KEY1 = @c_transferkey
                                       AND Key2 = @c_transferlinenumber
                                       AND Key3 = dbo.fnc_LTrim(@c_frlocflag) + dbo.fnc_LTrim(@c_tolocflag)) -- put in the 'location code'
                                                  -- tlting01 , use LTRIM and RTRIM
                        BEGIN
                           SELECT @b_success = 1
                           EXECUTE nspg_getkey
                                 'transmitlogkey'
                                 , 10
                                 , @c_trmlogkey OUTPUT
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                           IF NOT @b_success = 1
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=91009   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrTransferHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                           END
                           ELSE
                           BEGIN
                              INSERT INTO transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                              VALUES (@c_trmlogkey, 'ULPTRF', @c_transferkey , @c_transferlinenumber, dbo.fnc_LTrim(@c_frlocflag) + dbo.fnc_LTrim(@c_tolocflag), '0')

                              SELECT @n_err = @@ERROR
                              IF @n_err <> 0
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=91010   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrTransferHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                              END
                           END -- success = 1
                        END -- not exists in transmitlog
                     END -- allocatable to unallocatable loc OR vice versa
                  END -- this trantype need to interface back
               END -- ULP interface turn ON
            END

            /* IDSV5 - Leo - OW Interface */
            EXECUTE nspGetRight NULL,         -- Facility
                              @c_storerkey, -- Storer
                              NULL,         -- Sku
                              -- SOS13577 - Change this flag back to 'OWITF'
                              -- 'TRANSFERDTL INTERFACE - OW', -- ConfigKey
                              'OWITF',      -- ConfigKey
                              @b_success    OUTPUT,
                              @c_authority  OUTPUT,
                              @n_err        OUTPUT,
                @c_errmsg     OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
               BREAK
            END
            ELSE
            BEGIN
               IF @c_authority = '1'
               BEGIN
                  EXECUTE nsp_TransferDetailInterface_OW
                           @c_transferkey,
                           @c_transferlinenumber,
                           @c_type,
                           @b_success OUTPUT,
                           @n_err     OUTPUT,
                           @c_errmsg  OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                     BREAK
                  END
               END -- OW interface turn ON
            END -- Getright OK
            /* IDSV5 - Leo - OW Interface */

          /* IDSV5 - Leo - ALL (TW version) Interface */
          EXECUTE nspGetRight NULL,         -- Facility
                              @c_storerkey, -- Storer
                              NULL,         -- Sku
                              'TRANSFERDTL INTERFACE - ALL',      -- ConfigKey
                              @b_success    OUTPUT,
                              @c_authority  OUTPUT,
                              @n_err        OUTPUT,
                              @c_errmsg     OUTPUT
          IF @b_success <> 1
          BEGIN
             SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
             BREAK
          END
          ELSE
          BEGIN
             IF @c_authority = '1'
             BEGIN
                EXECUTE nsp_TransferDetailInterface_ALL
                        @c_transferkey,
                        @c_transferlinenumber,
                        @c_type,
                        @b_success OUTPUT,
                        @n_err     OUTPUT,
                        @c_errmsg  OUTPUT
                IF @b_success <> 1
                BEGIN
                  SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                  BREAK
                END
             END -- OW interface turn ON
          END -- Getright OK
          /* IDSV5 - Leo - ALL Interface */

          /* IDSV5 - Leo - IF Lottable03 changed */
          IF @c_lottable03 <> @c_tolottable03
          BEGIN
             EXECUTE nspGetRight NULL,         -- Facility
                                 @c_storerkey, -- Storer
                                 NULL,         -- Sku
                                 'TRANSFERDTL INTERFACE - LOT3',      -- ConfigKey
                                 @b_success    OUTPUT,
                                 @c_authority  OUTPUT,
                                 @n_err        OUTPUT,
                                 @c_errmsg     OUTPUT
             IF @b_success <> 1
             BEGIN
                SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                BREAK
             END
             ELSE
             BEGIN
                IF @c_authority = '1'
                BEGIN
                   EXECUTE nsp_TransferDetailInterface_Lottable03
                           @c_transferkey,
                           @c_transferlinenumber,
                           @c_type,
                           @b_success OUTPUT,
                           @n_err     OUTPUT,
                           @c_errmsg  OUTPUT
                   IF @b_success <> 1
                   BEGIN
                      SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                      BREAK
                   END
                END -- OW interface turn ON
             END -- Getright OK
         END
          /* IDSV5 - Leo - IF Lottable03 changed */
          /* IDSV5 - Leo - ALL Interface */

         -- Modify by SHONG ON 30th Jun 2003
         -- SOS# 12050
         -- TBLHK
         SELECT @c_TBLHKITF = '0'

         EXECUTE nspGetRight NULL,  -- facility
                  @c_storerkey,     -- Storerkey
                  NULL,             -- Sku
                  'TBLHKITF',       -- Configkey
                  @b_success  OUTPUT,
                  @c_TBLHKITF OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferdetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
            BREAK
         END
         ELSE
         BEGIN
            EXECUTE nspGetRight NULL, -- facility
                  @c_DP_Storerkey,    -- Storerkey
                  NULL,               -- Sku
                  'TBLHKITF',         -- Configkey
                  @b_success OUTPUT,
                  @c_DP_TBLHKITF OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = 'ntrTransferdetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
               BREAK
            END
            ELSE
            BEGIN
               IF @c_TBLHKITF = '1' OR @c_DP_TBLHKITF = '1'
               BEGIN
                  IF NOT EXISTS (SELECT RECEIPTKEY FROM RECEIPT (NOLOCK) WHERE ReceiptKey = @c_CustomerRef)
                  BEGIN
                     -- modified by Jeff.
                     SELECT  @n_FrFlag = CASE WHEN FrLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1
                                              WHEN FrLoc.Status = 'HOLD' THEN 1
                                         ELSE 0
                                         END
                           , @n_ToFlag = CASE WHEN ToLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1
                                              WHEN ToLoc.Status = 'HOLD' THEN 1
                                         ELSE 0
                                         END
                           , @nSKUFlag = CASE WHEN INSERTED.FromSKU <> INSERTED.ToSKU THEN 1
                                         ELSE 0
                                         END
                           , @nStorerFlag = CASE WHEN INSERTED.FromStorerkey <> INSERTED.ToStorerkey THEN 1
                                            ELSE 0
                                            END
                     FROM TRANSFER (NOLOCK), INSERTED , DELETED,  LOC FrLoc (NOLOCK), LOC ToLoc (NOLOCK)
                     WHERE INSERTED.Transferkey = DELETED.Transferkey
                     AND INSERTED.Transferlinenumber = DELETED.Transferlinenumber
                     AND TRANSFER.Transferkey = INSERTED.Transferkey
                     AND INSERTED.FromLoc = FrLoc.Loc
                     AND INSERTED.ToLoc = ToLoc.Loc
                     AND TRANSFER.CustomerRefNo NOT IN (SELECT RECEIPTKEY FROM RECEIPT (NOLOCK))
                     AND INSERTED.Transferkey = @c_transferkey
                     AND INSERTED.Transferlinenumber = @c_transferlinenumber
                     AND INSERTED.Status = '9'
                     GROUP BY FrLoc.Locationflag, ToLoc.Locationflag, FrLoc.Status, ToLoc.Status,
                     INSERTED.TransferLineNumber, INSERTED.FromSKU, INSERTED.TOSku, INSERTED.FromStorerkey,
                     INSERTED.ToStorerkey

                     IF @@ROWCOUNT = 0
                     BEGIN
                        BREAK
                     END

                     IF (@nSKUFlag = 1) OR (@n_FrFlag <> @n_ToFlag ) OR (@nStorerFlag = 1)
                     BEGIN
                        IF @c_TBLHKITF = '1'
                        BEGIN
                           IF NOT EXISTS (SELECT 1 FROM transmitlog2 (NOLOCK) WHERE key1 = @c_transferkey AND Key2 = @c_transferlinenumber
                                          AND Key3 = N'WD' AND TABLENAME = N'TBLREGTRF')
                           BEGIN
                              SELECT @b_success = 1
                              EXECUTE nspg_getkey
                                       'transmitlogkey2'  -- Modified by YokeBeen ON 26-Apr-2003
                                       , 10
                                       , @c_trmlogkey OUTPUT
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                              IF NOT @b_success = 1
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = convert(char(250),@n_err), @n_err=91011   -- should be SET to the sql errmessage but i don't know how to do so.
                                 SELECT @c_errmsg = 'nsql' + convert(char(5),@n_err) + ': Unable To Obtain Transmitlogkey. (ntrReceiptHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                              END
                              ELSE
                              BEGIN
                                 INSERT transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                                 VALUES (@c_trmlogkey, 'TBLREGTRF', @c_transferkey, @c_transferlinenumber, 'WD','0')
                              END
                           END -- not exists
                        END -- tblhkitf = '1'
                        IF @c_DP_TBLHKITF = '1'
                        BEGIN
                           IF NOT EXISTS (SELECT 1 FROM transmitlog2 (NOLOCK) WHERE key1 = @c_transferkey AND Key2 = @c_transferlinenumber
                                          AND Key3 = 'DP' AND TABLENAME = 'TBLREGTRF')
                           BEGIN
                              SELECT @b_success = 1
                              EXECUTE nspg_getkey
                                    'transmitlogkey2'  -- Modified by YokeBeen ON 26-Apr-2003
                                    , 10
                                    , @c_trmlogkey OUTPUT
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT
                              IF NOT @b_success = 1
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = convert(char(250),@n_err), @n_err=91012   -- should be SET to the sql errmessage but i don't know how to do so.
                                 SELECT @c_errmsg = 'nsql' + convert(char(5),@n_err) + ': Unable To Obtain Transmitlogkey. (ntrReceiptHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                              END
                              ELSE
                              BEGIN
                                 INSERT transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                                 VALUES (@c_trmlogkey, 'TBLREGTRF', @c_transferkey, @c_transferlinenumber, 'DP', '0')
                              END
                           END -- not exists
                       END -- DP TBLHKITF = '1'
                     END -- Alloc to Non-Alloc OR Vice versa
                  END -- IF exists
               END -- @c_TBLHKITF = '1'
            END -- IF @b_success (To Storer)
         END -- IF @b_success
         -- END of tblHK

         /* IDSV5 - Ricky - (TH version) Interface */
         EXECUTE nspGetRight NULL,         -- Facility
                             @c_storerkey, -- Storer
                             NULL,         -- Sku
                             'TRANSFERDTL INTERFACE-CCOPACK',      -- ConfigKey
                             @b_success    OUTPUT,
                             @c_authority  OUTPUT,
                             @n_err        OUTPUT,
                             @c_errmsg     OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
            BREAK
         END
         ELSE
         BEGIN
            IF @c_authority = '1'
            BEGIN
               IF EXISTS ( SELECT 1 FROM TRANSFER (NOLOCK) WHERE TRANSFERKEY = @c_transferkey AND Type = 'CCOPACK'
                           AND CustomerRefNo <> '' AND ReasonCode = 'W')
               BEGIN
                  EXECUTE nsp_TransferDetailInterface_CCOPACK
                           @c_transferkey,
                           @c_transferlinenumber,
                           @c_type,
                           @b_success OUTPUT,
                           @n_err     OUTPUT,
                           @c_errmsg  OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @c_errmsg = 'ntrTransferDetailUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                     BREAK
                  END
               END
            END -- TRANSFERDTL INTERFACE-CCOPACK turn ON
         END -- Getright OK
         END -- while
      END -- status 9 exists
   END
   /* END Modification */
   ---------------------------------------------------------------------------
   QUIT_TR:                            --(Wan01)
   IF @n_continue = 3  -- Error Occured - Process AND Return
   BEGIN
       -- (ChewKP01)
       -- To support RDT - start
       DECLARE @n_IsRDT INT
       EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

       IF @n_IsRDT = 1
       BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_starttcnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > = @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTransferDetailUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = 'PROFILER,700,00,9,ntrTransferDetailUpdate Trigger                       ,' + CONVERT(char(12), GetDate(), 114)
            PRINT @profiler
         END
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,700,00,9,ntrTransferDetailUpdate Trigger                       ,' + CONVERT(char(12), GetDate(), 114)
         PRINT @profiler
      END
      RETURN
   END
END

GO