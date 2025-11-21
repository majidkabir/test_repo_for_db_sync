SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: nspInventoryHold                                     */
/* Creation Date: 05-Aug-2002                                             */
/* Copyright: IDS                                                         */
/* Written by:                                                            */
/*                                                                        */
/* Purpose:                                                               */
/*                                                                        */
/* Called By:                                                             */
/*                                                                        */
/* PVCS Version: 1.6                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 06/11/2002   Leo Ng          Program rewrite for IDS version 5         */
/* 17-Oct-2002  Ricky           Merge code from SOS, FBR and Performance  */
/*                              tuning from Aug 24th till Sep 30th        */
/* 03-Nov-2004  MaryVong        Add in Configkey='IDSHOLDLOC' for C4      */
/* 01-Dec-2004  Shong           Add checking to prevent redundance hold   */
/*                              for Taiwan Unilever Interface             */
/* 03-Dec-2004  Shong           Bug Fixing                                */
/* 07-Sep-2006  MaryVong        Add in RDT compatible error messages      */
/* 02-Mar-2007  Vicky           SOS#69748 - Add Configkey = INVHOLDLOG    */
/* 04-Jul-2007  Vicky           SOS#80373 - Add checking on duplicate     */
/*                              Invholdkey with both status = 0 being     */
/*                              inserted into Transmitlog3                */
/* 26-Oct-2007  June            SOS89194                                  */
/* 14-Jul-2010  Shong           Change USER_NAME to sUSER_sNAME           */
/* 28-Oct-2013  MCTang          Add Configkey = INVHSTSLOG (MC01)         */
/* 28-Apr-2014  CSCHONG         Add Lottable06-15 (CS01)                  */
/* 06-JUL-2015  CSCHONG         SQL 2012 compatible (CS02)                */
/* 10-JUL-2015  YTWan           SOS#347393 - Project Merlion - Display    */
/*                              Storer in Inventory Hold Screen(Wan01)    */
/* 27-Oct-2015  Leong     1.5   SOS# 355593 - Bug Fix.                    */
/* 27-Jul-2017  TLTING    1.6   Missing nolock, remove setrowcount        */
/* 20-Oct-2017  SHONG     1.7   Use JOIN instead of Comma                 */
/* 27-Feb-2019  YokeBeen  1.8   WMS7973 - Revised Trigger Point values.   */
/*                              Differentiate new records - (YokeBeen01)  */
/* 21-Mar-2024  Wan02     1.9   UWP-17363-Fix not to increase/decrease for*/
/*                              hold/unhold ID if LocationFlag is HOLD/DAMAGE*/
/* 05-APR-2024  Wan03     2.0   UWP-17363-Fix increase/decrease hold by iD*/  
/*                              if Loc Status is not ok and locationflag  */  
/*                              is not damage/hold                        */  
/**************************************************************************/
CREATE   PROC [dbo].[nspInventoryHold]
               @c_lot          NVARCHAR(10)
,              @c_Loc          NVARCHAR(10)
,              @c_ID           NVARCHAR(18)
,              @c_Status       NVARCHAR(10)
,              @c_Hold         NVARCHAR(1)
,              @b_Success      int           OUTPUT
,              @n_err          int           OUTPUT
,              @c_errmsg       NVARCHAR(250) OUTPUT
,              @c_remark       NVARCHAR(260) = '' -- SOS89194
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_starttcnt       INT            -- Holds the current transaction count
         , @c_preprocess      NVARCHAR(250)  -- preprocess
         , @c_pstprocess      NVARCHAR(250)  -- post process
         , @n_cnt             INT
         , @n_err2            INT            -- For Additional Error Detection

   DECLARE @c_lottable01      NVARCHAR(18)
         , @c_lottable02      NVARCHAR(18)
         , @c_lottable03      NVARCHAR(18)
         , @d_lottable04      DateTime
         , @d_lottable05      DateTime
         , @c_lottable06      NVARCHAR(30)       --(CS01)
         , @c_lottable07      NVARCHAR(30)       --(CS01)
         , @c_lottable08      NVARCHAR(30)       --(CS01)
         , @c_lottable09      NVARCHAR(30)       --(CS01)
         , @c_lottable10      NVARCHAR(30)       --(CS01)
         , @c_lottable11      NVARCHAR(30)       --(CS01)
         , @c_lottable12      NVARCHAR(30)       --(CS01)
         , @d_lottable13      datetime           --(CS01)
         , @d_lottable14      datetime           --(CS01)
         , @d_lottable15      datetime           --(CS01)
         , @c_Sku             NVARCHAR(20)
         , @c_StorerKey       NVARCHAR(15)

   DECLARE @cStorerKey        NVARCHAR(15)
         , @cKey2             NVARCHAR(5)

   DECLARE @c_transmitlogkey  NVARCHAR(10)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @n_err2=0

   DECLARE @c_InventoryHoldKey      NVARCHAR(10)
         , @c_IDSHOLDLOC            NVARCHAR(1)    -- Added By MaryVong on 04Oct04 (C4)
         , @c_HoldLocNum            NVARCHAR(4)    -- Added By MaryVong on 04Oct04 (C4)
         , @c_CurrInventoryHoldKey  NVARCHAR(10)   -- Added By MaryVong on 04Oct04 (C4)
         , @c_Key2Prefix            NVARCHAR(1)    -- Added By MaryVong on 04Oct04 (C4)
         , @c_Key2                  NVARCHAR(5)    -- Added By MaryVong on 04Oct04 (C4)
         , @c_Key3                  NVARCHAR(20)   -- Added By MaryVong on 04Oct04 (C4)

   --(Wan01) - START
   SET @cStorerKey = ''
   SET @c_Sku = ''
   SET @c_lottable01 = ''
   SET @c_lottable02 = ''
   SET @c_lottable03 = ''
   SET @d_lottable04 = '1900-01-01'
   SET @d_lottable05 = '1900-01-01'
   SET @c_lottable06 = ''
   SET @c_lottable07 = ''
   SET @c_lottable08 = ''
   SET @c_lottable09 = ''
   SET @c_lottable10 = ''
   SET @c_lottable11 = ''
   SET @c_lottable12 = ''
   SET @d_lottable13 = '1900-01-01'
   SET @d_lottable14 = '1900-01-01'
   SET @d_lottable15 = '1900-01-01'
   --(Wan01) - END

   /* #INCLUDE <SPIH1.SQL> */
   /* Commented by DLIM 20010828 for PMT Bug where InventoryHoldKey is increased by 2 */
   /*
   IF @n_continue=1 or @n_continue=2
   BEGIN
   SELECT @b_success = 1
   EXECUTE   nspg_getkey
   'InventoryHoldKey'
   , 10
   , @c_InventoryHoldKey OUTPUT
   , @b_success OUTPUT
   , @n_err OUTPUT
   , @c_errmsg OUTPUT
   IF NOT @b_success = 1
   BEGIN
   SELECT @n_continue = 3
   END
   END
   */
   /* End Comment by DLIM */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_LOT), '') <> ''
      BEGIN
         IF ISNULL( RTRIM(@c_id), '')  <> '' OR ISNULL(RTRIM(@c_LOC), '') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62426 --78401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert Failed On InventoryHold. More Than One Parameter Is Not Null. (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_LOC), '') <> ''
      BEGIN
         -- SOS 7782 wally 3.sep.02
         -- prevent holding a location which is already on hold
         IF EXISTS (SELECT locationflag FROM loc (NOLOCK) WHERE loc = @c_loc
         and locationflag <> 'NONE' and locationflag <> '')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62427 --78499 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Location Already ON HOLD. (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF ISNULL(RTRIM(@c_id), '') <> '' OR ISNULL(RTRIM(@c_LOT), '') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62428 --78402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert Failed On InventoryHold. More Than One Parameter Is Not Null. (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_id), '')  <> ''
      BEGIN
         IF ISNULL(RTRIM(@c_LOC), '') <> '' OR ISNULL(RTRIM(@c_LOT), '') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62429 -- 78403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More Than One Parameter Is Not Null. (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_Status), '') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62430 --78404   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. Status is blank! (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF RTRIM(@c_Hold) <> '1' and RTRIM(@c_Hold) <> '0'
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62431 --78405   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. Hold flag should be 1 or 0! (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_CurrentHoldFlag    NVARCHAR(1)
            , @b_newrecord          INT
            , @d_currentdatetime    DateTime
            , @c_currentuser        NVARCHAR(18)
            , @n_numberofrecsonhold INT

      DECLARE @c_looplot            NVARCHAR(10)
            , @c_looploc            NVARCHAR(10)
            , @c_loopid             NVARCHAR(18)
            , @n_qtytoaddtolot      INT

      SELECT @b_newrecord = 0
      SELECT @d_currentdatetime = GETDATE(), @c_currentuser = sUSER_sNAME(), @c_CurrentHoldFlag = '0'

      BEGIN TRANSACTION

      IF ISNULL( RTRIM(@c_id), '')  <> ''
      BEGIN
         SELECT @c_CurrentHoldFlag = HOLD
         FROM   INVENTORYHOLD (NOLOCK)
         WHERE  STATUS = @c_status
         AND    ID     = @c_id

         SELECT @n_cnt = @@ROWCOUNT

         IF @n_cnt = 0
         BEGIN
            SELECT @b_newrecord = 1
         END
         IF @n_cnt > 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62432 --78406   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More than one record with this Status and ID exists! (nspInventoryHold)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         -- Added By SHONG on 26th Nov 2004
         -- UTL Taiwan Customization
         IF (@n_continue = 1 or @n_continue = 2) and @c_Hold = '1'
         BEGIN
            SELECT @cStorerKey = ISNULL(MAX(StorerKey), '')
            FROM   LOTxLOCxID (NOLOCK)
            WHERE  ID = @c_id

            IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ConfigKey = 'UTLITF'
                      AND   sValue    = '1')
            BEGIN
               SELECT TOP 1 @c_CurrentHoldFlag = HOLD
               FROM   INVENTORYHOLD (NOLOCK)
               WHERE  ID = @c_id
               AND    INVENTORYHOLD.HOLD = '1'
               
               SELECT @n_cnt = @@ROWCOUNT

               IF @n_cnt = 0
               BEGIN
                  SELECT @b_NewRecord = 1
               END
               IF @n_cnt > 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62433 --78406   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More than one record with this ID exists! (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  SELECT TOP 1 @c_CurrentHoldFlag = HOLD
                    FROM INVENTORYHOLD (NOLOCK)
                    JOIN LOTxLOCxID (NOLOCK) ON (INVENTORYHOLD.LOT = LOTxLOCxID.LOT)
                   WHERE LOTxLOCxID.ID = @c_id
                     AND INVENTORYHOLD.HOLD = '1'

                  SELECT @n_cnt = @@ROWCOUNT

                  IF @n_cnt = 0
                  BEGIN
                     SELECT @b_NewRecord = 1
                  END
                  IF @n_cnt > 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62434 --78406   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LOT Already Hold! (nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
            END
         END
         -- End of UTL Customization

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            -- (Wan01) - START
            SET @cStorerKey = ''
            SELECT TOP 1 @cStorerKey =  StorerKey
            FROM   LOTxLOCxID (NOLOCK)
            WHERE  ID = @c_id
            AND    Qty > 0

            IF @cStorerKey = ''
            BEGIN
               SELECT @cStorerKey = ISNULL(MAX(StorerKey), '')  --MC01
               FROM   LOTxLOCxID (NOLOCK)
               WHERE  ID = @c_id
            END
            -- (Wan01) - END

            IF @b_newrecord = 1
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspg_getkey
                       'InventoryHoldKey'
                     , 10
                     , @c_InventoryHoldKey OUTPUT
                     , @b_success          OUTPUT
                     , @n_err              OUTPUT
                     , @c_errmsg           OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62435
                  SELECT @c_errmsg = 'nspInventoryHold: ' + dbo.fnc_RTrim(@c_errmsg)
               END

               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  --FBR049 IDSHK CCLAW 16/08/2001 - Leave all lottables blank.
                  /*
                  INSERT INVENTORYHOLD (InventoryHoldKey,Id,Status,hold,DateOn,WhoOn,StorerKey, SKU, lottable01,lottable02,lottable03,lottable04,lottable05)
                  VALUES (@c_inventoryholdkey,@c_id,@c_status,@c_hold,@d_currentdatetime,@c_currentuser,@c_StorerKey, @c_SKU, @c_lottable01,@c_lottable02,@c_lottable03,@d_lottable04,@d_lottable05)
                  */
                  -- SOS89194 : Add in Remark
                  /*CS01 Start*/
                  INSERT INVENTORYHOLD (InventoryHoldKey,Id,Status,hold,DateOn,WhoOn
                                       , StorerKey, SKU
                                       , lottable01,lottable02,lottable03,lottable04,lottable05
                                       , lottable06,lottable07,lottable08,lottable09,lottable10
                                       , lottable11,lottable12,lottable13,lottable14,lottable15
                                       , Remark)
                  VALUES (@c_inventoryholdkey,@c_id,@c_status,@c_hold,@d_currentdatetime,@c_currentuser
                         ,@cStorerKey, @c_SKU                     --(Wan01)
                         ,@c_lottable01,@c_lottable02,@c_lottable03,@d_lottable04,@d_lottable05 --(Wan01)
                         ,@c_lottable06,@c_lottable07,@c_lottable08,@c_lottable09,@c_lottable10    --(Wan01)
                         ,@c_lottable11,@c_lottable12,@d_lottable13,@d_lottable14,@d_lottable15    --(Wan01)
                         ,@c_remark)
                  /*CS01 Start*/
                  SELECT @n_err = @@ERROR

                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                  END

                  -- Added By Vicky on 02-March-2007
                  -- For SOS#69748
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     --DECLARE @cKey2 NVARCHAR(5)   --MC01

                     --SELECT @cStorerKey = ISNULL(MAX(StorerKey), '')  --MC01
                     --FROM   LOTxLOCxID (NOLOCK)
                     --WHERE  ID = @c_id

                     IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   ConfigKey = 'INVHOLDLOG'
                               AND   sValue    = '1')
                     BEGIN
                        BEGIN TRAN

                        IF @c_hold = '1'
                        BEGIN
                           SELECT @cKey2 = 'HOLD'
                        END
                        ELSE
                        BEGIN
                           SELECT @cKey2 = 'OK'
                        END

                        -- SOS#80373 (Start)
                        IF NOT EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'INVHOLDLOG-ID'
                                        AND Key1 = @c_inventoryholdkey AND Key2 = @cKey2
                                        AND Key3 = @cStorerKey AND Transmitflag = '0')
                        BEGIN
                           SELECT @c_transmitlogkey = ''
                           SELECT @b_success = 1
                           EXECUTE nspg_getkey
                                  'TransmitlogKey3'
                                , 10
                                , @c_transmitlogkey OUTPUT
                                , @b_success OUTPUT
                                , @n_err OUTPUT
                                , @c_errmsg OUTPUT

                           IF @b_success <> 1
                           BEGIN
                              SELECT @n_continue=3
                           END
                           ELSE
                           BEGIN
                              INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                              VALUES  (@c_transmitlogkey, 'INVHOLDLOG-ID', @c_inventoryholdkey, @cKey2, @cStorerKey,'0')

                              SELECT @n_err= @@Error

                              IF NOT @n_err=0
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                              END
--                         SELECT @b_success = 1
--                         EXEC ispGenTransmitLog3 'INVHOLDLOG-ID', @c_inventoryholdkey, @cKey2, @cStorerKey, ''
--                         , @b_success OUTPUT
--                         , @n_err OUTPUT
--                         , @c_errmsg OUTPUT
--
--                         IF @b_success <> 1
--                         BEGIN
--                            SELECT @n_continue = 3
--                            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
--                            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
--                         END
                           END -- Insert Transmitlog3
                        END -- Not Exists
                        COMMIT TRAN
                     END -- Exists Storerconfig - INVHOLDLOG

                     --MC01 - S
                     IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   ConfigKey = 'INVHSTSLOG'
                               AND   sValue    = '1')
                     BEGIN
                        -- (YokeBeen01) - Start 
                        IF @c_hold = '1'
                        BEGIN
                           SELECT @cKey2 = 'U2H-A'
                        END
                        ELSE
                        BEGIN
                           SELECT @cKey2 = 'H2U-A'
                        END
                        -- (YokeBeen01) - End 

                        SELECT @c_transmitlogkey = ''
                        SELECT @b_success = 1
                        EXECUTE nspg_getkey
                               'TransmitlogKey3'
                             , 10
                             , @c_transmitlogkey OUTPUT
                             , @b_success        OUTPUT
                             , @n_err            OUTPUT
                             , @c_errmsg         OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue=3
                        END
                        ELSE
                        BEGIN
                           BEGIN TRAN

                           INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                           VALUES  (@c_transmitlogkey, 'INVHSTSLOG', @c_inventoryholdkey, @cKey2, @cStorerKey, '0')

                           SELECT @n_err= @@Error

                           IF NOT @n_err=0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                           END
                           ELSE
                           BEGIN
                              COMMIT TRAN
                           END
                        END
                     END -- Exists Storerconfig - INVHSTSLOG
                     --MC01 - E
                  END
               END
            END
            ELSE
            BEGIN
               UPDATE INVENTORYHOLD
               SET hold = @c_hold,
                   Storerkey = @cStorerKey,                       -- (Wan01)
                   DateOn = (CASE @c_hold WHEN '1' THEN @d_currentdatetime ELSE DateOn END) ,
                   WhoOn  = (CASE @c_hold WHEN '1' THEN @c_currentuser ELSE WhoOn END),
                   DateOff= (CASE @c_hold WHEN '0' THEN @d_currentdatetime ELSE DateOff END) ,
                   WhoOff = (CASE @c_hold WHEN '0' THEN @c_currentuser ELSE WhoOff END)
               WHERE STATUS = @c_status
               AND   ID = @c_id

               SELECT @n_err = @@ERROR
               IF @n_err > 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62436 --78408   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On InventoryHold.(nspInventoryHold)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               -- MC01-S
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   ConfigKey = 'INVHSTSLOG'
                            AND   sValue    = '1')
                  BEGIN
                     IF @c_hold = '1'
                     BEGIN
                        SELECT @cKey2 = 'U2H'
                     END
                     ELSE
                     BEGIN
                        SELECT @cKey2 = 'H2U'
                     END

                     DECLARE Cur_InventoryHold CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT InventoryHoldKey
                     FROM   INVENTORYHOLD WITH (NOLOCK)
                     WHERE  STATUS = @c_status
                     AND    ID = @c_id
                     GROUP BY InventoryHoldKey
                     
                     OPEN  Cur_InventoryHold
                     FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @c_transmitlogkey = ''
                        SELECT @b_success = 1

                        EXECUTE nspg_getkey
                               'TransmitlogKey3'
                             , 10
                             , @c_transmitlogkey OUTPUT
                             , @b_success        OUTPUT
                             , @n_err            OUTPUT
                             , @c_errmsg         OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue=3
                        END
                        ELSE
                        BEGIN
                           BEGIN TRAN

                           INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                           VALUES  (@c_transmitlogkey, 'INVHSTSLOG', @c_InventoryHoldKey, @cKey2, @cStorerKey, '0')

                           SELECT @n_err= @@Error

                           IF NOT @n_err=0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Insert transmitlog3 (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                           END
                           ELSE
                           BEGIN
                              COMMIT TRAN
                           END
                        END

                        FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey
                     END
                     CLOSE Cur_InventoryHold
                     DEALLOCATE Cur_InventoryHold
                  END -- Exists Storerconfig - INVHSTSLOG
               END
               -- MC01-E
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_hold = '1'
               BEGIN
                  UPDATE ID WITH (ROWLOCK)
                  SET STATUS = 'HOLD'
                  WHERE ID = @c_id

                  SELECT @n_err = @@ERROR
                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62437 --78409   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ID.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS(SELECT * FROM INVENTORYHOLD (NOLOCK) WHERE ID = @c_id AND HOLD = '1')
                  BEGIN
                     UPDATE ID WITH (ROWLOCK)
                     SET STATUS = 'OK'
                     WHERE ID = @c_id

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 62438 --78410   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ID.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
               END
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_hold = '1' and @c_CurrentHoldFlag = '0'
               BEGIN
                  SELECT @n_numberofrecsonhold = COUNT(*)
                  FROM INVENTORYHOLD (NOLOCK)
                  WHERE ID = @c_id and HOLD = '1'

                  IF @n_numberofrecsonhold = 1
                  BEGIN
                     UPDATE LOT WITH (ROWLOCK)
                     SET QTYONHOLD = QTYONHOLD +
                     ( SELECT SUM(LOTxLOCxID.QTY)
                     FROM LOTxLOCxID (Nolock)
                     JOIN LOC (Nolock) ON LOTxLOCxID.LOC = LOC.LOC  
                     WHERE LOTxLOCxID.ID = @c_id 
                     AND LOC.STATUS <> 'HOLD' AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')       --(Wan03)--Wan02
                     AND LOTxLOCxID.LOT = LOT.LOT
                     AND LOTxLOCxID.QTY > 0
                     )
                     FROM LOT 
                     JOIN LOTxLOCxID WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
                     JOIN LOC L WITH (NOLOCK) ON LOTxLOCxID.LOC = L.LOC 
                     WHERE LOTxLOCxID.ID = @c_id
                     AND LOTxLOCxID.QTY > 0
                     AND L.STATUS <> 'HOLD' AND L.LocationFlag NOT IN ('HOLD','DAMAGE')           --(Wan03)--Wan02

                     SELECT @n_err = @@ERROR

                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END

               IF @c_hold = '0' and @c_CurrentHoldFlag = '1'
               BEGIN
                  SELECT @n_numberofrecsonhold = COUNT(1)
                  FROM INVENTORYHOLD WITH (NOLOCK)
                  WHERE ID = @c_id and HOLD = '1'

                  IF @n_numberofrecsonhold = 0
                  BEGIN
                     UPDATE LOT SET QTYONHOLD = QTYONHOLD -
                     ( SELECT SUM(LOTxLOCxID.QTY)
                     FROM LOTxLOCxID (NOLOCK)
                     JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC 
                     WHERE LOTxLOCxID.ID = @c_id 
                     AND LOC.STATUS <> 'HOLD' AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')       --(Wan03)--Wan02
                     AND LOTxLOCxID.LOT = LOT.LOT
                     AND LOTxLOCxID.QTY > 0 )
                     FROM LOT 
                     JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot 
                     JOIN LOC L WITH (NOLOCK) ON L.Loc = LOTxLOCxID.Loc  
                     WHERE LOTxLOCxID.ID = @c_id
                     AND LOTxLOCxID.QTY > 0
                     AND L.STATUS <> 'HOLD' AND L.LocationFlag NOT IN ('HOLD','DAMAGE')           --(Wan03)--Wan02

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END
            END
         END
      END

      IF ISNULL(RTRIM(@c_LOC), '') <> ''
      BEGIN
         --(Wan01) - START
         SELECT TOP 1 @cStorerKey = StorerKey
         FROM   LOTxLOCxID (NOLOCK)
         WHERE  LOC = @c_loc
         ORDER BY EditDate DESC
         --(Wan01) - END

         SELECT @c_CurrentHoldFlag = HOLD
         FROM INVENTORYHOLD WITH (NOLOCK) 
         WHERE STATUS = @c_status
         AND   LOC = @c_loc
         SELECT @n_cnt = @@ROWCOUNT
         IF @n_cnt = 0
         BEGIN
            SELECT @b_newrecord = 1
         END
         IF @n_cnt > 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62439 --78420   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More than one record with this Status and ID exists! (nspInventoryHold)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF @b_newrecord = 1
            BEGIN
               SELECT @b_success = 1
               EXECUTE   nspg_getkey
               'InventoryHoldKey'
               , 10
               , @c_InventoryHoldKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62440
                  SELECT @c_errmsg = 'nspInventoryHold: ' + dbo.fnc_RTrim(@c_errmsg)
               END

               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  -- SOS89194 : Add Remark
                  /*CS01 start*/
                  INSERT INVENTORYHOLD (InventoryHoldKey,Loc,Status,hold,DateOn,WhoOn
                                       ,Storerkey, SKU                                                            --(Wan01)
                                       ,lottable01,lottable02,lottable03,lottable04,lottable05                    --(Wan01)
                                       ,lottable06,lottable07,lottable08,lottable09,lottable10
                                       ,lottable11,lottable12,lottable13,lottable14,lottable15
                                       ,Remark)
                  VALUES (@c_inventoryholdkey,@c_loc,@c_status,@c_hold,@d_currentdatetime,@c_currentuser
                        , @cStorerKey, @c_SKU                                                                     --(Wan01)
                        , @c_lottable01,@c_lottable02,@c_lottable03,@d_lottable04,@d_lottable05                   --(Wan01)
                        , @c_lottable06,@c_lottable07,@c_lottable08,@c_lottable09,@c_lottable10                   --(Wan01)
                        , @c_lottable11,@c_lottable12,@d_lottable13,@d_lottable14,@d_lottable15                   --(Wan01)
                        , @c_Remark)
                  /*CS01 End*/

                  SELECT @n_err = @@ERROR
                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            END
            ELSE
            BEGIN
               UPDATE INVENTORYHOLD WITH (ROWLOCK)
               SET hold = @c_hold,
               Storerkey = @cStorerKey,                       -- (Wan01)
               DateOn = (CASE @c_hold WHEN '1' THEN @d_currentdatetime ELSE DateOn END) ,
               WhoOn  = (CASE @c_hold WHEN '1' THEN @c_currentuser ELSE WhoOn END),
               DateOff= (CASE @c_hold WHEN '0' THEN @d_currentdatetime ELSE DateOff END) ,
               WhoOff = (CASE @c_hold WHEN '0' THEN @c_currentuser ELSE WhoOff END)
               WHERE STATUS = @c_status
               AND   LOC = @c_loc

               SELECT @n_err = @@ERROR
               IF @n_err > 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62441 --78422   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On InventoryHold.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_hold = '1'
               BEGIN
                  UPDATE LOC  WITH (ROWLOCK)
                  SET STATUS = 'HOLD'
                  WHERE LOC = @c_Loc

                  SELECT @n_err = @@ERROR
                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62442 --78423   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On LOC.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM INVENTORYHOLD WITH (NOLOCK) 
                  WHERE LOC = @c_loc AND HOLD = '1'
                  )
                  BEGIN
                     UPDATE LOC  WITH (ROWLOCK)
                     SET STATUS = 'OK'
                     WHERE LOC = @c_loc
                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 62443 --78424   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On LOC.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
               END
            END

            -- Added By MaryVong on 04Oct04 (C4) - Start
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               -- Get Storerkey based on Loc
               IF (SELECT COUNT(DISTINCT StorerKey) FROM SKUxLOC (NOLOCK) WHERE Loc = @c_Loc and qty > 0) > 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62444 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err) + ': More than 1 storerkey using this location. (nspInventoryHold)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               ELSE
               BEGIN
                  SELECT @c_StorerKey = (SELECT DISTINCT StorerKey FROM SKUxLOC (NOLOCK) WHERE Loc = @c_Loc and QTY > 0 )
               END

               IF @n_continue=1 or @n_continue=2 -- Get configkey
               BEGIN
                  SELECT @c_IDSHOLDLOC = '0'
                  EXECUTE nspGetRight
                  NULL,             -- facility
                  @c_storerkey,     -- Storerkey
                  NULL,             -- Sku
                  'IDSHOLDLOC',     -- Configkey
                  @b_success  OUTPUT,
                  @c_IDSHOLDLOC     OUTPUT,
                  @n_err            OUTPUT,
                  @c_errmsg         OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 62445
                     SELECT @c_errmsg = 'nspInventoryHold :' + dbo.fnc_RTrim(@c_errmsg)
                  END
               END

               IF @c_IDSHOLDLOC = '1'
               BEGIN
                  IF (@b_newrecord = 1 AND @c_Hold = '1') OR (@b_newrecord = 0) -- Apply for new and hold record OR existing record
                  BEGIN
                     SELECT @c_CurrInventoryHoldKey = InventoryHoldKey
                     FROM INVENTORYHOLD (NOLOCK)
                     WHERE STATUS = @c_status
                     AND   LOC = @c_loc
                     AND   Hold = @c_hold

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 62446
                        SELECT @c_errmsg = 'nspInventoryHold: Get CurrInventoryHoldKey'
                     END

                     IF @n_continue = 1 or @n_continue = 2 -- Get HoldLoc running num.
                     BEGIN
                        SELECT @b_success = 0
                        SELECT @c_HoldLocNum = ''

                        EXECUTE nspg_getkey
                        'HoldLocNum'
                        , 4
                        , @c_HoldLocNum OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 62447
                           SELECT @c_errmsg = 'nspInventoryHold: ' + dbo.fnc_RTrim(@c_errmsg)
                        END
                        ELSE
                        BEGIN
                           IF @c_Hold = '1'
                              SELECT @c_Key2Prefix = 'H'
                           ELSE
                              SELECT @c_Key2Prefix = 'R'

                           SELECT @c_Key2 = @c_Key2Prefix + @c_HoldLocNum
                           SELECT @c_Key3 = dbo.fnc_RTrim(@c_StorerKey) + '-' + @c_Loc

                           EXEC ispGenTransmitLog2 'IDSHOLDLOC', @c_CurrInventoryHoldKey, @c_Key2, @c_Key3, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                        END

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 62448 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                           SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err) + ': Insert Into Table TransmitLog2 Table (IDSHOLDLOC) Failed. (nspInventoryHold)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END -- End of Get HoldLoc running num.
                  END -- End of Apply for new and hold record OR existing record
               END -- @c_IDSHOLDLOC = '1'
            END
            -- Added By MaryVong on 04Oct04 (C4) -End

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_hold = '1' and @c_CurrentHoldFlag = '0'
               BEGIN
                  SELECT @n_numberofrecsonhold = COUNT(1)
                  FROM INVENTORYHOLD WITH (NOLOCK) 
                  WHERE LOC = @c_loc and HOLD = '1'

                  IF @n_numberofrecsonhold = 1
                  BEGIN
                     UPDATE LOT  WITH (ROWLOCK)
                     SET QTYONHOLD = QTYONHOLD +
                     ( SELECT SUM(LOTxLOCxID.QTY)
                     FROM LOTxLOCxID (Nolock)
                     JOIN ID (Nolock) ON ID.Id = LOTxLOCxID.Id 
                     WHERE LOTxLOCxID.LOC = @c_loc
                     AND   ID.STATUS <> 'HOLD'
                     AND LOTxLOCxID.LOT = LOT.LOT
                     AND LOTxLOCxID.QTY > 0
                     )
                     FROM LOT 
                     JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot
                     JOIN ID I WITH (NOLOCK) ON I.Id = LOTxLOCxID.Id  
                     WHERE LOTxLOCxID.LOC = @c_loc
                     AND   LOTxLOCxID.QTY > 0
                     AND   I.STATUS <> 'HOLD'

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END
               IF @c_hold = '0' and @c_CurrentHoldFlag = '1'
               BEGIN
                  SELECT @n_numberofrecsonhold = COUNT(1)
                  FROM INVENTORYHOLD WITH (NOLOCK) 
                  WHERE LOC = @c_loc and HOLD = '1'

                  IF @n_numberofrecsonhold = 0
                  BEGIN
                     UPDATE LOT  WITH (ROWLOCK)
                     SET QTYONHOLD = QTYONHOLD -
                     ( SELECT SUM(LOTxLOCxID.QTY)
                     FROM LOTxLOCxID (Nolock)
                     JOIN ID (Nolock) ON ID.Id = LOTxLOCxID.Id
                     WHERE LOTxLOCxID.LOC = @c_loc
                     AND ID.STATUS <> 'HOLD'
                     AND LOTxLOCxID.LOT = LOT.LOT
                     AND LOTxLOCxID.QTY > 0
                     )
                     FROM LOT 
                     JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot
                     JOIN ID I WITH (NOLOCK) ON I.Id = LOTxLOCxID.Id 
                     WHERE LOTxLOCxID.LOC = @c_loc
                     AND   LOTxLOCxID.QTY > 0
                     AND   I.STATUS <> 'HOLD'

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END
            END
         END
      END

      IF ISNULL(RTRIM(@c_LOT), '') <> ''
      BEGIN
         SELECT @c_CurrentHoldFlag = HOLD
         FROM  INVENTORYHOLD WITH (NOLOCK) 
         WHERE LOT = @c_lot
         AND   STATUS = @c_status

         SELECT @n_cnt = @@ROWCOUNT
         IF @n_cnt = 0
         BEGIN
            SELECT @b_newrecord = 1
         END

         IF @n_cnt > 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62449 --78440   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More than one record with this Status and LOT exists! (nspInventoryHold)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         SELECT @cStorerKey = StorerKey  --MC01
               ,@c_SKU      = Sku         --(Wan01)
         FROM   LOT (NOLOCK)
         WHERE  LOT = @c_LOT
         -- AND    Qty > 0                --(Wan01) -- SOS# 355593

         IF (@n_continue = 1 or @n_continue = 2) and @c_Hold = '1'
         BEGIN
            --SELECT @cStorerKey = StorerKey  --MC01
            --FROM   LOT (NOLOCK)
            --WHERE  LOT = @c_LOT

            IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @cStorerKey and ConfigKey = 'UTLITF'
                      AND sValue = '1')
            BEGIN
               SELECT TOP 1  @c_CurrentHoldFlag = HOLD
               FROM  INVENTORYHOLD WITH (NOLOCK) 
               WHERE LOT = @c_lot
               AND   INVENTORYHOLD.HOLD = '1'
               AND   Status <> @c_status

               SELECT @n_cnt = @@ROWCOUNT

               IF @n_cnt = 0
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM INVENTORYHOLD WITH (NOLOCK) WHERE LOT = @c_lot AND Status = @c_status )
                     SELECT @b_newrecord = 1
               END
               IF @n_cnt > 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62450 --78440   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On InventoryHold. More than one record with this LOT exists! (nspInventoryHold)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF @b_newrecord = 1
            BEGIN
               SELECT @b_success = 1
               EXECUTE   nspg_getkey
               'InventoryHoldKey'
               , 10
               , @c_InventoryHoldKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62451
                  SELECT @c_errmsg = 'nspInventoryHold: ' + dbo.fnc_RTrim(@c_errmsg)
               END

               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  --- end of addition
                  --FBR049 IDSHK CCLAW 16/08/2001 - Leave all lottables blank.
                  /*
                  INSERT INVENTORYHOLD (InventoryHoldKey,Lot,Status,hold,DateOn,WhoOn,Storerkey, SKU, Lottable01,Lottable02,Lottable03,Lottable04,Lottable05)
                  VALUES (@c_inventoryholdkey,@c_lot,@c_status,@c_hold,@d_currentdatetime,@c_StorerKey, @c_SKU, @c_currentuser,@c_lottable01,@c_lottable02,@c_lottable03,@d_lottable04,@d_lottable05)
                  */
                  --SELECT @c_Lot, @c_Loc, @c_Id, @c_Lottable01, @c_Lottable02, @c_Lottable03
                  -- SOS89194 : Add Remark
                  INSERT INVENTORYHOLD (InventoryHoldKey,Lot,Status,hold,DateOn,WhoOn
                          , Storerkey, SKU
                          , Lottable01,Lottable02,Lottable03,Lottable04,Lottable05
                          , Lottable06,Lottable07,Lottable08,Lottable09,Lottable10                    --(Wan01)
                          , Lottable11,Lottable12,Lottable13,Lottable14,Lottable15                    --(Wan01)
                          , Remark)
                  VALUES (@c_inventoryholdkey,@c_lot,@c_status,@c_hold,@d_currentdatetime,@c_currentuser
                          , @cStorerKey, @c_SKU                                                       --(Wan01)
                          , @c_lottable01,@c_lottable02,@c_lottable03,@d_lottable04,@d_lottable05     --(Wan01)
                          , @c_lottable06,@c_lottable07,@c_lottable08,@c_lottable09,@c_lottable10     --(Wan01)
                          , @c_lottable11,@c_lottable12,@d_lottable13,@d_lottable14,@d_lottable15     --(Wan01)
                          , @c_Remark)                                                                --(Wan01)

                  SELECT @n_err = @@ERROR
                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                  END

                  -- MC01-S
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   ConfigKey = 'INVHSTSLOG'
                               AND   sValue    = '1')
                     BEGIN
                        IF @c_hold = '1'
                        BEGIN
                           SELECT @cKey2 = 'U2H'
                        END
                        ELSE
                        BEGIN
                           SELECT @cKey2 = 'H2U'
                        END

                        SELECT @c_transmitlogkey = ''
                        SELECT @b_success = 1
                        EXECUTE nspg_getkey
                               'TransmitlogKey3'
                             , 10
                             , @c_transmitlogkey OUTPUT
                             , @b_success        OUTPUT
                             , @n_err            OUTPUT
                             , @c_errmsg         OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue=3
                        END
                        ELSE
                        BEGIN
                           BEGIN TRAN

                           INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                           VALUES  (@c_transmitlogkey, 'INVHSTSLOG', @c_inventoryholdkey, @cKey2, @cStorerKey, '0')

                           SELECT @n_err= @@Error

                           IF NOT @n_err=0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrIDUpdate) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                           END
                           ELSE
                           BEGIN
                              COMMIT TRAN
                           END
                        END
                     END -- Exists Storerconfig - INVHSTSLOG
                  END
                  -- MC01-E
               END
            END
            ELSE
            BEGIN
               UPDATE INVENTORYHOLD WITH (ROWLOCK)
               SET hold = @c_hold,
                   Storerkey = @cStorerKey,                       -- (Wan01)
                   DateOn = (CASE @c_hold WHEN '1' THEN @d_currentdatetime ELSE DateOn END) ,
                   WhoOn  = (CASE @c_hold WHEN '1' THEN @c_currentuser ELSE WhoOn END),
                   DateOff= (CASE @c_hold WHEN '0' THEN @d_currentdatetime ELSE DateOff END) ,
                   WhoOff = (CASE @c_hold WHEN '0' THEN @c_currentuser ELSE WhoOff END)
               WHERE STATUS = @c_status
               AND   LOT = @c_lot

               SELECT @n_err = @@ERROR
               IF @n_err > 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62452 --78442   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On InventoryHold.(nspInventoryHold) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               -- MC01-S
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   ConfigKey = 'INVHSTSLOG'
                            AND   sValue    = '1')
                  BEGIN
                     IF @c_hold = '1'
                     BEGIN
                        SELECT @cKey2 = 'U2H'
                     END
                     ELSE
                     BEGIN
                        SELECT @cKey2 = 'H2U'
                     END

                     DECLARE Cur_InventoryHold CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT InventoryHoldKey
                     FROM   INVENTORYHOLD WITH (NOLOCK)
                     WHERE  STATUS = @c_status
                     AND    LOT = @c_lot
                     GROUP BY InventoryHoldKey
                     
                     OPEN  Cur_InventoryHold
                     FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @c_transmitlogkey = ''
                        SELECT @b_success = 1

                        EXECUTE nspg_getkey
                               'TransmitlogKey3'
                             , 10
                             , @c_transmitlogkey OUTPUT
                             , @b_success        OUTPUT
                             , @n_err            OUTPUT
                             , @c_errmsg         OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue=3
                        END
                        ELSE
                        BEGIN
                           BEGIN TRAN

                           INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                           VALUES  (@c_transmitlogkey, 'INVHSTSLOG', @c_InventoryHoldKey, @cKey2, @cStorerKey, '0')

                           SELECT @n_err= @@Error

                           IF NOT @n_err=0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to insert TRANSMITLOG3 (ntrIDUpdate) (SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                           END
                           ELSE
                           BEGIN
                              COMMIT TRAN
                           END
                        END

                        FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey
                     END
                     CLOSE Cur_InventoryHold
                     DEALLOCATE Cur_InventoryHold
                  END -- Exists Storerconfig - INVHSTSLOG
               END
               -- MC01-E
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_hold = '1'
               BEGIN
                  UPDATE LOT WITH (ROWLOCK)
                  SET STATUS = 'HOLD'
                  WHERE LOT = @c_Lot

                  SELECT @n_err = @@ERROR
                  IF @n_err > 0
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM INVENTORYHOLD WITH (NOLOCK) 
                  WHERE LOT = @c_lot AND HOLD = '1'
                  )
                  BEGIN
                     UPDATE LOT WITH (ROWLOCK)
                     SET STATUS = 'OK'
                     WHERE LOT = @c_lot

                     SELECT @n_err = @@ERROR
                     IF @n_err > 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END
            END
         END
      END
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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

         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspInventoryHold'
         --RAISERROR @n_err @c_errmsg
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR   --(CS02)

         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END

GO