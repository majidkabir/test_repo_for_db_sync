SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspItrnAddDepositCheck                             */
/* Creation Date:                                                       */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 06/11/2002   Leo Ng        Program rewrite for IDS version 5         */
/* 11-May-2006  MaryVong      Add in RDT compatible error messages      */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 22-Jul-2009  SHONG         SOS140686 - Dynamic Pick Location         */
/* 06-Oct-2009  SHONG         SOS224115 - LCI Project Update UCC LOT    */
/* 31-May-2012  Leong         SOS# 245592 - Script revision.            */
/* 25-Jun-2013  TLTING01      Deadlock Tuning - reduce update to ID     */
/* 24-apr-2014  CSCHONG       Add Lottable06-15 (CS01)                  */
/* 17-MAR-2016  NJOW01        Fix - to include loctype 'DYNPPICK' when  */
/*                            calculate qtyexpected                     */
/* 22-MAR-2017  JayLim        SQL2012 compatibility modification (Jay01)*/
/* 27-Jul-2017  TLTING        missing (NOLOCK)                          */
/* 06-Feb-2018  SWT02     1.6 Added Channel Management Logic            */
/*                            Added QtyOnHold For Channel Mgmt          */
/* 23-JUL-2019  Wan01     1.7 WMS - 9914 [MY] JDSPORTSMY - Channel      */
/*                            Inventory Ignore QtyOnHold - CR           */
/* 26-SEP-2019  Wan02     1.7 WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for */
/*                            Channel                                   */
/* 15-Mar-2024  Wan03     1.8 UWP-16968-Post PalletType to Inventory When*/
/*                            Finalize                                  */
/* 21-Mar-2024  Wan04     1.9 UWP-17363-Fix QtyonHold not increase if   */
/*                            loc.stats<>'OK' And Hold ID               */
/* 05-APR-2024  Wan05     2.0 UWP-17363-Fix Increase QtyOnHold if Loc   */
/*                            Status not 'ok' or locationflag is 'damage'*/
/*                            or 'hold'                                 */
/* 17-JUL-2024  Wan03     1.9 LFWM-4446 - RG[GIT] Serial Number Solution*/
/*                            - Transfer by Serial Number               */
/************************************************************************/
CREATE   PROC [dbo].[nspItrnAddDepositCheck]
     @c_itrnkey      NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(20)
   , @c_Lot          NVARCHAR(10)
   , @c_ToLoc        NVARCHAR(10)
   , @c_ToID         NVARCHAR(18)
   , @c_packkey      NVARCHAR(10)
   , @c_Status       NVARCHAR(10)
   , @n_casecnt      int       -- Casecount being inserted
   , @n_innerpack    int       -- innerpacks being inserted
   , @n_Qty          int       -- QTY (Most important) being inserted
   , @n_pallet       int       -- pallet being inserted
   , @f_cube         float     -- cube being inserted
   , @f_grosswgt     float     -- grosswgt being inserted
   , @f_netwgt       float     -- netwgt being inserted
   , @f_otherunit1   float     -- other units being inserted.
   , @f_otherunit2   float     -- other units being inserted too.
   , @c_lottable01   NVARCHAR(18) = ''       
   , @c_lottable02   NVARCHAR(18) = ''    
   , @c_lottable03   NVARCHAR(18) = ''
   , @d_lottable04   datetime = NULL
   , @d_lottable05   datetime = NULL
   , @c_lottable06   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable07   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable08   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable09   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable10   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable11   NVARCHAR(30) = ''    --(CS01)
   , @c_lottable12   NVARCHAR(30) = ''    --(CS01)
   , @d_lottable13   datetime = NULL      --(CS01)
   , @d_lottable14   datetime = NULL      --(CS01)
   , @d_lottable15   datetime = NULL      --(CS01)
   , @c_SourceKey    NVARCHAR(20)
   , @c_SourceType   NVARCHAR(30)
   , @b_Success      int        OUTPUT
   , @n_err          int        OUTPUT
   , @c_ErrMsg       NVARCHAR(250)  OUTPUT
   , @c_Channel      NVARCHAR(20) = '' --(SWT02)
   , @n_Channel_ID   BIGINT = 0 OUTPUT --(SWT02)
   , @c_PalletType   NVARCHAR(10)   = ''                                            -- (Wan03) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_skudefallowed NVARCHAR(18)  /* Default Sku Allowed ?*/
         , @n_continue      int       /* continuation flag
                                         1=Continue
                                         2=failed but continue processsing
                                         3=failed do not continue processing
                                         4=successful but skip furthur processing */
         , @n_err2          int       -- For Additional Error Detection
         , @c_preprocess    NVARCHAR(250) -- preprocess
         , @c_pstprocess    NVARCHAR(250) -- post process
         , @n_cnt           int       /* variable to hold @@ROWCOUNT */
         , @c_facility      NVARCHAR(5)

   SELECT @n_continue = 1, @b_success = 0, @n_err = 1, @c_ErrMsg = ''

   DECLARE @c_allowoverallocations  NVARCHAR(1) -- Flag to see IF overallocations are allowed.
   DECLARE @c_allowidqtyupdate      NVARCHAR(1) -- Flag to see IF update on qty in the id table is allowed
         , @c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- (SWT02)

   DECLARE @c_SerialNo                 NVARCHAR(50) = ''                            --(Wan03)
         , @c_SerialNokey              NVARCHAR(10) = ''                            --(Wan03)
         , @c_Lot_SN                   NVARCHAR(10) = ''                            --(Wan03)
         , @c_ASNFizUpdLotToSerialNo   NVARCHAR(10) = '0'                           --(Wan03)

   DECLARE @b_addid int
   SELECT @b_addid = 0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Added By Ricky to handle Overallocation by storerkey
      SELECT @c_facility = FACILITY FROM LOC (NOLOCK)
      WHERE LOC = @c_ToLoc

      SELECT @b_success = 0
      EXECUTE nspGetRight @c_facility,
               @c_StorerKey,                 -- Storer
               @c_Sku,                       -- Sku
               'ALLOWOVERALLOCATIONS',      -- ConfigKey
               @b_success              OUTPUT,
               @c_allowoverallocations OUTPUT,
               @n_err                  OUTPUT,
               @c_ErrMsg               OUTPUT
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61831
         SELECT @c_ErrMsg = 'nspItrnAddDepositCheck:' + RTRIM(@c_ErrMsg)
      END

      IF ISNULL(RTRIM(@c_allowoverallocations),'') = ''
      BEGIN
         SELECT @c_allowoverallocations = '0'
      END
   END

   -- (SWT02)
   SET @c_ChannelInventoryMgmt = '0'
   If @n_continue = 1 or @n_continue = 2
   Begin
      Select @b_success = 0
      Execute nspGetRight2 @c_facility,
      @c_StorerKey,             -- Storer
      @c_Sku,                   -- Sku
      'ChannelInventoryMgmt',   -- ConfigKey
      @b_success    output,
      @c_ChannelInventoryMgmt  output,
      @n_err        output,
      @c_ErrMsg     output
      If @b_success <> 1
      Begin
         Select @n_continue = 3, @n_err = 61961, @c_ErrMsg = 'nspItrnAddDepositCheck:' + ISNULL(RTRIM(@c_ErrMsg),'')
      End
   END    

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_allowidqtyupdate = NSQLValue
      FROM NSQLCONFIG WITH (NOLOCK)
      WHERE CONFIGKEY = 'ALLOWIDQTYUPDATE'

      IF ISNULL(RTRIM(@c_allowidqtyupdate),'') = ''
      BEGIN
         SELECT @c_allowidqtyupdate = '0'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @d_lottable04 = ''
      BEGIN
         SELECT @d_lottable04 = NULL
      END
      IF @d_lottable05 = ''
      BEGIN
         SELECT @d_lottable05 = NULL
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_StorerKey),'') = ''
         BEGIN
            SELECT @c_storerkey = ( SELECT LTRIM(RTRIM(NSQLValue))
                                    FROM NSQLCONFIG WITH (NOLOCK)
                                    WHERE NSQLCONFIG.ConfigKey = 'gc_storerdef' )

            IF ISNULL(RTRIM(@c_StorerKey),'') = ''
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61832
               SELECT @c_ErrMsg = 'NSQL ' + CONVERT(char(5), @n_err) + ': Storerkey is blank OR null - not allowed! (nspItrnAddDepositCheck)'
            END
            ELSE
            BEGIN
               UPDATE ITRN WITH (ROWLOCK)
               SET StorerKey = @c_storerkey 
               WHERE Itrn.ItrnKey = @c_ItrnKey

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61833
                  SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Insert Trigger On ITRN Failed Because An Attempt To Update StorerKey Failed. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
               END
               ELSE IF @n_cnt = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61834
                  SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddDepositCheck)'
               END
            END
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_Sku),'') = ''
         BEGIN
            SELECT @c_SkuDefAllowed = ( SELECT LTRIM(RTRIM(NSQLValue))
                                        FROM NSQLCONFIG WITH (NOLOCK)
                                        WHERE ConfigKey = 'gb_skudefallowed' )

            IF @c_SkuDefAllowed = 'TRUE'
            BEGIN
               SELECT @c_sku = (SELECT NSQLVALUE FROM NSQLCONFIG WITH (NOLOCK) WHERE Configkey = 'gc_skudef')

               IF ISNULL(RTRIM(@c_sku),'') = ''
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61835
                  SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Sku is blank OR null - not allowed! (nspItrnAddDepositCheck)'
               END
               ELSE
               BEGIN
                  UPDATE ITRN SET sku = @c_sku WHERE itrnkey = @c_itrnkey

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61836
                     SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Insert Trigger On ITRN Failed Because An Attempt To Update SKU Failed. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
                  END
                  ELSE IF @n_cnt = 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61837
                     SELECT @c_ErrMsg='NSQL ' + CONVERT(char(5),@n_err) + ': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddDepositCheck)'
                  END
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61838
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Default SKU Is Not Allowed AND SKU Passed Is Blank! (nspItrnAddDepositCheck)'
            END
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Storerkey = @c_storerkey AND SKU = @c_sku AND OnReceiptCopyPackkey = '1')
         BEGIN
            SELECT @c_lottable01 = @c_packkey
         END
      END
      /* Validate Lot Number */
      /* Lot number cannot be defaulted.  IF one is not passed, use the lottables to */
      /* lookup into the lotattribute file.  IF not found, call the procedure to add */
      /* a lot number to the LOTATTRIBUTE File                                       */
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF ISNULL(RTRIM(@c_Lot),'') = ''
         BEGIN
            /* Lookup lottables in the lotattribute file AND return lot number */
            /* CS01 Start*/
            DECLARE @b_isok int
            SELECT @b_isok = 0
            EXECUTE nsp_lotlookup
                    @c_storerkey
                  , @c_sku
                  , @c_lottable01
                  , @c_lottable02
                  , @c_lottable03
                  , @d_lottable04
                  , @d_lottable05
                  , @c_lottable06
                  , @c_lottable07
                  , @c_lottable08
                  , @c_lottable09
                  , @c_lottable10
                  , @c_lottable11
                  , @c_lottable12
                  , @d_lottable13
                  , @d_lottable14
                  , @d_lottable15
                  , @c_Lot       OUTPUT
                  , @b_isok      OUTPUT
                  , @n_err       OUTPUT
                  , @c_ErrMsg    OUTPUT
              /* CS01 End*/
            IF @b_isok = 1
            BEGIN
               IF ISNULL(RTRIM(@c_Lot),'') = ''
               BEGIN
                  /* Add To Lotattribute File */
                  SELECT @b_isok = 0
                  EXECUTE nsp_lotgen
                          @c_storerkey
                        , @c_sku
                        , @c_lottable01
                        , @c_lottable02
                        , @c_lottable03
                        , @d_lottable04
                        , @d_lottable05
                        , @c_lottable06   --(CS01)
                        , @c_lottable07   --(CS01)
                        , @c_lottable08   --(CS01)
                        , @c_lottable09   --(CS01)
                        , @c_lottable10   --(CS01)
                        , @c_lottable11   --(CS01)
                        , @c_lottable12   --(CS01)
                        , @d_lottable13   --(CS01)
                        , @d_lottable14   --(CS01)
                        , @d_lottable15   --(CS01)
                        , @c_Lot       OUTPUT
                        , @b_isok      OUTPUT
                        , @n_err       OUTPUT
                        , @c_ErrMsg    OUTPUT

                  IF @b_isok <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61839
                     SELECT @c_ErrMsg = 'nspItrnAddDepositCheck: ' + RTRIM(@c_ErrMsg)
                  END
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61840
               SELECT @c_ErrMsg = 'nspItrnAddDepositCheck: ' + RTRIM(@c_ErrMsg)
            END
         END -- IF ISNULL(RTRIM(@c_Lot),'') = ''
         ELSE
         BEGIN
            DECLARE @c_verifysku NVARCHAR(20)

            SELECT @c_verifysku = SKU FROM LotAttribute WITH (NOLOCK) WHERE LOT = @c_Lot

            IF @@rowcount <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61841
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Lot Number Is Not Unique OR Does Not Exist In The LOTATTRIBUTE Table! (nspItrnAddDepositCheck)'
            END
            ELSE
            BEGIN
               IF @c_sku <> @c_verifysku
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61842
                  SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Lot Number AND SKU Passed Do Not Match The Definition In The LOTATTRIBUTE Table! (nspItrnAddDepositCheck)'
               END
            END
         END -- IF ISNULL(RTRIM(@c_Lot),'') = ''         
      END
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE @n_rcnt int, @n_curcasecnt int, @n_curinnerpack int, @n_curqty int, @c_curstatus NVARCHAR(10),
                 @n_curpallet int, @f_curcube float, @f_curgrosswgt float, @f_curnetwgt float,
                 @f_curotherunit1 float, @f_curotherunit2 float

         SELECT @n_curcasecnt    = casecnt
              , @n_curinnerpack  = innerpack
              , @n_curqty        = Qty
              , @n_curpallet     = pallet
              , @f_curcube       = [cube]
              , @f_curgrosswgt   = grosswgt
              , @f_curnetwgt     = netwgt
              , @f_curotherunit1 = otherunit1
              , @f_curotherunit2 = otherunit2
         FROM LOT WITH (NOLOCK) WHERE LOT = @c_Lot

         SELECT @n_rcnt = @@ROWCOUNT
         IF @n_rcnt = 0
         BEGIN
            INSERT INTO LOT (LOT,CASECNT,INNERPACK,QTY, PALLET,[CUBE],GROSSWGT,NETWGT,OTHERUNIT1,OTHERUNIT2,STORERKEY,SKU)
            VALUES (@c_Lot,@n_casecnt, @n_innerpack, @n_Qty, @n_pallet, @f_cube, @f_grosswgt, @f_netwgt, @f_otherunit1, @f_otherunit2, @c_storerkey,@c_sku )

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61843
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5), @n_err) + ': Insert Failed On Table LOT. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
         END

         IF @n_rcnt = 1 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            UPDATE LOT SET CASECNT    = CASECNT + @n_casecnt
                         , INNERPACK  = INNERPACK + @n_innerpack
                         , QTY        = QTY + @n_Qty
                         , PALLET     = PALLET + @n_pallet
                         , [CUBE]       = [CUBE] + @f_cube
                         , GROSSWGT   = GROSSWGT + @f_grosswgt
                         , NETWGT     = NETWGT + @f_netwgt
                         , OTHERUNIT1 = OTHERUNIT1 + @f_otherunit1
                         , OTHERUNIT2 = OTHERUNIT2 + @f_otherunit2
            WHERE LOT = @c_Lot

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61844
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table LOT. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61845
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update To Table LOT Returned Zero Rows Affected. (nspItrnAddWithdrawlCheck)'
            END
         END
         IF (@n_rcnt <> 1 AND @n_rcnt <> 0) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61846
            SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Lot Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddDepositCheck)'
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @n_rcnt = NULL, @n_curqty = NULL, @c_curstatus = NULL
         SELECT  @n_curqty = Qty, @c_curstatus = Status FROM ID WITH (NOLOCK) WHERE ID = @c_toid
         SELECT @n_rcnt = @@ROWCOUNT

         IF @n_rcnt = 0
         BEGIN
            IF ISNULL(RTRIM(@c_Status),'') = ''
            BEGIN
               SELECT @c_Status = 'OK'
            END

            IF @c_allowidqtyupdate = '1'
            BEGIN
               INSERT INTO ID (ID, QTY, STATUS, PACKKEY, PalletType)                --(Wan03)
               VALUES (@c_toid, @n_Qty, @c_status, @c_packkey, @c_PalletType)       --(Wan03)
            END
            ELSE
            BEGIN
               INSERT INTO ID (ID, QTY, STATUS, PACKKEY, PalletType)                --(Wan03)
               VALUES (@c_toid, 0, @c_status,@c_packkey, @c_PalletType)             --(Wan03)
            END

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61847
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Insert Failed On Table ID. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
            ELSE
            BEGIN
               SELECT @b_addid = 1
            END
         END

         IF @n_rcnt = 1 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            /* Update the existing id */
            /* You can never override a status on receipt for an ID that */
            /* is already there!                                         */
            /* Warning:  Attempting to change this behaviour can really screw up */
            /* the HOLD module. Be very very careful! */
            SELECT @c_status = @c_curstatus

            IF @c_allowidqtyupdate = '1'
            BEGIN
               UPDATE ID with (ROWLOCK) 
               SET QTY = QTY + @n_Qty, Status = @c_Status, Packkey = @c_packkey
                 , PalletType = @c_PalletType                                       --(Wan03)               
               WHERE ID = @c_toid
            END
            ELSE
            BEGIN
               SET @n_cnt = 0
               
               SELECT @n_cnt = COUNT(1) FROM  ID with (NOLOCK) WHERE ID = @c_toid   
               --tlting01
               IF EXISTS ( SELECT 1 FROM  ID with (NOLOCK) WHERE ID = @c_toid AND ( [Status] <> @c_Status OR Packkey = @c_packkey ) )
               BEGIN
                  UPDATE ID with (ROWLOCK) SET Status = @c_Status, Packkey = @c_packkey 
                  , PalletType = @c_PalletType                                      --(Wan03)
                  WHERE ID = @c_toid    --tlting01
               END
            END

            SELECT @n_err = @@ERROR  --, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61848
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table ID. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
            --ELSE IF @n_cnt = 0
            IF @n_cnt = 0 AND (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61849
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update To Table ID Returned Zero Rows Affected. (nspItrnAddWithdrawlCheck)'
            END
         END

         IF (@n_rcnt = 1 OR @n_rcnt = 0) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            IF ISNULL(RTRIM(@c_packkey),'') <> '' AND ISNULL(RTRIM(@c_toid),'') <> ''
            BEGIN
               DECLARE @n_ti int, @n_hi int, @n_totalqty int
               SELECT @n_ti = 0, @n_hi = 0, @n_totalqty = 0

               SELECT @n_totalqty = QTY FROM ID WITH (NOLOCK) WHERE ID = @c_toid

               SELECT @n_hi = CEILING(@n_totalqty / CaseCnt / PALLETTI ), @n_ti = PALLETTI
               FROM PACK WITH (NOLOCK)
               WHERE PACKKEY = @c_packkey
                 AND CaseCnt > 0
                 AND PALLETTI > 0

               IF @n_ti > 0 OR @n_hi > 0
               BEGIN
                  UPDATE ID with (ROWLOCK) 
                  SET PutawayTI = @n_ti, PutawayHI = @n_hi
                  WHERE ID = @c_toid

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61850
                     SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table ID. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
                  END
               END
            END
         END

         IF (@n_rcnt <> 1 AND @n_rcnt <> 0) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61851
            SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': ID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddDepositCheck)'
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @n_rcnt = NULL, @n_curqty = NULL
         SELECT @n_curqty = Qty FROM SKUxLOC WITH (NOLOCK) WHERE Storerkey = @c_storerkey AND SKU = @c_sku AND LOC = @c_toloc
         SELECT @n_rcnt = @@ROWCOUNT

         IF @n_rcnt = 0
         BEGIN
            INSERT INTO SKUxLOC (STORERKEY, SKU, LOC, QTY) VALUES (@c_storerkey, @c_sku, @c_toloc, @n_Qty)
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61852
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Insert Failed On Table SKUxLOC. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
         END

         IF @n_rcnt = 1 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            -- SOS140686
            UPDATE SKUxLOC SET QTYEXPECTED =
               CASE
                  --WHEN  (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')) 
                  --   THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) )
                  WHEN @c_allowoverallocations = '0' THEN 0
                  WHEN ( SKUxLOC.Locationtype NOT IN ('PICK','CASE') AND
                         LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') ) THEN 0
                  WHEN  ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) ) >= 0
                        AND @c_allowoverallocations = '1'
                        AND ( SKUxLOC.locationtype IN ('PICK','CASE')
                        OR (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')) ) --NJOW01
                     THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) )
                  ELSE 0
               END,
               QtyReplenishmentOverride =
                  CASE
                     WHEN QtyReplenishmentOverride - @n_Qty > 0
                        THEN QtyReplenishmentOverride - @n_Qty
                     ELSE 0
                  END,
               QTY = QTY + @n_Qty
            FROM SKUxLOC
            JOIN LOC WITH (NOLOCK) ON LOC.LOC = SKUxLOC.LOC
            WHERE SKUxLOC.STORERKEY = @c_storerkey
            AND SKUxLOC.SKU = @c_sku
            AND SKUxLOC.LOC = @c_toloc

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61853
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table SKUxLOC. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61854
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update To Table SKUxLOC Returned Zero Rows Affected. (nspItrnAddWithdrawlCheck)'
            END
         END

         IF (@n_rcnt <> 1 AND @n_rcnt <> 0) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61855
            SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': SKUxLOC Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddDepositCheck)'
         END
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @n_rcnt = NULL, @n_curqty = NULL
         SELECT @n_curqty = Qty FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_Lot AND LOC = @c_toloc AND ID = @c_toid
         SELECT @n_rcnt = @@ROWCOUNT

         IF @n_rcnt = 0
         BEGIN
            INSERT INTO LOTxLOCxID (LOT, LOC, ID, QTY, STORERKEY, SKU) VALUES (@c_Lot, @c_toloc, @c_toid, @n_Qty, @c_storerkey, @c_sku )

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61856
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Insert Failed On Table LOTxLOCxID. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
         END

         IF @n_rcnt = 1 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            UPDATE LOTxLOCxID
               SET QTY = LOTxLOCxID.QTY + @n_Qty,
                   PENDINGMOVEIN =
                                 CASE
                                    WHEN LOTxLOCxID.PENDINGMOVEIN - @n_Qty < 0
                                       THEN 0
                                    ELSE LOTxLOCxID.PENDINGMOVEIN - @n_Qty
                                 END,
                   QtyExpected =
                                 CASE
                                    --WHEN LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') AND  
                                    --     ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty)) >= 0
                                    --   THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty))
                                    --WHEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty)) >= 0 AND
                                    --     @c_AllowOverAllocations ='1'
                                    --   THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty))
                                    --WHEN @c_AllowOverAllocations = '0' THEN 0
                                    --ELSE 0

                                    WHEN @c_allowoverallocations = '0' THEN 0
                                    WHEN ( SKUXLOC.Locationtype NOT IN ('PICK','CASE') AND
                                           LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') ) THEN 0
                                    WHEN  ( (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty) ) >= 0
                                          AND @c_allowoverallocations = '1'
                                          AND ( SKUXLOC.locationtype IN ('PICK','CASE')
                                          OR (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')) ) --NJOW01
                                       THEN ( (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - (LOTxLOCxID.Qty + @n_Qty) )
                                    ELSE 0

                                 END
            FROM LOTxLOCxID
            JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc
            JOIN SKUXLOC WITH (NOLOCK) ON LOTxLOCxID.Storerkey = SKUXLOC.Storerkey AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc = SKUXLOC.Loc
            WHERE  LOTxLOCxID.LOT = @c_Lot
            AND    LOTxLOCxID.LOC = @c_toloc
            AND    LOTxLOCxID.ID  = @c_toid

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61857
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table LOTxLOCxID. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61858
               SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update To Table LOTxLOCxID Returned Zero Rows Affected. (nspItrnAddWithdrawlCheck)'
            END
         END

         IF (@n_rcnt <> 1 AND @n_rcnt <> 0) AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61859
            SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': LOTxLOCxID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddDepositCheck)'
         END
      END

      -- (SWT02)
      IF @n_continue = 1 or @n_continue = 2
      BEGIN       
         IF @c_ChannelInventoryMgmt = '1'       
         BEGIN
            IF ISNULL(RTRIM(@c_Channel), '') <> ''  AND
               ISNULL(@n_Channel_ID,0) = 0
            BEGIN
               SET @n_Channel_ID = 0
               
               BEGIN TRY
                  EXEC isp_ChannelGetID 
                      @c_StorerKey   = @c_StorerKey
                     ,@c_Sku         = @c_SKU
                     ,@c_Facility    = @c_Facility
                     ,@c_Channel     = @c_Channel
                     ,@c_LOT         = @c_LOT
                     ,@n_Channel_ID  = @n_Channel_ID OUTPUT
                     ,@b_Success  = @b_Success OUTPUT
                     ,@n_ErrNo = @n_Err OUTPUT
                     ,@c_ErrMsg = @c_ErrMsg OUTPUT                
               END TRY
               BEGIN CATCH
                     SELECT @n_err = ERROR_NUMBER(),
                            @c_ErrMsg = ERROR_MESSAGE()
                            
                     SELECT @n_continue = 3
                     SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddDepositCheck)' 
               END CATCH                                          
            END 

            IF @n_Channel_ID > 0 
            BEGIN
               --(Wan02) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - START
               DECLARE @b_UpdateChannel      BIT         = 1
                     , @n_FromChannel_ID     BIGINT      = 0
                     , @c_TransferKey        NVARCHAR(10)= ''
                     , @c_TransferLineNumber NVARCHAR(5) = ''

               SET @b_UpdateChannel = 1

               IF @c_SourceType LIKE 'ntrTransferDetail%'
               BEGIN
                  SET @c_TransferKey = SUBSTRING(@c_SourceKey, 1, 10)
                  SET @c_TransferLineNumber = SUBSTRING(@c_SourceKey, 11, 5)

                  SET @n_FromChannel_ID = 0
                  SELECT TOP 1 @n_FromChannel_ID = I.Channel_ID
                  FROM ITRN I WITH (NOLOCK)
                  WHERE I.SourceKey = @c_SourceKey
                  AND   I.SourceType LIKE 'ntrTransferDetail%'
                  AND   I.TranType = 'WD'

                  IF @n_FromChannel_ID = @n_Channel_ID
                  BEGIN
                     SET @b_UpdateChannel = 0
                  END
               END
               --(Wan01) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - END

               --(Wan01) - START: User Channel InventoryHold to Hold Instead
               --IF EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)
               --          WHERE Loc = @c_ToLoc
               --          AND ( LocationFlag IN ('DAMAGE','HOLD') OR LOC.[Status]  ='HOLD' ))
               --BEGIN
               --   UPDATE ChannelInv WITH (ROWLOCK)
               --      SET Qty = Qty + @n_Qty, 
               --          QtyOnHold = QtyOnHold + @n_Qty,  
               --          EditDate = GETDATE(),
               --          EditWho  = SUSER_SNAME() 
               --   WHERE Channel_ID = @n_Channel_ID 
               --   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                
               --END
               --ELSE 
               IF @b_UpdateChannel = 1
               BEGIN
                  UPDATE ChannelInv WITH (ROWLOCK)
                     SET Qty = Qty + @n_qty, 
                         EditDate = GETDATE(),
                         EditWho  = SUSER_SNAME() 
                  WHERE Channel_ID = @n_Channel_ID 
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                
  
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61992  
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                     +': Update Failed on Table ChannelInv. (nspItrnAddDepositCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  END 
               END  
               --(Wan01) - END 
               --(Wan02) - END: Use Channel InventoryHold to Hold Instead                                          
            END 
         END 
      END
      -- End (SWT02)
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE ITRN WITH (ROWLOCK) 
         SET TrafficCop = NULL,
             StorerKey  = @c_StorerKey,
             Sku        = @c_Sku,
             Lot        = @c_Lot,
             ToId       = @c_ToId,
             ToLoc      = @c_ToLoc,
             Lottable01 = @c_Lottable01,
             Lottable04 = @d_Lottable04,
             Lottable05 = @d_Lottable05,
             Status     = @c_Status, 
             Channel_ID = @n_Channel_ID, -- (SWT02) 
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME() 
         WHERE ItrnKey = @c_itrnkey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61860
            SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table Itrn. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
         END
      END
      
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         --(Wan04) - Move Down - START
         /* IF the status of the new stuff is not OK (ie: its on hold             */
         /* AND we are using IDs AND ID is new then we must call nspInventoryHold */
         --IF @n_continue = 1 OR @n_continue = 2
         --BEGIN
            --IF @b_addid = 1 AND @c_status <> 'OK'
            --BEGIN
            --   EXECUTE nspInventoryHold
            --              ''
            --            , ''
            --            , @c_toid
            --            , @c_status
            --            , '1'
            --            , @b_Success OUTPUT
            --            , @n_err     OUTPUT
            --            , @c_ErrMsg  OUTPUT
            --   IF @b_success <> 1
            --   BEGIN
            --      SELECT @n_continue = 3
            --   END
            --END
            --ELSE
            --BEGIN
               --IF EXISTS( SELECT 1 FROM ID WITH (NOLOCK) WHERE Id = @c_toid AND Status <> 'OK')  --(Wan05)
               --           OR EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Loc = @c_toloc AND    --(Wan05)
               IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Loc = @c_toloc AND                 --(Wan05)
                          (Status <> 'OK' OR Locationflag = 'HOLD' OR Locationflag = 'DAMAGE'))
               BEGIN
                  UPDATE LOT SET Qtyonhold = Qtyonhold + @n_Qty
                  WHERE LOT = @c_Lot

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61861
                     SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table LOT. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
                  END
               END
            --END
         --END
         --(Wan04) - Move Down - END
      END

      --(Wan04) - Move Down - START
      -- Fixed QtyOnHold not increase if loc.status = 'HOLD' and hold ID
      /* IF the status of the new stuff is not OK (ie: its on hold             */
      /* AND we are using IDs AND ID is new then we must call nspInventoryHold */
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @b_addid = 1 AND @c_status <> 'OK'
         BEGIN
            EXECUTE nspInventoryHold
                       ''
                     , ''
                     , @c_toid
                     , @c_status
                     , '1'
                     , @b_Success OUTPUT
                     , @n_err     OUTPUT
                     , @c_ErrMsg  OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      --(Wan04) - Move Down - END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF (SELECT NSQLValue FROM NSQLConfig WITH (NOLOCK) WHERE ConfigKey = 'WAREHOUSEBILLING') = '1'
         BEGIN
            EXECUTE nspItrnAddDWBill
                     'D'
                     , @c_itrnkey
                     , @c_StorerKey
                     , @c_Sku
                     , @c_Lot
                     , @c_ToLoc
                     , @c_ToID
                     , @c_Status
                     , @n_casecnt
                     , @n_innerpack
                     , @n_Qty
                     , @n_pallet
                     , @f_cube
                     , @f_grosswgt
                     , @f_netwgt
                     , @f_otherunit1
                     , @f_otherunit2
                     , @c_lottable01
                     , @c_lottable02
                     , @c_lottable03
                     , @d_lottable04
                     , @d_lottable05
                     , @c_SourceKey
                     , @c_SourceType
                     , @b_Success OUTPUT
                     , @n_err     OUTPUT
                     , @c_ErrMsg  OUTPUT

            IF @b_Success = 0
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
   END -- @n_continue = 1 OR @n_continue = 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_authority         NVARCHAR(1)  = '0', 
              @c_ReceiptKey        NVARCHAR(10) = '', 
              @c_ReceiptLineNumber NVARCHAR(5)  = ''

      IF @c_SourceType LIKE 'ntrReceiptDetail%'
      BEGIN
         SELECT @b_success = 0, @c_facility = ''      
         SET @c_ReceiptKey = SUBSTRING(@c_SourceKey, 1, 10)
         SET @c_ReceiptLineNumber = SUBSTRING(@c_SourceKey, 11, 5)
         
         SELECT @c_facility = Facility 
         FROM Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @c_ReceiptKey

         EXECUTE nspGetRight
                  @c_facility,
                  @c_storerkey,                 -- Storer
                  @c_sku,                       -- Sku
                  'UPDATE ReceiptDetail TOLOC', -- ConfigKey
                  @b_success    OUTPUT,
                  @c_authority  OUTPUT,
                  @n_err        OUTPUT,
                  @c_ErrMsg     OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61862
            SELECT @c_ErrMsg = 'nspItrnAddDepositCheck:' + RTRIM(@c_ErrMsg)
         END
         ELSE
         BEGIN
            IF @c_authority = '1'
            BEGIN
               IF @c_SourceType LIKE 'ntrReceiptDetail%'
               BEGIN
                  UPDATE ReceiptDetail
                     SET ToLot      = @c_Lot,
                         TrafficCop = NULL, 
                         EditDate = GETDATE(),
                         EditWho = SUSER_SNAME(), 
                         Channel_ID = @n_Channel_ID -- (SWT02)
                  WHERE ReceiptKey  = @c_ReceiptKey
                  AND ReceiptLineNumber = @c_ReceiptLineNumber 

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61863
                     SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table ReceiptDetail. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
                  END
               END
            END -- IF @c_authority = '1'
            
            -- (Wan02) START --Update Channel_ID to ReceiptDetail if Channel_ID > 0
            ELSE
            BEGIN
               IF @n_Channel_ID > 0
               BEGIN
                  UPDATE ReceiptDetail
                     SET TrafficCop = NULL, 
                        EditDate = GETDATE(),
                        EditWho = SUSER_SNAME(), 
                        Channel_ID = @n_Channel_ID  
                  WHERE ReceiptKey  = @c_ReceiptKey
                  AND ReceiptLineNumber = @c_ReceiptLineNumber 

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61864
                     SELECT @c_ErrMsg='NSQL '+CONVERT(char(5),@n_err) + ': Update Failed On Table ReceiptDetail. (nspItrnAddDepositCheck)' + '(' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
                  END
               END
            END
            -- (Wan02) END
         END --  IF @b_success = 1
         --(Wan02) - START
         IF @n_continue = 1 or @n_continue=2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM RECEIPT RH WITH (NOLOCK)
                        JOIN RECEIPTDETAIL RD WITH (NOLOCK)  
                              ON RD.Receiptkey =  RH.Receiptkey  
                        LEFT OUTER JOIN ChannelInvHold HH WITH (NOLOCK)
                              ON  RH.Receiptkey = HH.Sourcekey
                              AND HH.HoldType   = 'ASN'
                        LEFT OUTER  JOIN ChannelInvHoldDetail HD WITH (NOLOCK)
                              ON  HH.InvHoldkey = HD.InvHoldkey
                              AND HD.SourceLineNo = RD.ReceiptLineNumber
                        WHERE RH.Receiptkey    = @c_Receiptkey
                        AND   RH.HoldChannel   = '1'
                        AND   RD.ReceiptLineNumber = @c_ReceiptLineNumber
                        AND   HD.InvHoldkey IS NULL
                       )
            BEGIN
               EXEC isp_ChannelInvHoldWrapper
                          @c_HoldType     = 'ASN'       
                        , @c_SourceKey    = @c_Receiptkey  
                        , @c_SourceLineNo = @c_ReceiptLineNumber                         
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
                        , @c_Hold         = '1'     
                        , @c_Remarks      = ''      
                        , @b_Success      = @b_Success   OUTPUT
                        , @n_Err          = @n_Err       OUTPUT
                        , @c_ErrMsg       = @c_ErrMsg    OUTPUT

               IF @b_Success = 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 70010
                  SET @c_errmsg  = CONVERT(char(5),@n_err)+': Error Executing isp_ChannelInvHoldWrapper. (nspItrnAddDepositCheck)'
               END
            END
          END
         ----(Wan02) - END 
         -- SOS224115
         -- Added by SHONG, Update UCC IF Source from ReceiptDetail update

         IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK)
                     WHERE ReceiptKey = @c_ReceiptKey 
                     AND ReceiptLineNumber = @c_ReceiptLineNumber
                     AND [Status] < '2' 
                     AND (LOT IS NULL OR LOT = ''))
         BEGIN
            UPDATE UCC WITH (ROWLOCK)
            SET LOT = @c_Lot,
                LOC = @c_ToLoc,
                ID  = @c_ToID,
                [STATUS] = CASE WHEN STATUS = '0' THEN '1' ELSE STATUS END
            WHERE ReceiptKey = @c_ReceiptKey 
              AND ReceiptLineNumber = @c_ReceiptLineNumber
              AND [Status] < '2'
         END                  
      END -- @c_SourceType LIKE 'ntrReceiptDetail%'
   END

   IF @n_Continue IN (1,2)                                                          --(Wan03)-START
   BEGIN
      SET @c_ASNFizUpdLotToSerialNo = '0'
      SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr

      IF @c_SourceType LIKE 'ntrTransferDetail%'
      BEGIN
         SET @c_SerialNo = ''
         SELECT @c_SerialNo = td.FromSerialNo
         FROM TRANSFERDETAIL AS td (NOLOCK)
         JOIN dbo.ITRN AS i (NOLOCK) ON td.TransferKey+td.TransferLineNumber = i.SourceKey
         JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = td.FromStorerKey AND s.Sku = td.FromSku
         WHERE i.ItrnKey = @c_itrnkey
         AND td.FromSerialNo <> ''
         AND s.SerialNoCapture IN ('1','2','3')
      END

      IF @c_SerialNo <> ''
      BEGIN
         SET @c_SerialNokey = ''
         SELECT @c_SerialNoKey = sn.SerialNoKey
               ,@c_Lot_SN = sn.Lot
         FROM dbo.SerialNo AS sn (NOLOCK)
         WHERE sn.SerialNo= @c_SerialNo
         AND sn.Storerkey = @c_StorerKey
         AND sn.Sku = @c_Sku

         IF @c_SerialNokey <> ''
         BEGIN
            UPDATE dbo.SerialNo WITH (ROWLOCK)
            SET Lot      = CASE WHEN @c_ASNFizUpdLotToSerialNo = '1' AND @c_Lot_SN <> @c_Lot
                                THEN @c_Lot ELSE Lot END
               ,ID       = CASE WHEN ID <> @c_ToID THEN @c_ToID ELSE ID END
               ,EditWho  = SUSER_SNAME()
               ,EditDate = GETDATE()
            WHERE SerialNoKey = @c_SerialNoKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 61865
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table SerialNo. (nspItrnAddDepositCheck)'
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END

         IF @n_Continue IN (1,2)
         BEGIN
            EXEC dbo.ispITrnSerialNoDeposit
              @c_TranType     = 'DP'
            , @c_StorerKey    = @c_StorerKey
            , @c_SKU          = @c_SKU
            , @c_SerialNo     = @c_SerialNo
            , @n_QTY          = @n_QTY
            , @c_SourceKey    = @c_SourceKey
            , @c_SourceType   = @c_SourceType
            , @b_Success      = @b_Success     OUTPUT
            , @n_Err          = @n_Err         OUTPUT
            , @c_ErrMsg       = @c_ErrMsg      OUTPUT

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
            END
         END
      END
   END                                                                              --(Wan03)-END

   -- Commented by SHONG on 13-Feb-2018
   -- Added By SHONG on 05-Mar-2004
   -- Auto swap Lot
   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   DECLARE @c_authority_swaplot NVARCHAR(1)
   --   SELECT @b_success = 0, @c_facility = null

   --   EXECUTE nspGetRight
   --            '',
   --            @c_storerkey,           -- Storer
   --            '',                     -- Sku
   --            'ReAllocatePickDetail', -- ConfigKey
   --            @b_success            OUTPUT,
   --            @c_authority_swaplot  OUTPUT,
   --            @n_err                OUTPUT,
   --            @c_ErrMsg             OUTPUT

   --   IF @b_success <> 1
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @n_err = 61864
   --      SELECT @c_ErrMsg = 'nspItrnAddDepositCheck:' + RTRIM(@c_ErrMsg)
   --   END
   --   ELSE
   --   BEGIN
   --      IF @c_authority_swaplot = '1'
   --      BEGIN
   --         IF EXISTS( SELECT SKU FROM SKUxLOC WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU = @c_SKU AND
   --                    LOC = @c_ToLOC AND LocationType IN ('PICK', 'CASE'))
   --         BEGIN
   --            IF EXISTS( SELECT LOT FROM LOTxLOCxID WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU = @c_SKU AND
   --                       LOC = @c_ToLOC AND QtyExpected > 0 )
   --            BEGIN
   --               IF @c_Status = 'OK' OR @c_Status = ''
   --               BEGIN
   --                  EXEC ispReAllocPickDetail
   --                        @c_Storerkey,
   --                        @c_SKU,
   --                        @c_Lot,
   --                        @c_ToLOC,
   --                        @c_TOID,
   --                        @n_Qty,
   --                        @c_lottable01,
   --                        @c_lottable02,
   --                        @c_lottable03,
   --                        @d_lottable04,
   --                        @d_lottable05,
   --                        @b_Success OUTPUT,
   --                        @n_err     OUTPUT,
   --                        @c_ErrMsg  OUTPUT
   --                  IF @b_Success = 0
   --                  BEGIN
   --                     SELECT @n_continue = 3
   --                  END
   --               END
   --            END
   --         END
   --      END
   --   END
   --END

   IF @n_continue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit AND raise an error back to parent, let the parent decide

         -- Commit until the level we BEGIN with
         -- Notes: Original codes do not have COMMIT TRAN, error will be handled by parent
         -- WHILE @@TRANCOUNT > @n_starttcnt
         --    COMMIT TRAN
         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspItrnAddDepositCheck'
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
END

GO