SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspItrnAddAdjustmentCheck                           */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.7                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author        Purposes                                   */
/* 11-May-2006  MaryVong      Add in RDT compatible error messages       */
/* 13-Sep-2006  MaryVong      Add in RDT compatible error messages       */
/* 25-Jun-2013  TLTING01      Deadlock Tune                              */
/* 15-JUL-2013  YTWan     1.2 SOS#251326: Add Commingle Lottables        */
/*                            validation to Exceed and RDT (Wan01)       */
/* 28-APR-2014  CSCHONG   1.3 Add Lottable06-15  (CS01)                  */
/* 18-MAY-2015  YTWan     1.4 SOS#341733 - ToryBurch HK SAP - Allow      */
/*                            CommingleSKU with NoMixLottablevalidation  */
/*                            to Exceed and RDT (Wan02)                  */
/* 01-JUN-2015  YTWan     1.5 SOS#343525 - UA  C NoMixLottable validation*/
/*                            CR(Wan03)                                  */
/* 06-Feb-2018  SWT02     1.6 Added Channel Management Logic             */
/*                        1.6.1 Handle QtyOnHold For Channel Mgmt        */
/* 23-JUL-2019  Wan04     1.7 WMS - 9914 [MY] JDSPORTSMY - Channel       */
/*                            Inventory Ignore QtyOnHold - CR            */
/* 10-Feb-2023  NJOW01    1.8 WMS-21722 Allow check nomixlottable for all*/
/*                            commingle sku in a loc.                    */
/* 10-Feb-2023  NJOW01    1.8 DEVOPS Combine Script                      */
/* 09-AUG-2023  Wan05     1.9 LFWM-4397 - RG [GIT] Serial Number Solution*/
/*                            -  Adjustment by Serial Number             */
/* 03-JAN-2024  Wan06     2.6 LFWM-4405 - [GIT] Serial Number Solution-Post*/
/*                            Cycle Count by Adjustment Serialnon - Fix  */
/*                            sourcetype truncate issue                  */
/*************************************************************************/
CREATE   PROC  [dbo].[nspItrnAddAdjustmentCheck]
               @c_itrnkey      NVARCHAR(10)
,              @c_StorerKey    NVARCHAR(15)
,              @c_Sku          NVARCHAR(20)
,              @c_Lot          NVARCHAR(10)
,              @c_ToLoc        NVARCHAR(10)
,              @c_ToID         NVARCHAR(18)
,              @c_packkey      NVARCHAR(10)
,              @c_Status       NVARCHAR(10)
,              @n_casecnt      int       -- Casecount being inserted
,              @n_innerpack    int       -- innerpacks being inserted
,              @n_Qty          int       -- QTY (Most important) being inserted
,              @n_pallet       int       -- pallet being inserted
,              @f_cube         float     -- cube being inserted
,              @f_grosswgt     float     -- grosswgt being inserted
,              @f_netwgt       float     -- netwgt being inserted
,              @f_otherunit1   float     -- other units being inserted.
,              @f_otherunit2   float     -- other units being inserted too.
,              @c_lottable01   NVARCHAR(18) = ''
,              @c_lottable02   NVARCHAR(18) = ''
,              @c_lottable03   NVARCHAR(18) = ''
,              @d_lottable04   datetime = NULL
,              @d_lottable05   datetime = NULL
,              @c_lottable06   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable07   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable08   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable09   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable10   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable11   NVARCHAR(30) = ''      --(CS01)
,              @c_lottable12   NVARCHAR(30) = ''      --(CS01)
,              @d_lottable13   datetime = NULL        --(CS01)
,              @d_lottable14   datetime = NULL        --(CS01)
,              @d_lottable15   datetime = NULL        --(CS01)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @c_Channel      NVARCHAR(20) = '' --(SWT02)
,              @n_Channel_ID   BIGINT = 0 OUTPUT --(SWT02)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_skudefallowed NVARCHAR(18)
   ,      @n_continue int
   ,      @n_err2 int              -- For Additional Error Detection
   ,      @c_preprocess NVARCHAR(250)  -- preprocess
   ,      @c_pstprocess NVARCHAR(250)  -- post process
   ,      @n_cnt int
   ,      @c_facility NVARCHAR(5)

   --(Wan01) - START
   DECLARE @c_IDLottable01    NVARCHAR(18)
      , @c_IDLottable02       NVARCHAR(18)
      , @c_IDLottable03       NVARCHAR(18)
      , @d_IDLottable04       DATETIME
      , @c_IDLottable06       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable07       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable08       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable09       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable10       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable11       NVARCHAR(30)            --(Wan03)
      , @c_IDLottable12       NVARCHAR(30)            --(Wan03)
      , @d_IDLottable13       DATETIME                --(Wan03)
      , @d_IDLottable14       DATETIME                --(Wan03)
      , @d_IDLottable15       DATETIME                --(Wan03)

      , @c_NoMixLottable01    NVARCHAR(1)
      , @c_NoMixLottable02    NVARCHAR(1)
      , @c_NoMixLottable03    NVARCHAR(1)
      , @c_NoMixLottable04    NVARCHAR(1)
      , @c_NoMixLottable06    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable07    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable08    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable09    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable10    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable11    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable12    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable13    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable14    NVARCHAR(1)             --(Wan03)
      , @c_NoMixLottable15    NVARCHAR(1)             --(Wan03)

      , @c_CommingleSku       NVARCHAR(1)              --(Wan02)  
      , @c_ChkLocByCommingleSkuFlag  NVARCHAR(10)      --(Wan02)
      , @c_ChannelInventoryMgmt      NVARCHAR(10) = '0' -- (SWT02)
      , @c_ChkNoMixLottableForAllSku NVARCHAR(30) = ''  -- NJOW01   
                                                        -- 
      , @c_SerialNo                 NVARCHAR(50) = ''    --(Wan05)
      , @c_SerialNokey              NVARCHAR(10) = ''    --(Wan05)
      , @c_Status_SN                NVARCHAR(10) = '1'   --(Wan05)
      , @c_SourceKey                NVARCHAR(20) = ''    --(Wan05)
      , @c_SourceType               NVARCHAR(30) = ''    --(Wan06)(Wan05)
      , @c_TranType                 NVARCHAR(10) = ''    --(Wan05)
      , @c_ASNFizUpdLotToSerialNo   NVARCHAR(30) = ''    --(Wan05)
      
   SET @c_IDLottable01     = ''
   SET @c_IDLottable02     = ''
   SET @c_IDLottable03     = ''
   SET @c_IDLottable06     = ''                       --(Wan03)
   SET @c_IDLottable07     = ''                       --(Wan03)
   SET @c_IDLottable08     = ''                       --(Wan03)
   SET @c_IDLottable09     = ''                       --(Wan03)
   SET @c_IDLottable10     = ''                       --(Wan03)
   SET @c_IDLottable11     = ''                       --(Wan03)
   SET @c_IDLottable12     = ''                       --(Wan03)

   SET @c_NoMixLottable01  = '0'                      
   SET @c_NoMixLottable02  = '0'
   SET @c_NoMixLottable03  = '0'
   SET @c_NoMixLottable04  = '0'
   SET @c_NoMixLottable06  = '0'                      --(Wan03)
   SET @c_NoMixLottable07  = '0'                      --(Wan03)
   SET @c_NoMixLottable08  = '0'                      --(Wan03)
   SET @c_NoMixLottable09  = '0'                      --(Wan03)
   SET @c_NoMixLottable10  = '0'                      --(Wan03)
   SET @c_NoMixLottable11  = '0'                      --(Wan03)
   SET @c_NoMixLottable12  = '0'                      --(Wan03)
   SET @c_NoMixLottable13  = '0'                      --(Wan03)
   SET @c_NoMixLottable14  = '0'                      --(Wan03)      
   SET @c_NoMixLottable15  = '0'                      --(Wan03)
   --(Wan01) - END 
   SET @c_CommingleSku      = '1'                      --(Wan02)
   SET @c_ChkLocByCommingleSkuFlag = '0'               --(Wan02)

   IF @n_continue=1 or @n_continue=2
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
   SELECT @n_continue=1, @b_success=0, @n_err = 1,@c_errmsg=''
   DECLARE @c_allowoverallocations NVARCHAR(1) -- Flag to see if overallocations are allowed.
   DECLARE @c_allowidqtyupdate NVARCHAR(1) --- Flag to see if update on the qty in the id table is allowed
   /* #INCLUDE <SPIAAC1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Added by Ricky to control Overallocation by Storer level
      SELECT @c_facility = FACILITY 
      FROM LOC (NOLOCK)
      WHERE LOC = @c_ToLoc

      If @n_continue = 1 or @n_continue = 2
      Begin
         Select @b_success = 0
         
         Execute nspGetRight 
         @c_facility,
         @c_StorerKey,           -- Storer
         @c_Sku,                 -- Sku
         'ALLOWOVERALLOCATIONS',  -- ConfigKey
         @b_success    output,
         @c_allowoverallocations  output,
         @n_err        output,
         @c_errmsg     output
         If @b_success <> 1
         Begin
            Select @n_continue = 3, @n_err = 61961, @c_errmsg = 'nspItrnAddAdjustmentCheck:' + ISNULL(RTRIM(@c_errmsg),'')
         End
      End
      IF @c_allowoverallocations is null
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
      @c_StorerKey,           -- Storer
      '',                     -- Sku
      'ChannelInventoryMgmt', -- ConfigKey
      @b_success    output,
      @c_ChannelInventoryMgmt  output,
      @n_err        output,
      @c_errmsg     output
      If @b_success <> 1
      Begin
         Select @n_continue = 3, @n_err = 61961, @c_errmsg = 'nspItrnAddAdjustmentCheck:' + ISNULL(RTRIM(@c_errmsg),'')
      End
   END    
      
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_allowidqtyupdate = NSQLValue
      FROM NSQLCONFIG (NOLOCK)
      WHERE CONFIGKEY = 'ALLOWIDQTYUPDATE'
      IF @c_allowidqtyupdate is null
      BEGIN
         SELECT @c_allowidqtyupdate = '0'
      END
   END

   IF @n_continue =1 or @n_continue=2
   BEGIN
      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF (@c_StorerKey = '') OR (@c_StorerKey IS NULL)
         BEGIN
            SELECT @c_storerkey=( SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
            FROM NSQLCONFIG (NOLOCK)
            WHERE NSQLCONFIG.ConfigKey = 'gc_storerdef')
            IF @c_storerkey IS NULL
            BEGIN
               SELECT @n_continue = 3 , @n_err = 61962 --61700
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storerkey is blank or null - not allowed! (nspItrnAddAdjustmentCheck)'
            END
            ELSE
            BEGIN
               UPDATE ITRN with (ROWLOCK)
               SET StorerKey = @c_storerkey WHERE Itrn.ItrnKey = @c_ItrnKey
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61963 --61701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Trigger On ITRN Failed Because An Attempt To Update StorerKey Failed. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
               ELSE IF @n_cnt = 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61964 --61725
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
               END
            END
         END
      END

      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF   (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL)
         BEGIN
            SELECT @c_SkuDefAllowed =( SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
            FROM NSQLCONFIG (NOLOCK)
            WHERE ConfigKey = 'gb_skudefallowed' )
            IF @c_SkuDefAllowed = 'TRUE'
            BEGIN
               SELECT @c_sku=(SELECT NSQLVALUE FROM NSQLCONFIG (NOLOCK) WHERE NSQLCONFIG.Configkey='gc_skudef')
               IF @c_sku IS NULL
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 61965 --61702
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storerkey is blank or null - not allowed! (nspItrnAddAdjustmentCheck)'
               END
               ELSE
               BEGIN
                  UPDATE ITRN with (ROWLOCK) 
                  SET sku = @c_sku WHERE itrnkey = @c_itrnkey
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61966 --61703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Trigger On ITRN Failed Because An Attempt To Update SKU Failed. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END
                  ELSE IF @n_cnt = 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61967 --61726
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
                  END
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3 , @n_err = 61968 --61704
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Default SKU Is Not Allowed And SKU Passed Is Blank! (nspItrnAddAdjustmentCheck)'
            END
         END
      END
      
      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF ISNULL(RTRIM(@c_LOT), '') = ''
         BEGIN
            DECLARE @b_isok int
            SELECT @b_isok=0
            EXECUTE nsp_lotlookup
            @c_storerkey
            , @c_sku
            , @c_lottable01
            , @c_lottable02
            , @c_lottable03
            , @d_lottable04
            , @d_lottable05
            , @c_lottable06      --(CS01)
            , @c_lottable07      --(CS01)
            , @c_lottable08      --(CS01)
            , @c_lottable09      --(CS01)
            , @c_lottable10      --(CS01)
            , @c_lottable11      --(CS01)
            , @c_lottable12      --(CS01)
            , @d_lottable13      --(CS01)
            , @d_lottable14      --(CS01)
            , @d_lottable15      --(CS01)
            , @c_lot       OUTPUT
            , @b_isok      OUTPUT
            , @n_err       OUTPUT
            , @c_errmsg    OUTPUT
            IF @b_isok = 1
            BEGIN
               IF ISNULL(RTRIM(@c_LOT), '') = ''
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 61969 --61705
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lot Number Does Not Exist In The LOTATTRIBUTE Table! (nspItrnAddAdjustmentCheck)'
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61970
               SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'') 
            END
         END
         ELSE
         BEGIN
            DECLARE @c_verifysku NVARCHAR(20)
            SELECT @c_verifysku=SKU FROM LOTATTRIBUTE (NOLOCK) WHERE LOT=@c_lot
            IF @@rowcount <> 1
            BEGIN
               SELECT @n_continue = 3 , @n_err = 61971 --61706
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lot Number Is Not Unique Or Does Not Exist In The LOTATTRIBUTE Table! (nspItrnAddAdjustmentCheck)'
            END
            ELSE
            BEGIN
               IF @c_sku <> @c_verifysku
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 61972 --61708
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lot Number and SKU Passed Do Not Match The Definition In The LOTATTRIBUTE Table! (nspItrnAddAdjustmentCheck)'
               END
            END
         END -- IF ISNULL(RTRIM(@c_LOT), '') = ''

        --(Wan02) - START
         IF @n_continue=1 or @n_continue=2
         BEGIN
            SET @b_success = 0
            Execute nspGetRight 
                    @c_facility 
                  , @c_StorerKey               -- Storer
                  , @c_Sku                     -- Sku
                  , 'ChkLocByCommingleSkuFlag'  -- ConfigKey
                  , @b_success                  OUTPUT 
                  , @c_ChkLocByCommingleSkuFlag  OUTPUT 
                  , @n_err                      OUTPUT 
                  , @c_errmsg                   OUTPUT
            
            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err = 61980
               SET @c_errmsg = 'nspItrnAddAdjustmentCheck:' + RTRIM(@c_errmsg)
            END
         END
         --(Wan02) - END

         --NJOW01 S
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
               SET @n_err = 61981
               SET @c_errmsg = 'nspItrnAddAdjustmentCheck:' + RTRIM(@c_errmsg)
            END
         END
         --NJOW01 E
         
         --(Wan01) - START
         IF @n_continue=1 or @n_continue=2
         BEGIN
            SELECT @c_IDlottable01 = RTRIM(LA.Lottable01)
                  ,@c_IDlottable02 = RTRIM(LA.Lottable02)   
                  ,@c_IDlottable03 = RTRIM(LA.Lottable03)
                  ,@d_IDlottable04 = ISNULL(LA.Lottable04, CONVERT(DATETIME,'19000101'))
                  ,@c_IDLottable06 = RTRIM(LA.Lottable06)                                               --(Wan03) 
                  ,@c_IDLottable07 = RTRIM(LA.Lottable07)                                               --(Wan03) 
                  ,@c_IDLottable08 = RTRIM(LA.Lottable08)                                               --(Wan03) 
                  ,@c_IDLottable09 = RTRIM(LA.Lottable09)                                               --(Wan03) 
                  ,@c_IDLottable10 = RTRIM(LA.Lottable10)                                               --(Wan03) 
                  ,@c_IDLottable11 = RTRIM(LA.Lottable11)                                               --(Wan03)       
                  ,@c_IDLottable12 = RTRIM(LA.Lottable12)                                               --(Wan03) 
                  ,@d_IDLottable13 = ISNULL(LA.Lottable13, CONVERT(DATETIME,'19000101'))                --(Wan03) 
                  ,@d_IDLottable14 = ISNULL(LA.Lottable14, CONVERT(DATETIME,'19000101'))                --(Wan03)     
                  ,@d_IDLottable15 = ISNULL(LA.Lottable15, CONVERT(DATETIME,'19000101'))                --(Wan03) 
            FROM LOTATTRIBUTE LA WITH (NOLOCK)
            WHERE LA.Lot = @c_LOT

            SELECT @c_NoMixLottable01 = CASE WHEN LOC.NoMixLottable01 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan02)     
                  ,@c_NoMixLottable02 = CASE WHEN LOC.NoMixLottable02 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan02)      
                  ,@c_NoMixLottable03 = CASE WHEN LOC.NoMixLottable03 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan02)      
                  ,@c_NoMixLottable04 = CASE WHEN LOC.NoMixLottable04 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan02)
                  ,@c_NoMixLottable06 = CASE WHEN LOC.NoMixLottable06 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable07 = CASE WHEN LOC.NoMixLottable07 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable08 = CASE WHEN LOC.NoMixLottable08 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable09 = CASE WHEN LOC.NoMixLottable09 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable10 = CASE WHEN LOC.NoMixLottable10 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable11 = CASE WHEN LOC.NoMixLottable11 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable12 = CASE WHEN LOC.NoMixLottable12 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable13 = CASE WHEN LOC.NoMixLottable13 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable14 = CASE WHEN LOC.NoMixLottable14 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_NoMixLottable15 = CASE WHEN LOC.NoMixLottable15 IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03)   
                  ,@c_CommingleSku    = CASE WHEN LOC.CommingleSku    IN ('1','Y') THEN '1' ELSE '0' END  --(Wan03) 
                  ,@c_CommingleSku    = LOC.CommingleSku                --(Wan02)
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @c_ToLoc

                        --(Wan02) - START
            IF @c_ChkLocByCommingleSkuFlag = '0'
            BEGIN
               IF @c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1'
               OR @c_NoMixLottable06 = '1' OR @c_NoMixLottable07 = '1' OR @c_NoMixLottable08 = '1' OR @c_NoMixLottable09 = '1' OR @c_NoMixLottable10 = '1'--(Wan03)
               OR @c_NoMixLottable11 = '1' OR @c_NoMixLottable12 = '1' OR @c_NoMixLottable13 = '1' OR @c_NoMixLottable14 = '1' OR @c_NoMixLottable15 = '1'--(Wan03)
               BEGIN
                  SET @c_CommingleSku = '0'
               END
               ELSE
               BEGIN
                  SET @c_CommingleSku = '1'
               END 
            END
            --(Wan02) - END
            IF @c_CommingleSku = '0'                                    --(Wan02)
               --@c_NoMixLottable01 = '1' OR @c_NoMixLottable02 = '1' OR @c_NoMixLottable03 = '1' OR @c_NoMixLottable04 = '1' --(Wan02)
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)  
                          WHERE LLI.Loc = @c_ToLoc
                          AND  (LLI.Storerkey <> @c_Storerkey OR  LLI.Sku <> @c_Sku)
                          AND   LLI.Qty - LLI.QtyPicked > 0)    
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 61992  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust commingle sku on Location: ' + RTRIM(@c_ToLOC) 
                              + '. (nspItrnAddAdjustmentCheck)' 
                  GOTO QUIT_MixLottables_Check  
                END
            END
  
            IF @c_NoMixLottable01 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable01 <> @c_IDLottable01) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)    
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61993  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow adjust on to No Mix Lottable01 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'  
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable02 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable02 <> @c_IDLottable02) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)    
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61994
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust on No Mix Lottable02 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'  
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable03 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable03 <> @c_IDLottable03) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)    
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61995 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust on No Mix Lottable03 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable04 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND  (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                          AND   ISNULL(LA.Lottable04, CONVERT(DATETIME, '19000101')) <> @d_IDLottable04)
                          AND   LLI.Qty - LLI.QtyPicked > 0)    
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61996 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust on No Mix Lottable04 Location: ' + RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check  
               END
            END

            --(Wan03) - START
            IF @c_NoMixLottable06 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable06 <> @c_IDLottable06) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 61997 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable06 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable07 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable07 <> @c_IDLottable07) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 61998 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable07 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable08 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable08 <> @c_IDLottable08) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 61999 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable08 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable09 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable09 <> @c_IDLottable09) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62000 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable09 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable10 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable10 <> @c_IDLottable10) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62001 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable10 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable11 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable11 <> @c_IDLottable11) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62002 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable11 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable12 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') AND LA.Lottable12 <> @c_IDLottable12) --NJOW01
                          AND   LLI.Qty - LLI.QtyPicked > 0)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62003 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable12 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)'
                  GOTO QUIT_MixLottables_Check 
               END
            END

            IF @c_NoMixLottable13 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku  OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                          AND    ISNULL(LA.Lottable13, CONVERT(DATETIME, '19000101')) <> @d_IDLottable13)
                          AND   LLI.Qty - LLI.QtyPicked > 0) 
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62004 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable13 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)' 
                  GOTO QUIT_MixLottables_Check
               END
            END

            IF @c_NoMixLottable14 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku  OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                          AND    ISNULL(LA.Lottable14, CONVERT(DATETIME, '19000101')) <> @d_IDLottable14)
                          AND   LLI.Qty - LLI.QtyPicked > 0) 
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62005 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable14 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)' 
                  GOTO QUIT_MixLottables_Check
               END
            END

            IF @c_NoMixLottable15 = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM LOTATTRIBUTE LA WITH (NOLOCK)
                          JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LA.Lot = LLI.Lot)
                          WHERE LLI.Loc = @c_ToLoc
                          AND   (LA.Storerkey = @c_Storerkey AND (LA.Sku = @c_Sku OR @c_ChkNoMixLottableForAllSku = '1') --NJOW01
                          AND    ISNULL(LA.Lottable15, CONVERT(DATETIME, '19000101')) <> @d_IDLottable15)
                          AND   LLI.Qty - LLI.QtyPicked > 0) 
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 62006 
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                              +': Not Allow to adjust to No Mix Lottable15 Location: ' +  RTRIM(@c_ToLoc) + '. (nspItrnAddAdjustmentCheck)' 
                  GOTO QUIT_MixLottables_Check
               END
            END
            --(Wan03) - END
            QUIT_MixLottables_Check:
         END
         --(Wan01) - END
      END

      IF @n_continue=1 or @n_continue=2
      BEGIN
         DECLARE @n_rcnt int,@n_curcasecnt int, @n_curinnerpack int , @n_curqty int, @c_curstatus NVARCHAR(10),
         @n_curpallet int , @f_curcube float, @f_curgrosswgt float, @f_curnetwgt float ,
         @f_curotherunit1 float, @f_curotherunit2 float
         SELECT    @n_curcasecnt=casecnt
         ,  @n_curinnerpack=innerpack
         ,  @n_curqty=Qty
         ,  @n_curpallet=pallet
         ,  @f_curcube=cube
         ,  @f_curgrosswgt=grosswgt
         ,  @f_curnetwgt=netwgt
         ,  @f_curotherunit1=otherunit1
         ,  @f_curotherunit2=otherunit2
         FROM LOT (NOLOCK) WHERE LOT = @c_lot
         SELECT @n_rcnt=@@ROWCOUNT
         IF @n_rcnt=0
         BEGIN
            INSERT INTO LOT (LOT,CASECNT,INNERPACK,QTY, PALLET,CUBE,GROSSWGT,NETWGT,OTHERUNIT1,OTHERUNIT2,STORERKEY,SKU)
            VALUES (@c_lot,@n_casecnt, @n_innerpack, @n_qty, @n_pallet, @f_cube, @f_grosswgt, @f_netwgt, @f_otherunit1, @f_otherunit2, @c_storerkey,@c_sku )
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61973 --61738   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table Itrn. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
         ELSE IF @n_rcnt=1
         BEGIN
            UPDATE LOT with (ROWLOCK)
            SET   CASECNT=CASECNT+@n_casecnt
            , INNERPACK=INNERPACK+@n_innerpack
            , QTY = QTY+@n_qty
            , PALLET=PALLET+@n_pallet
            , CUBE=CUBE+@f_cube
            , GROSSWGT=GROSSWGT+@f_grosswgt
            , NETWGT=NETWGT+@f_netwgt
            , OTHERUNIT1=OTHERUNIT1+@f_otherunit1
            , OTHERUNIT2=OTHERUNIT2+@f_otherunit2
            WHERE LOT=@c_lot
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61974 --61709   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOT. (nspItrnAddAjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61975 --61727
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table LOT Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3 , @n_err = 61976 --61710
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lot Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddAdjustmentCheck)'
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         SELECT @n_rcnt=NULL, @n_curqty=NULL, @c_curstatus=NULL
         SELECT @n_curqty=Qty, @c_curstatus=Status FROM ID (NOLOCK) WHERE ID = @c_toid
         SELECT @n_rcnt=@@ROWCOUNT
         IF @n_rcnt=0
         BEGIN
            IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Status)) IS NULL)
            BEGIN
               SELECT @c_Status = 'OK'
            END
            IF @c_allowidqtyupdate = '1'
            BEGIN
               INSERT INTO ID (ID, QTY, STATUS,PACKKEY) VALUES (@c_toid, @n_qty, @c_status, @c_packkey)
            END
            ELSE
            BEGIN
               INSERT INTO ID (ID, QTY, STATUS,PACKKEY) VALUES (@c_toid, 0, @c_status, @c_packkey)
            END
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61977 --61739   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table ID. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
         ELSE IF @n_rcnt=1
         BEGIN
            IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Status)) IS NULL)
            BEGIN
               SELECT @c_Status = @c_curstatus
            END
            IF @c_allowidqtyupdate = '1'
            BEGIN
               -- Added By SHONG 04-07-2002
               -- To prevent the Qty in the ID to become too large until datatype 'int' cannot handle
               IF dbo.fnc_RTrim(@c_toid) IS NOT NULL AND dbo.fnc_RTrim(@c_toid) <> ''
               BEGIN
                  UPDATE ID WITH (ROWLOCK) 
                  SET QTY = QTY+@n_qty, Status = @c_Status, Packkey = @c_packkey WHERE ID=@c_toid
               END
               ELSE
                  SELECT @n_cnt = 1, @n_err = 0
            END
            ELSE
            BEGIN

               --tlting01
               SET @n_cnt = 0

               SELECT @n_cnt = COUNT(1) FROM  ID with (NOLOCK) WHERE ID = @c_toid
                              
               /* Update table 'Id' */    
               IF EXISTS ( SELECT 1 FROM  ID with (NOLOCK) WHERE ID = @c_toid AND [Status] <> @c_Status )
               BEGIN  
                  UPDATE ID WITH (ROWLOCK) 
                  SET Status = @c_Status, Packkey = @c_packkey WHERE ID=@c_toid
               END
            END
            SELECT @n_err = @@ERROR--, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61978 --61713   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         -- ELSE IF @n_cnt = 0
            IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61979 --61729
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table ID Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3 , @n_err = 61980 --61714
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddAdjustmentCheck)'
         END
         IF (@n_rcnt = 1 or @n_rcnt = 0) and (@n_continue =1 or @n_continue=2)
         BEGIN
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NOT NULL
            BEGIN
               DECLARE @n_ti int, @n_hi int, @n_totalqty int, @c_currentpackkey NVARCHAR(10)
               SELECT @n_ti = 0, @n_hi = 0, @n_totalqty = 0
               SELECT @n_totalqty = QTY,@c_currentpackkey = PACKKEY FROM ID (NOLOCK) WHERE ID = @c_toid
               IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_currentpackkey)) IS NOT NULL
               BEGIN
                  SELECT @n_hi = Ceiling(@n_totalqty / CaseCnt / PALLETTI), @n_ti = PALLETTI
                  FROM PACK (NOLOCK)
                  WHERE PACKKEY = @c_currentpackkey
                  AND PALLETTI > 0
                  AND CaseCnt > 0
                  IF @n_ti > 0 or @n_hi > 0
                  BEGIN
                     UPDATE ID with (ROWLOCK)
                     SET PutawayTI = @n_ti, PutawayHI = @n_hi
                     WHERE ID = @c_toid
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 61981 --61749   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                     END
                  END
               END
            END
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         SELECT @n_rcnt=NULL, @n_curqty=NULL
         SELECT  @n_curqty=Qty FROM SKUxLOC (NOLOCK) WHERE STORERKEY = @c_storerkey and SKU = @c_sku and LOC = @c_toloc
         SELECT @n_rcnt=@@ROWCOUNT
         IF @n_rcnt=0
         BEGIN
            INSERT INTO SKUxLOC (STORERKEY, SKU, LOC, QTY) VALUES (@c_storerkey, @c_sku, @c_toloc, @n_qty)
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61982 --61741   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table SKUxLOC. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
         ELSE IF @n_rcnt=1
         BEGIN
            UPDATE SKUxLOC with (ROWLOCK)
            SET QTYEXPECTED = CASE
            WHEN @c_allowoverallocations = '0'
            THEN 0
            WHEN SKUxLOC.Locationtype <> 'PICK' and SKUxLOC.Locationtype <> 'CASE'
            THEN 0
            WHEN  ( (SKUxLOC.QtyAllocated  + SKUxLOC.QtyPicked)
            - (SKUxLOC.Qty + @n_qty) ) >= 0 and @c_allowoverallocations = '1' and (SKUxLOC.locationtype = 'PICK' or SKUxLOC.locationtype = 'CASE')
            THEN ( (SKUxLOC.QtyAllocated  + SKUxLOC.QtyPicked)
            - (SKUxLOC.Qty + @n_qty) )
            ELSE 0
            END ,
            QtyReplenishmentOverride =
            CASE WHEN QtyReplenishmentOverride - @n_qty > 0 
                 THEN CASE WHEN @n_qty > 0 THEN QtyReplenishmentOverride - @n_qty
                           ELSE QtyReplenishmentOverride
                           END
                 ELSE 0
                 END ,
            QTY = QTY + @n_qty
            WHERE STORERKEY = @c_storerkey and SKU = @c_sku and LOC=@c_toloc

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61983 --61735   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table SKUxLOC. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61984 --61736
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table SKUxLOC Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3 , @n_err = 61985 --61737
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SKUxLOC Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddAdjustmentCheck)'
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         SELECT @n_rcnt=NULL, @n_curqty=NULL
         SELECT  @n_curqty=Qty FROM LOTxLOCxID (NOLOCK) WHERE LOT=@c_lot and LOC=@c_toloc and ID=@c_toid
         SELECT @n_rcnt=@@ROWCOUNT
         IF @n_rcnt=0
         BEGIN
            INSERT INTO LOTxLOCxID (LOT, LOC, ID, QTY, STORERKEY, SKU) VALUES (@c_lot, @c_toloc, @c_toid, @n_qty, @c_storerkey, @c_sku )
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61986 --61744   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table LOTxLOCxID. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
         ELSE IF @n_rcnt=1
         BEGIN
            UPDATE LOTxLOCxID WITH (ROWLOCK)
            SET QTY=QTY+@n_qty,
            PENDINGMOVEIN =
            CASE
            WHEN PENDINGMOVEIN - @n_qty < 0 and @n_qty > 0
            THEN 0
            WHEN PENDINGMOVEIN - @n_qty >= 0 and @n_qty > 0
            THEN PENDINGMOVEIN - @n_qty
            ELSE PENDINGMOVEIN
            END
            WHERE LOT=@c_lot and LOC=@c_toloc and ID=@c_toid
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61987 --61721   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddAdustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            ELSE IF @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61988 --61733
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table LOTxLOCxID Returned Zero Rows Affected. (nspItrnAddAdjustmentCheck)'
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3 , @n_err = 61989 --61722
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LOTxLOCxID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddAdjustmentCheck)'
         END
      END

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_toid and STATUS <> 'OK')
         OR EXISTS (SELECT * FROM LOC (NOLOCK) WHERE LOC = @c_toloc and
         (STATUS <> 'OK' OR LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE')
         )
         BEGIN
            UPDATE LOT with (ROWLOCK)
            SET QTYONHOLD = QTYONHOLD + @n_qty
            WHERE LOT = @c_lot
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61990 --61745   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
               +': Update Failed on Table LOT. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
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
                     ,@b_Success     = @b_Success  OUTPUT
                     ,@n_ErrNo       = @n_Err      OUTPUT
                     ,@c_ErrMsg      = @c_ErrMsg   OUTPUT                  
               END TRY
               BEGIN CATCH
                     SELECT @n_err = ERROR_NUMBER(),
                            @c_ErrMsg = ERROR_MESSAGE()
                            
                     SELECT @n_continue = 3
                     SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddAdjustmentCheck)' 
               END CATCH                                                   
            END
            IF @n_Channel_ID > 0
            BEGIN
               --(Wan04) - START: Use Channel InventoryHold to Hold Instead
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
               --BEGIN
                  UPDATE ChannelInv WITH (ROWLOCK)
                     SET Qty = Qty + @n_qty, 
                         EditDate = GETDATE(),
                         EditWho  = SUSER_SNAME() 
                  WHERE Channel_ID = @n_Channel_ID 
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                
               --END   
               --(Wan04) - END                             
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61992  
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                  +': Update Failed on Table ChannelInv. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                           
            END            
         END             
      END
      -- End (SWT02)
      -- (Wan05) - START     
      IF @n_continue=1 or @n_continue=2
      BEGIN 
         SET @c_SerialNo = '' 
         SELECT @c_SerialNo  = a.SerialNo
              , @c_SourceKey = i.SourceKey
              , @c_SourceType= i.SourceType
              , @c_TranType  = i.TranType
         FROM ADJUSTMENTDETAIL AS a (NOLOCK)
         JOIN dbo.ITRN AS i (NOLOCK) ON a.AdjustmentKey+a.AdjustmentLineNumber = i.SourceKey
         JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = a.StorerKey AND s.Sku = a.Sku
         WHERE i.ItrnKey = @c_itrnkey
         AND a.SerialNo <> ''
         AND s.SerialNoCapture IN ('1','2','3')
         
         IF @c_SerialNo <> ''
         BEGIN
            SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr
            SET @c_Status_SN = '1'
            
            SET @c_SerialNokey = ''
            SELECT @c_SerialNoKey = sn.SerialNoKey
            FROM dbo.SerialNo AS sn (NOLOCK)
            WHERE sn.SerialNo = @c_SerialNo
            AND sn.Storerkey = @c_StorerKey
 
            IF @c_SerialNoKey <> ''
            BEGIN
               SET @c_Status_SN = '1'

               IF @n_Qty < 0 
               BEGIN 
                  SET @c_Status_SN = 'CANC'
               END

               UPDATE dbo.SerialNo WITH (ROWLOCK)
               SET [STATUS] = @c_Status_SN
                  ,Lot   = CASE WHEN @c_ASNFizUpdLotToSerialNo = '1' THEN @c_Lot ELSE Lot END
                  ,ID    = CASE WHEN ID <> @c_ToID THEN @c_ToID ELSE ID END
                  ,EditWho  = SUSER_SNAME()
                  ,EditDate = GETDATE()
               WHERE SerialNoKey = @c_SerialNoKey
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 62007
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table SerialNo. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            
            IF @c_SerialNoKey = '' AND @n_Continue IN (1,2)  
            BEGIN
               EXECUTE nspg_GetKey   
                    @KeyName     = 'SERIALNO'  
                  , @fieldlength = 10  
                  , @keystring   = @c_SerialNoKey OUTPUT  
                  , @b_success   = @b_success     OUTPUT  
                  , @n_err       = @n_err         OUTPUT  
                  , @c_errmsg    = @c_errmsg      OUTPUT  
                  , @b_resultset = 0  
                  , @n_batch     = 1  
        
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3                                                                                                
                  SET @n_err = 62008                                                                                           
                  SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (nspItrnAddAdjustmentCheck)'   
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                    
               END  
               
               IF @n_Continue IN (1,2)  
               BEGIN 
                  INSERT INTO dbo.SerialNo
                      (
                          SerialNoKey
                      ,   OrderKey
                      ,   OrderLineNumber
                      ,   StorerKey
                      ,   SKU
                      ,   SerialNo
                      ,   Qty
                      ,   [Status]
                      ,   LotNo
                      ,   ID
                      ,   ExternStatus
                      ,   PickSlipNo
                      ,   CartonNo
                      ,   UserDefine01
                      ,   UserDefine02
                      ,   UserDefine03
                      ,   UserDefine04
                      ,   UserDefine05
                      ,   LabelLine
                      ,   UCCNo
                      ,   Lot
                      )
                  VALUES
                      (
                          @c_SerialNoKey                                         -- SerialNoKey - nvarchar(10)
                      ,   N''                                                    -- OrderKey - nvarchar(10)
                      ,   N''                                                    -- OrderLineNumber - nvarchar(5)
                      ,   @c_StorerKey                                           -- StorerKey - nvarchar(15)
                      ,   @c_Sku                                                 -- SKU - nvarchar(20)
                      ,   @c_SerialNo                                            -- SerialNo - nvarchar(50)
                      ,   @n_Qty                                                 -- Qty - int
                      ,   @c_Status_SN                                           -- Status - nvarchar(10)
                      ,   ''                                                     -- LotNo - nvarchar(20)
                      ,   @c_ToID                                                -- ID - nvarchar(18)
                      ,   N'0'                                                   -- ExternStatus - nvarchar(10)
                      ,   N''                                                    -- PickSlipNo - nvarchar(10)
                      ,   0                                                      -- CartonNo - int
                      ,   N''                                                    -- UserDefine01 - nvarchar(30)
                      ,   N''                                                    -- UserDefine02 - nvarchar(30)
                      ,   N''                                                    -- UserDefine03 - nvarchar(30)
                      ,   N''                                                    -- UserDefine04 - nvarchar(30)
                      ,   N''                                                    -- UserDefine05 - nvarchar(30)
                      ,   N''                                                    -- LabelLine - nvarchar(5)
                      ,   N''                                                    -- UCCNo - nvarchar(20)
                      ,   IIF(@c_ASNFizUpdLotToSerialNo='1',@c_Lot,'')           -- Lot - nvarchar(10)
                      )
                   
                  SET @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 62008    
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into SERIALNO Table. (nspItrnAddAdjustmentCheck)'   
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
                  END  
               END    
            END
            
            IF @n_Continue IN (1, 2)   
            BEGIN
               EXEC dbo.ispITrnSerialNoAdjustment 
                 @c_ItrnKey      = @c_ItrnKey
               , @c_TranType     = @c_TranType
               , @c_StorerKey    = @c_StorerKey
               , @c_SKU          = @c_SKU
               , @c_SerialNo     = @c_SerialNo 
               , @n_QTY          = @n_QTY 
               , @c_SourceKey    = @c_SourceKey 
               , @c_SourceType   = @c_SourceType
               , @b_Success      = @b_Success  OUTPUT  
               , @n_Err          = @n_Err      OUTPUT  
               , @c_ErrMsg       = @c_ErrMsg   OUTPUT

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
               END
            END 
         END
      END  
      -- (Wan05) - END      
  
      IF @n_continue=1 or @n_continue=2
      BEGIN
         UPDATE Itrn with (ROWLOCK)
         SET TrafficCop = NULL,
             StorerKey = @c_StorerKey,
             Sku = @c_Sku,
             Lot = @c_Lot,
             ToId = @c_ToId,
             ToLoc = @c_ToLoc,
             Lottable04 = @d_Lottable04,
             Lottable05 = @d_Lottable05,
             Status = @c_Status,
             Channel_ID = @n_Channel_ID, 
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME() 
         WHERE ItrnKey = @c_itrnkey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61991 
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table Itrn. (nspItrnAddAdjustmentCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END
   END -- @n_continue=1 or @n_continue=2

/* #INCLUDE <SPIAAC2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddAdjustmentCheck'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END      
   ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
   /* End Return Statement */
END



GO