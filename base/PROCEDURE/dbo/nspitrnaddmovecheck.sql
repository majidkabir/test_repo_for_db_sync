SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Stored Procedure: nspItrnAddMoveCheck                                  */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by:                                                            */
/*                                                                        */
/* Purpose:                                                               */
/*                                                                        */
/* Called By:                                                             */
/*                                                                        */
/* PVCS Version: 2.9                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver. Purposes                                   */
/* 09-May-2006  MaryVong       Add in RDT compatible error messages       */
/* 07-Sep-2006  MaryVong       Add in RDT compatible error messages       */
/* 22-Jul-2009  SHONG          SOS140686 - Dynamic Pick Location          */
/* 28-Jul-2011  SHONG          Enhance Dynamic Pick ExpectedQty           */
/*                             Calculation                                */
/* 30-JUL-2012  YTWan     1.3  SOS#251326:Add Commingle Lottables         */
/*                        1.4  validation to Exceed and RDT (Wan01)       */
/* 02-APR-2013  YTWan     1.5  SOS#251326: Allow place to loc that had    */
/*                             been picked (Wan02)                        */
/* 25-Jun-2013  TLTING01  1.6  Deadlock Tuning - reduce update to ID      */
/* 24-Jul-2013  YTWan     1.7  SOS#282285:Unique HostWHCode Check (Wan03  */
/* 05-Jum-2014  Shong     1.8  Fixing Update Pickdetail Issues (Shong01)  */
/*                             need deploy ispItrnAddMoveQtyAllocated     */
/* 21-Nov-2014  SHONG     1.9  Performance Tuning                         */
/* 28-Apr-2014  CSCHONG   2.0  Add Lottable06-15 (CS01)                   */
/* 12-Feb-2014  YTWan     2.0  SOS#315474 - Project Merlion - Exceed GTM  */
/*                             Kiosk Module; ConfirmPick Move (Wan04)     */
/* 18-MAY-2015  YTWan     2.1 SOS#341733 - ToryBurch HK SAP - Allow       */
/*                            CommingleSKU with NoMixLottablevalidation   */
/*                            to Exceed and RDT (Wan05)                   */
/* 01-JUN-2015  YTWan     2.1 SOS#343525 - UA - NoMixLottable validation  */
/*                            CR(Wan06)                                   */
/* 10-AUG-2015  YTWan     2.2 FIXED Moverefkey Checking performance(Wan07)*/
/* 15-Sep-2016  TLTING    2.3 Deadlock Tune                               */
/* 22-Mar-2017  TLTING01  2.4 Deadlock Tune - ROWLOCK on select           */
/* 30-JUN-2017  Leong     2.5 IN00389849 - Revise error message.          */
/* 22-Mar-2018  Wan08     2.6 WMS-4288 - [CN] UA Relocation Phase II -    */
/*                            Exceed Channel of IQC                       */
/* 05-Mar-2018  SWT01     2.6 Auto Swap LOT for Replenishment             */
/* 10-Aug-2018  NJOW01    2.6 Allow skip channel when move from or to     */
/*                            specific loc type. if non specific from     */
/*                            or to loc is hold then will be rejected     */
/* 15-Aug-2018  SWT02     2.7 Change Update PendingMoveIn Logic           */
/* 11-Oct-2018  NJOW02    2.8 Allow call swap lot by loc when replen move */
/* 23-JUL-2019  Wan09     2.9 WMS - 9914 [MY] JDSPORTSMY - Channel        */
/*                            Inventory Ignore QtyOnHold - CR             */
/* 24-OCT-2019  NJOW02    3.0 Fix unique moverefkey check in a loc for UA */
/* 14-NOV-2019  WAN10     3.1 Performance Enhancement when there is 100k  */  
/*                            for the same fromloc in the pickdetail      */
/* 08-Apr-2020  NJOW03    3.2 Add additional info to error message        */
/* 05-Dec-2020  SWT03     3.3 Change UOM = 7 for ECOM Replenisment        */
/* 10-Feb-2023  NJOW04    WMS-21722 Allow check nomixlottable for all     */
/*                        commingle sku in a loc.                         */
/* 10-Feb-2023  NJOW04    DEVOPS Combine Script                           */
/* 25-Sep-2023  NJOW05    WMS-23743 Update channelinv when move facility  */
/* 21-Nov-2024  SWT04     FCR-822 - Merge Pallets with Serial Numbers     */
/* 22-Jan-2025  Wan11     UWP-23317 - Unpick Serial if change on id.      */
/*                        Fixed RDT move issue(FCR-540)                   */
/**************************************************************************/

CREATE   PROCEDURE [dbo].[nspItrnAddMoveCheck]
     @c_itrnkey      NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(20)
   , @c_Lot          NVARCHAR(10)
   , @c_fromloc      NVARCHAR(10)
   , @c_fromid       NVARCHAR(18)
   , @c_ToLoc        NVARCHAR(10)
   , @c_ToID         NVARCHAR(18)
   , @c_packkey      NVARCHAR(10)
   , @c_Status       NVARCHAR(10)
   , @n_casecnt      INT       -- Casecount being inserted
   , @n_innerpack    INT       -- innerpacks being inserted
   , @n_Qty          INT       -- QTY (Most important) being inserted
   , @n_pallet       INT       -- pallet being inserted
   , @f_cube         FLOAT     -- cube being inserted
   , @f_grosswgt     FLOAT     -- grosswgt being inserted
   , @f_netwgt       FLOAT     -- netwgt being inserted
   , @f_otherunit1   FLOAT     -- other units being inserted.
   , @f_otherunit2   FLOAT     -- other units being inserted too.
   , @c_lottable01   NVARCHAR(18) = ''
   , @c_lottable02   NVARCHAR(18) = ''
   , @c_lottable03   NVARCHAR(18) = ''
   , @d_lottable04   DATETIME     = NULL
   , @d_lottable05   DATETIME     = NULL
   , @c_lottable06   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable07   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable08   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable09   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable10   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable11   NVARCHAR(30) = ''     --(CS01)
   , @c_lottable12   NVARCHAR(30) = ''     --(CS01)
   , @d_lottable13   DATETIME = NULL       --(CS01)
   , @d_lottable14   DATETIME = NULL       --(CS01)
   , @d_lottable15   DATETIME = NULL       --(CS01)
   , @b_Success      INT        OUTPUT
   , @n_err          INT        OUTPUT
   , @c_errmsg       NVARCHAR(250)  OUTPUT
   , @c_MoveRefKey   NVARCHAR(10)  = ''        --(Wan04)
   , @c_Channel      NVARCHAR(20) = ''      --(Wan08)
   , @n_Channel_ID   BIGINT = 0 OUTPUT      --(Wan08)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
        @c_skudefallowed NVARCHAR(18) /* Default Sku Allowed ?*/
       ,@n_continue      INT          /* continuation flag
                                       1=Continue
                                       2=failed but continue processsing
                                       3=failed do not continue processing
                                       4=successful but skip furthur processing */
       ,@n_err2          INT             -- For Additional Error Detection
       ,@c_preprocess    NVARCHAR(250)   -- preprocess
       ,@c_pstprocess    NVARCHAR(250)   -- post process
       ,@n_cnt           INT             /* variable to hold @@ROWCOUNT */
       ,@c_authority     NVARCHAR(1)     -- added for idsv5 by Ricky Yee (18/06/2002)
       ,@c_facility      NVARCHAR(5)
       ,@c_IDSHOLDLOC    NVARCHAR(1)     -- Added By MaryVong on 04Oct04 (C4)
       ,@c_FromLocStatus NVARCHAR(10)    -- Added By MaryVong on 04Oct04 (C4)
       ,@c_ToLocStatus   NVARCHAR(10)    -- Added By MaryVong on 04Oct04 (C4)

   --(Wan01) - START
 DECLARE @c_IDLottable01      NVARCHAR(18)
      , @c_IDLottable02       NVARCHAR(18)
      , @c_IDLottable03       NVARCHAR(18)
      , @d_IDLottable04       DATETIME
      , @c_IDLottable06       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable07       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable08       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable09       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable10       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable11       NVARCHAR(30)            --(Wan06)
      , @c_IDLottable12       NVARCHAR(30)            --(Wan06)
      , @d_IDLottable13       DATETIME                --(Wan06)
      , @d_IDLottable14       DATETIME                --(Wan06)
      , @d_IDLottable15       DATETIME                --(Wan06)

      , @c_NoMixLottable01    NVARCHAR(1)
      , @c_NoMixLottable02    NVARCHAR(1)
      , @c_NoMixLottable03    NVARCHAR(1)
      , @c_NoMixLottable04    NVARCHAR(1)
      , @c_NoMixLottable06    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable07    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable08    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable09    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable10    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable11    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable12    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable13    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable14    NVARCHAR(1)             --(Wan06)
      , @c_NoMixLottable15    NVARCHAR(1)             --(Wan06)
      , @c_CommingleSku       NVARCHAR(1)             --(Wan05)
      , @c_ChkLocByCommingleSkuFlag  NVARCHAR(10)      --(Wan05)
      
      , @c_FromChannelInventoryMgmt  NVARCHAR(10)      --(Wan08) 
      , @c_ToChannelInventoryMgmt    NVARCHAR(10)      --(Wan08) 
      , @n_FromChannel_ID            BIGINT            --(Wan08)
      , @n_ToChannel_ID              BIGINT            --(Wan08)
      , @c_FromFacility              NVARCHAR(5)       --(Wan08)
      , @c_FromLocationFlag          NVARCHAR(10)      --(Wan08)
      , @c_ToLocationFlag            NVARCHAR(10)      --(Wan08)
      , @n_FromQtyHold               INT               --(Wan08)
      , @n_ToQtyHold                 INT               --(Wan08)   
      , @n_FromQtyMove               INT               --(Wan08)
      , @n_ToQtyMove                 INT               --(Wan08)
      , @b_ChannelIsNeeded           BIT               --(Wan08)
                                     
      , @c_FromLocTypeSkipChannel    CHAR(1)           --NJOW01
      , @c_ToLocTypeSkipChannel      CHAR(1)           --NJOW01
      , @c_ChkNoMixLottableForAllSku NVARCHAR(30) = '' --NJOW04      

   SET @c_IDLottable01     = ''
   SET @c_IDLottable02     = ''
   SET @c_IDLottable03     = ''
   SET @c_IDLottable06     = ''                       --(Wan06)
   SET @c_IDLottable07     = ''                       --(Wan06)
   SET @c_IDLottable08     = ''                       --(Wan06)
   SET @c_IDLottable09     = ''                       --(Wan06)
   SET @c_IDLottable10     = ''                       --(Wan06)
   SET @c_IDLottable11     = ''                       --(Wan06)
   SET @c_IDLottable12     = ''                       --(Wan06)

   SET @c_NoMixLottable01  = '0'
   SET @c_NoMixLottable02  = '0'
   SET @c_NoMixLottable03  = '0'
   SET @c_NoMixLottable04  = '0'
   SET @c_NoMixLottable06  = '0'                      --(Wan06)
   SET @c_NoMixLottable07  = '0'                      --(Wan06)
   SET @c_NoMixLottable08  = '0'                      --(Wan06)
   SET @c_NoMixLottable09  = '0'                      --(Wan06)
   SET @c_NoMixLottable10  = '0'                      --(Wan06)
   SET @c_NoMixLottable11  = '0'                      --(Wan06)
   SET @c_NoMixLottable12  = '0'                      --(Wan06)
   SET @c_NoMixLottable13  = '0'                      --(Wan06)
   SET @c_NoMixLottable14  = '0'                      --(Wan06)
   SET @c_NoMixLottable15  = '0'                      --(Wan06)
   --(Wan01) - END

   SET @c_CommingleSku      = '1'                      --(Wan05)
   SET @c_ChkLocByCommingleSkuFlag = '0'               --(Wan05)

   --(Wan03) - START
   DECLARE @c_UniqueHostWHCode      NVARCHAR(10)
         , @c_FromLocHostWHCode     NVARCHAR(10)
         , @c_ToLocHostWHCode       NVARCHAR(10)

   SET @c_UniqueHostWHCode = '0'
   SET @c_FromLocHostWHCode= ''
   SET @c_ToLocHostWHCode  = ''
   --(Wan03) - END

   --(Wan08) - START
   SET @c_FromChannelInventoryMgmt = '0'      
   SET @c_ToChannelInventoryMgmt   = '0'      
   SET @n_FromChannel_ID           = 0
   SET @n_ToChannel_ID             = 0
   SET @c_FromFacility             = ''
   SET @c_FromLocationFlag         = ''
   SET @c_ToLocationFlag           = ''
   SET @n_FromQtyHold              = 0
   SET @n_ToQtyHold                = 0   
   SET @n_FromQtyMove              = 0
   SET @n_ToQtyMove                = 0
   SET @b_ChannelIsNeeded          = 0
   --(Wan08) - END

   --SWT03
   DECLARE  @b_UpdUOM              BIT              
   SET      @b_UpdUOM              =  0
   --SWT03

   /* Fix input parameters */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      /* Fix blank Lottable04 and Lottable05 */
      IF @d_lottable04 = ''
      BEGIN
         SELECT @d_lottable04 = NULL
      END
      IF @d_lottable05 = ''
      BEGIN
         SELECT @d_lottable05 = NULL
      END
   END
   /* End Fix input parameters */
   /* Set default values for variables */

   SELECT @n_continue=1, @b_success=0, @n_err = 1,@c_errmsg=''
   DECLARE @c_AllowOverAllocations NVARCHAR(1) -- Flag to see if overallocations are allowed.
   DECLARE @c_AllowIDQtyUpdate NVARCHAR(1) -- Flag to see if update on qty in the ID table is allowed

   /* Execute Preprocess */
   /* #INCLUDE <SPIAMC1.SQL> */
   /* End Execute Preprocess */
   /* Start Main Processing */
   /* Get status of overallocations flag */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Added By Ricky to handle Overallocation by storerkey

      SELECT @c_facility = LOC.FACILITY
            ,@c_ToLocationFlag = LOC.LocationFlag      --(Wan08)
            ,@c_ToLocStatus= LOC.Status                --(Wan08)
            ,@c_ToLocTypeSkipChannel = CASE WHEN CODELKUP.UDF01 = 'MOVESKIPCHANNEL' THEN  'Y' ELSE 'N' END  --NJOW01
      FROM LOC (NOLOCK)
      JOIN CODELKUP(NOLOCK) ON LOC.LocationType = CODELKUP.Code AND CODELKUP.ListName = 'LOCTYPE'  --NJOW01
      WHERE LOC.LOC = @c_ToLoc

      Select @b_success = 0
      Execute nspGetRight @c_facility,
      @c_StorerKey,                -- Storer
      @c_Sku,                      -- Sku
      'ALLOWOVERALLOCATIONS',  -- ConfigKey
      @b_success                output,
      @c_AllowOverAllocations   output,
      @n_err                    output,
      @c_errmsg                output
      If @b_success <> 1
      Begin
         Select @n_continue = 3, @n_err = 62011, @c_errmsg = 'nspItrnAddMoveCheck:' + RTRIM(@c_errmsg)
      End

      --  SELECT @c_AllowOverAllocations = NSQLValue
      --   FROM NSQLCONFIG (NOLOCK)
      --  WHERE CONFIGKEY = 'ALLOWOVERALLOCATIONS'

      IF @c_AllowOverAllocations is null
      BEGIN
         SELECT @c_AllowOverAllocations = '0'
      END
   END
   /* End get status of overallocations flag */

   -- Added By MaryVong on 04Oct04 (C4) - Start
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      SELECT @c_IDSHOLDLOC = '0'

       EXECUTE nspGetRight
        NULL,     -- facility
        @c_StorerKey,   -- Storerkey
        NULL,     -- Sku
        'IDSHOLDLOC',    -- Configkey
        @b_success   OUTPUT,
        @c_IDSHOLDLOC     OUTPUT,
        @n_err    OUTPUT,
        @c_errmsg   OUTPUT

       IF @b_success <> 1
       BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62012
            SELECT @c_errmsg = 'nspItrnAddMoveCheck' + RTRIM(@c_errmsg)
       END
     ELSE
     BEGIN
        IF @c_IDSHOLDLOC = '1'
        BEGIN
           SELECT @c_FromLocStatus = Status FROM LOC (NOLOCK) Where Loc = @c_FromLoc
           SELECT @c_ToLocStatus = Status FROM LOC (NOLOCK) Where Loc = @c_ToLoc

           IF @c_FromLocStatus = 'HOLD' OR @c_ToLocStatus = 'HOLD'
           BEGIN
              SELECT @n_continue = 3, @n_err = 62013 --62246
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Status For Both From and To Location Cannot be ON HOLD (nspItrnAddMoveCheck)'
           END
        END
     END
   END
   -- Added By MaryVong on 04Oct04 (C4) - End

   --(Wan03) - START
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Added By Ricky to handle Overallocation by storerkey

      Select @b_success = 0
      Execute nspGetRight
              @c_facility
            , @c_StorerKey                -- Storer
            , @c_Sku                      -- Sku
            , 'UniqueHostWHCode'           -- ConfigKey
            , @b_success               OUTPUT
            , @c_UniqueHostWHCode      OUTPUT
            , @n_err                   OUTPUT
            , @c_errmsg                OUTPUT

      If @b_success <> 1
      Begin
         SET @n_continue = 3
         SET @n_err = 62059
         SET @c_errmsg = 'nspItrnAddMoveCheck: ' + RTRIM(@c_errmsg)
      End

      IF @c_UniqueHostWHCode = '1'
      BEGIN
         SELECT @c_FromLocHostWHCode = ISNULL(RTRIM(HostWHCode),'')
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_FromLoc

         SELECT @c_ToLocHostWHCode = ISNULL(RTRIM(HostWHCode),'')
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_ToLoc

         IF @c_FromLocHostWHCode <> @c_ToLocHostWHCode
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62060
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move To Location: ' + RTRIM(@c_ToLOC)
                        + ' with different HostWHCode: ' + RTRIM(@c_ToLocHostWHCode)
                        + ' when ''UniqueHostWHCode'' Configkey is turn on. (nspItrnAddMoveCheck)'
         END
      END
   END
   --(Wan03) - END

   --(Wan05) - START
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SET @b_success = 0
      Execute nspGetRight
              @c_facility
            , @c_StorerKey               -- Storer
            , @c_Sku                     -- Sku
            , 'ChkLocByCommingleSkuFlag'  -- ConfigKey
            , @b_success                  OUTPUT
            , @c_ChkLocByCommingleSkuFlag OUTPUT
            , @n_err                      OUTPUT
            , @c_errmsg                   OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62065
         SET @c_errmsg = 'nspItrnAddMoveCheck:' + RTRIM(@c_errmsg)
      END
   END
   --(Wan05) - END
   
  --NJOW04 S
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SET @b_success = 0
      Execute nspGetRight
              @c_facility
            , @c_StorerKey               -- Storer
            , @c_Sku                     -- Sku
            , 'ChkNoMixLottableForAllSku'  -- ConfigKey
            , @b_success                   OUTPUT
            , @c_ChkNoMixLottableForAllSku OUTPUT
            , @n_err                       OUTPUT
            , @c_errmsg                    OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62066
         SET @c_errmsg = 'nspItrnAddMoveCheck:' + RTRIM(@c_errmsg)
      END
   END
   --NJOW04 E   

   --(Wan01) - START
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_IDlottable01 = RTRIM(LA.Lottable01)
            ,@c_IDlottable02 = RTRIM(LA.Lottable02)
            ,@c_IDlottable03 = RTRIM(LA.Lottable03)
            ,@d_IDlottable04 = ISNULL(LA.Lottable04, CONVERT(DATETIME,'19000101'))
            ,@c_IDLottable06 = RTRIM(LA.Lottable06)                                               --(Wan06)
            ,@c_IDLottable07 = RTRIM(LA.Lottable07)                                               --(Wan06)
            ,@c_IDLottable08 = RTRIM(LA.Lottable08)                                               --(Wan06)
            ,@c_IDLottable09 = RTRIM(LA.Lottable09)                                               --(Wan06)
            ,@c_IDLottable10 = RTRIM(LA.Lottable10)                                               --(Wan06)
            ,@c_IDLottable11 = RTRIM(LA.Lottable11)                                               --(Wan06)
            ,@c_IDLottable12 = RTRIM(LA.Lottable12)                                               --(Wan06)
            ,@d_IDLottable13 = ISNULL(LA.Lottable13, CONVERT(DATETIME,'19000101'))                --(Wan06)
            ,@d_IDLottable14 = ISNULL(LA.Lottable14, CONVERT(DATETIME,'19000101'))                --(Wan06)
            ,@d_IDLottable15 = ISNULL(LA.Lottable15, CONVERT(DATETIME,'19000101'))                --(Wan06)
      FROM LOTATTRIBUTE LA WITH (NOLOCK)
      WHERE LA.Lot = @c_LOT

      SELECT @c_NoMixLottable01 = CASE WHEN LOC.NoMixLottable01 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)
            ,@c_NoMixLottable02 = CASE WHEN LOC.NoMixLottable02 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)
            ,@c_NoMixLottable03 = CASE WHEN LOC.NoMixLottable03 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)
            ,@c_NoMixLottable04 = CASE WHEN LOC.NoMixLottable04 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)
            ,@c_NoMixLottable06 = CASE WHEN LOC.NoMixLottable06 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable07 = CASE WHEN LOC.NoMixLottable07 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable08 = CASE WHEN LOC.NoMixLottable08 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable09 = CASE WHEN LOC.NoMixLottable09 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable10 = CASE WHEN LOC.NoMixLottable10 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable11 = CASE WHEN LOC.NoMixLottable11 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable12 = CASE WHEN LOC.NoMixLottable12 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable13 = CASE WHEN LOC.NoMixLottable13 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable14 = CASE WHEN LOC.NoMixLottable14 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_NoMixLottable15 = CASE WHEN LOC.NoMixLottable15 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan06)
            ,@c_CommingleSku    = CASE WHEN LOC.CommingleSku    IN ('1','Y') THEN '1' ELSE '0' END  --(Wan05)

      FROM LOC WITH (NOLOCK)
      WHERE LOC = @c_ToLoc

      --(Wan05) - START
      IF @c_ChkLocByCommingleSkuFlag = '0'
      BEGIN
         IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'
         OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan06)
         OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan06)
         BEGIN
            SET @c_CommingleSku = '0'
         END
         ELSE
         BEGIN
            SET @c_CommingleSku = '1'
         END
      END
      --(Wan05) - END

      IF @c_CommingleSku = '0'                                    --(Wan05)
      --IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1' --(Wan05)
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
                    WHERE LLI.Loc = @c_ToLoc
                    AND  (LLI.Storerkey <> @c_Storerkey OR  LLI.Sku <> @c_Sku)
                    AND   LLI.Qty - LLI.QtyPicked > 0)   --(Wan02)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62058
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move commingle sku To Location: ' + RTRIM(@c_ToLOC)
                        + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable01 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable01 <> @c_IDLottable01) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)   --(Wan02)
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62053
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable01 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable02 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable02 <> @c_IDLottable02) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)   --(Wan02)
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62054
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable02 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable03 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable03 <> @c_IDLottable03) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)   --(Wan02)
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62055
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable03 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable04 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW04
                    AND   ISNULL(LA.Lottable04, CONVERT(DATETIME, '19000101')) <> @d_IDLottable04)
                    AND   LLI.Qty - LLI.QtyPicked > 0)   --(Wan02)
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62056
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable04 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END
      --(Wan06) - START
      IF @c_NoMixLottable06 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable06 <> @c_IDLottable06) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62063
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable06 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable07 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable07 <> @c_IDLottable07) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62064
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable07 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable08 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable08 <> @c_IDLottable08) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62065
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable08 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable09 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable09 <> @c_IDLottable09) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62066
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable09 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable10 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable10 <> @c_IDLottable10) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62067
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable10 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable11 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable11 <> @c_IDLottable11) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62068
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable11 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable12 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable12 <> @c_IDLottable12) --NJOW04
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62069
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable12 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable13 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW04
                    AND    ISNULL(LA.Lottable13, CONVERT(DATETIME, '19000101')) <> @d_IDLottable13)
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62070
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable13 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable14 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW04
                    AND    ISNULL(LA.Lottable14, CONVERT(DATETIME, '19000101')) <> @d_IDLottable14)
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62071
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable14 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END

      IF @c_NoMixLottable15 = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                    JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                    WHERE LLI.Loc = @c_ToLoc
                    AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW04
                    AND    ISNULL(LA.Lottable15, CONVERT(DATETIME, '19000101')) <> @d_IDLottable15)
                    AND   LLI.Qty - LLI.QtyPicked > 0)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62072
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Not Allow to move to No Mix Lottable15 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddMoveCheck)'
            GOTO QUIT_MixLottables_Check
         END
      END
      --(Wan06) - END

      QUIT_MixLottables_Check:
   END
   --(Wan01) - END

   /* Get the status of idqtyupdate flag*/
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_AllowIDQtyUpdate = NSQLValue
      FROM NSQLCONFIG (NOLOCK)
      WHERE CONFIGKEY = 'ALLOWIDQTYUPDATE'
      IF @c_AllowIDQtyUpdate is null
      BEGIN
         SELECT @c_AllowIDQtyUpdate = '0'
      END
   END
   /* End get status of idqtyupdate flag */
 IF @n_continue =1 or @n_continue=2
   BEGIN
      /* Work Variables */
      DECLARE @c_Work_FromLoc     NVARCHAR(10)
             ,@c_Work_Fromid      NVARCHAR(18)
             ,@c_Work_lot         NVARCHAR(10)
             ,@c_Work_Storerkey   NVARCHAR(15)
             ,@c_Work_SKU         NVARCHAR(20)

      DECLARE @c_Work_toloc       NVARCHAR(10)
             ,@c_Work_toid        NVARCHAR(18)
             ,@b_addid            INT
             ,@c_InitialID        NVARCHAR(18)

      IF ISNULL(RTRIM(@c_LOT),'') <> '' AND ISNULL(RTRIM(@c_FromLOC),'') <> '' AND
         ISNULL(RTRIM(@c_StorerKey),'') <> '' AND ISNULL(RTRIM(@c_SKU),'') <> '' AND
         @n_Qty > 0
      BEGIN

         SELECT @c_Work_lot=lot, @c_Work_FromLoc=Loc, @c_Work_Fromid=id, @c_Work_Storerkey=Storerkey, @c_Work_SKU=Sku
         FROM LOTxLOCxID (NOLOCK)
         WHERE LOT=@c_LOT
           AND LOC=@c_FromLoc
           AND ID = @c_FromID
           AND Qty >= @n_Qty
           SELECT @n_cnt = @@ROWCOUNT

         IF @n_cnt <> 1
         BEGIN
            /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
            SELECT @n_continue = 3 , @n_err = 62010
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                             + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                             + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                             + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                             + ', Qty = ' + CAST(@n_Qty AS VARCHAR) 
                             + '. (nspItrnAddMoveCheck)' --IN00389849
         END
         ELSE IF @n_cnt = 1
         BEGIN
            /* Unique Row Found */
            GOTO FINDTOLOCATION
         END
      END

      /* Search By ID,LOC,QTY */
      IF ISNULL(RTRIM(@c_FromID),'') <> ''
      BEGIN
         SELECT @c_Work_FromLoc = Loc,
                @c_Work_Fromid = id,
                @c_Work_lot = lot,
                @c_Work_Storerkey = Storerkey,
                @c_Work_SKU = Sku
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_fromid
           AND QTY > 0
         SELECT @n_cnt = @@ROWCOUNT
         IF @n_cnt > 0
         BEGIN
            /* Figure out whether or not this ID exists in multiple locations. */
            /* If the ID does not exist in multiple locations then set the     */
            /* location variable to the location that the ID is in!            */
            SELECT @c_Work_FromLoc = LOC FROM LOTxLOCxID (NOLOCK)
            WHERE ID = @c_fromid AND QTY > 0
            GROUP BY LOC
            IF @@ROWCOUNT = 1
            BEGIN
               SELECT @c_fromloc = @c_Work_FromLoc
            END
            /* figure out whether this is truely a multiple row pallet in lotxlocxid table */
            /* if not replace the 0 qty with actual qty for that loc,lot and id in         */
            /* the itrn table based upon itrnkey coming down                               */
 /* We will issue the following queries in order:                               */
            /* ID and QTY> 0                                                               */
            /* ID,LOC and QTY>0                                                            */
            DECLARE @id_count INT, @id_qty INT
            SELECT @id_count = count(*) FROM lotxlocxid  (NOLOCK) WHERE ID = @c_fromid and qty > 0
            IF (@id_count = 1 and @n_Qty = 0)
            BEGIN
               SELECT @n_Qty = QTY FROM lotxlocxid (NOLOCK) WHERE ID = @c_fromid and QTY > 0
               UPDATE ITRN with (ROWLOCK)
               SET QTY = @n_Qty
               where ITRNKEY = @c_itrnkey
            END
           IF @id_count > 1
            BEGIN
               SELECT @id_count = count(*) FROM lotxlocxid (NOLOCK) WHERE ID = @c_fromid and loc = @c_fromloc and qty > 0
               IF (@id_count = 1 and @n_Qty = 0)
               BEGIN
                  SELECT @n_Qty = QTY FROM lotxlocxid (NOLOCK) WHERE ID = @c_fromid and loc = @c_fromloc and QTY > 0
                  UPDATE ITRN with (ROWLOCK)
                  SET QTY = @n_Qty
                  where ITRNKEY = @c_itrnkey
               END
            END
            /* If an SKU was passed in but no lot number, then check to see if has */
            /* only one lot.                                                       */
            /* If it does, set the incomming LOT variable to the lot number .      */
            /* If there are multiple LOTs, then error.                             */
            IF (ISNULL( RTRIM(@c_SKU),'' ) <> '' and ISNULL(RTRIM(@c_LOT),'') = '' OR @c_LOT = 'NOLOT')
            BEGIN
               SELECT @c_Work_lot = LOT FROM LOTxLOCxID (NOLOCK)
               WHERE ID = @c_fromid
               AND LOC = @c_fromloc
               AND QTY > 0
               AND SKU = @c_sku
               GROUP BY LOT
               IF @@ROWCOUNT = 1
               BEGIN
                  SELECT @c_lot = @c_Work_lot
               END
               ELSE
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 62014 --62246
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                                   + 'Sku = ' + ISNULL(RTRIM(@c_Sku),'')
                                   + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                                   + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                                   + ' - SKU Is Not Qualified. (nspItrnAddMoveCheck)' --IN00389849
               END
            END
            /* End if SKU Was Passed... */
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @n_cnt > 1
               BEGIN
                  /* Qualify Search By LOCATION */
                  SELECT @c_Work_FromLoc=Loc, @c_Work_Fromid=id,@c_Work_lot=lot, @c_Work_Storerkey = Storerkey, @c_Work_SKU=Sku
                  FROM LOTxLOCxID (NOLOCK)
                  WHERE ID = @c_fromid AND LOC=@c_fromloc AND QTY > 0
                  SELECT @n_cnt = @@ROWCOUNT
                  IF @n_cnt > 1
                  BEGIN
                     /* Qualify Search With LOT */
                     SELECT @c_Work_FromLoc=Loc, @c_Work_Fromid=id,@c_Work_lot=lot, @c_Work_Storerkey = Storerkey, @c_Work_SKU=Sku 
                     FROM LOTxLOCxID (NOLOCK) WHERE ID = @c_fromid AND QTY > 0 AND LOC=@c_fromloc AND LOT=@c_lot
                     SELECT @n_cnt = @@ROWCOUNT
                     IF @n_cnt > 1
                     BEGIN
                        /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
                        SELECT @n_continue = 3 , @n_err = 62015 --62200
                        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                                         + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                                         + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                                         + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                                         + '. (nspItrnAddMoveCheck)' --IN00389849
                     END
                  ELSE IF @n_cnt = 1
                  BEGIN
                     IF (@n_continue = 1 or @n_continue = 2)
                     BEGIN
                        /* Unique Row Found */
                        /* If the QTY is 0, assume that the full thing is being moved */
                        IF @n_Qty = 0
                        BEGIN
                           SELECT @n_Qty = qty
                           FROM LOTxLOCxID (NOLOCK)
                           WHERE ID = @c_fromid AND QTY > 0 AND LOC=@c_fromloc AND LOT=@c_lot
                           UPDATE ITRN with (ROWLOCK)
                            SET QTY = @n_Qty
                           where ITRNKEY = @c_itrnkey
                        END
                        /* End if the QTY is 0, assume that the full thing is being moved */
                        /* Find the TO Location */
                        GOTO FINDTOLOCATION
                     END
                  END
               ELSE IF ((@n_cnt = 0 and  (ISNULL(RTRIM(@c_LOT),'') = '') or @c_LOT = 'NOLOT'))
               BEGIN
                  /* This part of the code is supposed to execute only    */
                  /* once because a unique row should be found every time */
                  IF (@n_continue = 1 or @n_continue = 2)
                  BEGIN
                     /* move each lot for that pallet/loc */
                     DECLARE @c_xLot NVARCHAR(10), @n_xQty INT
                     DECLARE CURSOR_LOT INSENSITIVE CURSOR FOR
                     SELECT LOT, QTY, STORERKEY, SKU FROM LOTxLOCxID (NOLOCK)
                     WHERE ID = @c_fromid AND LOC=@c_fromloc AND QTY > 0
                     OPEN CURSOR_LOT
                     IF @@CURSOR_ROWS = 0
                     BEGIN
                        /* !! setting up variables for returning error */
                        SELECT @b_success = 0, @n_continue = 3 , @n_err = 62016 --62243
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PalletID or LOC Not Found! (nspItrnAddMoveCheck)'
                     END
                  END
                  IF @n_continue =1 or @n_continue=2
                  BEGIN
                     /* pick up the first ITRN key inserted in the trigger       */
                     /* this record is to deleted after the exit from the cursor */
                     /* loop */
                     /* what happens if this is not a multimove ?*/
                     /* will move the declare statment to top later */
                     DECLARE @c_first_itrnkey NVARCHAR(10)
                     DECLARE @n_ItrnSysId INT
                     DECLARE @c_sourcekey NVARCHAR(20)
                     DECLARE @c_sourcetype NVARCHAR(30)
                     DECLARE @c_xPackKey NVARCHAR(10)
                     DECLARE @c_xUom NVARCHAR(10)
                     DECLARE @n_UomCalc INT
                     DECLARE @n_Uomqty INT
                     DECLARE @c_xstorerkey NVARCHAR(15)
                     DECLARE @c_xsku NVARCHAR(20)
                     DECLARE @c_xstatus NVARCHAR(10)
                     /* hence I am going to pick it from itrn */
                     /* table */
                     /* pick up the status of this id from the id table */
                     SELECT @c_first_itrnkey = @c_itrnkey
                     SELECT @c_sourcekey = sourcekey,
                     @c_sourcetype = sourcetype
                     FROM ITRN (NOLOCK) WHERE
                     ITRNKEY = @c_first_itrnkey
                     IF (ISNULL(RTrim(@c_status), '') ='')
                     BEGIN
                        select @c_xstatus = status from id (NOLOCK) where
                        id = @c_fromid
                     END
                     /* pick up some values from the first record  */
                     /* to propagate to the multiple itrn records  */
                     /* delete the first extraneous record         */
                     /* what do we do if there is only one record? */
                     /* i.e. it is not a multimove                 */
                     /* if it is a multimove the code should never */
                     /* come down here after the first time        */
                     /* which creates a dummy record with qty = 0  */
                     IF (@n_continue = 1 or @n_continue = 2)
                     BEGIN
                        DELETE ITRN
                        where ItrnKey = @c_first_itrnkey
                     END
                     WHILE (1=1)   /* loop thru the Lots in the cursor */
                     BEGIN
                        FETCH NEXT FROM CURSOR_LOT INTO @c_xLot, @n_xQty,
                        @c_xstorerkey, @c_xsku
                        IF @@FETCH_STATUS <> 0
                        BEGIN
                           BREAK
                        END
                        /* Call self recursively, passing the above lot and its qty. */
                        /* This will give a uniq ID x LOC x LOT combination          */
                        /* and so the move will be done in following call            */
                        /* Get the new ITRNKey                                       */
                        IF @n_continue=1 or @n_continue=2
                        BEGIN
                           SELECT @b_success = 1
                           EXECUTE   nspg_getkey
                           'ItrnKey'
                           , 10
                           , @c_ItrnKey OUTPUT
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                           IF NOT @b_success = 1
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @n_err = 62017
                              SELECT @c_errmsg = 'nspItrnAddMoveCheck: ' + RTRIM(@c_errmsg)
                           END
                        END
                        /* End Get The new ITRNKey */
                        /* the variable @n_ItrnSysId
                        is not passed down in nspItrnAddMoveCheck */
                        /*  Calculate The Hash Key */
                        IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                           IF @n_ItrnSysId IS NULL
                           BEGIN
                              SELECT @n_ItrnSysId = RAND() * 2147483647
                           END
                        END
                        /* End Calculate The Hash Key */
                        IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                           /* pick up the pack key for the */
                           /* storerkey and sku            */
                           SELECT @c_xpackkey = SKU.packkey,
                                  @c_xUom = PACK.PACKUOM3
                           FROM SKU WITH (NOLOCK)
                           JOIN PACK WITH (NOLOCK) ON PACK.PACKKey = SKU.PACKKey
                           WHERE SKU.STORERKEY = @c_xstorerkey
                           AND   SKU.SKU = @c_xsku

                           INSERT         itrn
                           (
                                     ItrnKey
                           ,         ItrnSysId
                           ,         TranType
                           ,         StorerKey
                           ,         Sku
                           ,         Lot
                           ,         FromLoc
                           ,         FromID
                           ,         ToLoc
                           ,         ToID
                           ,         Status
                           ,         lottable01
                           ,         lottable02
                           ,         lottable03
                           ,         lottable04
                           ,         lottable05
                           ,         lottable06    --(CS01)
                           ,         lottable07    --(CS01)
                           ,         lottable08    --(CS01)
                           ,         lottable09    --(CS01)
                           ,         lottable10    --(CS01)
                           ,         lottable11    --(CS01)
                           ,         lottable12    --(CS01)
                           ,         lottable13    --(CS01)
                           ,         lottable14    --(CS01)
                           ,         lottable15    --(CS01)
                           ,         casecnt
                           ,         innerpack
                           ,         Qty
                           ,         pallet
                           ,         [cube]
                           ,         grosswgt
                           ,         netwgt
                           ,         otherunit1
                           ,         otherunit2
                           ,         SourceKey
                           ,         SourceType
                           ,         PackKey
                           ,         UOM
                           ,         UOMCalc
                           ,         UOMQty
                           ,         EffectiveDate
                           ,         Channel              --(Wan08)
                           ,         Channel_ID           --(Wan08)                              
                           )
                           VALUES    (
                                     @c_ItrnKey
                           ,         @n_ItrnSysId
                           ,         'MV'
                           ,         @c_xStorerKey
                           ,         @c_xSku
                           ,         @c_xLot    -- !!
                           ,         @c_FromLoc
                           ,         @c_fromID
                           ,         @c_ToLoc
                           ,         @c_ToID
                           ,         ISNULL(RTrim(@c_xStatus), '')
                           ,         @c_lottable01
                           ,         @c_lottable02
                           ,         @c_lottable03
                           ,         @d_lottable04
                           ,         @d_lottable05
                           ,         @c_lottable06    --(CS01)
                           ,         @c_lottable07    --(CS01)
                           ,         @c_lottable08    --(CS01)
                           ,         @c_lottable09    --(CS01)
                           ,         @c_lottable10    --(CS01)
                           ,         @c_lottable11    --(CS01)
                           ,         @c_lottable12    --(CS01)
                           ,         @d_lottable13    --(CS01)
                           ,         @d_lottable14    --(CS01)
                           ,         @d_lottable15    --(CS01)
                           ,         @n_casecnt
                           ,         @n_innerpack
                           ,         @n_xQty    -- !!
                           ,         @n_pallet
                           ,         @f_cube
                           ,         @f_grosswgt
                           ,         @f_netwgt
                           ,         @f_otherunit1
                           ,         @f_otherunit2
                           ,         @c_SourceKey
                           ,         @c_SourceType
                           ,         @c_xPackKey
                           ,         @c_xUOM
                           ,         @n_UOMCalc
                           ,         @n_UOMQty
                           ,         getdate()
                           ,         @c_Channel             --(Wan08)
                           ,         @n_Channel_ID          --(Wan08) 
                           )
                           SELECT @n_err = @@ERROR
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                           END
                        END
                     END  --  while
                     CLOSE CURSOR_LOT
                     DEALLOCATE CURSOR_LOT
                  END
                  /* that's it! we are done with the move of a full pallet (id) */
                  RETURN
                  /* Commented out by NB on 10/29/96 for full pallet move changes */
                  /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
                  /* SELECT @n_continue = 3 , @n_err = 62241 */
                  /* SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot Find Unique From ROW. (nspItrnAddMoveCheck)' */
               END
            ELSE
               BEGIN
                  /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
                  SELECT @n_continue = 3 , @n_err = 62018 --62245
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                                   + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                                   + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                                   + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                                   + '. (nspItrnAddMoveCheck)' --IN00389849
               END
               /* End Qualify Search With Lot */
            END
         ELSE IF @n_cnt = 1
         BEGIN
            /* Unique Row Found */
            /* If the QTY is 0, assume that the full thing is being moved */
            IF @n_Qty = 0
            BEGIN
               SELECT @n_Qty = qty
               FROM LOTxLOCxID (NOLOCK)
               WHERE ID = @c_fromid AND LOC=@c_fromloc AND QTY > 0
            END
            /* End if the QTY is 0, assume that the full thing is being moved */
            /* Find the TO Location */
            GOTO FINDTOLOCATION
         END
      ELSE IF @n_cnt = 0
      BEGIN
         /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
         SELECT @n_continue = 3 , @n_err = 62019 --62240
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                          + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                          + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                          + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                          + '. (nspItrnAddMoveCheck)' --IN00389849
      END
      /* End Qualify Search By Location */
   END
   ELSE IF @n_cnt = 1
   BEGIN
      /* Unique Row Found */
      /* If the QTY is 0, assume that the full thing is being moved */
      IF @n_Qty = 0
      BEGIN
         SELECT @n_Qty = qty
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_fromid AND QTY > 0
      END
      /* End if the QTY is 0, assume that the full thing is being moved */
      /* Find the TO Location */
      GOTO FINDTOLOCATION
   END
   ELSE IF @n_cnt = 0
   BEGIN
      /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
      SELECT @n_continue = 3 , @n_err = 62020 --62201
      SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                       + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                       + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                       + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                       + '. (nspItrnAddMoveCheck)' --IN00389849
   END
END
/* End - IF @n_continue = 1 or @n_continue = 2 */
END
ELSE
   BEGIN
      SELECT @n_continue = 3 , @n_err = 62021 --62241
      SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                       + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                       + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                       + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                       + '. (nspItrnAddMoveCheck)' --IN00389849
   END /* IF @n_cnt > 0 */
END     /* End Search By ID */
/* Search By LOT, LOC & QTY */
IF @n_continue=1 or @n_continue=2
BEGIN
   IF (ISNULL(RTrim(@c_LOT), '') <>'')
   BEGIN
      SELECT @c_fromID = Space(18)
      SELECT @c_Work_lot=lot, @c_Work_FromLoc=Loc, @c_Work_Fromid=id, @c_Work_Storerkey=Storerkey, @c_Work_SKU=Sku
      FROM LOTxLOCxID (NOLOCK)
      WHERE LOT=@c_LOT
      AND LOC=@c_FromLoc
      AND Qty > 0
      AND ID = @c_fromID
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt <> 1
      BEGIN
         /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
         SELECT @n_continue = 3 , @n_err = 62022 --62202
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                          + 'Lot = ' + ISNULL(RTRIM(@c_LOT),'')
                          + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                          + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                          + '. (nspItrnAddMoveCheck)' --IN00389849
      END
   ELSE IF @n_cnt = 1
   BEGIN
      /* Unique Row Found */
      GOTO FINDTOLOCATION
   END
END
ELSE
   BEGIN
      /* Search By SKU,LOC,QTY */
      /* DEV NOTE: In Future Releases, This Search Should Be By SKU+LOTTABLES+LOC+QTY */
      SELECT @c_fromID = Space(18)
      SELECT @c_Work_FromLoc=Loc, @c_Work_Fromid=id,@c_Work_lot=lot, @c_Work_Storerkey = Storerkey, @c_Work_SKU=Sku
      FROM LOTxLOCxID (NOLOCK)
      WHERE LOC=@c_fromloc AND STORERKEY = @c_StorerKey AND SKU=@c_sku AND QTY > 0
      AND ID = @c_fromID
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt <> 1
      BEGIN
         /* Out Of Luck - Cannot Continue Because Unique FROM Row Not Found */
         SELECT @n_continue = 3 , @n_err = 62023 --62203
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot find unique FROM row:' + CHAR(13)
                          + 'StorerKey = ' + ISNULL(RTRIM(@c_StorerKey),'')
                          + ', Sku = ' + ISNULL(RTRIM(@c_Sku),'')
                          + ', Loc = ' + ISNULL(RTRIM(@c_FromLoc),'')
                          + ', Id = ' + ISNULL(RTRIM(@c_FromID),'')
                          + '. (nspItrnAddMoveCheck)' --IN00389849
      END
   ELSE IF @n_cnt = 1
   BEGIN
      /* Unique Row Found */
      GOTO FINDTOLOCATION
   END
END /* End Search By LOT, LOC & QTY */
END
/* Start Of Finding TO Location And ID Record */
/* If Not Found, Insert A Blank Record Into The Appropriate Tables */
FINDTOLOCATION:
IF @n_continue=1 or @n_continue=2
BEGIN
   /* At this point, the WORK Variables have ALL data needed for the from location. */
   SELECT @c_lot = @c_Work_lot, @c_fromloc=@c_Work_FromLoc, @c_fromid=@c_Work_Fromid ,
   @c_sku=@c_Work_SKU, @c_StorerKey=@c_Work_Storerkey,@b_addid = 0
END
IF @n_continue=1 or @n_continue=2
BEGIN
   /* Default TOID and TOLOC IF Necessary */
   IF (ISNULL(RTrim(@c_ToID), '') ='')
   BEGIN
      SELECT @c_toid = @c_fromID
   END
   IF SUBSTRING(@c_toid,1,5)='CLEAR'
   BEGIN
      SELECT @c_toid = ''
   END
   IF (ISNULL(RTrim(@c_ToLoc), '') ='')
   BEGIN
      SELECT @c_toloc = @c_fromloc
   END
   IF SUBSTRING(@c_toloc,1,5)='CLEAR'
   BEGIN
      SELECT @c_toloc = ''
   END
   IF (ISNULL(RTrim(@c_PackKey), '') ='')
   BEGIN
      SELECT @c_packkey = PACKKEY FROM ID (NOLOCK) WHERE ID = @c_fromid
   END
   /* IF loseid field is set in LOC table, set ID equal to '' */
   SELECT @c_initialid = @c_toid
   IF EXISTS(SELECT * FROM LOC (NOLOCK) WHERE LOC = @c_toloc
   AND LoseID = '1')
   BEGIN
      SELECT @c_toid = ''
   END
   DECLARE @n_dummy NVARCHAR(18)
   /* Does The TO ID Exist In The ID Table ? */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_dummy=ID FROM ID (NOLOCK) WHERE ID = @c_toid
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt  = 0
      BEGIN
         /* Insert New Row Into ID,LOTxID,LOTxLOCxID */
         INSERT INTO ID (ID,PACKKEY) VALUES (@c_toid,@c_packkey)
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62024 --62204   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table ID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '

         END
         ELSE
         BEGIN
            SELECT @b_addid = 1
         END
      END -- IF @n_cnt = 0
      ELSE
   IF @n_cnt > 1
      BEGIN
         /* Whoops! Too Many IDs - Shouldn't Happen Because */
         /* ID in This Table Should be Unique And enforced By The Database Engine*/
         SELECT @n_continue = 3 , @n_err = 62025 --62207
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Too Many IDS in ID Table. (nspItrnAddMoveCheck)'
      END -- IF @n_cnt > 1
   END -- IF @n_continue....
   /* End Does The To ID Exist In The ID Table? */
   /* Does The TO Location Exist In The LOC Table? */
   /* If Not, Error! */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_dummy=LOC FROM LOC (NOLOCK) WHERE LOC = @c_toloc
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt  = 0
      BEGIN
         SELECT @n_continue = 3 , @n_err = 62026 --62208
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move TO Location Does Not Exist. (nspItrnAddMoveCheck)'
      END
   END
   /* End Does The Location Exist In The Loc table */
   /* Does the TO SKU x Location Exist In The SKUxLOC Table? */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_dummy=LOC FROM SKUxLOC (NOLOCK) WHERE STORERKEY = @c_StorerKey AND SKU = @c_sku AND LOC = @c_toloc
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt  = 0
      BEGIN
         INSERT INTO SKUxLOC (LOC,STORERKEY,SKU) VALUES (@c_toloc,@c_StorerKey,@c_sku)
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62027 --62235   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table SKUxLOC. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
         END
      END
   END
   /* End Does The TO SKU x Location Exist In The SKUxLOC Table */
   /* Does The TO Location x TO ID x LOT Exist In The LOTxLOCxID Table? */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @n_dummy=LOC FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_toloc AND ID = @c_toid AND LOT = @c_lot
      SELECT @n_cnt = @@ROWCOUNT
      IF @n_cnt  = 0
      BEGIN
         INSERT INTO LOTxLOCxID (ID,LOC,LOT,STORERKEY,SKU) VALUES (@c_toid, @c_toloc, @c_lot,@c_StorerKey,@c_sku)
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @n_err = 62028 --62210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table LOTxLOCxID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
            /* End Trap SQL Server Error */
         END
      END
   END
   /* End Does The TO Location x TO ID x LOT Exist In The LOTxLOCxID table */
END
/* End of FINDTOLOCATION: Label */
/* This Is The Start Of The Actual Move.  At This Point */
/* You should have lot, loc and ids all filled in! */
/* Remove allocations if any */
IF @n_continue = 1 or @n_continue = 2
BEGIN
   DECLARE @b_RemoveAllocations INT,
           @n_QtyOnHand         INT
         , @n_qtyallocated      INT             --(Wan04)
         , @n_ExistsCnt         INT = 0         --(Wan10)
         , @n_QtyAvailable      INT             --NJOW03 

   SELECT @b_RemoveAllocations =
      CASE WHEN Qty - (QtyAllocated + QtyPicked) < @n_Qty
           THEN 1
           WHEN @c_MoveRefKey <> ''             --(Wan04)
           THEN 1                               --(Wan04)
           ELSE 0
      END,
      @n_QtyOnHand = Qty,
      @n_QtyAvailable = Qty - (QtyAllocated + QtyPicked) --NJOW03
   FROM LOTxLOCxID (NOLOCK)
   WHERE LOT = @c_LOT and LOC = @c_FromLoc and ID=@c_FromID

   -- (Shong01)
   -- Not allow to move partial pallet, system have no idea which pickdetail to update
   IF @b_RemoveAllocations = 1 AND @n_QtyOnHand <> @n_Qty AND @c_MoveRefKey = ''   --(Wan04)
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62061
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Partial Pallet With Allocated Qty Not Allow to Move. Lot=' + @c_Lot +  ' FromLoc=' + @c_FromLoc + ' FromID=' + RTRIM(@c_FromID) +
             ' QtyOnHand='+CAST(@n_QtyOnHand AS NVARCHAR) + ' QtyAvailable=' + CAST(@n_QtyAvailable AS NVARCHAR) + ' QtyToMove=' + CAST(@n_Qty AS NVARCHAR) + ' (nspItrnAddMoveCheck)' --NJOW03
      --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Partial Pallet With Allocated Qty Not Allow to Move. (nspItrnAddMoveCheck)'
   END

   --(Wan04) - START   
   IF @c_MoveRefKey <> ''
   BEGIN                     
      /*
      -- Wan07: Fixed Performance Issue (START)
      --IF EXISTS ( SELECT 1
      --            FROM PICKDETAIL WITH (NOLOCK)
      --            WHERE MoveRefKey = @c_MoveRefKey
      --            AND   ( Lot <> @c_LOT OR
      --                    Loc <> @c_FromLoc OR
      --                    ID  <> @c_FromID )
      --            )      
      IF EXISTS ( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE MoveRefKey <> @c_MoveRefKey AND MoveRefKey <> '' AND MoveRefKey IS NOT NULL
                  AND   Lot = @c_LOT
                  AND   Loc = @c_FromLoc
                  AND   ID  = @c_FromID
                  AND Status < '9'
                  AND shipflag <> 'Y'
                )
                
      --Wan07: Fixed Performance Issue (END)
      */  
      --(Wan10) - START    
      --IF EXISTS (SELECT 1 
      --           FROM PICKDETAIL WITH (NOLOCK)
      --           WHERE Moverefkey = @c_MoveRefkey
      --           AND Storerkey = @c_Storerkey
      --           AND Loc = @c_FromLoc
      --           AND (Lot <> @c_Lot
      --                OR ID <> @c_FromID)
      --           AND Status <> '9'
      --           AND Shipflag <> 'Y'     
      --           )  --NJOW02
      SET @n_ExistsCnt = 0
      SELECT TOP 1 @n_ExistsCnt = 1   
                 FROM PICKDETAIL WITH (NOLOCK)  
                 WHERE Moverefkey = @c_MoveRefkey  
                 AND Storerkey = @c_Storerkey  
                 AND Loc = @c_FromLoc  
                 AND (Lot <> @c_Lot  
                      OR ID <> @c_FromID)  
                 AND Status <> '9'  
                 AND Shipflag <> 'Y'       
                 OPTION (OPTIMIZE FOR (@c_FromLoc UNKNOWN))

      IF @n_ExistsCnt = 1      
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62062
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not a unique batch move. (nspItrnAddMoveCheck)'
      END   
      --(Wan10) - END    
   END
 
   --(Wan04) - END
--   IF @b_RemoveAllocations = 1
--   BEGIN
--      UPDATE PICKDETAIL with (ROWLOCK)
--      SET QTYMOVED = QTY,
--           Qty = 0
--      WHERE LOT = @c_LOT and LOC = @c_FromLoc and ID=@c_FromID
--      AND STATUS < '9'
--      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--      IF @n_err <> 0
--      BEGIN
--         SELECT @n_continue = 3
--
--         SELECT @n_err = 62029 --62244   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PickDetail. (nspItrnAddMoveCheck)'
--            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
--
--      END
--   END
   /* WHERE LOT = @c_LOT and LOC = @c_FromLoc and ID=@c_FromID  */
END
/* End Remove allocations if any */

   --NJOW05 S
   IF (@n_continue = 1 or @n_continue = 2) AND ISNULL(@c_Channel, '') <> '' 
   BEGIN
      SELECT @c_FromFacility = LOC.Facility         
      FROM LOC WITH (NOLOCK)
      WHERE LOC.Loc = @c_FromLoc

      SET @c_ToChannelInventoryMgmt = '0'
      SET @b_success = 0
      Execute nspGetRight2 
         @c_facility
      ,  @c_StorerKey            -- Storer
      ,  ''                      -- Sku
      ,  'ChannelInventoryMgmt'  -- ConfigKey
      ,  @b_success                    OUTPUT
      ,  @c_ToChannelInventoryMgmt     OUTPUT
      ,  @n_err                        OUTPUT
      ,  @c_ErrMsg                     OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62073
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight. (nspItrnAddMoveCheck) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      END
      
      IF @n_continue = 1 or @n_continue = 2   
      BEGIN      
         IF @c_FromFacility = @c_Facility
         BEGIN
            SET @c_FromChannelInventoryMgmt = @c_ToChannelInventoryMgmt
         END
         ELSE
         BEGIN
            SET @c_FromChannelInventoryMgmt = '0'
            SET @b_success = 0
            Execute nspGetRight2 
               @c_Fromfacility
            ,  @c_StorerKey            -- Storer
            ,  ''                      -- Sku
            ,  'ChannelInventoryMgmt'  -- ConfigKey
            ,  @b_success                    OUTPUT
            ,  @c_FromChannelInventoryMgmt   OUTPUT
            ,  @n_err                        OUTPUT
            ,  @c_ErrMsg                     OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err = 62074
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight. (nspItrnAddMoveCheck) ' + ISNULL(RTRIM(@c_ErrMsg),'')
            END
         END
      END   

      IF (@n_continue = 1 or @n_continue = 2)  
      BEGIN
         IF @c_FromChannelInventoryMgmt = '1' AND @c_FromFacility <> @c_Facility  
         BEGIN
            IF ISNULL(@n_Channel_ID,0) = 0
            BEGIN
               SET @n_FromChannel_ID = 0
               
               BEGIN TRY
                  EXEC isp_ChannelGetID
                      @c_StorerKey  = @c_StorerKey
                     ,@c_Sku        = @c_SKU
                     ,@c_Facility   = @c_FromFacility
                     ,@c_Channel    = @c_Channel
                     ,@c_LOT        = @c_LOT
                     ,@n_Channel_ID = @n_FromChannel_ID  OUTPUT
                     ,@b_Success    = @b_Success         OUTPUT
                     ,@n_ErrNo      = @n_Err             OUTPUT
                     ,@c_ErrMsg     = @c_ErrMsg          OUTPUT 
               
               END TRY
               BEGIN CATCH
                     SET @n_err = ERROR_NUMBER()
                     SET @c_ErrMsg = ERROR_MESSAGE()
                            
                     SET @n_continue = 3
                     SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddMoveCheck)' 
               END CATCH                                          
            END 

            IF (@n_continue = 1 or @n_continue = 2) AND @n_FromChannel_ID > 0
            BEGIN
               IF EXISTS(  SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                           WHERE ci.Channel_ID = @n_FromChannel_ID 
                           AND (ci.Qty - ci.QtyAllocated - ci.QtyOnHold - @n_Qty) < 0)
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 62077 
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                                 +'Channel Qty available less than Qty to move over facility. (nspItrnAddMoveCheck)'
               END

               IF (@n_continue = 1 or @n_continue = 2) 
               BEGIN
                  UPDATE ChannelInv WITH (ROWLOCK)
                     SET Qty      = Qty - @n_Qty
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME() 
                  WHERE Channel_ID = @n_FromChannel_ID 

                  SET @n_err = @@ERROR
                  SET @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 62078
                     SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                     +': Update Failed on Table ChannelInv. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  END  
               END
            END
         END             
         
         IF @c_ToChannelInventoryMgmt = '1' AND @c_FromFacility <> @c_Facility
         BEGIN
            IF ISNULL(@n_Channel_ID,0) = 0
            BEGIN
               SET @n_ToChannel_ID = 0
            
               BEGIN TRY
                  EXEC isp_ChannelGetID 
                      @c_StorerKey  = @c_StorerKey
                     ,@c_Sku        = @c_SKU
                     ,@c_Facility   = @c_Facility
                     ,@c_Channel    = @c_Channel
                     ,@c_LOT        = @c_LOT
                     ,@n_Channel_ID = @n_ToChannel_ID OUTPUT
                     ,@b_Success    = @b_Success      OUTPUT
                     ,@n_ErrNo      = @n_Err          OUTPUT
                     ,@c_ErrMsg     = @c_ErrMsg       OUTPUT                        
               END TRY
               BEGIN CATCH
                     SET @n_err = ERROR_NUMBER()
                     SET @c_ErrMsg = ERROR_MESSAGE()
                         
                     SET @n_continue = 3
                     SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddMoveCheck)' 
               END CATCH                                          
            END 

            IF (@n_continue = 1 or @n_continue = 2) AND @n_ToChannel_ID > 0
            BEGIN
               UPDATE ChannelInv WITH (ROWLOCK)
               SET Qty      = Qty + @n_Qty
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME() 
               WHERE Channel_ID = @n_ToChannel_ID 
               
               SET @n_err = @@ERROR
               SET @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 62081 
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                  +': Update Failed on Table ChannelInv. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               END                           
               
               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  SET @n_Channel_ID = @n_ToChannel_ID
               END
            END   
         END               
      END        
   END
   --NJOW05 E

   -- (Wan09) - START: User Channel InventoryHold to Hold Instead
   /*
   -- (Wan08) = START
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN
      SELECT @c_FromFacility = LOC.Facility         
            ,@c_FromLocationFlag = LOC.LocationFlag
            ,@c_FromLocStatus= LOC.Status
            ,@c_FromLocTypeSkipChannel = CASE WHEN CODELKUP.UDF01 = 'MOVESKIPCHANNEL' THEN  'Y' ELSE 'N' END  --NJOW01
      FROM LOC WITH (NOLOCK)
      JOIN CODELKUP (NOLOCK) ON LOC.LocationType = CODELKUP.Code AND CODELKUP.ListName = 'LOCTYPE'   --NJOW01   
      WHERE LOC.Loc = @c_FromLoc

      SET @c_ToChannelInventoryMgmt = '0'
      SET @b_success = 0
      Execute nspGetRight2 
         @c_facility
      ,  @c_StorerKey            -- Storer
      ,  ''                      -- Sku
      ,  'ChannelInventoryMgmt'  -- ConfigKey
      ,  @b_success                    OUTPUT
      ,  @c_ToChannelInventoryMgmt     OUTPUT
      ,  @n_err                        OUTPUT
      ,  @c_ErrMsg                     OUTPUT


      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62073
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight. (nspItrnAddMoveCheck) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      END
      
      IF @n_continue = 1 or @n_continue = 2   
      BEGIN      
         IF @c_FromFacility = @c_Facility
         BEGIN
            SET @c_FromChannelInventoryMgmt = @c_ToChannelInventoryMgmt
         END
         ELSE
         BEGIN
            SET @c_FromChannelInventoryMgmt = '0'
            SET @b_success = 0
            Execute nspGetRight2 
               @c_Fromfacility
            ,  @c_StorerKey            -- Storer
            ,  ''                      -- Sku
            ,  'ChannelInventoryMgmt'  -- ConfigKey
            ,  @b_success                    OUTPUT
            ,  @c_FromChannelInventoryMgmt   OUTPUT
            ,  @n_err                        OUTPUT
            ,  @c_ErrMsg                     OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err = 62074
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight. (nspItrnAddMoveCheck) ' + ISNULL(RTRIM(@c_ErrMsg),'')
            END
         END
      END  
   END        

   IF @n_continue = 1 or @n_continue = 2 
   BEGIN  
      SET @n_FromQtyHold = -1 * @n_Qty
      SET @n_FromQtyMove = -1 * @n_Qty
      IF (@c_FromLocationFlag = 'NONE' AND @c_FromLocStatus = 'OK') OR @c_FromChannelZeroLocHold = '1'   --(Wan09)
      BEGIN
         SET @n_FromQtyHold = 0
      END

      SET @n_ToQtyHold = @n_Qty
      SET @n_ToQtyMove = @n_Qty
      IF (@c_ToLocationFlag = 'NONE' AND @c_ToLocStatus = 'OK') OR @c_ToChannelZeroLocHold = '1'         --(Wan09)
      BEGIN
         SET @n_ToQtyHold = 0
      END

      IF @c_FromFacility = @c_Facility
      BEGIN
         SET @n_ToQtyHold = @n_FromQtyHold + @n_ToQtyHold
         SET @n_ToQtyMove = @n_FromQtyMove + @n_ToQtyMove              
      END

      IF ISNULL(RTRIM(@c_Channel), '') = ''
      BEGIN
         IF @c_ToChannelInventoryMgmt = '1' AND @n_ToQtyHold <> 0
         BEGIN
            SET @b_ChannelIsNeeded = 1
         END
         ELSE IF @c_FromChannelInventoryMgmt = '1' AND @n_FromQtyHold <> 0 
             AND @c_FromFacility <> @c_Facility
         BEGIN
            SET @b_ChannelIsNeeded = 1
         END
         
         --NJOW01 
         IF @c_FromLocTypeSkipChannel = 'Y' OR @c_ToLocTypeSkipChannel = 'Y' 
         BEGIN
            SET @b_ChannelIsNeeded = 0
            IF @c_ToChannelInventoryMgmt = '1' AND @c_ToLocTypeSkipChannel <> 'Y' AND (@c_ToLocationFlag <> 'NONE' OR @c_ToLocStatus <> 'OK')
                SET @b_ChannelIsNeeded = 1
            IF @c_FromChannelInventoryMgmt = '1' AND @c_FromLocTypeSkipChannel <> 'Y' AND (@c_FromLocationFlag <> 'NONE' OR @c_FromLocStatus <> 'OK')           
                SET @b_ChannelIsNeeded = 1
         END    
             
         IF @b_ChannelIsNeeded = 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62075  
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                         +': Move not allow. Channel is required. (nspItrnAddMoveCheck)' 

         END
      END
         
      -- Channel <> '' - START
      IF (@n_continue = 1 or @n_continue = 2) AND ISNULL(RTRIM(@c_Channel), '') <> ''  
      BEGIN
         IF @c_FromChannelInventoryMgmt = '1' AND @c_FromFacility <> @c_Facility  
         BEGIN
            IF ISNULL(@n_Channel_ID,0) = 0
            BEGIN
               SET @n_FromChannel_ID = 0
               
               BEGIN TRY
                  EXEC isp_ChannelGetID
                      @c_StorerKey  = @c_StorerKey
                     ,@c_Sku        = @c_SKU
                     ,@c_Facility   = @c_FromFacility
                     ,@c_Channel    = @c_Channel
                     ,@c_LOT        = @c_LOT
                     ,@n_Channel_ID = @n_FromChannel_ID  OUTPUT
                     ,@b_Success    = @b_Success         OUTPUT
                     ,@n_ErrNo      = @n_Err             OUTPUT
                     ,@c_ErrMsg     = @c_ErrMsg          OUTPUT 
               
               END TRY
               BEGIN CATCH
                     SET @n_err = ERROR_NUMBER()
                     SET @c_ErrMsg = ERROR_MESSAGE()
                            
                     SET @n_continue = 3
                     SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddMoveCheck)' 
               END CATCH                                          
            END 

            IF (@n_continue = 1 or @n_continue = 2) AND @n_FromChannel_ID > 0
            BEGIN
               IF EXISTS(  SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                           WHERE ci.Channel_ID = @n_FromChannel_ID 
                           AND (ci.QtyOnHold + @n_FromQtyHold) < 0)
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 62076
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                                 +'Channel inventory Qty on hold < 0. (nspItrnAddMoveCheck)'
               END

               IF (@n_continue = 1 or @n_continue = 2)
               BEGIN
                  IF EXISTS(  SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                              WHERE ci.Channel_ID = @n_FromChannel_ID 
                              AND (ci.Qty + @n_FromQtyMove) - ci.QtyAllocated - (ci.QtyOnHold + @n_FromQtyHold) < 0)
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 62077 
                     SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                                    +'Channel Qty available less than Qty on Hold. (nspItrnAddMoveCheck)'
                  END
               END

               IF (@n_continue = 1 or @n_continue = 2) 
               BEGIN
                  UPDATE ChannelInv WITH (ROWLOCK)
                     SET Qty      = Qty + @n_FromQtyMove
                        ,QtyOnHold= QtyOnHold + @n_FromQtyHold  
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME() 
                  WHERE Channel_ID = @n_FromChannel_ID 

                  SET @n_err = @@ERROR
                  SET @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 62078
                     SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                     +': Update Failed on Table ChannelInv. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  END  
               END
            END
         END         

         IF @n_continue = 1 or @n_continue = 2 
         BEGIN  
            IF @c_ToChannelInventoryMgmt = '1'  
            BEGIN
               IF ISNULL(@n_Channel_ID,0) = 0
               BEGIN
                  SET @n_ToChannel_ID = 0
               
                  BEGIN TRY
                     EXEC isp_ChannelGetID 
                           @c_StorerKey  = @c_StorerKey
                        ,@c_Sku        = @c_SKU
                        ,@c_Facility   = @c_Facility
                        ,@c_Channel    = @c_Channel
                        ,@c_LOT        = @c_LOT
                        ,@n_Channel_ID = @n_ToChannel_ID OUTPUT
                        ,@b_Success    = @b_Success      OUTPUT
                        ,@n_ErrNo      = @n_Err          OUTPUT
                        ,@c_ErrMsg     = @c_ErrMsg       OUTPUT
                        --,@b_CreateNewID= @b_CreateNewID                     
                  END TRY
                  BEGIN CATCH
                        SET @n_err = ERROR_NUMBER()
                        SET @c_ErrMsg = ERROR_MESSAGE()
                            
                        SET @n_continue = 3
                        SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddMoveCheck)' 
                  END CATCH                                          
               END 

               IF (@n_continue = 1 or @n_continue = 2) AND @n_ToChannel_ID > 0
               BEGIN
                  IF @n_ToQtyHold <> 0
                  BEGIN
                     IF EXISTS(  SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                                 WHERE ci.Channel_ID = @n_ToChannel_ID 
                                 AND (ci.QtyOnHold + @n_ToQtyHold) < 0)
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 62079
                        SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                                       +'Channel inventory Qty on hold < 0. (nspItrnAddMoveCheck)'
                     END

                     IF (@n_continue = 1 or @n_continue = 2)
                     BEGIN
                        IF EXISTS(  SELECT 1 FROM ChannelInv AS ci WITH(NOLOCK)
                                    WHERE ci.Channel_ID = @n_ToChannel_ID 
                                    AND (ci.Qty + @n_ToQtyMove) - ci.QtyAllocated - (ci.QtyOnHold + @n_ToQtyHold) < 0)
                        BEGIN
                           SET @n_continue = 3
                           SET @n_err = 62080 
                           SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                                          +'Channel Qty available less than Qty on Hold. (nspItrnAddMoveCheck)'
                        END
                     END
                  END

                  IF (@n_continue = 1 or @n_continue = 2) AND (@n_ToQtyMove <> 0 OR @n_ToQtyHold <> 0)
                  BEGIN
                     UPDATE ChannelInv WITH (ROWLOCK)
                     SET Qty      = Qty + @n_ToQtyMove
                        ,QtyOnHold= QtyOnHold + @n_ToQtyHold   
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME() 
                     WHERE Channel_ID = @n_ToChannel_ID 

                     SET @n_err = @@ERROR
                     SET @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 62081 
                        SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)
                        +': Update Failed on Table ChannelInv. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                     END                           

                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN
                        SET @n_Channel_ID = @n_ToChannel_ID
                     END
                  END
               END 
            END
         END
      END
      -- Channel <> '' --END
   END
   -- (Wan08) = END 
   */
   -- (Wan09) - END: User Channel InventoryHold to Hold Instead
      
MOVESTART:
/* Start Update to Gsix tables */
/*VXN*/
DECLARE @n_ti INT, @n_hi INT, @n_totalqty INT, @c_currentpackkey NVARCHAR(10)
IF @c_AllowIDQtyUpdate = '1'
BEGIN
   /* Reduce The FROM ID in The ID Table */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE ID with (ROWLOCK) SET QTY = QTY - @n_Qty WHERE ID = @c_fromID
      /* Check SQL Error Message */
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62030 --62214   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
      END
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62031 --62215
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table ID Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
   END
END
/* Update the ID table with TIxHI numbers */
IF (@n_continue =1 or @n_continue=2)
BEGIN
   IF (ISNULL(RTrim(@c_FromID), '') <>'')
   BEGIN
      SELECT @n_ti = 0, @n_hi = 0, @n_totalqty = 0
      SELECT @n_totalqty = QTY,@c_currentpackkey = PACKKEY FROM ID (NOLOCK) WHERE ID = @c_fromid
      IF (ISNULL(RTrim(@c_CurrentPackkey), '') <>'')
      BEGIN
         SELECT @n_hi = Ceiling(@n_totalqty / CaseCnt / PALLETTI), @n_ti = PALLETTI
         FROM PACK (NOLOCK)
         WHERE PACKKEY = @c_currentpackkey
         AND PALLETTI > 0
         AND CASECNT > 0
         IF @n_ti > 0 or @n_hi > 0
         BEGIN
            UPDATE ID with (ROWLOCK) SET PutawayTI = @n_ti, PutawayHI = @n_hi
            WHERE ID = @c_fromid
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 62032 --62248   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
            END
         END
      END
   END
END
/* End Update the ID table with TIxHI numbers */
END
/* Add To the TOID In The ID Table */
IF @n_continue=1 or @n_continue=2
BEGIN
   /* Fix blank column 'Status' */
   IF @b_addid = 1
   BEGIN
      IF (ISNULL(RTrim(@c_status), '') ='')
      BEGIN
         /* Let the status of the TOID be the same as the FROMID. */
         /* However, only allow this if the TOID is new!  */
         SELECT @c_Status = Status FROM ID (NOLOCK) WHERE ID = @c_fromID
      END
   END
   ELSE
      BEGIN
         /* The TOID is not new, therefore the status cannot be changed       */
         /* Warning:  Attempting to change this behaviour can really screw up */
         /* the HOLD module. Be very very careful!                            */
         SELECT @c_Status = Status FROM ID (NOLOCK) WHERE ID = @c_TOID
      END
      /*VXN*/
      IF @c_AllowIDQtyUpdate = '1'
      BEGIN
         /* Update table 'Id' */
         UPDATE ID with (ROWLOCK) SET QTY = QTY + @n_Qty, Status = @c_Status WHERE ID = @c_TOID
      END
      ELSE
      BEGIN
         --tlting01
         SET @n_cnt = 0
         SELECT @n_cnt = COUNT(1) FROM  ID with (NOLOCK) WHERE ID = @c_toid

         /* Update table 'Id' */
         IF EXISTS ( SELECT 1 FROM  ID with (NOLOCK) WHERE ID = @c_TOID AND [Status] <> @c_Status )
         BEGIN
            UPDATE ID with (ROWLOCK) SET Status = @c_Status WHERE ID = @c_TOID
         END
      END
      /* Check SQL Error Message */
      SELECT @n_err = @@ERROR -- , @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62033 --62218   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '

      END
   -- ELSE IF @n_cnt = 0
   IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62034 --62219
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table ID Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
   END
   /* Update the ID table with TIxHI numbers */
   IF (@n_continue =1 or @n_continue=2)
   BEGIN
      IF (ISNULL(RTrim(@c_ToID), '') <>'')
      BEGIN
         SELECT @n_ti = 0, @n_hi = 0, @n_totalqty = 0
         SELECT @n_totalqty = QTY,@c_currentpackkey = PACKKEY FROM ID (NOLOCK) WHERE ID = @c_toid
         IF (ISNULL(RTrim(@c_CurrentPackkey), '') <>'')
         BEGIN
            SELECT @n_hi = Ceiling(@n_totalqty/ CaseCnt / PALLETTI), @n_ti = PALLETTI
            FROM PACK (NOLOCK)
            WHERE PACKKEY = @c_currentpackkey
            AND PALLETTI > 0
            AND CASECNT > 0
            IF @n_ti > 0 or @n_hi > 0
            BEGIN
               UPDATE ID with (ROWLOCK) SET PutawayTI = @n_ti, PutawayHI = @n_hi
               WHERE ID = @c_toid
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  /* Trap SQL Server Error */
                  SELECT @n_err = 62035 --62249   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
                  /* End Trap SQL Server Error */
               END
            END
         END
      END
   END
   /* End Update the ID table with TIxHI numbers */
END
/* Reduce From The SKUxLOC Combo */
IF @n_continue=1 or @n_continue=2
BEGIN
 -- SOS140686 (SHONG)
--   QTYEXPECTED =
--   CASE
--    WHEN LOC.LocationType IN ('DYNPICKP', 'DYNPICKR')
--
--         THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) -
--            (CASE WHEN SKUxLOC.Qty <= 0 THEN @n_Qty
--                  WHEN @n_Qty > SKUxLOC.Qty THEN @n_Qty - SKUxLOC.Qty
--                  ELSE SKUxLOC.Qty - @n_Qty
--             END) )
--      WHEN @c_AllowOverAllocations = '0' THEN 0
--      WHEN ( SKUxLOC.Locationtype NOT IN ('PICK','CASE') AND
--             LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR') ) THEN 0
--      WHEN  ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) > (SKUxLOC.Qty - @n_Qty) )
--               AND @c_AllowOverAllocations = '1'
--               AND ( SKUxLOC.locationtype IN ('PICK','CASE') )
--         THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) -
--                  (CASE WHEN SKUxLOC.Qty <= 0 THEN @n_Qty
--                        WHEN @n_Qty > SKUxLOC.Qty THEN @n_Qty - SKUxLOC.Qty
--                        ELSE SKUxLOC.Qty - @n_Qty
--                   END) )
--      ELSE 0
--   END,

   UPDATE SKUxLOC with (ROWLOCK)
   SET
   QTYEXPECTED =
   CASE
      WHEN  ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) > (SKUxLOC.Qty - @n_Qty) )
         THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) -
                  (CASE WHEN SKUxLOC.Qty <= 0 THEN @n_Qty
                        WHEN @n_Qty > SKUxLOC.Qty THEN @n_Qty - SKUxLOC.Qty
                        ELSE SKUxLOC.Qty - @n_Qty
                   END) )
      ELSE 0
   END,
   QtyReplenishmentOverride =
   CASE
      WHEN QtyReplenishmentOverride - @n_Qty > 0
           THEN QtyReplenishmentOverride - @n_Qty
      ELSE 0
   END,
   Qty = Qty - @n_Qty
   FROM SKUxLOC
   --JOIN LOC (NOLOCK) ON LOC.LOC = SKUxLOC.LOC
   WHERE SKUxLOC.STORERKEY = @c_StorerKey
   and SKUxLOC.SKU = @c_SKU
   and SKUxLOC.LOC = @c_FromLoc

   /* Check SQL Error Message */
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      /* Trap SQL Server Error */
      SELECT @n_err = 62036 --62236   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SKUxLOC. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
      /* End Trap SQL Server Error */
   END
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_err = 62037 --62237
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table SKUxLOC Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
   END
END
/* Add To The SKUxLOC Combo */
IF @n_continue=1 or @n_continue=2
BEGIN
 -- SOS140686 (SHONG)
--   CASE
--    WHEN LOC.LocationType IN ('DYNPICKP', 'DYNPICKR')
--    THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) )
--      WHEN @c_AllowOverAllocations = '0' THEN 0
--      WHEN ( SKUxLOC.Locationtype NOT IN ('PICK','CASE') AND
--             LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR') ) THEN 0
--      WHEN  ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) ) >= 0
--               and @c_AllowOverAllocations = '1'
--               and ( SKUxLOC.locationtype IN ('PICK','CASE'))
--         THEN ( (SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty) )
--      ELSE 0
--   END,

   UPDATE SKUxLOC with (ROWLOCK)
   SET QtyExpected =
   CASE
      WHEN  ((SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty)) >= 0
         THEN ((SKUxLOC.QtyAllocated + SKUxLOC.QtyPicked) - (SKUxLOC.Qty + @n_Qty))
      ELSE 0
   END,
   QtyReplenishmentOverride =
   CASE
      WHEN QtyReplenishmentOverride - @n_Qty > 0
         THEN QtyReplenishmentOverride - @n_Qty
      ELSE 0
   END,
   Qty = Qty + @n_Qty
   FROM SKUxLOC
   --JOIN LOC (NOLOCK) ON LOC.LOC = SKUxLOC.LOC
   WHERE SKUxLOC.STORERKEY = @c_StorerKey
     and SKUxLOC.SKU = @c_SKU
     and SKUxLOC.LOC = @c_ToLoc

   /* Check SQL Error Message */
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      /* Trap SQL Server Error */
      SELECT @n_err = 62038 --62238   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SKUxLOC. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
      /* End Trap SQL Server Error */
   END
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62039 --62239
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table SKUxLOC Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
   END
END
/* Reduce The FROM LOTxLOCxID Combo */
IF @n_continue=1 or @n_continue=2
BEGIN
 -- SOS140686 (SHONG)
--   CASE
--       WHEN LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') AND
--           ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty)) >= 0
--         THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty))
--         WHEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty)) >= 0 AND
--             @c_AllowOverAllocations ='1'
--           THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty))
--         WHEN @c_AllowOverAllocations = '0' THEN 0
--         ELSE 0
--    END

 UPDATE LOTxLOCxID with (ROWLOCK)
   SET Qty = Qty - @n_Qty,
     LOTxLOCxID.QtyExpected =
   CASE
      WHEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty)) >= 0
        THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty - @n_Qty))
      ELSE 0
   END
 FROM LOTxLOCxID
 --JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc
 WHERE  LOTxLOCxID.LOT = @c_LOT
 AND    LOTxLOCxID.LOC = @c_FromLoc
 AND   LOTxLOCxID.ID=@c_FromID

   /* Check SQL Error Message */
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      /* Trap SQL Server Error */
      SELECT @n_err = 62040 --62231   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
      /* End Trap SQL Server Error */
   END
ELSE IF @n_cnt = 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 62041 --62232
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table LOTxLOCxID Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
END
END
/* Add To The TO LOTxLOCxID Combo */
IF @n_continue=1 or @n_continue=2
BEGIN

 -- SOS140686 (SHONG)
--  CASE
--      WHEN LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') AND
--          ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty)) >= 0
--        THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty))
--        WHEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty)) >= 0 AND
--            @c_AllowOverAllocations ='1'
--          THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty))
--        WHEN @c_AllowOverAllocations = '0' THEN 0
--        ELSE 0
--   END,

 UPDATE LOTxLOCxID with (ROWLOCK)
 SET LOTxLOCxID.QtyExpected =
   CASE
     WHEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty)) >= 0
       THEN ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)-(LOTxLOCxID.Qty + @n_Qty))
     WHEN @c_AllowOverAllocations = '0' THEN 0
     ELSE 0
   END,
   Qty = LOTxLOCxID.QTY + @n_Qty
 FROM LOTxLOCxID
 --JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc
 WHERE  LOTxLOCxID.LOT = @c_LOT
 AND    LOTxLOCxID.LOC = @c_ToLoc
 AND    LOTxLOCxID.ID = @c_toid

/* Check SQL Error Message */
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   /* Trap SQL Server Error */
   SELECT @n_err = 62042 --62233   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
   /* End Trap SQL Server Error */
END
ELSE IF @n_cnt = 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 62043 --62234
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table LOTxLOCxID Returned Zero Rows Affected. (nspItrnAddMoveCheck)'
END
END
/* Update QTYPENDINGIN field...                                    */
/* Note that the variable @c_initialid holds the ID that the user  */
/* passed.  This id will be different from the @c_toid that has    */
/* been used everywhere so far IF the location field LOSEID        */
/* has been set to '1'.                                      */
/* We need to reduce QTYPENDINGIN for the ID that the user passed  */
/* into this program so our whereclause will be using @c_initialid */
IF @n_continue=1 or @n_continue=2
BEGIN
   -- By SHONG 15th Aug 2018 (SWT02)

   DECLARE @c_IDFound NVARCHAR(18) = '',
           @c_PendingMoveInQtyIgnoreID NVARCHAR(10) = '0',
           @n_PendingMoveInQty INT = 0, 
           @n_RemainPendingMoveIN INT = 0 
            
      
   --IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)  
   --          WHERE LOT = @c_LOT and LOC = @c_ToLoc 
   --          and ID = @c_InitialID   
   --          AND PendingMoveIN > 0) 
   
   Select @b_success = 0          
   Execute nspGetRight 
   @c_Facility,          
   @c_StorerKey,  -- Storer          
   '',            -- Sku          
   'PendingMoveInQtyIgnoreID',  -- ConfigKey          
   @b_success               OUTPUT,          
   @c_PendingMoveInQtyIgnoreID  OUTPUT,          
   @n_err                   OUTPUT,          
   @c_errmsg                OUTPUT          
   If @b_success <> 1          
   Begin          
      Select @n_continue = 3, @n_err = 62011, @c_errmsg = 'nspItrnAddMoveCheck:' + RTRIM(@c_errmsg) 
   End    
   
   IF @c_PendingMoveInQtyIgnoreID = '1' 
   AND EXISTS(SELECT 1 FROM LOC (NOLOCK) 
              WHERE Loc = @c_ToLoc 
              AND LOC.LocationType='ROBOTSTG' 
              AND LOC.LocationCategory='ROBOT' )
   BEGIN
      SET @n_RemainPendingMoveIN = @n_Qty 
      
      DECLARE CUR_PENDING_MOVE_IN CURSOR LOCAL FAST_FORWARD READ_ONLY
      FOR SELECT [ID], PendingMoveIN FROM LOTxLOCxID WITH (NOLOCK)  
      WHERE LOT = @c_LOT 
      AND   LOC = @c_ToLoc 
      AND   PendingMoveIN > 0
      ORDER BY CASE WHEN ID = @c_InitialID THEN 1 ELSE 5 END 
      
      OPEN CUR_PENDING_MOVE_IN
      
      FETCH NEXT FROM CUR_PENDING_MOVE_IN INTO @c_IDFound, @n_PendingMoveInQty 
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         IF @n_PendingMoveInQty > @n_RemainPendingMoveIN
            SET @n_PendingMoveInQty = @n_RemainPendingMoveIN
            
         UPDATE LOTxLOCxID with (ROWLOCK)     
         SET PENDINGMOVEIN =  CASE WHEN PENDINGMOVEIN - @n_PendingMoveInQty < 0  THEN 0        
                                   ELSE PENDINGMOVEIN - @n_PendingMoveInQty        
                              END        
         WHERE LOT = @c_LOT 
         AND LOC = @c_ToLoc 
         AND ID = @c_IDFound 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
         IF @n_err <> 0        
         BEGIN        
            SELECT @n_continue = 3                         
            SELECT @n_err = 62045      
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddMoveCheck)' + ' ( '   
                  + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '        
                 
         END   
                  
         SET @n_RemainPendingMoveIN = @n_RemainPendingMoveIN - @n_PendingMoveInQty
         
         IF @n_RemainPendingMoveIN <= 0 
            BREAK  
         FETCH NEXT FROM CUR_PENDING_MOVE_IN INTO @c_IDFound, @n_PendingMoveInQty 
      END
      CLOSE CUR_PENDING_MOVE_IN
      DEALLOCATE CUR_PENDING_MOVE_IN 
   END
   ELSE 
   BEGIN
      SELECT TOP 1 @c_IDFound = ID 
      FROM LOTxLOCxID WITH (NOLOCK)  
      WHERE LOT = @c_LOT 
      AND   LOC = @c_ToLoc 
      AND   PendingMoveIN > 0
      AND  ( ID = @c_InitialID OR ID = @c_ToID)
      ORDER BY ID DESC 
      IF @@ROWCOUNT > 0 
      BEGIN
         UPDATE LOTxLOCxID with (ROWLOCK)     
         SET PENDINGMOVEIN =  CASE WHEN PENDINGMOVEIN - @n_Qty < 0  THEN 0        
                                   ELSE PENDINGMOVEIN - @n_Qty        
                              END        
         WHERE LOT = @c_LOT 
         AND LOC = @c_ToLoc 
         AND ID = @c_IDFound 
         --AND ID  = @c_InitialID        
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
         IF @n_err <> 0        
         BEGIN        
            SELECT @n_continue = 3                         
            SELECT @n_err = 62044 --62249   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddMoveCheck)' + ' ( '   
                  + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '        
                 
         END   
      END      
   END   
END
/* End Update To Gsix tables */
/* OK - now, we must deal with hold issues */
IF @n_continue = 1 or @n_continue = 2
BEGIN
   /* if the FROMLOC or FROMID is on hold,reduce the qtyonhold */
   /* if the TOLOC or TOID is on hold, increase the qtyonhold  */
   /* if the FROMID is on hold but the toid is new, then the   */
   /*    TOID should contain the same status as the fromid and */
   /*     should be treated as such in the above two lines.    */
   /* Reduce QTYONHOLD for FROMLOC/FROMID */
   IF EXISTS (SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_FromID and STATUS <> 'OK')
   OR EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_FromLoc
   AND (STATUS <> 'OK' or LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE')
   )
   BEGIN
      UPDATE LOT with (ROWLOCK)
      SET QTYONHOLD = QTYONHOLD - @n_Qty
      WHERE LOT = @c_lot
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
        SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @n_err = 62045 --62245   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOT for QTYONHOLD. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
         /* End Trap SQL Server Error */
      END
   END
   /* Add to QTYONHOLD for TOLOC/TOID IF and only IF */
   /* the ID already existed and to TOID is on hold  */
   /* or the TOLOC is on hold                        */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ( EXISTS (SELECT * FROM ID (NOLOCK) WHERE ID = @c_toid and STATUS <> 'OK')
      OR EXISTS (SELECT * FROM LOC (NOLOCK) WHERE LOC = @c_toloc
      and (STATUS <> 'OK' or LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE')
      )
      ) AND @b_addid = 0
      BEGIN
         UPDATE LOT with (ROWLOCK)
         SET QTYONHOLD = QTYONHOLD + @n_Qty
         WHERE LOT = @c_lot
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @n_err = 62046 --62246   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOT for QTYONHOLD. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
            /* End Trap SQL Server Error */
         END
      END
   END
   /* If the TOLOC is on hold, the TOID is NOT on hold and */
   /* the TOID is new, the add to the QTYONHOLD */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT * FROM LOC (NOLOCK) WHERE LOC = @c_toloc
      and (STATUS <> 'OK' or LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE')
      )
      AND
      EXISTS (SELECT * FROM ID (NOLOCK) WHERE ID = @c_toid and STATUS = 'OK'
      )
      AND @b_addid = 1
      BEGIN
         UPDATE LOT with (ROWLOCK)
         SET QTYONHOLD = QTYONHOLD + @n_Qty
         WHERE LOT = @c_lot
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @n_err = 62047 --62247   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOT for QTYONHOLD. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
            /* End Trap SQL Server Error */
         END
      END
   END

   --(Wan11) - Move Sequence in between Lotxlocxid and Pickdetail Update
   /* SWT04 FCR-822 - Merge Pallets with Serial Numbers 
      Start*/
   IF @n_continue = 1 or @n_continue = 2          
   BEGIN 
      IF EXISTS(SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                WHERE SKU = @c_Sku
                AND StorerKey = @c_StorerKey 
                AND SerialNoCapture IN ('1','3'))
      BEGIN
         BEGIN TRY
            EXEC dbo.msp_SerialNoMoveCheck 
                  @c_itrnkey    = @c_itrnkey   
                , @c_StorerKey  = @c_StorerKey 
                , @c_Sku        = @c_Sku       
                , @c_Lot        = @c_Lot       
                , @c_fromloc    = @c_fromloc   
                , @c_fromid     = @c_fromid    
                , @c_ToLoc      = @c_ToLoc     
                , @c_ToID       = @c_ToID      
                , @c_packkey    = @c_packkey   
                , @c_Status     = @c_Status    
                , @n_casecnt    = @n_casecnt   
                , @n_innerpack  = @n_innerpack 
                , @n_Qty        = @n_Qty       
                , @n_pallet     = @n_pallet    
                , @f_cube       = @f_cube      
                , @f_grosswgt   = @f_grosswgt  
                , @f_netwgt     = @f_netwgt    
                , @f_otherunit1 = @f_otherunit1
                , @f_otherunit2 = @f_otherunit2
                , @c_lottable01 = @c_lottable01
                , @c_lottable02 = @c_lottable02
                , @c_lottable03 = @c_lottable03
                , @d_lottable04 = @d_lottable04
                , @d_lottable05 = @d_lottable05
                , @c_lottable06 = @c_lottable06
                , @c_lottable07 = @c_lottable07
                , @c_lottable08 = @c_lottable08
                , @c_lottable09 = @c_lottable09
                , @c_lottable10 = @c_lottable10
                , @c_lottable11 = @c_lottable11
                , @c_lottable12 = @c_lottable12
                , @d_lottable13 = @d_lottable13
                , @d_lottable14 = @d_lottable14
                , @d_lottable15 = @d_lottable15
                , @b_Success    = @b_Success OUTPUT  
                , @n_err        = @n_err     OUTPUT  
                , @c_errmsg     = @c_errmsg  OUTPUT  
                , @c_MoveRefKey = @c_MoveRefKey
                , @c_Channel    = @c_Channel   
                , @n_Channel_ID = @n_Channel_ID OUTPUT
         END TRY
         BEGIN CATCH
               SET @n_err = ERROR_NUMBER()
               SET @c_ErrMsg = ERROR_MESSAGE()
                               
               SET @n_continue = 3
               SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddMoveCheck)' 
         END CATCH                                          
      END
   END
   /* SWT04 FCR-822 END */

   /* If the TOLOC is not on hold, the TOID is is on hold and */
   /* the TOID is new, then call the nspInventoryHold SP. */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF NOT EXISTS ( SELECT * FROM LOC (NOLOCK) WHERE LOC = @c_toloc
      and (STATUS <> 'OK' or LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE')
      )
      AND
      EXISTS (SELECT * FROM ID (NOLOCK) WHERE ID = @c_toid and STATUS <> 'OK'
      )
      AND @b_addid = 1
      BEGIN
         /* Call SP */
         EXECUTE nspInventoryHold
         ''
         , ''
         , @c_toid
         , @c_Status
         , '1'
         , @b_Success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END
END
/* End Deal With Hold Issues */
/* Update pickdetail to put back allocations */
IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF @b_RemoveAllocations = 1
   BEGIN
--      UPDATE PICKDETAIL with (ROWLOCK)
--      SET QTYMOVED = 0 ,
--      Qty = QTYMOVED ,
--      LOC = @c_ToLoc,
--      ID = @c_toid
--      WHERE LOT = @c_LOT and LOC = @c_FromLoc and ID=@c_FromID
--      AND STATUS < '9'

      CREATE TABLE #tpickdet  (
      Pickdetailkey NVARCHAR(10) NOT NULL,
        LOT          NVARCHAR(10) NOT NULL,
        LOC          NVARCHAR(10) NOT NULL,
        ID           NVARCHAR(18) NOT NULL,
        PRIMARY KEY CLUSTERED (Pickdetailkey)
        )

     INSERT INTO #tpickdet (Pickdetailkey,LOT, LOC, ID )
      SELECT Pickdetailkey,LOT, @c_ToLoc, @c_toid
     FROM PICKDETAIL  WITH (NOLOCK)
      WHERE LOT = @c_LOT and LOC = @c_FromLoc and ID=@c_FromID
      AND STATUS < '9'
      AND (( MoveRefKey = @c_MoveRefKey) OR
           ( MoveRefKey IS NULL AND @c_MoveRefKey = ''))
        

      IF EXISTS ( SELECT 1 FROM #tpickdet WITH (NOLOCK)  )
      BEGIN
         --SWT03
         IF EXISTS ( SELECT 1 FROM SKUxLOC WITH (NOLOCK) 
                     WHERE StorerKey = @c_StorerKey 
                     AND SKU = @c_SKU 
                     AND LOC = @c_ToLoc 
                     AND LocationType IN ('PICK','CASE') ) AND @c_MoveRefKey like 'E%'  -- SWT03 WWANG02
         BEGIN
            SET @b_UpdUOM = 1 
         END
            
        UPDATE PICKDETAIL with (ROWLOCK)
        SET
          LOC = #tpickdet.Loc,
          ID = #tpickdet.ID,
          UOM = CASE WHEN @b_UpdUOM = 1 AND UOM = '6' THEN '7' ELSE UOM END, -- SWT03
          MoveRefKey = CASE WHEN @b_UpdUOM = 1 THEN @c_MoveRefKey ELSE '' END, --SWT03 WWANG02
          EditWho = SUSER_SNAME(),
          EditDate = GETDATE()
        FROM PICKDETAIL
        JOIN #tpickdet WITH (NOLOCK) ON PICKDETAIL.PickDetailKey =  #tpickdet.Pickdetailkey
        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
        IF @n_err <> 0
        BEGIN
          SELECT @n_continue = 3
          SELECT @n_err = 62048 --62245   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PickDetail. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '

        END
     END
   END
END
/* End Update pickdetail to put back allocations */
/* Update Itrn with calculated columns */
IF @n_continue=1 or @n_continue=2
BEGIN
   UPDATE Itrn with (ROWLOCK)
   SET  TrafficCop = NULL,
   StorerKey = @c_StorerKey,
   Sku = @c_Sku,
   Lot = @c_Lot,
   FromId = @c_FromId,
   FromLoc = @c_FromLoc,
   ToId = @c_ToId,
   ToLoc = @c_ToLoc,
   Lottable04 = @d_Lottable04,
   Lottable05 = @d_Lottable05,
   Status = @c_Status
,  Channel_ID = @n_ToChannel_ID --(Wan08)   
   WHERE ItrnKey = @c_itrnkey

   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62049
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Itrn. (nspItrnAddMoveCheck)'
         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
   END
END
/* End Update Itrn with calculated columns */
/* Generate Cycle Count Alert for Location 'LOST' */
IF @n_continue=1 or @n_continue=2
BEGIN
   IF @c_ToLoc LIKE 'LOST%'
   BEGIN
      DECLARE @c_AlertMessage NVARCHAR(255)
      SELECT @c_AlertMessage =
      'CYCLE COUNT ALERT: StorerKey=' + RTRIM(@c_StorerKey) +
      ', Sku=' + RTRIM(@c_SKU) +
      ', Lot=' + RTRIM(@c_LOT) +
      ', FromId=' + RTRIM(@c_FromID) +
      ', FromLoc=' + RTRIM(@c_FromLoc) +
      ', ToId=' + RTRIM(@c_ToId) +
      ', ToLoc=' + RTRIM(@c_ToLoc) +
      ', Qty=' + RTRIM(CONVERT(char(10), @n_Qty))
      SELECT @b_success = 1
      EXECUTE nspLogAlert
      @c_ModuleName   = 'nspItrnAddMoveCheck',
      @c_AlertMessage = @c_AlertMessage,
      @n_Severity     = NULL,
      @b_success       = @b_success OUTPUT,
      @n_err          = @n_err OUTPUT,
      @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62050
         SELECT @c_errmsg = 'nspItrnAddMoveCheck: ' + RTRIM(@c_errmsg)
      END
   END
END
/* End Generate Cycle Count Alert for Location 'LOST' */
END -- @n_continue =1 or @n_continue=2

-- added for idsv5 by Ricky Yee (18/06/2002), extract from IDSTWSP) *** Start
IF @n_continue=1 or @n_continue=2
BEGIN
   select @b_success = 0
   Execute nspGetRight null,     -- facility
   @c_StorerKey,    -- Storerkey
   @c_sku,    -- Sku
   'ASNLOTUPDATE',  -- Configkey
   @b_success    output,
   @c_authority  output,
   @n_err     output,
   @c_errmsg     output
   If @b_success <> 1
   begin
      select @n_continue = 3, @n_err = 62051, @c_errmsg = 'nspItrnAddMoveCheck' + RTRIM(@c_errmsg)
   end
else if @c_authority = '1'
begin
   IF EXISTS (SELECT ITRNKEY
   FROM   ITRN (NOLOCK), RECEIPTDETAIL (NOLOCK)
   WHERE  SourceType = 'WSPUTAWAY'
   AND    SourceKey  = RTRIM(RECEIPTDETAIL.ReceiptKey) + RTRIM(RECEIPTDETAIL.ReceiptLineNumber)
   AND    TranType   = 'MV'
   AND    ITRN.ItrnKey = @c_ItrnKey)
   BEGIN
      UPDATE RECEIPTDETAIL with (ROWLOCK)
      SET PutawayLoc = ITRN.ToLoc,
      RECEIPTDETAIL.ToID = ITRN.ToID,
      RECEIPTDETAIL.TrafficCop = NULL
      FROM RECEIPTDETAIL, ITRN (NOLOCK)
      WHERE  SourceType = 'WSPUTAWAY'
      AND    SourceKey  = RTRIM(RECEIPTDETAIL.ReceiptKey) + RTRIM(RECEIPTDETAIL.ReceiptLineNumber)
      AND    TranType   = 'MV'
      AND    PutawayLoc = ''
      AND    ITRN.ItrnKey = @c_ItrnKey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62052
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ReceiptDetail. (nspItrnAddMoveCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_ErrMsg),'') + ' ) '
      END
   END
end
END -- @n_continue =1 or @n_continue=2
-- added for idsv5 by Ricky Yee (18/06/2002), extract from IDSTWSP) *** End

-- Added By SHONG on 05-Mar-2004          
-- Auto swap Lot          
If @n_continue = 1 or @n_continue = 2          
Begin          
   Declare @c_authority_swaplot NVARCHAR(1)          
          ,@c_swlotoption1 NVARCHAR(30) --NJOW02
   Select @b_success = 0, @c_facility = null          
          
   Execute nspGetRight '',           
       @c_StorerKey,   -- Storer          
       '',             -- Sku          
       'AutoReplenSwapLot',      -- ConfigKey          
       @b_success            output,           
       @c_authority_swaplot  output,           
       @n_err                output,           
       @c_errmsg             output,
       @c_swlotoption1       output --NJOW02
       
   If @b_success <> 1          
   Begin          
       Select @n_continue = 3, @n_err = 62057, @c_errmsg = 'nspItrnAddMoveCheck:' + RTRIM(@c_errmsg)          
   End          
   Else           
   Begin          
      If @c_authority_swaplot = '1'          
      Begin          
         IF EXISTS(SELECT 1
                   FROM SKUxLOC SL (NOLOCK) 
                   WHERE SL.StorerKey = @c_StorerKey 
                   AND SL.SKU = @c_SKU 
                   AND SL.LOC = @c_ToLOC 
                   AND SL.LocationType IN ('PICK', 'CASE')) OR
            EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_ToLOC AND LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK'))  --NJOW02                            
         BEGIN          
            IF EXISTS(SELECT LOT FROM LOTxLOCxID (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU AND          
                   LOC = @c_ToLOC AND QtyExpected > 0 )          
            BEGIN          
               EXEC [dbo].[isp_ReplenSwapLot]
                  @c_LOT         =  @c_LOT,
                  @c_LOC         =  @c_ToLOC,
                  @c_ID          =  @c_ToId,
                  @c_ForcePicked =  'N',
                  @c_LoadKey     =  '',
                  @c_OrderKey    =  '',
                  @b_Success     =  @b_Success OUTPUT,
                  @n_ErrNo       =  @n_Err    OUTPUT,
                  @c_ErrMsg      =  @c_ErrMsg OUTPUT,  
                  @b_Debug       =  0                      
               IF NOT @b_Success = 1          
               BEGIN          
                  SELECT @n_continue = 3          
               END          
               
               --NJOW02
               IF @c_swlotoption1 = 'ReplSwapInv' 
               BEGIN
                  EXEC isp_ReplSwapInv 
                       @c_Storerkey = @c_Storerkey,
                       @c_ForcePicked = 'N',          
                       @c_Loc = @c_ToLoc,
                       @c_Sku = @c_SKU,
                       @c_callfrom  = 'INVMOVE'

               END        
            END           
         END           
      End          
   End          
End    

/* End Main Processing */
/* Post Process Starts */
/* #INCLUDE <SPIAMC2.SQL> */
/* Post Process Ends */
/* Return Statement */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddMoveCheck'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END
ELSE
BEGIN
   /* Error Did Not Occur , Return Normally */
   SELECT @b_success = 1
   RETURN
END
/* End Return Statement */
END

GO