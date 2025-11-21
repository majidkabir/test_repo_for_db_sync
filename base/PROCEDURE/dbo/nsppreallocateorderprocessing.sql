SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: nspPreAllocateOrderProcessing                           */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Pre-Allocate Order Processing                               */
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 11-Sep-2002  Ricky      SOS36159 - change SOStatus to <> 'CANC'      */
/* 05-Jun-2003  Vicky      SOS38185 - Include Partially Picked Orders   */
/*                         in Mass Allocation Processing                */
/* 13-Jun-2003  June       SOS11744 - PGD PHP - use same Prealloc       */
/*                         strategy as HK, therefore has introduced a   */
/*                         a new storerconfig flag 'PREALLOCONFULLOUM'  */
/*                         to prevent partial preallocation.            */
/* 14-Jul-2003  Ricky      To include Partial allocate orders in the    */
/*                         mass allocation                              */
/* 02-Sep-2003  Admin      Check in For Wally (Changes for Phimippine   */
/*                         Watson Implementation)                       */
/* 10-Nov-2003  June       SOS14874 (PGD TH)-if order minshelflife <> 0,*/
/*                         check it in preallocation.                   */
/* 20-Jan-2004  Ricky      commented checking of @c_APreallocatePickCode*/
/*                         like 'NSPPR_HK%' for IDSHK                   */
/* 27-Jan-2004  Wally      SOS 19415 - fix initiliaze of variables      */
/* 18-Feb-2004  Shong      Performance Tuning for Thailand              */
/* 25-Feb-2004  Shong      2nd Preformance Review                       */
/* 25-Mar-2004  June       Merge from 1.6.1.0 (TH OW - SOS17522) -      */
/*                         min shelf life changes                       */
/* 30-Apr-2004  MaryVong   FBR18050 (NZMM) Set MinShelfLife only stores */
/*                         in days                                      */
/* 17-Jun-2004  June       SOS22128 - IDSPH CMC changes, add in extra   */
/*                         sorting                                      */
/* 03-Aug-2004  Admin      SOS 25604 - avoid allocating CANC order      */
/* 11-Oct-2004  Shong      Debug                                        */
/* 18-Oct-2004  Mohit      Change cursor type                           */
/* 27-Oct-2004  June       SOS25145 (IDSPH - ULP) add extra order       */
/*                         selection parm : Route                       */
/* 08-Nov-2004  June       Bug fixes - IDSSG has ' in lottable02        */
/* 15-Jun-2005  June       SOS36159 - change SOStatus to <> 'CANC'      */
/* 20-Jul-2005  June       SOS38185 - Include Partially Picked Orders   */
/*                         in Mass Allocation Processing                */
/* 23-Nov-2005  MaryVong   SOS42877 Add in missing range Ordergroupend  */
/*                         for mass allocation                        */
/* 07-Mar-2006  MaryVong   SOS47070 Add in extra checking for partial   */
/*                         pallet allocation                            */
/* 01-Oct-2009  SHONG      Enhance the Debug Message                    */
/* 27-Nov-2013  YTWan      SOS#293830:LP allocation by default          */
/*                         strategykey. (Wan01)                         */
/* 25-Apr-2014  SHONG      Added 10 Lottables                           */
/* 19-Nov-2014  NJOW01     Remove orderselection default flag checking  */
/*                         error                                        */
/* 25-Nov-2014  ChewKP     Extend UOM varible from 5 to 10 (ChewKP01)   */
/* 23-Mar-2015  Shong01    336160-Default StrategyKey from StorerConfig */
/* 14-Apr-2014  CSCHONG    SOS#339057 (CS01)                            */
/* 28-Apr-2015  Leong      Bug Fix (Leong01).                           */
/* 29-May-2015  NJOW02     342109 - Get casecnt from lottable           */
/* 19-AUG-2015  YTWan      Fixed assign@c_aLottable05 from lottable05   */
/*                         (Wan02)                                      */
/* 20-Sep-2016  TLTING     Change SET ROWCOUNT to TOP 1                 */
/* 21-SEP-2016  SHONG      Performance Tuning                           */
/* 01-NOV-2016  Wan03      WMS-669 - PMS Allocation Logic               */
/* 03-May-2017  NJOW03     Fix to prevent incorrect lot qty rtn from    */
/*                         pickcode                                     */
/* 15-Nov-2017  Wan04      Check Facility Lot Qty Available             */
/* 20-Apr-2018  SWT01      Channel Management Check Qty Available       */
/* 07-Mar-2019  NJOW04     StorerDefaultAllocStrategy support discrete  */
/*                         allocate from order and wave                 */
/* 23-JUL-2019  Wan05      ChannelInventoryMgmt use nspGetRight2        */
/* 08-OCT-2019  Wan06      WMS - 9914 [MY] JDSPORTSMY - Channel         */
/*                         Inventory Ignore QtyOnHold - CR              */ 
/* 08-OCT-2019  Wan07      Fixed to Get Channel If there is candidate   */
/*                         in Cursor                                    */ 
/* 15-OCT-2019  CSCHONG    WMS-10874 - support lottable02 ' value(CS02) */
/* 08-Jan-2020  NJOW05     WMS-10420 add strategykey parameter          */  
/* 12-Feb-2020  Wan08      SQLBindParm. Create Temp table to Store      */
/*                         Preallocate data from pickcode               */ 
/* 03-Jul-2020  CheeMun    INC1192122 - Initialize ChannelID = 0        */ 
/* 01-Dec-2020  NJOW06     WMS-15746 get channel hold qty by config     */  
/* 23-Jun-2022  WLChooi    DevOps Combine Script                        */
/* 23-Jun-2022  WLChooi    Bug Fix - Add Strategykey into #OPORDERLINES */
/*                         (WL01)                                       */
/* 27-SEP-2022  NJOW07     WMS-20812 Pass in additional parameters to   */
/*                         isp_ChannelAllocGetHoldQty_Wrapper.          */                                
/*                         Pass in PreAllocateStrategyKey and           */
/*                         PreAllocateStrategyLineNumber to pickcode    */
/************************************************************************/
CREATE   PROC  [dbo].[nspPreAllocateOrderProcessing]
               @c_orderkey     NVARCHAR(10)
,              @c_oskey        NVARCHAR(10)
,              @c_oprun        NVARCHAR(9)
,              @c_doroute      NVARCHAR(1)
,              @c_xdock        NVARCHAR(1)  = ''
,              @c_fromloc      NVARCHAR(10) = ''
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @c_extendparms  NVARCHAR(250) = ''
,              @c_StrategykeyParm NVARCHAR(10) = '' --NJOW05  
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_continue int,
   @n_starttcnt int, -- Holds the current transaction count
   @n_cnt int, -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250), -- preprocess
   @c_pstprocess NVARCHAR(250), -- post process
   @n_err2 int, -- For Additional Error Detection
   @b_debug int, -- Debug: 0 - OFF, 1 - show all, 2 - map
   @c_sectionkey NVARCHAR(3)

DECLARE @c_OtherParms NVARCHAR(200),  -- For CDC
   @c_prev_storer NVARCHAR(15),
   @c_prealloc NVARCHAR(1),
   @c_owitf NVARCHAR(1),
   @cPackUOM1 NVARCHAR(10), -- (ChewKP01)
   @cPackUOM2 NVARCHAR(10), -- (ChewKP01)
   @cPackUOM3 NVARCHAR(10), -- (ChewKP01)
   @cPackUOM4 NVARCHAR(10), -- (ChewKP01)
   @nRecordFound int,
   @c_DefaultStrategykey    NVARCHAR(1),      --(Wan01)
   @cExecSQL NVARCHAR(4000),
   @c_AllocateGetCasecntFrLottable NVARCHAR(10), --NJOW02
   @c_CaseQty NVARCHAR(30), --NJOW02
   @c_SQL              NVARCHAR(2000), --NJOW02
   @n_LotAvailableQty  INT --NJOW03   
  ,@n_FacLotAvailQty   INT = 0      --(Wan04) 
  
  ,@c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- (SWT01)  
  ,@c_Channel               NVARCHAR(20) = '' --(SWT01)
  ,@n_Channel_ID            BIGINT = 0        --(SWT01) 
  ,@n_Channel_Qty_Available INT = 0            
  ,@n_AllocatedHoldQty INT = 0                                                                        
  ,@c_SourceType                NVARCHAR(50) --NJOW06
  ,@c_SourceKey                 NVARCHAR(30) --NJOW06
  ,@n_ChannelHoldQty            INT          --NJOW06
  
SET @c_DefaultStrategykey = ''               --(Wan01)

SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg="", @n_err2=0
SELECT @b_debug = 0

SELECT @c_prev_storer = SPACE(10)

IF @c_doroute = '1' or @c_doroute = '2'
BEGIN
   SELECT @b_debug = Convert(int, @c_doroute)
END

-- select @b_debug = 1

IF @n_continue=1 or @n_continue=2
BEGIN
   IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_orderkey)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_orderkey))='' ) AND (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey))='')
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78300
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Parameters Passed (nspPreAllocateOrderProcessing)"
   END
END -- @n_continue =1 or @n_continue = 2

IF @n_continue = 1 or @n_continue =2
BEGIN
   -- Create Temp Table #OPORDERS
   -- Replace the BULK Select INTO WHERE OrderKey = '!XYZ!' to 1=2
   -- Added By Ricky For IDSV5 for userdefine06 and userdefine07 column
   
   CREATE TABLE #OPORDERS
   (
      OrderKey              NVARCHAR(10),
      StorerKey             NVARCHAR(15),
      ConsigneeKey          NVARCHAR(15) NULL,
      [Type]                NVARCHAR(10) NULL,
      [STATUS]              NVARCHAR(10) NULL,
      [Priority]            NVARCHAR(10) NULL,
      DeliveryDate          DATETIME NULL,
      OrderDate             DATETIME NULL,
      Intermodalvehicle     NVARCHAR(30) NULL,
      OrderGroup            NVARCHAR(20) NULL,
      UserDefine06          DATETIME NULL,
      UserDefine07          DATETIME NULL,
      Facility              NVARCHAR(5) NULL,
      XDockFlag             NVARCHAR(1) NULL
   )
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      CREATE INDEX OPOrdersIdx1 ON #OPORDERS (OrderKey)
   END   
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oprun)) IS NULL or dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oprun))=''
   BEGIN
      SELECT @b_success = 0
      EXECUTE dbo.nspg_getkey 'PREOPRUN', 9, @c_oprun OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   END
END

--(Wan03)- START
--IF @n_continue = 1 or @n_continue = 2
--BEGIN
--   DECLARE @c_AutoDeletePreallocations NVARCHAR(1) -- Flag to see if existing preallocations should be deleted prior to running
--   SELECT @c_AutoDeletePreallocations = NSQLValue
--   FROM NSQLCONFIG (NOLOCK)
--   WHERE CONFIGKEY = "AutoDeletePreAllocation"

--   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_AutoDeletePreallocations)) is null
--   BEGIN
--      SELECT @c_AutoDeletePreallocations = "1"
--   END
--END
--(Wan03)- END

IF @n_continue=1 or @n_continue=2
BEGIN
   /* IDSV5 - Leo */
   Declare @c_authority NVARCHAR(1), @c_freegoodsallocation NVARCHAR(1)
   Select @b_success = 0, @c_freegoodsallocation = '0'
   Execute dbo.nspGetRight
   null, -- Facility
   null, -- Storer
   null, -- Sku
   'FREE GOODS ALLOCATION',
   @b_success      OUTPUT,
   @c_authority    OUTPUT,
   @n_err          OUTPUT,
   @c_errmsg       OUTPUT
   If @b_success <> 1
   Begin
      Select @n_continue = 3
      Select @c_errmsg = 'nspPreAllocateOrderProcessing : ' + dbo.fnc_RTrim(@c_errmsg)
   End
   Else
   Begin
      Select @c_freegoodsallocation = @c_authority
   End
END

IF @n_continue=1 or @n_continue=2
BEGIN
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_orderkey)) IS NOT NULL
   BEGIN
      -- customization for HK.
      -- Disregard orders with type = 'M', 'I' if bypass_ordertype = '1'
      /* IDSV5 - Leo */
      Select @b_success = 0
      Execute dbo.nspGetRight null,  -- Facility
      null,                      -- Storer
      null,                      -- Sku
      'BYPASS ORDER - TYPE = M & I',
      @b_success      OUTPUT,
      @c_authority    OUTPUT,
      @n_err          OUTPUT,
      @c_errmsg       OUTPUT
      If @b_success <> 1
      Begin
         Select @n_continue = 3
         Select @c_errmsg = 'nspPreAllocateOrderProcessing : ' + dbo.fnc_RTrim(@c_errmsg)
      End
      Else
      Begin
         If @c_authority = '1'
         Begin
            -- Added By Ricky For IDSV5 for userdefine06 and userdefine07 column
            INSERT #OPORDERS
                 ( Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag )
            SELECT Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag
            FROM ORDERS (NOLOCK)
            WHERE ORDERKEY = @c_orderkey AND Type NOT IN ('M', 'I')
               -- Start : SOS36159
               -- AND ORDERS.SOStatus = '0'
               AND ORDERS.SOStatus <> N'CANC'
               -- End : SOS36159
               AND ORDERS.Status < N'9'
         End
         Else
         Begin
            -- Added By Ricky For IDSV5 for userdefine06 and userdefine07 column
            INSERT #OPORDERS
                 ( Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag )
            SELECT OrderKey,StorerKey,ConsigneeKey,Type,Status, Priority,DeliveryDate,OrderDate ,
            Intermodalvehicle , OrderGroup, userdefine06,  userdefine07, Facility, xdockflag
            FROM ORDERS (NOLOCK)
            WHERE OrderKey = @c_orderkey
               -- Start : SOS36159
               -- AND ORDERS.SOStatus = '0'
               AND ORDERS.SOStatus <> 'CANC'
               -- End : SOS36159
               AND ORDERS.Status < '9'
         End
      End

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78303   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      ELSE IF @n_cnt = 0
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE TYPE IN ('M', 'I') AND ORDERKEY = @c_orderkey)
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 78304
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Order Does Not Exist. (nspPreAllocateOrderProcessing)"
         END
      END
   END -- Allocate By Order Key
   ELSE
   BEGIN
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         /* IDSV5 - Leo - PH MASS ALLOCATION */
         DECLARE @d_orderdatestart datetime, @d_orderdateend datetime,
         @d_deliverydatestart datetime, @d_deliverydateend datetime ,
         @c_ordertypestart NVARCHAR(10), @c_ordertypeend NVARCHAR(10) ,
         @c_orderprioritystart NVARCHAR(10) , @c_orderpriorityend NVARCHAR(10) ,
         @c_StorerKeystart NVARCHAR(15), @c_StorerKeyend NVARCHAR(15) ,
         @c_consigneekeystart NVARCHAR(15), @c_consigneekeyend NVARCHAR(15) ,
         @c_carrierkeystart NVARCHAR(15), @c_carrierkeyend NVARCHAR(15) ,
         @c_orderkeystart NVARCHAR(10), @c_orderkeyend NVARCHAR(10) ,
         @c_externorderkeystart NVARCHAR(30), @c_externorderkeyend NVARCHAR(30) ,
         @c_ordergroupstart NVARCHAR(20), @c_ordergroupend NVARCHAR(20),
         @n_maxorders int, @d_OrderDate datetime,  -- Added By June - 19.Oct.01
         @c_facility NVARCHAR(10), -- CDC Migration
         -- Add by June 05.June.03
         @d_LoadingDateStart datetime, @d_LoadingDateEnd datetime,
         -- SOS25145 - Add by June 26.Jul.04
         @c_RouteStart NVARCHAR(10), @c_RouteEnd NVARCHAR(10)

         -- check if MASS allocatin or LOAD allocation

         declare @c_xdockpokeystart NVARCHAR(20),
                 @c_xdockpokeyend NVARCHAR(20)

         IF @c_doroute = '3'
         Begin -- mass allocation
            Select @d_orderdatestart = orderdatestart ,
            @d_orderdateend   = orderdateend ,
            @d_deliverydatestart = deliverydatestart ,
            @d_deliverydateend = deliverydateend ,
            @c_ordertypestart = ordertypestart ,
            @c_ordertypeend = ordertypeend ,
            @c_orderprioritystart = orderprioritystart ,
            @c_orderpriorityend = orderpriorityend ,
            @c_StorerKeystart = StorerKeystart ,
            @c_StorerKeyend = StorerKeyend ,
            @c_consigneekeystart = consigneekeystart ,
            @c_consigneekeyend = consigneekeyend ,
            @c_carrierkeystart = carrierkeystart ,
            @c_carrierkeyend = carrierkeyend ,
            @c_orderkeystart = orderkeystart ,
            @c_orderkeyend = orderkeyend ,
            @c_externorderkeystart = externorderkeystart ,
            @c_externorderkeyend = externorderkeyend ,
            @c_ordergroupstart = ordergroupstart ,
            @c_ordergroupend = ordergroupend ,
            @n_maxorders = maxorders ,
            @c_facility = facility , -- CDC Migration
            @d_LoadingDateStart = LoadingDateStart,   -- Add by June 05.June.03
            @d_LoadingDateEnd = LoadingDateEnd,       -- Add by June 05.June.03
            @c_xdockpokeystart = xdockpokeystart,
            @c_xdockpokeyend = xdockpokeyend,
            @c_RouteStart = RouteStart, -- SOS25145
            @c_RouteEnd = RouteEnd -- SOS25145
            FROM OrderSelection WITH (NOLOCK)
            WHERE OrderSelectionkey = @c_oskey

            -- insert into #oporders based on selection criteria
            INSERT #OPORDERS
                 ( Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag )
            SELECT DISTINCT -- SOS38185
            ORDERS.OrderKey, ORDERS.StorerKey, ORDERS.ConsigneeKey,
            ORDERS.Type, ORDERS.Status, ORDERS.Priority, ORDERS.DeliveryDate, ORDERS.OrderDate,
            ORDERS.IntermodalVehicle, ORDERS.OrderGroup, ORDERS.userdefine06, ORDERS.userdefine07,
            ORDERS.FACILITY, -- Added By Ricky for IDSV5,
            ORDERS.xdockflag
            FROM ORDERS (NOLOCK)
            JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey -- SOS38185
            WHERE ORDERS.StorerKey >=@c_StorerKeystart
            AND ORDERS.StorerKey <= @c_StorerKeyend
            -- Start : SOS38185
            -- AND ORDERS.Status IN ('0', '1')
            AND ORDERS.Status < '9'
            AND ORDERDETAIL.Status = '0'
            -- End : SOS38185
            -- Start : SOS36159
            -- AND ORDERS.SOStatus = '0'
            AND ORDERS.SOStatus <> 'CANC'
            -- End : SOS36159
            AND ORDERS.ConsigneeKey >= @c_consigneekeystart
            AND ORDERS.ConsigneeKey <=  @c_consigneekeyend
            AND ORDERS.Type >=  @c_ordertypestart
            AND ORDERS.Type <=  @c_OrderTypeEnd
            AND ORDERS.OrderDate >= @d_orderdatestart
            AND ORDERS.OrderDate <= @d_orderdateend
            AND ORDERS.DeliveryDate >= @d_deliveryDateStart
            AND ORDERS.DeliveryDate <= @d_deliveryDateEnd
            AND ORDERS.Priority >= @c_orderpriorityStart
            AND ORDERS.Priority <= @c_orderpriorityEnd
            AND ORDERS.Intermodalvehicle >= @c_carrierkeystart
            AND ORDERS.Intermodalvehicle <= @c_carrierkeyend
            AND ORDERS.Orderkey >= @c_OrderkeyStart
            AND ORDERS.Orderkey <= @c_OrderkeyEnd
            AND ORDERS.ExternOrderkey >= @c_ExternOrderkeyStart
            AND ORDERS.ExternOrderkey <= @c_ExternOrderkeyEnd
            AND ORDERS.OrderGroup >= @c_ordergroupstart
            AND ORDERS.OrderGroup <= @c_ordergroupend -- SOS42877
            and orders.facility = @c_facility -- CDC Migration
            AND isnull(ORDERS.Userdefine06, 0) >= isnull(@d_LoadingDateStart,0)   -- Add by June 05.June.03
            AND isnull(ORDERS.Userdefine06, 0) <= isnull(@d_LoadingDateEnd,0)     -- Add by June 05.June.03
            and orders.Route >= @c_RouteStart -- SOS25145
            and orders.Route <= @c_RouteEnd -- SOS25145
            and orders.pokey >= @c_xdockpokeystart
            and orders.pokey <= @c_xdockpokeyend

            SELECT @n_cnt = @@ROWCOUNT
         End -- mass allocation
         Else
         Begin
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF EXISTS (SELECT 1 FROM NSQLCONFIG WHERE CONFIGKEY = 'Bypass_ordertype' and Nsqlvalue = '1')
               BEGIN
                  -- Added By Ricky For IDSV5 for userdefine06 and userdefine07 column
                  INSERT #OPORDERS
                 ( Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag )
                  SELECT ORDERS.OrderKey, ORDERS.StorerKey, ORDERS.ConsigneeKey,  ORDERS.Type, ORDERS.Status,
                  ORDERS.Priority, ORDERS.DeliveryDate, ORDERS.OrderDate, ORDERS.IntermodalVehicle, ORDERS.OrderGroup,
                  ORDERS.userdefine06,  ORDERS.userdefine07, ORDERS.Facility, ORDERS.xdockflag
                  FROM ORDERS (NOLOCK)
                  JOIN LoadPlanDetail (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
                  WHERE ORDERS.Status < '9'
                  AND LoadPlanDetail.LoadKey = @c_oskey
                  AND ORDERS.Type NOT IN ('M', 'I')
                  -- Added By SHONG, Do not allocate Wave Order Here.. 22 May 2002
                  AND (ORDERS.UserDefine08 <> 'Y' OR LEFT(@c_extendparms, 2)='WP') -- NJOW02 if call from wave no checking
               END
               ELSE
               BEGIN
                  -- Added By Ricky For IDSV5 for userdefine06 and userdefine07 column
                  INSERT #OPORDERS
                 ( Orderkey,          StorerKey,    Consigneekey,  Type,         Status,
                   Priority,          DeliveryDate, Orderdate,
                   Intermodalvehicle, OrderGroup,   userdefine06,  userdefine07, Facility,
                   xdockflag )
                  SELECT ORDERS.OrderKey, ORDERS.StorerKey, ORDERS.ConsigneeKey, ORDERS.Type, ORDERS.Status,
                  ORDERS.Priority, ORDERS.DeliveryDate, ORDERS.OrderDate, ORDERS.IntermodalVehicle, ORDERS.OrderGroup,
                  ORDERS.userdefine06, ORDERS.userdefine07, ORDERS.Facility, ORDERS.xdockflag
                  FROM ORDERS (NOLOCK)
                  JOIN LoadPlanDetail (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
                  WHERE ORDERS.Status < '9'
                    AND LoadPlanDetail.LoadKey = @c_oskey
                  -- Added By SHONG, Do not allocate Wave Order Here.. 22 May 2002
                  AND (ORDERS.UserDefine08 <> 'Y' OR LEFT(@c_extendparms, 2)='WP') -- NJOW02 if call from wave no checking
               END

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78306   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END -- @n_continue = 1 or @n_continue = 2
         End -- Loadplan Allocation
      END
   END
END

SELECT @n_cnt = COUNT(*) FROM #OPORDERS
IF @n_cnt = 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 78307
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders To Process. (nspPreAllocateOrderProcessing)"
END

IF @b_debug = 1 or @b_debug = 2
BEGIN
   PRINT 'Pre-Allocation: Started at ' + CONVERT(varchar(20), GetDate())
   PRINT ''
   PRINT 'OrderKey: ' + RTRIM(@c_orderkey)
   PRINT 'Load Key: ' + RTRIM(@c_oskey)
   PRINT 'Facility: ' + RTRIM(@c_Facility)
   PRINT ''
   PRINT 'Number of Order Lines to process: ' + CAST(@n_cnt as NVARCHAR(5))
   -- SELECT * FROM #OPORDERS
END

--(Wan08) - START
IF @n_continue = 1 OR @n_continue = 2  
BEGIN  
   IF OBJECT_ID('tempdb..#PREALLOCATE_CANDIDATES','u') IS NOT NULL
   BEGIN
      DROP TABLE #PREALLOCATE_CANDIDATES;
   END

   CREATE TABLE #PREALLOCATE_CANDIDATES
   (  RowID          INT            NOT NULL IDENTITY(1,1) 
   ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  QtyAvailable   INT            NOT NULL DEFAULT(0)
   )
END
--(Wan08) - END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   --(Wan03) - START
   DECLARE @c_AutoDeletePreallocations NVARCHAR(1)
      ,    @c_SC_Facility              NVARCHAR(5)
      ,    @c_SC_Storerkey             NVARCHAR(15)

   DECLARE CUR_SC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          #OPORDERS.Facility
         ,#OPORDERS.Storerkey
   FROM #OPORDERS 
    
   OPEN CUR_SC

   FETCH NEXT FROM CUR_SC INTO @c_SC_Facility
                             , @c_SC_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_AutoDeletePreallocations = '0'

      EXEC nspGetRight  
                  @c_Facility  = @c_SC_Facility         
               ,  @c_Storerkey = @c_SC_Storerkey      
               ,  @c_Sku = ''       
               ,  @c_Configkey = 'AutoDeletePreAllocation'        
               ,  @b_Success   = @b_Success OUTPUT    
               ,  @c_authority = @c_AutoDeletePreallocations OUTPUT   
               ,  @n_err       = @n_err     OUTPUT    
               ,  @c_errmsg    = @c_errmsg  OUTPUT
   --(Wan03) - END
      IF @c_AutoDeletePreallocations = "1"
      BEGIN
         DELETE PREALLOCATEPICKDETAIL 
         FROM #OPORDERS 
         WHERE PREALLOCATEPICKDETAIL.Orderkey = #OPORDERS.Orderkey 
         AND #OPORDERS.Facility  = @c_SC_Facility                    --(Wan03)
         AND #OPORDERS.Storerkey = @c_SC_Storerkey                   --(Wan03)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78329   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete From PreallocatePickDetail Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   --(Wan03) - START
      FETCH NEXT FROM CUR_SC INTO @c_SC_Facility
                                 ,@c_SC_Storerkey
   END
   CLOSE CUR_SC
   DEALLOCATE CUR_SC
   --(Wan03) - END
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF EXISTS(SELECT 1 FROM #OPORDERS OPD 
             JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = OPD.Orderkey 
             WHERE PICKDETAIL.caseid LIKE N'C%')
   BEGIN
      DELETE PICKDETAIL 
      FROM #OPORDERS OPD
      WHERE PICKDETAIL.Orderkey = OPD.Orderkey 
        AND PICKDETAIL.caseid LIKE N'C%'

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78330   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete From PickDetail Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
END


IF @n_continue = 1 or @n_continue = 2
BEGIN
   -- Create Temp Table #OPORDERLINES
   CREATE TABLE #OPORDERLINES
   (
      OrderKey                NVARCHAR(10),
      OrderLineNumber         NVARCHAR(5),
      StorerKey       NVARCHAR(15),
      Sku                     NVARCHAR(20),
      PickCode                NVARCHAR(10)NULL,
      Lot                     NVARCHAR(10)NULL,
      ID                      NVARCHAR(18)NULL,
      Lottable01              NVARCHAR(18)NULL,
      Lottable02              NVARCHAR(18)NULL,
      Lottable03              NVARCHAR(18)NULL,
      Lottable04              DATETIME NULL,
      Lottable05              DATETIME NULL,
      Lottable06              NVARCHAR(30) NULL,
      Lottable07              NVARCHAR(30) NULL,
      Lottable08              NVARCHAR(30) NULL,
      Lottable09              NVARCHAR(30) NULL,
      Lottable10              NVARCHAR(30) NULL,
      Lottable11              NVARCHAR(30) NULL,
      Lottable12              NVARCHAR(30) NULL,
      Lottable13              DATETIME NULL,
      Lottable14              DATETIME NULL,
      Lottable15              DATETIME NULL,
      OpenQty                 INT NULL,
      QtyAllocated            INT NULL,
      QtyPreAllocated         INT NULL,
      QtyPicked               INT NULL,
      PackKey                 NVARCHAR(10) NULL,
      TYPE                    NVARCHAR(10) NULL,
      Priority                NVARCHAR(10) NULL,
      DeliveryDate            DATETIME NULL,
      IntermodalVehicle       NVARCHAR(30) NULL,
      PreAllocatePickCode     NVARCHAR(10) NULL,
      Facility                NVARCHAR(5) NULL,
      MinShelfLife            INT NULL,
      UOM                     NVARCHAR(10) NULL,
      Channel                 NVARCHAR(20) NULL,
      StrategyKey             NVARCHAR(10) NULL   --WL01      
   )

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78328   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of OPORDERLINES Temp Table Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   
   --IF @n_continue = 1 or @n_continue = 2
--BEGIN
   --   CREATE INDEX OPOrderLineIdx1 ON #OPORDERLINES (OrderKey)
   --END
      
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF @c_freegoodsallocation = '1'
   BEGIN
      INSERT #OPORDERLINES
        ( OrderKey,             OrderLineNumber,     StorerKey,
          Sku,                  PickCode,            Lot,
          ID,                   Lottable01,          Lottable02,
          Lottable03,           Lottable04,          Lottable05,
          Lottable06,           Lottable07,          Lottable08,
          Lottable09,           Lottable10,          Lottable11,
          Lottable12,           Lottable13,          Lottable14,
          Lottable15,           OpenQty,             QtyAllocated,
          QtyPreAllocated,      QtyPicked,           PackKey,
          TYPE,                 Priority,            DeliveryDate,
          IntermodalVehicle,    PreAllocatePickCode, Facility,
          MinShelfLife,         UOM,                 Channel  )
      SELECT ORDERDETAIL.ORDERKEY
            ,ORDERDETAIL.OrderLineNumber
            ,ORDERDETAIL.StorerKey
            ,ORDERDETAIL.SKU
            ,ORDERDETAIL.PICKCODE
            ,ORDERDETAIL.LOT
            ,ORDERDETAIL.ID
            ,ORDERDETAIL.LOTTABLE01
            ,ORDERDETAIL.LOTTABLE02
            ,ORDERDETAIL.LOTTABLE03
            ,ORDERDETAIL.LOTTABLE04
            ,ORDERDETAIL.LOTTABLE05
            ,ORDERDETAIL.LOTTABLE06
            ,ORDERDETAIL.LOTTABLE07
            ,ORDERDETAIL.LOTTABLE08
            ,ORDERDETAIL.LOTTABLE09
            ,ORDERDETAIL.LOTTABLE10
            ,ORDERDETAIL.LOTTABLE11
            ,ORDERDETAIL.LOTTABLE12
            ,ORDERDETAIL.LOTTABLE13
            ,ORDERDETAIL.LOTTABLE14
            ,ORDERDETAIL.LOTTABLE15
            ,(ORDERDETAIL.OpenQty + ORDERDETAIL.FreeGoodQty) AS 'OpenQty'
            ,ORDERDETAIL.QtyAllocated
            ,ORDERDETAIL.QtyPreAllocated
            ,ORDERDETAIL.QtyPicked
            ,ISNULL(ORDERDETAIL.PackKey,'')
            ,#OPORDERS.Type
            ,#OPORDERS.Priority
            ,#OPORDERS.DeliveryDate
            ,#OPORDERS.IntermodalVehicle
            ,PreAllocatePickCode = N''
            ,#OPORDERS.Facility
            ,ORDERDETAIL.MinShelfLife
            ,ORDERDETAIL.UOM
            ,Channel=ISNULL(ORDERDETAIL.Channel, '') 
      FROM   ORDERDETAIL WITH (NOLOCK)
      JOIN #OPORDERS ON ORDERDETAIL.orderkey = #OPORDERS.OrderKey
      WHERE  ((ORDERDETAIL.OpenQty + ORDERDETAIL.FreeGoodQty) -
              (OrderDetail.QtyAllocated + OrderDetail.QtyPreAllocated + OrderDetail.QtyPicked) > 0)
   END
   ELSE
   BEGIN
      INSERT #OPORDERLINES
        ( OrderKey,             OrderLineNumber,     StorerKey,
          Sku,                  PickCode,            Lot,
          ID,                   Lottable01,          Lottable02,
          Lottable03,           Lottable04,          Lottable05,
          Lottable06,           Lottable07,          Lottable08,
          Lottable09,           Lottable10,          Lottable11,
          Lottable12,           Lottable13,          Lottable14,
          Lottable15,           OpenQty,             QtyAllocated,
          QtyPreAllocated,      QtyPicked,           PackKey,
          TYPE,                 Priority,            DeliveryDate,
          IntermodalVehicle,    PreAllocatePickCode, Facility,
          MinShelfLife,         UOM,                 Channel  )
      SELECT ORDERDETAIL.ORDERKEY
            ,ORDERDETAIL.OrderLineNumber
            ,ORDERDETAIL.StorerKey
            ,ORDERDETAIL.SKU
            ,ORDERDETAIL.PICKCODE
            ,ORDERDETAIL.LOT
            ,ORDERDETAIL.ID
            ,ORDERDETAIL.LOTTABLE01
            ,ORDERDETAIL.LOTTABLE02
            ,ORDERDETAIL.LOTTABLE03
            ,ORDERDETAIL.LOTTABLE04
            ,ORDERDETAIL.LOTTABLE05
            ,ORDERDETAIL.LOTTABLE06
            ,ORDERDETAIL.LOTTABLE07
            ,ORDERDETAIL.LOTTABLE08
            ,ORDERDETAIL.LOTTABLE09
            ,ORDERDETAIL.LOTTABLE10
            ,ORDERDETAIL.LOTTABLE11
            ,ORDERDETAIL.LOTTABLE12
            ,ORDERDETAIL.LOTTABLE13
            ,ORDERDETAIL.LOTTABLE14
            ,ORDERDETAIL.LOTTABLE15
            ,ORDERDETAIL.OpenQty
            ,ORDERDETAIL.QtyAllocated
            ,ORDERDETAIL.QtyPreAllocated
            ,ORDERDETAIL.QtyPicked
            ,ISNULL(ORDERDETAIL.PackKey,'')
            ,#OPORDERS.Type
            ,#OPORDERS.Priority
            ,#OPORDERS.DeliveryDate
            ,#OPORDERS.IntermodalVehicle
            ,PreAllocatePickCode = N''
            ,#OPORDERS.Facility
            ,ORDERDETAIL.MinShelfLife
            ,ORDERDETAIL.UOM
            ,Channel=ISNULL(ORDERDETAIL.Channel, '') 
      FROM ORDERDETAIL WITH (NOLOCK)
      JOIN #OPORDERS ON ORDERDETAIL.orderkey = #OPORDERS.OrderKey
      WHERE OrderDetail.OpenQty - ( OrderDetail.QtyAllocated + OrderDetail.QtyPreAllocated + OrderDetail.QtyPicked) > 0
   END

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3

      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78310   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert of rows into the OPORDERLINES Temp Table Failed (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END

   IF (SELECT count(*) FROM #OPORDERLINES) = 0
   BEGIN
      SELECT @n_continue = 4
   END



END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   DECLARE @c_cartonizationgroup NVARCHAR(10),  @c_routingkey NVARCHAR(10),  @c_dorouting NVARCHAR(1),  @c_docartonization NVARCHAR(1),
   @c_preallocationgrouping NVARCHAR(10),  @c_preallocationsort NVARCHAR(10),  @c_waveoption NVARCHAR(10),  @c_workoskey NVARCHAR(10)
   SELECT @c_dorouting = @c_doroute

   -- SET ROWCOUNT 1

   If @c_doroute = '3' -- IDSV5 - Leo - PH MASS ALLOCATION
   Begin
      SELECT TOP 1 @c_cartonizationgroup = cartonizationgroup ,
            @c_routingkey = routingkey ,
            @c_preallocationgrouping = preallocationgrouping ,
            @c_preallocationsort = preallocationsort ,
            @c_waveoption = waveoption ,
            @c_workoskey = OrderSelectionkey
      FROM  OrderSelection (NOLOCK)
      WHERE OrderSelectionKey = @c_oskey

      SELECT @n_cnt = @@ROWCOUNT
   End
   Else
   Begin
      SELECT TOP 1 @c_cartonizationgroup = cartonizationgroup,
              @c_routingkey = routingkey,
              @c_preallocationgrouping = preallocationgrouping,
              @c_preallocationsort = preallocationsort,
              @c_waveoption = waveoption,
              @c_workoskey = OrderSelectionkey
      FROM OrderSelection (NOLOCK)
      WHERE DefaultFlag = '1'
      SELECT @n_cnt = @@ROWCOUNT

      IF @n_cnt = 0
      BEGIN
         SELECT TOP 1 @c_cartonizationgroup = cartonizationgroup,
                 @c_routingkey = routingkey,
                 @c_preallocationgrouping = preallocationgrouping,
                 @c_preallocationsort = preallocationsort,
                 @c_waveoption = waveoption,
                 @c_workoskey = OrderSelectionkey
         FROM OrderSelection (NOLOCK)
         WHERE OrderSelectionkey = 'STD'
         SELECT @n_cnt = @@ROWCOUNT
      END

      --NJOW01 Start
      IF @n_cnt = 0
      BEGIN
         SELECT  TOP 1 @c_cartonizationgroup = cartonizationgroup,
                 @c_routingkey = routingkey,
                 @c_preallocationgrouping = preallocationgrouping,
                 @c_preallocationsort = preallocationsort,
                 @c_waveoption = waveoption,
                 @c_workoskey = OrderSelectionkey
         FROM OrderSelection (NOLOCK)
         ORDER BY OrderSelectionkey
         SELECT @n_cnt = @@ROWCOUNT
      END

      IF @n_cnt = 0
      BEGIN
          SELECT @c_cartonizationgroup = 'STD'
          SELECT @c_preallocationsort = '1'
          SELECT @c_preallocationgrouping = '1'
          SELECT @c_waveoption = 'DISCRETE'
          SELECT @c_routingkey = 'STD'
          SELECT @n_cnt = 1
      END
      --NJOW01 End
   End
   IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78312
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Incomplete OrderSelection Parameters! (nspPreAllocateOrderProcessing)"
   END

   -- SET ROWCOUNT 0
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   IF EXISTS(SELECT 1 FROM #OPORDERLINES OPD WHERE OPD.PackKey = N'')
   BEGIN
      UPDATE OPD 
            SET PackKey = SKU.PackKey
      FROM #OPORDERLINES OPD 
      JOIN SKU (NOLOCK) ON OPD.StorerKey = SKU.StorerKey AND OPD.Sku = SKU.Sku 
      WHERE OPD.PackKey = '' 
        AND SKU.PackKey IS NOT NULL
   END

   /* Start - Customization for IDS - Added by DLIM for FBR24A 20010716 */
   IF @c_xdock = 'Y'
   BEGIN
      UPDATE #OPORDERLINES SET PICKCODE = "XDOCK"
   END
   ELSE
   BEGIN
      UPDATE #OPORDERLINES 
         SET PICKCODE = STRATEGY.PreAllocateStrategyKey
      FROM #OPORDERLINES
      JOIN SKU WITH (NOLOCK) ON #OPORDERLINES.StorerKey = SKU.StorerKey
                            AND #OPORDERLINES.SKU = SKU.SKU
      JOIN STRATEGY WITH (NOLOCK) ON SKU.Strategykey = Strategy.Strategykey

      --(Wan01) - START
      IF @c_extendparms = 'LP'
      BEGIN
         SELECT @c_DefaultStrategykey = ISNULL(RTRIM(LOADPLAN.DefaultStrategykey),'')
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)
         WHERE LOADPLANDETAIL.Orderkey = @c_Orderkey
         AND LOADPLAN.DefaultStrategykey = 'Y'
      END

      IF @c_oskey <> ''
      BEGIN
         SELECT @c_DefaultStrategykey = ISNULL(RTRIM(DefaultStrategykey),'')
         FROM LOADPLAN WITH (NOLOCK)
         WHERE LOADPLAN.Loadkey = @c_oskey
      END

      --IF @c_DefaultStrategykey = 'Y'
            IF ISNULL(@c_StrategykeyParm,'') <> ''  --NJOW05   
      BEGIN  
         UPDATE TMP    
         SET StrategyKey = ISNULL(STRATEGY.PreAllocateStrategyKey, '')    
         FROM #OPORDERLINES TMP    
         JOIN STRATEGY     WITH (NOLOCK) ON  STRATEGY.Strategykey = @c_StrategykeyParm           
      END        
      ELSE IF (@c_DefaultStrategykey = 'Y' AND (@c_extendparms = 'LP' OR  @c_oskey <> '')) 
         OR (@c_extendparms <> 'LP')   --NJOW04
      BEGIN
--         UPDATE #OPORDERLINES
--            SET PickCode = ISNULL(RTRIM(STRATEGY.PreAllocateStrategyKey),'')
--         FROM #OPORDERLINES TMP
--         JOIN STORER   WITH (NOLOCK) ON TMP.Storerkey = STORER.Storerkey
--         JOIN STRATEGY WITH (NOLOCK) ON STORER.Strategykey = STRATEGY.Strategykey
         -- (SHONG01)
          --NJOW03
         IF @c_extendparms = 'LP' OR @c_oskey <> ''
         BEGIN         
            UPDATE TMP
                SET PickCode = CASE
                                    WHEN ISNULL(RTRIM(STRATEGY.PreAllocateStrategyKey),'') = '' AND ISNULL(RTRIM(STORERCONFIG.sValue),'') = '' THEN
                                       TMP.PickCode
                                    WHEN ISNULL(RTRIM(STRATEGY.PreAllocateStrategyKey),'') <> '' THEN
                                       STRATEGY.PreAllocateStrategyKey -- Leong01
                                    WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') <> '' THEN
                                       STG2.PreAllocateStrategyKey
                                    ELSE
                                       TMP.PickCode
                                 END
            FROM #OPORDERLINES TMP
            JOIN STORER   WITH (NOLOCK) ON TMP.Storerkey = STORER.Storerkey
            LEFT OUTER JOIN STRATEGY WITH (NOLOCK) ON STORER.Strategykey = STRATEGY.Strategykey
            LEFT OUTER JOIN STORERCONFIG WITH (NOLOCK) ON StorerConfig.StorerKey = TMP.Storerkey AND StorerConfig.Facility = TMP.Facility
                                                          AND StorerConfig.ConfigKey = 'StorerDefaultAllocStrategy'
            LEFT OUTER JOIN STRATEGY STG2 WITH (NOLOCK) ON STG2.StrategyKey = STORERCONFIG.sValue
         END
         ELSE
         BEGIN
              -- @c_extendparms <> 'LP  ORDER/WAVE Discrete NJOW04    
            UPDATE TMP
            SET PickCode = STRATEGY.PreAllocateStrategyKey 
            FROM #OPORDERLINES TMP
            JOIN STORERCONFIG WITH (NOLOCK) ON StorerConfig.StorerKey = TMP.Storerkey 
                                               AND StorerConfig.Facility = TMP.Facility
                                               AND StorerConfig.ConfigKey = 'StorerDefaultAllocStrategy'
            JOIN STRATEGY WITH (NOLOCK) ON STRATEGY.StrategyKey = StorerConfig.sValue            
         END
      END
      /*ELSE
      BEGIN
          --(Wan01) - END

         UPDATE #OPORDERLINES 
            SET PICKCODE = STRATEGY.PreAllocateStrategyKey
         FROM #OPORDERLINES
         JOIN SKU WITH (NOLOCK) ON #OPORDERLINES.StorerKey = SKU.StorerKey
                               AND #OPORDERLINES.SKU = SKU.SKU
         JOIN STRATEGY WITH (NOLOCK) ON SKU.Strategykey = Strategy.Strategykey
      END*/   --(Wan01)
   END
END
/* End - Customization for IDS - Added by DLIM for FBR24A 20010716 */

IF @n_continue = 1 or @n_continue = 2
BEGIN
   DECLARE @b_cursorordergroups_open int, @b_cursorcandidates_open int, @b_cursorlineitems_open int

   DECLARECURSOR_ORDERS:

   SELECT @b_cursorordergroups_open = 0, @b_cursorcandidates_open = 0, @b_cursorlineitems_open = 0
   IF ( SELECT SuperOrderFlag FROM LoadPlan (NOLOCK) WHERE LoadKey = @c_oskey ) = 'Y'
   BEGIN
      SELECT @c_preallocationsort = '4'
   END
   /***** Customised For MNLT *****/

   IF @c_preallocationsort = "1"
   BEGIN
      EXEC ('DECLARE CURSOR_ORDERS CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT
      #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,   #OPORDERS.Type,   #OPORDERLINES.PickCode,  #OPORDERS.Priority,
      #OPORDERLINES.Lot,         #OPORDERLINES.Lottable01,    #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03,
      #OPORDERLINES.Lottable04,  #OPORDERLINES.Lottable05 ,   #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
      #OPORDERLINES.Lottable08,  #OPORDERLINES.Lottable09 ,   #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
      #OPORDERLINES.Lottable12,  #OPORDERLINES.Lottable13 ,   #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
      #OPORDERS.DeliveryDate,    #OPORDERS.IntermodalVehicle,
      #OPORDERLINES.OrderKey,    #OPORDERLINES.Facility,      #OPORDERLINES.OrderLineNumber, #OPORDERS.Orderdate,
      #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
      FROM #OPORDERLINES,#OPORDERS
      WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
      GROUP BY
      #OPORDERLINES.Orderkey,       #OPORDERLINES.OrderLineNumber, #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,
      #OPORDERS.Type,               #OPORDERS.Priority,            #OPORDERS.Deliverydate,
      #OPORDERS.IntermodalVehicle,  #OPORDERLINES.PickCode,        #OPORDERLINES.Lot,
      #OPORDERLINES.Lottable01,     #OPORDERLINES.Lottable02,      #OPORDERLINES.Lottable03,
      #OPORDERLINES.Lottable04,     #OPORDERLINES.Lottable05,      #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
      #OPORDERLINES.Lottable08,     #OPORDERLINES.Lottable09 ,     #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
      #OPORDERLINES.Lottable12,     #OPORDERLINES.Lottable13 ,     #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
      #OPORDERLINES.Facility,       #OPORDERS.OrderDate,
      #OPORDERS.xdockflag,          #OPORDERLINES.Channel 
      ORDER BY #OPORDERS.Deliverydate,       #OPORDERS.Priority,        #OPORDERS.IntermodalVehicle,
      #OPORDERLINES.Orderkey,       #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,
      #OPORDERS.Type,#OPORDERLINES.PickCode,                   #OPORDERLINES.Lot,
      #OPORDERLINES.Lottable01,     #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03,
      #OPORDERLINES.Lottable04,     #OPORDERLINES.Lottable05')
   END
ELSE IF @c_preallocationsort = "2"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT
   #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,           #OPORDERS.Type,            #OPORDERLINES.PickCode,
   #OPORDERS.Priority,
   #OPORDERLINES.Lot,         #OPORDERLINES.Lottable01,    #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03,
   #OPORDERLINES.Lottable04,  #OPORDERLINES.Lottable05,    #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08,  #OPORDERLINES.Lottable09 ,   #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12,  #OPORDERLINES.Lottable13 ,   #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,    #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.OrderKey,    #OPORDERLINES.Facility,      #OPORDERLINES.OrderLineNumber, #OPORDERS.Orderdate,
   #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY
   #OPORDERLINES.Orderkey,       #OPORDERLINES.OrderLineNumber, #OPORDERLINES.StorerKey,     #OPORDERLINES.Sku,
   #OPORDERS.Type,               #OPORDERS.Priority,          #OPORDERS.Deliverydate,
   #OPORDERS.IntermodalVehicle,  #OPORDERLINES.PickCode,      #OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01,     #OPORDERLINES.Lottable02,    #OPORDERLINES.Lottable03,
   #OPORDERLINES.Lottable04,     #OPORDERLINES.Lottable05,    #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08,     #OPORDERLINES.Lottable09 ,   #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12,     #OPORDERLINES.Lottable13 ,   #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
   #OPORDERLINES.Facility,       #OPORDERS.OrderDate,         #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
   ORDER BY 
   #OPORDERS.Deliverydate,       #OPORDERS.IntermodalVehicle, #OPORDERS.Priority,
   #OPORDERLINES.Lot,            #OPORDERLINES.Lottable01,    #OPORDERLINES.Lottable02,
   #OPORDERLINES.Lottable03,     #OPORDERLINES.Lottable04,    #OPORDERLINES.Lottable05')
END
ELSE IF @c_preallocationsort = "3"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT
   #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,  #OPORDERS.Type,   #OPORDERLINES.PickCode,   #OPORDERS.Priority,
   #OPORDERLINES.Lot,         #OPORDERLINES.Lottable01,   #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03,
   #OPORDERLINES.Lottable04,  #OPORDERLINES.Lottable05,   #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08,  #OPORDERLINES.Lottable09,   #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12,  #OPORDERLINES.Lottable13,   #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,    #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.OrderKey,    #OPORDERLINES.Facility,     #OPORDERLINES.OrderLineNumber, #OPORDERS.Orderdate,
   #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY #OPORDERLINES.Orderkey,  #OPORDERLINES.OrderLineNumber, #OPORDERLINES.StorerKey,  #OPORDERLINES.Sku,   #OPORDERS.Type,
   #OPORDERS.Priority,       #OPORDERS.Deliverydate,   #OPORDERS.IntermodalVehicle, #OPORDERLINES.PickCode,
   #OPORDERLINES.Lot,        #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02,    #OPORDERLINES.Lottable03,
   #OPORDERLINES.Lottable04, #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06,    #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10,    #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14,    #OPORDERLINES.Lottable15,
   #OPORDERLINES.Facility,   #OPORDERS.OrderDate,      #OPORDERS.xdockflag,         #OPORDERLINES.Channel 
   ORDER BY 
   #OPORDERS.Deliverydate,   #OPORDERS.Type,           #OPORDERS.Priority,
   #OPORDERLINES.Lot,        #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02,
   #OPORDERLINES.Lottable03, #OPORDERLINES.Lottable04, #OPORDERLINES.Lottable05')
END
ELSE IF @c_preallocationsort = "4"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT #OPORDERLINES.StorerKey,     #OPORDERLINES.Sku,         #OPORDERS.Type,   #OPORDERLINES.PickCode,    #OPORDERS.Priority,
   #OPORDERLINES.Lot,         #OPORDERLINES.Lottable01,  #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03,
   #OPORDERLINES.Lottable04,  #OPORDERLINES.Lottable05,  #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08,  #OPORDERLINES.Lottable09,  #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12,  #OPORDERLINES.Lottable13,  #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,    #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.OrderKey,    #OPORDERLINES.Facility,    #OPORDERLINES.OrderLineNumber, #OPORDERS.Orderdate,
   #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY 
   #OPORDERLINES.Orderkey,    #OPORDERLINES.OrderLineNumber, #OPORDERLINES.StorerKey,   #OPORDERLINES.Sku,    #OPORDERS.Type,
   #OPORDERS.Priority,        #OPORDERS.Deliverydate,   #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.PickCode,    #OPORDERLINES.Lot,        #OPORDERLINES.Lottable01,
   #OPORDERLINES.Lottable02,  #OPORDERLINES.Lottable03, #OPORDERLINES.Lottable04,   #OPORDERLINES.Lottable05,
   #OPORDERLINES.Lottable06,  #OPORDERLINES.Lottable07, #OPORDERLINES.Lottable08,   #OPORDERLINES.Lottable09,
   #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11, #OPORDERLINES.Lottable12,   #OPORDERLINES.Lottable13,
   #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15, #OPORDERLINES.Facility,     #OPORDERS.OrderDate,
   #OPORDERS.xdockflag,       #OPORDERLINES.Channel 
   ORDER BY #OPORDERLINES.Sku')
END
-- customized for ULP (Philippines) to cater for mass allocation sorting
-- orders should be sorted by priority, delivery date, booked date (OrderDate)
-- start: by WALLY 25.sep.2001
ELSE IF @c_preallocationsort = "5"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT #OPORDERLINES.StorerKey ,
   #OPORDERLINES.Sku ,
   #OPORDERS.Type ,
   #OPORDERLINES.PickCode ,
   #OPORDERS.Priority ,
   #OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02,    #OPORDERLINES.Lottable03,   #OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06,    #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09,    #OPORDERLINES.Lottable10,    #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13,    #OPORDERLINES.Lottable14,    #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,   #OPORDERS.IntermodalVehicle, #OPORDERLINES.OrderKey,      #OPORDERLINES.Facility,
   #OPORDERLINES.OrderLineNumber,   #OPORDERS.Orderdate,  -- Added by June 19.Oct.01
   #OPORDERS.xdockflag,      #OPORDERLINES.Channel 
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY #OPORDERLINES.Orderkey, #OPORDERLINES.StorerKey,#OPORDERLINES.Sku,#OPORDERS.Type,#OPORDERS.Priority,
   #OPORDERS.Deliverydate,   #OPORDERS.IntermodalVehicle, #OPORDERLINES.PickCode, #OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02, #OPORDERLINES.Lottable03,  #OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06, #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10,  #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14,  #OPORDERLINES.Lottable15,
   #OPORDERLINES.OrderKey, #OPORDERLINES.Facility, #OPORDERLINES.OrderLineNumber,
   #OPORDERS.OrderDate,    #OPORDERS.userdefine06, #OPORDERS.userdefine07, 
   #OPORDERS.xdockflag,    #OPORDERLINES.Channel   
   ORDER BY #OPORDERS.Priority DESC, #OPORDERS.userdefine06, #OPORDERS.Orderdate, #OPORDERLINES.OrderKey')
END
-- end: by WALLY 25.sep.2001

-- for watsons store ranking: wally 13.aug.2003
-- start01
ELSE IF @c_preallocationsort = "6"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT #OPORDERLINES.StorerKey ,
   #OPORDERLINES.Sku ,
   #OPORDERS.Type ,
   #OPORDERLINES.PickCode ,
   #OPORDERS.Priority ,
   #OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02, #OPORDERLINES.Lottable03,   #OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06, #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10,    #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14,    #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,
   #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.OrderKey,
   #OPORDERLINES.Facility,
   #OPORDERLINES.OrderLineNumber,
   #OPORDERS.Orderdate,  -- Added by June 19.Oct.01
   #OPORDERS.xdockflag,      #OPORDERLINES.Channel
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY #OPORDERLINES.Orderkey, #OPORDERLINES.StorerKey,#OPORDERLINES.Sku,#OPORDERS.Type,#OPORDERS.Priority,
   #OPORDERS.Deliverydate, #OPORDERS.IntermodalVehicle, #OPORDERLINES.PickCode,#OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01,#OPORDERLINES.Lottable02, #OPORDERLINES.Lottable03,#OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06,    #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10,    #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14,    #OPORDERLINES.Lottable15,
   #OPORDERLINES.OrderKey, #OPORDERLINES.Facility, #OPORDERLINES.OrderLineNumber,
   #OPORDERS.OrderDate, #OPORDERS.xdockflag,      #OPORDERLINES.Channel
   ORDER BY CONVERT(int, #OPORDERS.Priority)')
END
-- end01
-- SOS22128 - customized for CMC (Philippines) to cater for mass allocation sorting
-- orders should be sorted by Loading Date, Delivery date, booked date (OrderDate), priority, sales order#
-- start: by JUNE 22.APR.2004
ELSE IF @c_preallocationsort = "7"
BEGIN
   EXEC ('DECLARE CURSOR_ORDERS CURSOR  FAST_FORWARD READ_ONLY FOR
   SELECT #OPORDERLINES.StorerKey ,
   #OPORDERLINES.Sku ,
   #OPORDERS.Type ,
   #OPORDERLINES.PickCode ,
   #OPORDERS.Priority ,
   #OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01, #OPORDERLINES.Lottable02, #OPORDERLINES.Lottable03, #OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06, #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10, #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14, #OPORDERLINES.Lottable15,
   #OPORDERS.DeliveryDate,
   #OPORDERS.IntermodalVehicle,
   #OPORDERLINES.OrderKey,
   #OPORDERLINES.Facility,
   #OPORDERLINES.OrderLineNumber,
   #OPORDERS.Orderdate,  -- Added by June 19.Oct.01
   #OPORDERS.xdockflag,      #OPORDERLINES.Channel
   FROM #OPORDERLINES,#OPORDERS
   WHERE #OPORDERS.OrderKey = #OPORDERLINES.OrderKey
   GROUP BY #OPORDERLINES.Orderkey, #OPORDERLINES.StorerKey,#OPORDERLINES.Sku,#OPORDERS.Type,#OPORDERS.Priority,
   #OPORDERS.Deliverydate, #OPORDERS.IntermodalVehicle, #OPORDERLINES.PickCode,#OPORDERLINES.Lot,
   #OPORDERLINES.Lottable01,#OPORDERLINES.Lottable02, #OPORDERLINES.Lottable03,#OPORDERLINES.Lottable04,
   #OPORDERLINES.Lottable05, #OPORDERLINES.Lottable06,    #OPORDERLINES.Lottable07,
   #OPORDERLINES.Lottable08, #OPORDERLINES.Lottable09, #OPORDERLINES.Lottable10,    #OPORDERLINES.Lottable11,
   #OPORDERLINES.Lottable12, #OPORDERLINES.Lottable13, #OPORDERLINES.Lottable14,    #OPORDERLINES.Lottable15,
   #OPORDERLINES.OrderKey, #OPORDERLINES.Facility, #OPORDERLINES.OrderLineNumber,
   #OPORDERS.OrderDate, #OPORDERS.userdefine06, #OPORDERS.userdefine07, #OPORDERS.xdockflag, #OPORDERLINES.Channel  
   ORDER BY #OPORDERS.userdefine06, #OPORDERS.DeliveryDate, #OPORDERS.Orderdate, #OPORDERS.Priority DESC, #OPORDERLINES.OrderKey')
END
-- end: by JUNE - SOS22128

SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err = 16915
BEGIN
   CLOSE CURSOR_ORDERS
   DEALLOCATE CURSOR_ORDERS
   GOTO DECLARECURSOR_ORDERS
END

OPEN CURSOR_ORDERS
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err = 16905
BEGIN
   CLOSE CURSOR_ORDERS
   DEALLOCATE CURSOR_ORDERS
   GOTO DECLARECURSOR_ORDERS
END

IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78318   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Could not Open CURSOR_ORDERS (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
ELSE  BEGIN
   SELECT @b_cursorordergroups_open = 1
END
END

IF @n_continue = 1 or @n_continue = 2
BEGIN
   DECLARE @c_AStorerKey NVARCHAR(15),           @c_Asku NVARCHAR(20), @c_Atype NVARCHAR(10),  @c_Apriority NVARCHAR(10),
   @c_APreAllocateStrategyKey NVARCHAR(10),      @c_APreAllocatePickCode NVARCHAR(10),         @d_Adeliverydate DateTime,
   @c_AintermodalVehicle NVARCHAR(30),           @c_aOrderKey NVARCHAR(10),                    @c_aOrderLineNumber NVARCHAR(10),
   @c_Aid NVARCHAR(18),                          @c_Alot NVARCHAR(10),
   @c_aLottable01 NVARCHAR(18),                  @c_aLottable02 NVARCHAR(18),                  @c_aLottable03 NVARCHAR(18),
   @d_Alottable04 datetime,                      @d_Alottable05 datetime,                      @c_aLottable04 NVARCHAR(18),
   @c_aLottable05 NVARCHAR(18),                  @n_minshelflife int, -- Added by mmlee for fbr50
   @c_OrdUOM NVARCHAR(10), -- Added By SHONG -- (ChewKP01)

   @c_cStorerKey NVARCHAR(15), @c_csku NVARCHAR(20), @c_clot NVARCHAR(10),@n_cqty int,

   @c_lastPackKey NVARCHAR(10) ,  -- Last pack key used so we don't keep re-retrieveing the same info!
   @c_lastStorerSku NVARCHAR(35) ,  -- Last sku read so that we don't keep trying to get the same info from the sku table !
   @c_OnReceiptCopyPackKey NVARCHAR(10),
   @c_lottable01PackKey NVARCHAR(10) , -- The PackKey that is potentially held in lottable01
   @n_QtyLeftToFulfill int, @n_caseqty int, @n_palletqty int, @n_innerpackqty int, @n_otherunit1 int , @n_otherunit2 int,

   @c_lorderkey NVARCHAR(10), @c_lOrderLineNumber NVARCHAR(5), @c_lStorerKey NVARCHAR(15),    @c_lsku NVARCHAR(20),     @c_lpriority NVARCHAR(10),
   @c_ltype NVARCHAR(10),     @c_lPackKey NVARCHAR(10),        @b_candidateexhausted int, @n_candidateline int, @c_lcartongroup NVARCHAR(10),
   @c_endstring NVARCHAR(300),

   @c_docartonizeuom1 NVARCHAR(1),    @c_docartonizeuom2 NVARCHAR(1),    @c_docartonizeuom3 NVARCHAR(1),   @c_docartonizeuom4 NVARCHAR(1),
   @c_docartonizeuom8 NVARCHAR(1),    @c_docartonizeuom9 NVARCHAR(1),    @c_ldocartonize    NVARCHAR(1),

   @c_sStorerKey NVARCHAR(15),     @c_sSKU NVARCHAR(20),     @c_sloc NVARCHAR(10),        @c_sid NVARCHAR(18),     @n_sqty int,
   @c_sLOT NVARCHAR(10),
   @n_qtytotake int,           @n_qtyavailable int,  @n_pulltype int,         @n_packqty int,      @n_needed int,
   @n_packavailable int,       @c_sloctype NVARCHAR(10), @n_uomqty int,           @n_lotqtyavailable int,
   @n_available int,           @n_trynextuom int,

   @n_sqtyneededforuom1 int,    @n_sqtyneededforuom2 int,     @n_sqtyneededforuom3 int,
   @n_sqtyneededforuom4 int,    @n_sqtyneededforuom5 int,     @n_sqtyneededforuom6 int,
   @n_sqtyneededforuom7 int,    @n_sqtyneededwork int,        @c_spickmethod NVARCHAR(1),

   @c_preallocatepickdetailkey NVARCHAR(10),    @c_pickheaderkey NVARCHAR(5),     @n_pickrecscreated int,
   @b_pickupdatesuccess int,
   @c_sCurrentLineNumber NVARCHAR(5),  @c_suom NVARCHAR(10),
   -- ADDED BY SHONG
   @c_CursorScripts NVARCHAR(600),     @c_XDockLineNumber NVARCHAR(5)

   DECLARE
   @c_aLottable06 NVARCHAR(30),              @c_aLottable07 NVARCHAR(30),
   @c_aLottable08 NVARCHAR(30),              @c_aLottable09 NVARCHAR(30),
   @c_aLottable10 NVARCHAR(30),              @c_aLottable11 NVARCHAR(30),
   @c_aLottable12 NVARCHAR(30),
   @d_aLottable13 Datetime,                  @d_aLottable14 Datetime,
   @d_aLottable15 Datetime,                  @c_aLottable13 NVARCHAR(30),
   @c_aLottable14 NVARCHAR(30),              @c_aLottable15 NVARCHAR(30),
   @c_Lottable_Parm NVARCHAR(20)

   DECLARE
   @c_ParameterName NVARCHAR(200),          @n_OrdinalPosition INT

   --INC1192122(START)
   DECLARE
     @c_sPrevStorerKey	NVARCHAR(15)
   , @c_sPrevSKU  		NVARCHAR(20)
   , @c_PrevFACILITY  	NVARCHAR(5)
   , @c_PrevChannel   	NVARCHAR(20)
   , @c_sPrevLOT      	NVARCHAR(10)
   --INC1192122(END)
   
   SELECT  @n_minshelflife = 0 -- Added by mmlee for fbr50
   SELECT  @c_OrdUOM = ''

   SELECT @c_AStorerKey = SPACE(15), @c_Asku = SPACE(20), @c_Atype = SPACE(10),
   @c_Apriority = SPACE(10), @c_APreAllocateStrategyKey = SPACE(10), @c_Alot = SPACE(10),
   @c_aLottable01 = SPACE(18), @c_aLottable02 = SPACE(18), @c_aLottable03 = SPACE(18),
   @c_aLottable04 = SPACE(18), @c_aLottable05 = SPACE(18), @d_Alottable04 = NULL, @d_Alottable05 = NULL,
   @c_Aintermodalvehicle = SPACE(30), @c_aOrderKey = SPACE(10),

   @c_lastPackKey = SPACE(10), @n_caseqty = 0, @n_palletqty=0, @n_innerpackqty = 0, @n_otherunit1=0, @n_otherunit2=0,
   @b_candidateexhausted=0, @n_candidateline = 0,

   @n_qtytotake = 0, @n_qtyavailable = 0, @n_pulltype = 0, @n_packqty = 0, @n_needed = 0,
   @n_packavailable = 0, @c_sloctype = "", @n_uomqty = 0, @n_lotqtyavailable = 0, @n_available = 0, @n_trynextuom = 0,

   @n_sqtyneededforuom1 = 0, @n_sqtyneededforuom2 = 0, @n_sqtyneededforuom3 = 0, @n_sqtyneededforuom4 = 0,
   @n_sqtyneededforuom5 = 0, @n_sqtyneededforuom6 = 0,
   @n_sqtyneededforuom7 = 0, @n_sqtyneededwork = 0,    @c_spickmethod = "",
   @c_sCurrentLineNumber = SPACE(5), @c_suom = SPACE(10),

   @c_aLottable06 = '',  @c_aLottable07 = '',   @c_aLottable08 = '',
   @c_aLottable09 = '',  @c_aLottable10 = '',   @c_aLottable11 = '',
   @c_aLottable12 = '',  @c_aLottable13 = '',   @c_aLottable14 = '',
   @c_aLottable15 = '',  @d_aLottable13 = NULL, @d_aLottable14 = NULL,
   @d_aLottable15 = NULL

   WHILE (1 = 1) and (@n_continue = 1 or @n_continue = 2)
   BEGIN
      FETCH NEXT FROM CURSOR_ORDERS
      INTO @c_AStorerKey , @c_Asku, @c_Atype, @c_APreAllocateStrategyKey, @c_Apriority, @c_Alot, @c_aLottable01, @c_aLottable02,
         @c_aLottable03, @d_aLottable04, @d_aLottable05, @c_aLottable06, @c_aLottable07, @c_aLottable08, @c_aLottable09,
         @c_aLottable10, @c_aLottable11, @c_aLottable12, @d_aLottable13, @d_aLottable14,
         @d_aLottable15, @d_Adeliverydate, @c_Aintermodalvehicle, @c_aOrderKey, @c_facility,
         @c_aOrderLineNumber, @d_OrderDate, @c_xdock, @c_Channel

      IF @@FETCH_STATUS = -1
      BEGIN
         BREAK
      END
   ELSE IF @@FETCH_STATUS < -1
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78317
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Fetch Next Group. (nspPreAllocateOrderProcessing)"
      BREAK
   END


   -- CDC:Call Getright when StorerKey <> Prev_StorerKey to check the flag 'orderinfo4Preallocation'
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_AStorerKey <> @c_prev_storer
      BEGIN
         SELECT @c_prev_storer = @c_AStorerKey

         SELECT @b_success = 0
         Execute dbo.nspGetRight null,  -- facility
         @c_AStorerKey,   -- StorerKey
         null,            -- Sku
         'Orderinfo4Preallocation',         -- Configkey
         @b_success    output,
         @c_prealloc   output,
         @n_err        output,
         @c_errmsg     output
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'nspPreAllocateOrderProcessing' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            Execute dbo.nspGetRight null,  -- facility
            @c_AStorerKey,   -- StorerKey
            null,            -- Sku
            'OWITF',         -- Configkey
            @b_success    output,
            @c_owitf      output,
            @n_err        output,
            @c_errmsg     output
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'nspPreAllocateOrderProcessing' + dbo.fnc_RTrim(@c_errmsg)
            END
         END

         --NJOW02
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            Execute dbo.nspGetRight null,  -- facility
            @c_AStorerKey,   -- StorerKey
            null,            -- Sku
            'AllocateGetCasecntFrLottable',         -- Configkey
            @b_success    output,
            @c_AllocateGetCasecntFrLottable output,
            @n_err        output,
            @c_errmsg     output
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'nspPreAllocateOrderProcessing' + dbo.fnc_RTrim(@c_errmsg)
            END
         END
         -- SWT01
         SET @c_ChannelInventoryMgmt = '0'
         If @n_continue = 1 or @n_continue = 2
         Begin
            Select @b_success = 0
            Execute nspGetRight2    --(Wan05) 
            @c_facility,
            @c_AStorerKey,        -- Storer
            '',                   -- Sku
            'ChannelInventoryMgmt',  -- ConfigKey
            @b_success    output,
            @c_ChannelInventoryMgmt  output,
            @n_Err        output,
            @c_ErrMsg     output
            If @b_success <> 1
            Begin
               Select @n_continue = 3, @c_ErrMsg = 'nspPreAllocateOrderProcessing:' + ISNULL(RTRIM(@c_ErrMsg),'')
            End
         END             
      END
   END
   -- CDC:End Getirght

   SELECT @c_lorderkey = OrderKey,
          @c_lOrderLineNumber = OrderLineNumber,
          @c_lStorerKey = StorerKey,
          @c_lsku = Sku,
          @c_lPackKey  = PackKey,
          @n_QtyLeftToFulfill = (OpenQty - (QtyAllocated+QtyPreAllocated+QtyPicked)),
          @n_MinShelfLife = MinShelfLife,
          @c_OrdUOM = UOM
   FROM #OPORDERLINES
   WHERE OrderKey = @c_aOrderKey
   AND OrderLineNumber = @c_aOrderLineNumber

   --  AND OrderLineNumber = @c_lOrderLineNumber

   -- Start Changes, add by June 08.Dec.2003
   -- SOS17522, requested by Tomy to treat 1 - 60 as months & > 60 as days
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
      Select @b_success = 0
      Execute dbo.nspGetRight null,                       -- Facility
                   @c_lstorerkey,                 -- Storer
                   null,                          -- Sku
                   'MinShelfLife60Mth',
                   @b_success                               OUTPUT,
                   @c_MinShelfLife60Mth  OUTPUT,
                   @n_err          OUTPUT,
                   @c_errmsg       OUTPUT
      If @b_success <> 1
      Begin
          Select @n_continue = 3
          Select @c_errmsg = 'nspPreAllocateOrderProcessing : ' + dbo.fnc_RTrim(@c_errmsg)
      End
   END

   -- Added By MaryVong on 30-Apr-2004 (FBR18050 NZMM)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_ShelfLifeInDays NVARCHAR(1)
      Select @b_success = 0
      Execute dbo.nspGetRight null,   -- Facility
         @c_lstorerkey,      -- Storer
         null,               -- Sku
         'ShelfLifeInDays',
         @b_success              OUTPUT,
         @c_ShelfLifeInDays      OUTPUT,
         @n_err                  OUTPUT,
         @c_errmsg               OUTPUT
      If @b_success <> 1
      Begin
          Select @n_continue = 3
          Select @c_errmsg = 'nspPreAllocateOrderProcessing : ' + dbo.fnc_RTrim(@c_errmsg)
      End
   END

   /*
   IF @n_MinShelfLife is null
      SELECT @n_MinShelfLife = 0
   ELSE IF @n_MinShelfLife < 13
      SELECT @n_MinShelfLife = @n_MinShelfLife * 30
   -- ELSE
   --   SELECT @n_MinShelfLife = 0
   */

   IF @n_MinShelfLife IS NULL
   BEGIN
      SELECT @n_MinShelfLife = 0
   END
  ELSE IF @c_MinShelfLife60Mth = '1'
   BEGIN
      IF @n_MinShelfLife < 61
         SELECT @n_MinShelfLife = @n_MinShelfLife * 30
   END
   ELSE IF @c_ShelfLifeInDays = '1'
   BEGIN
      SELECT @n_MinShelfLife = @n_MinShelfLife  -- No conversion, only in days
   END                                          -- End Changes - FBR18050 NZMM
   ELSE IF @n_MinShelfLife < 13
   BEGIN
      SELECT @n_MinShelfLife = @n_MinShelfLife * 30
   END
   -- End Changes - SOS17522

   SELECT @c_sCurrentLineNumber = SPACE(5)
   SELECT @c_XDockLineNumber = SPACE(5)

   -- MMLEE 17 August 2001
   -- FBR030 IDSHK
   -- Allocation of partial full pallet in Pallet handling location
   -- must remark this park to handle allocation of partial full pallet.
   -- start

   -- Remarked by SOS47070
   -- Add in extra check on Pack.Pallet > 0, PreAllocateStrategyLineNumber = '00001' and UOM = '1'
   -- IF NOT EXISTS(SELECT * FROM PACK (NOLOCK) WHERE PackKey = @c_lPackKey AND Pallet <= @n_QtyLeftToFulfill)
   -- BEGIN
   --    SELECT @c_sCurrentLineNumber = '00001'
   -- END
   IF NOT EXISTS( SELECT * FROM PACK (NOLOCK)
                  WHERE PackKey = @c_lPackKey
                    AND Pallet <= @n_QtyLeftToFulfill
                    AND Pallet > 0 )
   BEGIN
      IF EXISTS( SELECT 1
                 FROM PreAllocateStrategyDetail (NOLOCK)
                 WHERE PreAllocateStrategyKey = @c_APreAllocateStrategyKey
                   AND PreAllocateStrategyLineNumber = '00001'
                   AND UOM = '1' )
      BEGIN
         SELECT @c_sCurrentLineNumber = '00001'
      END
   END
   -- End of SOS47070

   IF ( @b_debug = 1 or @b_debug = 2 )
   BEGIN
      -- print "in second loop...CURSOR_LINEITEMS"
      PRINT ''
      PRINT ''
      Print '-----------------------------------------------------'
      Print '-- OrderKey: ' + @c_lorderkey + ' Line:' + @c_lOrderLineNumber
      Print '-- SKU: ' + RTRIM(@c_lsku) + ' Open Qty:' + CAST(@n_QtyLeftToFulfill As NVARCHAR(10))
      Print '-- Pack Key :' + RTRIM(@c_lPackKey) + ' UOM:' + @c_OrdUOM
      Print '-- Lottables: (1)= ' + RTRIM(@c_aLottable01) + ' (2)= ' + RTRIM(@c_aLottable02) +
            ' (3)= ' + RTRIM(@c_aLottable03)
      Print '-- Exp Date: ' +   CASE WHEN @d_Alottable04 IS NOT NULL AND @d_Alottable04 <> '19000101' THEN
                              CONVERT(varchar(20), @d_Alottable04, 112) ELSE '' END
            + ' Receipt Dt :' + CASE WHEN @d_Alottable05 IS NOT NULL AND @d_Alottable04 <> '19000101' THEN
                                     CONVERT(varchar(20), @d_Alottable05, 112) ELSE '' END
      Print '-- Minimum Shelf Life: ' + CAST(@n_MinShelfLife As NVARCHAR(10))
      Print '-- Pre-Allocation Strategy Key: ' + @c_APreAllocateStrategyKey
   END

   WHILE (@n_QtyLeftToFulfill > 0)  -- DS: we don't need to loop when line is done
   BEGIN
      SELECT @n_trynextuom = 0
      --SET ROWCOUNT 1

      SELECT TOP 1 @c_sCurrentLineNumber = PreAllocateStrategyLineNumber,
             @c_APreAllocatePickCode = PreAllocatePickCode,
             @c_suom = UOM
      FROM PreAllocateStrategyDetail (NOLOCK)
      WHERE PreAllocateStrategyKey = @c_APreAllocateStrategyKey
        and PreAllocateStrategyLineNumber > @c_sCurrentLineNumber
      ORDER BY PreAllocateStrategyLineNumber

      IF @@ROWCOUNT = 0
      BEGIN
         --SET ROWCOUNT 0
         BREAK
      END
      --SET ROWCOUNT 0

      DECLARECURSOR_CANDIDATES:

      IF @d_aLottable04 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable04, 112) = '19000101'
         SELECT @c_aLottable04 = ''
      ELSE
         SELECT @c_aLottable04 = CONVERT(VARCHAR(20), @d_aLottable04, 112)

      IF @d_aLottable05 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable05, 112) = '19000101'
         SELECT @c_aLottable05 = ''
      ELSE
         SELECT @c_aLottable05 = CONVERT(VARCHAR(20), @d_aLottable05, 112) --(Wan02)

      IF @d_aLottable13 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable13, 112) = '19000101'
         SELECT @c_aLottable13 = ''
      ELSE
         SELECT @c_aLottable13 = CONVERT(VARCHAR(20), @d_aLottable13, 112)

      IF @d_aLottable14 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable14, 112) = '19000101'
         SELECT @c_aLottable14 = ''
      ELSE
         SELECT @c_aLottable14 = CONVERT(VARCHAR(20), @d_aLottable14, 112)


      IF @d_aLottable15 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable15, 112) = '19000101'
         SELECT @c_aLottable15 = ''
      ELSE
         SELECT @c_aLottable15 = CONVERT(VARCHAR(20), @d_aLottable15, 112)

      SELECT @b_cursorcandidates_open = 0

      -- BY SHONG - CHECKING
      -- Added By Shong
      /* Start - Customization for IDS - Added by DLIM for FBR24A 20010716 */
      IF @c_xdock = 'Y'
      BEGIN
         --SET ROWCOUNT 1

         SELECT TOP 1 @c_XDockLineNumber = PreAllocateStrategyLineNumber,
                @c_APreAllocatePickCode = PreAllocatePickCode,
                @c_suom = UOM
         FROM PreAllocateStrategyDetail (NOLOCK)
         WHERE PreAllocateStrategyKey = 'XDOCK'
         and PreAllocateStrategyLineNumber > @c_XDockLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            --SET ROWCOUNT 0
            BREAK
         END
         --SET ROWCOUNT 0
      END

      SELECT @n_packqty = CASE @c_suom
         WHEN 2 THEN CaseCnt
         WHEN 3 THEN InnerPack
         WHEN 1 THEN Pallet
         ELSE 1
         END
         FROM PACK (NOLOCK)
         WHERE PackKey = @c_lPackKey

      -- SELECT @c_endstring = RTRIM(convert(char(10),@n_packqty)) + "," + RTRIM(convert(char(10),@n_QtyLeftToFulfill))
      SELECT @c_EndString = '@n_UOMBase = ' + RTRIM(CONVERT(VARCHAR(10),@n_PackQty)) + ', @n_QtyLeftToFulfill=' + RTRIM(CONVERT(VARCHAR(10),@n_QtyLeftToFulfill))

      -- begin
      -- for HK use only.
      -- IF  @c_APreallocatePickCode like 'nspPR_HK%' OR @n_minshelflife <> 0
      -- Commented checking of the @c_APreallocatePickCode by Ricky for IDSHK
      IF  @n_minshelflife <> 0 -- Add minshelfLife by June 2.Oct.2003 (SOS14874 - PGD TH)
      BEGIN
         -- IF @n_minshelflife <> 0    - SOS14874
      SELECT @c_Alot = '*' + dbo.fnc_RTrim(CONVERT(Char(5), @n_MinShelfLife))
      END

      -- Add by June 12.Jun.03 SOS11744
      DECLARE @c_preallocfulluom NVARCHAR(1)
      SELECT  @b_success = 0
      EXECUTE dbo.nspGetRight null,              -- Facility
      @c_AStorerKey,     -- Storer
      null,              -- Sku
      'PREALLOCONFULLUOM',
      @b_success         OUTPUT,
      @c_preallocfulluom OUTPUT,
      @n_err             OUTPUT,
      @c_errmsg           OUTPUT
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = 'nspPreAllocateOrderProcessing : ' + RTRIM(@c_errmsg)
      END
      ELSE
      BEGIN
         IF @c_preallocfulluom = '1'
         BEGIN
            SELECT @n_packqty = CASE @c_OrdUOM
            WHEN PACKUOM1 THEN CaseCnt
            WHEN PACKUOM2 THEN InnerPack
            WHEN PACKUOM3 THEN 1
            WHEN PACKUOM4 THEN Pallet
            WHEN PACKUOM5 THEN Cube
            -- Modify by SHONG 05 May 2002
            -- Do not allocate when the PCKUOM not match
            -- Set to Max Number
         ELSE 99999999
      END
      FROM PACK (NOLOCK)
      WHERE PackKey = @c_lPackKey

   END
END
-- End - SOS11744

-- Added By SHONG
-- Check UOM, if UOM not exists then reject the allocation
-- Modify at 07 May 2002, ignore GDS storer
IF @c_owitf = '1'
BEGIN
   SELECT @cPackUOM1 = ISNULL(PackUOM1, ''),
          @cPackUOM2 = ISNULL(PackUOM2, ''),
          @cPackUOM3 = ISNULL(PackUOM3, ''),
          @cPackUOM4 = ISNULL(PackUOM4, '')
   FROM PACK (NOLOCK) WHERE PackKey = @c_lPackKey

   IF @c_OrdUOM NOT IN (@cPackUOM1, @cPackUOM2, @cPackuom3, @cPackUOM4)
   BEGIN
      IF @b_debug = 1
         SELECT  'Invalid UOM -- ', @c_lPackKey '@c_lPackKey', @c_OrdUOM '@c_OrdUOM'

      CONTINUE
   END
END

-- Changed by June 12.Jun.03 SOS11744
--SELECT @c_EndString = '@n_UOMBase = ' + RTRIM(CONVERT(VARCHAR(10),@n_PackQty)) + ', @n_QtyLeftToFulfill=' + RTRIM(CONVERT(VARCHAR(10),@n_QtyLeftToFulfill))

SET @c_OtherParms = ''

--IF EXISTS(SELECT 1 FROM [INFORMATION_SCHEMA].[PARAMETERS]
--            WHERE SPECIFIC_NAME = @c_APreAllocatePickCode
--            And PARAMETER_NAME Like '%Lottable06')
--BEGIN
--   SET @c_OtherParms =  ', @c_lottable06 = N''' + RTRIM(@c_aLottable06) + '''' +
--                        ', @c_lottable07 = N''' + RTRIM(@c_aLottable07) + '''' +
--                        ', @c_lottable08 = N''' + RTRIM(@c_aLottable08) + '''' +
--                        ', @c_lottable09 = N''' + RTRIM(@c_aLottable09) + '''' +
--                        ', @c_lottable10 = N''' + RTRIM(@c_aLottable10) + '''' +
--                        ', @c_lottable11 = N''' + RTRIM(@c_aLottable11) + '''' +
--                        ', @c_lottable12 = N''' + RTRIM(@c_aLottable12) + '''' +
--                        ', @d_lottable13 = N''' + RTRIM(@c_aLottable13) + '''' +
--                        ', @d_lottable14 = N''' + RTRIM(@c_aLottable14) + '''' +
--                        ', @d_lottable15 = N''' + RTRIM(@c_aLottable15) + ''''
--END

--IF @c_PreAlloc = '1'
--BEGIN
--   SELECT @c_OtherParms = ' ,@c_OtherParms= N''' + RTRIM(@c_aOrderKey) + RTRIM(@c_aOrderLineNumber) + ''' '
--END

SET @cExecSQL = @c_APreAllocatePickCode

DECLARE Cur_Parameters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT PARAMETER_NAME, ORDINAL_POSITION
FROM [INFORMATION_SCHEMA].[PARAMETERS] WITH (NOLOCK)
WHERE SPECIFIC_NAME = @c_APreAllocatePickCode
ORDER BY ORDINAL_POSITION

OPEN Cur_Parameters
FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cExecSQL = RTRIM(@cExecSQL) + CASE WHEN @n_OrdinalPosition = 1 THEN ' ' ELSE ' ,' END +
      CASE @c_ParameterName
         WHEN '@c_Facility'   THEN '@c_Facility = N''' + @c_facility + ''''
         WHEN '@c_lot'        THEN '@c_LOT = N''' + @c_Alot + ''''
         WHEN '@c_StorerKey'  THEN '@c_StorerKey = N''' + @c_aStorerKey + ''''
         WHEN '@c_SKU'        THEN '@c_SKU = N''' + @c_aSKU + ''''
         WHEN '@c_Lottable01' THEN '@c_Lottable01 = N''' + @c_aLottable01 + ''''
         WHEN '@c_Lottable02' THEN '@c_Lottable02 = N''' + REPLACE(@c_aLottable02,"'","''") + ''''    --(CS02)
         WHEN '@c_Lottable03' THEN '@c_Lottable03 = N''' + @c_aLottable03 + ''''
         WHEN '@d_Lottable04' THEN '@d_Lottable04 = N''' + @c_aLottable04 + ''''
         WHEN '@c_Lottable04' THEN '@c_Lottable04 = N''' + @c_aLottable04 + ''''
         WHEN '@d_Lottable05' THEN '@d_Lottable05 = N''' + @c_aLottable05 + ''''
         WHEN '@c_Lottable05' THEN '@c_Lottable05 = N''' + @c_aLottable05 + ''''
         WHEN '@c_Lottable06' THEN '@c_Lottable06 = N''' + @c_aLottable06 + ''''
         WHEN '@c_Lottable07' THEN '@c_Lottable07 = N''' + @c_aLottable07 + ''''
         WHEN '@c_Lottable08' THEN '@c_Lottable08 = N''' + @c_aLottable08 + ''''
         WHEN '@c_Lottable09' THEN '@c_Lottable09 = N''' + @c_aLottable09 + ''''
         WHEN '@c_Lottable10' THEN '@c_Lottable10 = N''' + @c_aLottable10 + ''''
         WHEN '@c_Lottable11' THEN '@c_Lottable11 = N''' + @c_aLottable11 + ''''
         WHEN '@c_Lottable12' THEN '@c_Lottable12 = N''' + @c_aLottable12 + ''''
         WHEN '@d_Lottable13' THEN '@d_Lottable13 = N''' + @c_aLottable13 + ''''
         WHEN '@c_Lottable13' THEN '@c_Lottable13 = N''' + @c_aLottable13 + ''''
         WHEN '@d_Lottable14' THEN '@d_Lottable14 = N''' + @c_aLottable14 + ''''
         WHEN '@c_Lottable14' THEN '@c_Lottable14 = N''' + @c_aLottable14 + ''''
         WHEN '@d_Lottable15' THEN '@d_Lottable15 = N''' + @c_aLottable15 + ''''
         WHEN '@c_Lottable15' THEN '@c_Lottable15 = N''' + @c_aLottable15 + ''''
         WHEN '@c_UOM'        THEN '@c_UOM = N''' + @c_sUOM + ''''
         WHEN '@c_OtherParms' THEN '@c_OtherParms= N''' + RTRIM(@c_aOrderKey) + RTRIM(@c_aOrderLineNumber) + 'O'' '  --NJOW05  
         WHEN '@n_UOMBase'    THEN '@n_UOMBase = ' + RTRIM(CONVERT(VARCHAR(10),@n_PackQty))
         WHEN '@n_QtyLeftToFulfill' THEN '@n_QtyLeftToFulfill = ' + RTRIM(CONVERT(VARCHAR(10),@n_QtyLeftToFulfill))
         WHEN '@c_PreAllocateStrategyKey' THEN ',@c_PreAllocateStrategyKey = N''' + RTRIM(@c_APreAllocateStrategyKey) + ''''  --NJOW07
         WHEN '@c_PreAllocateStrategyLineNumber' THEN ',@c_PreAllocateStrategyLineNumber = N''' + RTRIM(@c_sCurrentLineNumber) + ''''  --NJOW07               
      END

   FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
END
CLOSE Cur_Parameters
DEALLOCATE Cur_Parameters

--SET @cExecSQL = @c_APreAllocatePickCode + ' @c_storerkey= N''' + RTRIM(@c_aStorerKey) + '''' + ',' + ' @c_sku= N''' + RTRIM(@c_aSKU) + '''' + ',' + ' @c_lot= N''' + RTRIM(@c_Alot) + ''''
--+', @c_lottable01 = N''' + RTRIM(@c_aLottable01) + '''' + ', @c_lottable02 = N''' + RTRIM(@c_aLottable02) + '''' + ', @c_lottable03 = N''' + RTRIM(@c_aLottable03) + ''''
--+', @d_lottable04 = N''' + RTRIM(@c_aLottable04) + '''' + ', @d_lottable05 = N''' + RTRIM(@c_aLottable05) + '''' + ', @c_uom = N''' + RTRIM(@c_sUOM) + ''''
--+', @c_facility=N''' + RTRIM(@c_facility) + ''',' + RTRIM(@c_EndString) + RTRIM(@c_OtherParms)

IF ( @b_debug = 1 OR @b_debug = 2 )
BEGIN
   PRINT ''
   PRINT ''
   PRINT '-- Execute Pre-allocate Strategy ' + RTRIM(@c_APreAllocatePickCode) + ' UOM:' + RTRIM(@c_sUOM)
   PRINT '     EXEC ' + @cExecSQL

   SET @nRecordFound = 0
END

EXEC(@cExecSQL)

SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err = 16915
BEGIN
   CLOSE PREALLOCATE_CURSOR_CANDIDATES
   DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
   GOTO DECLARECURSOR_CANDIDATES
END

IF ISNULL(@cExecSQL,'') <> ''    --(CS01)
BEGIN
   OPEN PREALLOCATE_CURSOR_CANDIDATES
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
END

IF @n_err = 16905
BEGIN
   CLOSE PREALLOCATE_CURSOR_CANDIDATES
   DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
   GOTO DECLARECURSOR_CANDIDATES
END

IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 78315   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation/Opening of Candidate Cursor Failed! (nspPreAllocateOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
ELSE
BEGIN
   SELECT @b_cursorcandidates_open = 1
END

--IF @b_debug = 1
--BEGIN
--   SELECT @@CURSOR_ROWS 'CURSOR ROWS'
--END


IF ( @n_continue = 1 or @n_continue = 2)
BEGIN
   SELECT @n_candidateline = 0
   WHILE @n_QtyLeftToFulfill > 0
   BEGIN
      SELECT @n_candidateline = @n_candidateline + 1

      IF ISNULL(@cExecSQL,'') <> ''    --(CS01)
      BEGIN
         IF @n_candidateline = 1
         BEGIN
            FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES
            INTO  @c_sStorerKey, @c_sSKU, @c_sLOT, @n_qtyavailable -- , @c_actualfac_loc, @c_actualfac_id
         END
         ELSE
         BEGIN
            FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES
            INTO @c_sStorerKey, @c_sSKU,@c_sLOT, @n_qtyavailable -- , @c_actualfac_loc, @c_actualfac_id
         END
      END
      
      IF @@FETCH_STATUS = 0   --(Wan07) 
      BEGIN                   --(Wan07)
         --NJOW03
         SET @n_LotAvailableQty = 0
         SELECT @n_LotAvailableQty = Qty - QtyAllocated - QtyPicked - QtyPreAllocated
         FROM LOT (NOLOCK)
         WHERE Lot = @c_sLOT   
      
         IF @n_QtyAvailable > @n_LotAvailableQty 
            SET @n_QtyAvailable = @n_LotAvailableQty 

         --(Wan04) - START
         SELECT @n_FacLotAvailQty = SUM(LLI.Qty - LLI.QtyAllocated - LLi.QtyPicked)
         FROM LOTxLOCxID  LLI WITH (NOLOCK) 
         JOIN LOC         LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
         WHERE LLI.Lot =  @c_sLOT  
         AND   LOC.Facility = @c_facility

         IF @n_FacLotAvailQty < @n_QtyAvailable
         BEGIN 
            SET @n_QtyAvailable = @n_FacLotAvailQty  
         END
         --(Wan04) - END           
      
         -- (SWT01)
         IF (@n_continue = 1 or @n_continue = 2)     
         BEGIN       
            IF @c_ChannelInventoryMgmt = '1'       
            BEGIN
               --INC1192122(START)
               IF ((@c_sStorerKey <> @c_sPrevStorerKey) OR (@c_sSKU <> @c_sPrevSKU) 
                  OR (@c_FACILITY <> @c_PrevFACILITY) OR (@c_Channel <> @c_PrevChannel)
                  OR (@c_sLOT <> @c_sPrevLOT))
               BEGIN
                  SET @n_Channel_ID = 0 
               END
               --INC1192122(END)   
               
               IF ISNULL(RTRIM(@c_Channel), '') <> ''  AND
                  ISNULL(@n_Channel_ID,0) = 0
               BEGIN
                  SET @n_Channel_ID = 0
               
                  BEGIN TRY
                     EXEC isp_ChannelGetID 
                         @c_StorerKey   = @c_sStorerKey
                        ,@c_Sku         = @c_sSKU
                        ,@c_Facility    = @c_FACILITY
                        ,@c_Channel     = @c_Channel
                        ,@c_LOT         = @c_sLOT
                        ,@n_Channel_ID  = @n_Channel_ID OUTPUT
                        ,@b_Success     = @b_Success OUTPUT
                        ,@n_ErrNo       = @n_Err OUTPUT
                        ,@c_ErrMsg      = @c_ErrMsg OUTPUT                 
                  END TRY
                  BEGIN CATCH
                        SELECT @n_err = ERROR_NUMBER(),
                               @c_ErrMsg = ERROR_MESSAGE()
                            
                        SELECT @n_continue = 3
                        SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspPreAllocateOrderProcessing)' 
                  END CATCH                                          
               END 
               
               --INC1192122(START)
			   SET @c_sPrevStorerKey     =  @c_sStorerKey  
			   SET @c_sPrevSKU  		 =  @c_sSKU  
			   SET @c_PrevFACILITY       =  @c_FACILITY  
			   SET @c_PrevChannel        =  @c_Channel  
			   SET @c_sPrevLOT           =  @c_sLOT  		   
			   --INC1192122(END) 
               
               IF @n_Channel_ID > 0 
               BEGIN
                  SET @n_Channel_Qty_Available = 0 
               
                  SET @n_AllocatedHoldQty = 0

                  --NJOW06 S
                  SET @c_SourceType = 'nspPreAllocateOrderProcessing'
                  SET @n_ChannelHoldQty = 0
                  IF ISNULL(@c_Orderkey,'') = ''                                       
                     SET @c_SourceKey = SPACE(10) + @c_oskey 
                  ELSE
                     SET @c_SourceKey = @c_Orderkey   
                     
                  EXEC isp_ChannelAllocGetHoldQty_Wrapper  
                     @c_StorerKey = @c_sStorerkey, 
                     @c_Sku = @c_sSKU,  
                     @c_Facility = @c_Facility,           
                     @c_Lot = @c_sLOT,
                     @c_Channel = @c_Channel,
                     @n_Channel_ID = @n_Channel_ID,   
                     @n_AllocateQty = @n_QtyAvailable, --NJOW07     
                     @n_QtyLeftToFulFill = @n_QtyLeftToFulfill, --NJOW07                                           
                     @c_SourceKey = @c_SourceKey,
                     @c_SourceType = @c_SourceType, 
                     @n_ChannelHoldQty = @n_ChannelHoldQty OUTPUT,
                     @b_Success = @b_Success OUTPUT,
                     @n_Err = @n_Err OUTPUT, 
                     @c_ErrMsg = @c_ErrMsg OUTPUT
                                    
                  IF @b_success <> 1
                  BEGIN
                     SET @n_continue = 3                                                                                
                  END                     
                  --NJOW06 E   
                   
                  /*--(Wan06) - START
                  SELECT @n_AllocatedHoldQty = SUM(p.Qty) 
                  FROM PICKDETAIL AS p WITH(NOLOCK) 
                  JOIN LOC AS L WITH (NOLOCK) ON p.LOC = L.LOC AND L.LocationFlag IN ('HOLD','DAMAGE') 
                  JOIN ChannelInv AS ci WITH(NOLOCK) ON ci.Channel_ID = p.Channel_ID 
                  WHERE ci.Channel_ID = @n_Channel_ID
                  AND p.[Status] <> '9' 
                  AND p.Storerkey = @c_sStorerKey
                  AND p.Sku = @c_sSKU
                  AND p.LOT = @c_sLOT
                  AND p.Channel_ID = @n_Channel_ID 
                  --(Wan06) - END--*/
               
                  SELECT @n_Channel_Qty_Available = ci.Qty - ( ci.QtyAllocated - @n_AllocatedHoldQty ) - ci.QtyOnHold - @n_ChannelHoldQty --NJOW06
                  FROM ChannelInv AS ci WITH(NOLOCK)
                  WHERE ci.Channel_ID = @n_Channel_ID
                  IF @n_Channel_Qty_Available < @n_QtyAvailable
                  BEGIN 
                     SET @n_QtyAvailable = @n_Channel_Qty_Available   
                  END               
               END 
            END 
         END
         -- End (SWT01)   
      END --(Wan07)      
   IF @@FETCH_STATUS = -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         IF @nRecordFound = 0
         BEGIN
            PRINT ''
            PRINT ''
            PRINT '**** No Record Found In Strategy ****'

            Print '**** Check Stock Balance **** '

            SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,
                   QtyAvailable = SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0)),
                   Lottable01, Lottable02, Lottable03, CONVERT(varchar(12), Lottable04, 112) AS Lottable04,
                   CASE WHEN Lottable04 IS NULL THEN 0
                        ELSE DateDiff(Day, GetDate(), Lottable04)
                   END as Days2Expired,
                   CONVERT(varchar(12), Lottable05, 112) AS Lottable05
             FROM LOTxLOCxID (NOLOCK)
             JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
             JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.LOT = LotAttribute.LOT
             JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
             LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                              FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
                              WHERE  p.Orderkey = ORDERS.Orderkey
                              AND    p.StorerKey = @c_aStorerKey
                              AND    p.SKU = @c_aSKU
                              AND    p.Qty > 0
                              GROUP BY p.LOT, ORDERS.Facility)
                              P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility
             WHERE LOTxLOCxID.Qty > 0
             AND LOT.Status = 'OK' AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
             AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5
             AND LOC.locationflag = 'NONE'
             AND LOTxLOCxID.StorerKey = @c_aStorerKey
             AND LOTxLOCxID.SKU = @c_aSKU
             GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05
             HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
             ORDER BY Lottable04, Lottable05

         END
      END
      BREAK
   END

   IF @@FETCH_STATUS = 0
   BEGIN
      IF @b_debug = 1
      BEGIN
         SET @nRecordFound = 1
         PRINT ''
         PRINT '**** Found Stock ****'
         PRINT '     LOT: ' + @c_sLOT + ' Qty Available: ' + CAST(@n_qtyavailable as NVARCHAR(10))
         PRINT '     Qty LeftToFulfill: ' + CAST(@n_QtyLeftToFulfill as NVARCHAR(10))
      END

      IF @c_sSKU+@c_sStorerKey <> @c_laststorersku
      BEGIN
         SELECT @c_OnReceiptCopyPackKey = OnReceiptCopyPackKey, @c_laststorersku = @c_sStorerKey+@c_sSKU
         FROM SKU (nolock)
         WHERE StorerKey = @c_sStorerKey AND SKU = @c_sSKU
      END

      IF @c_OnReceiptCopyPackKey = "1"
      BEGIN
         SELECT @c_lottable01PackKey=Lottable01
         FROM LOTATTRIBUTE (nolock)
         WHERE LOT = @c_sLOT

         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01PackKey)) IS NOT NULL
         BEGIN
            IF EXISTS (SELECT PackKey FROM PACK (NOLOCK) WHERE PackKey = @c_lottable01PackKey)
            BEGIN
               SELECT @c_lPackKey = @c_lottable01PackKey
            END
         END
      END -- IF @c_OnReceiptCopyPackKey = "1"

      IF @c_lPackKey <> @c_lastPackKey
      BEGIN
         GOTO GETEQUIVALENCES
         RETURNFROMGETEQUIVALENCES:
      END
      --GOTO CALCULATEUOMSNEEDED
      --RETURNFROMCALCULATEUOMSNEEDED:

      IF @c_suom = "8" or @n_trynextuom = 1
      BEGIN
         SELECT @n_trynextuom = 1
         SELECT @c_suom = "1"
      END

      --NJOW02
      IF ISNULL(@c_AllocateGetCasecntFrLottable,'')
         IN ('01','02','03','06','07','08','09','10','11','12') AND @c_suom = '2'
      BEGIN
          SET @c_CaseQty = ''
          SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +
              ' FROM LOTATTRIBUTE(NOLOCK) ' +
              ' WHERE LOT = @c_sLOT '

           EXEC sp_executesql @c_SQL,
           N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_sLOT NVARCHAR(10)',
           @c_CaseQty OUTPUT,
          @c_sLOT

           IF ISNUMERIC(@c_CaseQty) = 1
           BEGIN
              SELECT @n_CaseQty = CAST(@c_CaseQty AS INT)
           END
      END

      NEXTUOM:
      SELECT @n_packqty = CASE @c_suom
      WHEN "1" THEN @n_palletqty
      WHEN "2" THEN @n_caseqty
      WHEN "3" THEN @n_innerpackqty
      WHEN "4" THEN @n_otherunit1
      WHEN "5" THEN @n_otherunit2
      WHEN "6" THEN 1
      WHEN "7" THEN 1
      ELSE 1 END,
      @c_ldocartonize = CASE @c_suom
      WHEN "1" THEN @c_docartonizeuom4
      WHEN "2" THEN @c_docartonizeuom1
      WHEN "3" THEN @c_docartonizeuom2
      WHEN "4" THEN @c_docartonizeuom8
      WHEN "5" THEN @c_docartonizeuom9
      WHEN "6" THEN @c_docartonizeuom3
      WHEN "7" THEN @c_docartonizeuom3
      ELSE "N" END

      IF @n_packqty = 0
      BEGIN
         IF @n_trynextuom = 0
         BEGIN
            BREAK
         END
      ELSE
      BEGIN
         SELECT @c_suom = Convert(char(1), Convert(int,@c_suom)+1 )
         IF @c_suom < "7"
         BEGIN
            GOTO NEXTUOM
         END
         ELSE BEGIN
            CONTINUE
         END
      END
   END -- IF @n_packqty = 0

   SELECT @n_needed = Floor(@n_QtyLeftToFulfill/@n_packqty) * @n_packqty
   SELECT @n_available = Floor(@n_qtyavailable/@n_packqty) * @n_packqty

   IF @n_available >= @n_needed
   BEGIN
      SELECT @n_qtytotake = @n_needed
   END
   ELSE BEGIN
      SELECT @n_qtytotake = @n_available
   END

   SELECT @n_uomqty = @n_qtytotake / @n_packqty

   IF @b_debug = 1
   BEGIN
      PRINT '     UOM to Take:' + RTRIM(@c_suom) + ' Pack Qty: ' + CAST(@n_packqty as NVARCHAR(10))
      PRINT '     Qty To Take: ' + CAST(@n_qtytotake as NVARCHAR(10))
   END

/* #INCLUDE <SPPREOP3.SQL> */

   IF @n_qtytotake > 0
   BEGIN
      GOTO UPDATEINV
      RETURNFROMUPDATEINV_01:
   END

   IF @n_trynextuom = 1 and @n_QtyLeftToFulfill > 0 and @n_qtyavailable > 0
   BEGIN
      SELECT @c_suom = Convert(char(1), Convert(int,@c_suom)+1 )
      IF @c_suom < "7"
      BEGIN
         GOTO NEXTUOM
      END
   END
END -- IF @@FETCH_STATUS = 0
END -- WHILE @n_QtyLeftToFulfill > 0
END -- IF ( @n_continue = 1 or @n_continue = 2)

  IF ISNULL(@cExecSQL,'') <> ''       --(CS01)
    BEGIN
      IF @b_cursorcandidates_open = 1
      BEGIN
         CLOSE PREALLOCATE_CURSOR_CANDIDATES
         DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
      END
   END
END -- WHILE (@n_QtyLeftToFulfill > 0)
--SET ROWCOUNT 0
END -- (1 = 1) and (@n_continue = 1 or @n_continue = 2)

--SET ROWCOUNT 0
END

IF @b_cursorordergroups_open = 1
BEGIN
   CLOSE CURSOR_ORDERS
   DEALLOCATE CURSOR_ORDERS
END

/* #INCLUDE <SPPREOP2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
   BEGIN
      ROLLBACK TRAN
   END
ELSE BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
END
execute nsp_logerror @n_err, @c_errmsg, "nspPreAllocateOrderProcessing"
RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
RETURN
END
ELSE BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

/***********************************************************************************************************************************
*
*  This is the GETEQUIVALENCES SubRoutine.
*
***********************************************************************************************************************************/
GETEQUIVALENCES:
SELECT   @n_palletqty = Pallet,
         @n_caseqty = CaseCnt,
         @n_innerpackQty = innerpack,
         @n_otherunit1 = CONVERT(int, OtherUnit1),
         @n_otherUnit2 = CONVERT(int, Otherunit2),
         @c_docartonizeuom1 = cartonizeuom1,
         @c_docartonizeuom2 = cartonizeuom2,
         @c_docartonizeuom3 = cartonizeuom3,
         @c_docartonizeuom4 = cartonizeuom4,
         @c_docartonizeuom8 = cartonizeuom8,
         @c_docartonizeuom9 = cartonizeuom9
FROM     PACK (nolock)
WHERE    PackKey = @c_lPackKey

SELECT @c_lastPackKey = @c_lPackKey
GOTO RETURNFROMGETEQUIVALENCES

/***********************************************************************************************************************************
*
*  This is the UPDATEINV SubRoutine.
*
***********************************************************************************************************************************/
UPDATEINV:
SELECT @b_pickupdatesuccess = 1

IF @b_pickupdatesuccess = 1
BEGIN
   SELECT @b_success = 0
   EXECUTE nspg_getkey "PreAllocatePickDetailKey", 10, @c_PreAllocatePickDetailKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   IF @b_success = 1
   BEGIN
      BEGIN TRANSACTION TROUTERLOOP
      IF @b_pickupdatesuccess = 1
      BEGIN
         INSERT PREALLOCATEPICKDETAIL  (PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,
         PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod)
         VALUES  (@c_PreAllocatePickDetailKey, @c_lorderkey, @c_lOrderLineNumber, @c_APreAllocateStrategyKey, @c_APreAllocatePickCode,
         @c_sLOT, @c_sStorerKey, @c_sSKU, @n_qtytotake, @n_uomqty, @c_suom,
         @c_lPackKey, @c_ldocartonize, @c_oprun, @c_spickmethod)
         SELECT @n_err = @@ERROR --, @n_cnt_sql = @@ROWCOUNT
         SELECT @n_cnt = COUNT(*) FROM PREALLOCATEPICKDETAIL (NOLOCK) WHERE preallocatepickdetailkey = @c_preallocatepickdetailkey
         IF not (@n_err = 0 AND @n_cnt = 1)
         BEGIN
            SELECT @b_pickupdatesuccess = 0
         END
      END
   END  -- IF @b_sucess = 1
   /* #INCLUDE <SPPREOP4.SQL> */
   IF @b_pickupdatesuccess = 1
   BEGIN
      COMMIT TRAN TROUTERLOOP
      SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_qtytotake
      SELECT @n_qtyavailable = @n_qtyavailable - @n_qtytotake
   END
ELSE BEGIN
   ROLLBACK TRAN TROUTERLOOP
   SELECT @n_err = 0
END
END
GOTO RETURNFROMUPDATEINV_01


GO