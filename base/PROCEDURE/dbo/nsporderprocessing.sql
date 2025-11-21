SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspOrderProcessing                                 */  
/* Creation Date:                                                       */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.2 (Unicode)                                          */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   VER  Purposes                                  */  
/* 06/11/2002   Leo Ng        Program rewrite for IDS version 5         */  
/* 23/09/2004   Shong         Performance Tuning                        */  
/* 26/07/2005   June          SOS38045 - bug fixed empty uom for olduom */  
/* 20/10/2005   Vicky         SOS42098 - add in missed out ordergroup   */  
/*                            range                                     */  
/* 17/01/2006   Shong         SOS # 45244, Default PickMethod to '3' IF */  
/*                            not setup in PutawayZone                  */  
/* 27/01/2006   Shong         Performance Tuning                        */  
/* 10/04/2006   Shong         Remove HardCoding Overallocation Flag     */  
/*                            for IDSTW - SUSR3 (SHONG_20060410)        */  
/* 22/05/2008   June          SOS99448- Configkey 'Orderinfo4Allocation'*/  
/*                            Pass extra parm @c_OtherParms to Pickcode */  
/* 18/02/2009   Shong         SOS129426 - Modify to support multiple    */  
/*                            pickface                                  */  
/* 19-May-2009  TLTING        TraceInfo (tlting01)                      */  
/* 01-Oct-2009  SHONG         Enhance the Debug Message                 */  
/* 13-May-2011  Leong         SOS# 213668 - Fixing Overallocation Issues*/  
/* 07-Sep-2011  YTWan         Fixing Divide by Zero error prompt at     */  
/*                            Exceed GUI ver 6. (Wan01)                 */  
/* 26-Nov-2013  TLTING        Change user_name() to SUSER_SNAME()       */  
/* 27-Nov-2013  YTWan    1.2  SOS#293830:LP allocation by default       */  
/*                            strategykey (Wan02)                       */  
/* 24-Apr-2014  Shong    1.3  Added Parameter Name when Execure Strategy*/  
/* 19-Nov-2014  NJOW01   1.4  Remove orderselection default flag check  */  
/*                            error                                     */  
/* 20-May-2014  NJOW02   1.5  310790-Multi pick loc overallocation with */  
/*                            no mix lot (PickOverAllocateNoMixLot)     */  
/* 25-Nov-2014  ChewKP   1.6  Extend UOM varible from 5 to 10 (ChewKP01)*/  
/* 19-Mar-2015  NJOW03   1.7  336160-Default Strategy Key is refering to*/  
/*                            StorerConfig if Strategy different within */  
/*                            Facility                                  */  
/* 29-May-2015  NJOW04   1.8  342109 - Get casecnt from lottable        */  
/* 18-Nov-2015  NJOW05   1.9  Skip PreAllocate and Allocate by Storer & */  
/*           Facility                                  */  
/* 18-Nov-2015  NJOW06   2.0  312318-Full pallet determind by pallet    */  
/*                            Id & Loc. Work with skip preallocation.   */  
/*                            @c_loctype=FULLPALLET                     */  
/* 11-Aug-2016  NJOW07   2.1  374687-Allowoverallocations storerconfig  */  
/*                            control by facility                       */  
/* 20-Sep-2016  NJOW08   2.2  Delete Preallocatepickdetail by looping   */   
/* 20-Sep-2016  TLTING   2.3  Change SetROWCOUNT 1 to Top 1             */  
/* 12-Jul-2017  TLTING   2.4  missing (NOLOCK)                          */  
/* 15-Nov-2017  Wan03    2.5  Check Facility Lot Qty Available          */  
/* 21-Dec-2017  NJOW09   2.6  WMS-3642 Get dynamic UOM qty from pickcode*/  
/*                            @c_LocType='UOM=xxx'. It will overwrite   */  
/*                            the UOM qty from packkkey. only work for  */  
/*                            skippreallocation.                        */  
/* 04-Jun-2018  NJOW10   2.7  Fix superorderflag cater for skip         */             
/*                            preallocation                             */  
/* 20-Apr-2018  SWT01    2.8  Channel Management Check Qty Available    */  
/* 18-Jan-2019  NJOW11   2.9  Fix get channel id                        */  
/* 07-Mar-2019  NJOW12   3.0  StorerDefaultAllocStrategy support discrete*/  
/*                            allocate from order and wave              */
/* 25-Apr-2019  NJOW13   3.1  WMS-1577 UCC allocation by pickcode.      */  
/*                            Allocation pickcode can return UCCNo from */  
/*                            other column. Expect uom 2,6,7 have uccno */  
/*                            value and other uom is empty. uom 2 will  */  
/*                            look for full ucc only, uom 2 only work if*/  
/*                            have fix ucc pack.casecnt or skip         */  
/*                            preallocation for non-fix. UCC status will*/  
/*                            change to 3 after allocation. UCC No. will*/  
/*                            stamp to pickdetail.dropid. No need filter*/  
/*                            qtyreplen and use ucc.status instead.     */  
/*                            storerconfig: uccallocation               */
/* 23-JUL-2019  Wan04    3.2  ChannelInventoryMgmt use nspGetRight2     */ 
/* 23-JUL-2019  Wan05    3.2  WMS - 9914 [MY] JDSPORTSMY - Channel      */
/*                            Inventory Ignore QtyOnHold - CR           */  
/* 22-SEP-2019  WLChooi  3.3  WMS-10216 - Able to filter by HostWHCode  */
/*                            when overallocation (Discrete only) (WL01)*/
/* 08-Jan-2020  NJOW14   3.4  WMS-10420 add strategykey parameter       */  
/* 12-Feb-2020  Wan06    3.4  SQLBindParm. Create Temp table to Store   */
/*                            Preallocate data from pickcode            */  
/* 18-Feb-2020  Wan07    3.4  WMS-11774                                 */  
/* 27-Mar-2020  NJOW15   3.5  WMS-12491 Get Over allocation pick loc by */
/*                            Custom SP                                 */ 
/* 21-MAY-2020  Wan08    3.6  Fixed no record retrieve if Loc.HostWHCode*/
/*                            is null & OverAllocPickByHostWHCode is off*/
/* 01-Dec-2020  NJOW16   3.7  WMS-15746 get channel hold qty by config  */  
/* 17-FEB-2021  LZG      3.8  INC1430235 - Extended to NVARCHAR 128 to  */
/*                            follow WMS tables AddWho & EditWho (ZG01) */
/* 14-FEB-2022  NJOW17   3.9  WMS-18820 Allow disable superorderflag    */
/*                            logic in discrete allocation by config    */
/* 14-FEB-2022  NJOW17   3.9  DEVOPS combine script                     */
/* 15-MAR-2022  NJOW18   4.0  WMS-19173 Update pickdetailkey and order  */
/*                            line no to UCC for UCC allocation         */
/* 18-MAY-2022  NJOW19   4.1  WMS-19173 UCC allocation not allow partial*/
/*                            UCC if the channel insufficient stock     */
/* 18-MAY-2022  NJOW19   4.1  DEVOPS combine script                     */
/* 07-Sep-2022  NJOW20   4.2  WMS-19078 Pass in AllocateStrategyKey and */
/*                            AllocateStrategyLineNumber to pickcode.   */
/*                            Othervalue(loctype) enhancements.         */
/*                            Add custom sp config to update OPORDERLINES*/
/* 27-SEP-2022  NJOW21   4.3  WMS-20812 Pass in additional parameters to*/
/*                            isp_ChannelAllocGetHoldQty_Wrapper        */ 
/* 16-May-2024  Wan09    4.4  UWP-19537-Mattel Overallocation           */
/* 07-Jul-2024  Wan10    4.5  UWP-19537-Mattel Overallocation           */
/*                            Get OverPickLoc from Sub SP               */
/* 18-Jul-2024  Wan11    4.6  UWP-22202-Mattel Overallocation           */
/*                            Get OverQtyLeftToFulfill from Sub SP      */
/*                            Do Not Overallocate to partial fulfill DPP*/
/************************************************************************/  

CREATE   PROC [dbo].[nspOrderProcessing]  
     @c_OrderKey     NVARCHAR(10)  
   , @c_oskey        NVARCHAR(10)  
   , @c_docarton     NVARCHAR(1)  
   , @c_doroute      NVARCHAR(1)  
   , @c_tblprefix    NVARCHAR(10)  
   , @b_Success      Int        OUTPUT  
   , @n_err          Int        OUTPUT  
   , @c_errmsg       NVARCHAR(250)  OUTPUT  
   , @c_extendparms  NVARCHAR(250) = ''   --(Wan02)
   , @c_StrategykeyParm NVARCHAR(10) = '' --NJOW14       
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue     Int  
         , @n_starttcnt    Int       -- Holds the current transaction count  
         , @n_cnt          Int       -- Holds @@ROWCOUNT after certain operations  
         , @c_preprocess   NVARCHAR(250) -- preprocess  
         , @c_pstprocess   NVARCHAR(250) -- post process  
         , @n_err2         Int       -- For Additional Error Detection  
         , @c_XDOCK        NVARCHAR(1)   --to check whether this is a XDOCK orders  
         , @c_fromloc      NVARCHAR(10)  
         , @c_toloc        NVARCHAR(10)  
         , @c_facility     NVARCHAR(10)  
         , @b_debug        Int       -- Debug 0 - OFF, 1 - Show ALL, 2 - Map  
         , @n_fetch_status Int  
         --, @c_lottable02   NVARCHAR(18)  -- IDSV5 - Leo  
         , @c_SuperFlag    NVARCHAR(1)  
         , @c_OtherParms   NVARCHAR(200)       -- SOS99448  
         , @c_Orderinfo4Allocation NVARCHAR(1) -- SOS99448  
         , @c_PickOverAllocateNoMixLot NVARCHAR(10) --NJOW02  
         , @c_AllocateGetCasecntFrLottable NVARCHAR(10) --NJOW04  
         , @c_CaseQty NVARCHAR(30) --NJOW04  
         , @c_SQL NVARCHAR(2000) --NJOW04  
         , @c_PreAllocatePickDetailKey NVARCHAR(10) --NJOW08  
         , @n_LotAvailableQty INT --NJOW03     
         , @n_FacLotAvailQty  INT = 0      --()Wan03                                            
         , @n_dynUOMQty       INT --NJOW09  
           
         , @c_ChannelInventoryMgmt      NVARCHAR(10) = '0' -- (SWT01)    
         , @c_Channel                   NVARCHAR(20) = '' --(SWT01)  
         , @n_Channel_ID                BIGINT = 0        --(SWT01)   
         , @n_Channel_Qty_Available     INT = 0                     
         , @c_aPrevLot                  NVARCHAR(10) --NJOW11  
         , @c_UCCAllocation             NVARCHAR(30) --NJOW13  
         , @c_UCCNo                     NVARCHAR(20) --NJOW13  
         , @c_PrevUCCNo                 NVARCHAR(20) --NJOW13 
         , @c_OverAllocPickByHostWHCode NVARCHAR(10) --WL01 
         , @c_OtherParmsExist           NVARCHAR(10) --NJOW14            
         , @c_OverAllocPickLoc_SP       NVARCHAR(30) --NJOW15            
         , @c_CallSource                NVARCHAR(20) --NJOW15
         , @n_OverAlQtyLeftToFulfill    INT          --NJOW15
         , @c_SourceType                NVARCHAR(50) --NJOW16
         , @c_SourceKey                 NVARCHAR(30) --NJOW16
         , @n_ChannelHoldQty            INT          --NJOW16
         , @c_FullPallet                NVARCHAR(10) --NJOW20
         , @c_DYNUOMQty                 NVARCHAR(10) --NJOW20
               
    -- NJOW05       
    DECLARE   
         @c_Lottable01 NVARCHAR(18),              @c_Lottable02 NVARCHAR(18),  
         @c_Lottable03 NVARCHAR(18),              @d_Lottable04 DATETIME,  
         @d_Lottable05 DATETIME,  
         @c_Lottable06 NVARCHAR(30),              @c_Lottable07 NVARCHAR(30),  
         @c_Lottable08 NVARCHAR(30),              @c_Lottable09 NVARCHAR(30),   
         @c_Lottable10 NVARCHAR(30),              @c_Lottable11 NVARCHAR(30),   
         @c_Lottable12 NVARCHAR(30),                
         @d_Lottable13 DATETIME,                  @d_Lottable14 DATETIME,   
         @d_Lottable15 DATETIME,                  @c_Lottable13 NVARCHAR(30),                
         @c_Lottable14 NVARCHAR(30),              @c_Lottable15 NVARCHAR(30),   
         @c_Lottable04 NVARCHAR(30),              @c_Lottable05 NVARCHAR(30),  
         @c_SkipPreAllocationFlag NVARCHAR(10),  
         @c_Storerkey NVARCHAR(15),  
         @n_NextQtyLeftToFulfill INT,            
         @c_Lottable_Parm NVARCHAR(20),             
         @c_SQLExecute NVARCHAR(4000),  
         @c_ParameterName NVARCHAR(200),            
         @n_OrdinalPosition INT
         
   --NJOW17
   DECLARE @c_AutoUpdSupordflag         NVARCHAR(30),
           @c_sfoption1                 NVARCHAR(50),
           @c_sfoption2                 NVARCHAR(50),
           @c_sfoption3                 NVARCHAR(50),
           @c_sfoption4                 NVARCHAR(50),
           @c_sfoption5                 NVARCHAR(4000)           
                                     
   -- Added By SHONG - Performance Tuning Rev 1.0  
   DECLARE  @c_PHeaderKey NVARCHAR(18),  
            @c_CaseId   NVARCHAR(10)  
           ,@n_AllocatedHoldQty INT = 0   

   DECLARE @c_OverPickLoc              NVARCHAR(10)                                 --(Wan10)
   DECLARE @CUR_AddSQL                 CURSOR                                       --(Wan11)
  
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0,@n_cnt = 0  
   SELECT @c_errmsg="",@n_err2=0  
   SELECT @b_debug = 0  
   IF @c_tblprefix = 'DS1' or @c_tblprefix = 'DS2'  
   BEGIN  
      SELECT @b_debug = Convert(Int, Right(@c_tblprefix, 1))  
   END  
  
   DECLARE @n_cnt_sql     Int  -- Additional holds for @@ROWCOUNT to try catch a wrong processing  
         , @c_DefaultStrategykey    NVARCHAR(1)    --(Wan02)  
  
   SET @c_DefaultStrategykey = ''                  --(Wan02)  
   SET @c_SkipPreAllocationFlag = '0' --NJOW05  
     
   --NJOW05  
   IF ISNULL(@c_Orderkey,'') <> ''  
   BEGIN  
      SELECT TOP 1 @c_StorerKey = O.StorerKey,  
                   @c_Facility  = O.Facility  
      FROM ORDERS o WITH (NOLOCK)   
      WHERE o.OrderKey = @c_Orderkey  
   END  
   ELSE  
   BEGIN  
      SELECT TOP 1 @c_StorerKey = O.StorerKey,  
                   @c_Facility  = O.Facility  
      FROM   LoadPlanDetail lpd WITH (NOLOCK)  
      JOIN   ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey  
      WHERE  lpd.LoadKey = @c_oskey  
   END  
  
   /* #INCLUDE <SPOP1.SQL> */  
  
   /* IDSV5 - Leo */  
   DECLARE @c_authority NVARCHAR(1)  
   SELECT Space(1) 'UOM' INTO #Tmp_SuperOrder_UOM where 1 = 2  
   INSERT INTO #Tmp_SuperOrder_UOM values ('2')  
   INSERT INTO #Tmp_SuperOrder_UOM values ('6')  
   /* IDSV5 - Leo */  
  
   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      IF (@c_OrderKey IS NULL or @c_OrderKey='')   
         AND OBJECT_ID(@c_tblprefix+"orders") IS NULL   
         AND (@c_oskey IS NULL or @c_oskey='')  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63500  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Invalid Parameters Passed (nspOrderProcessing)"  
      END  
   END -- @n_continue =1 or @n_continue = 2  
  
 -- TraceInfo (tlting01) - Start  
   DECLARE    @d_starttime    datetime,  
              @d_endtime      datetime,  
              @d_step1        datetime,  
              @d_step2        datetime,  
              @d_step3        datetime,  
              @d_step4        datetime,  
              @d_step5        datetime,  
              @c_col1         NVARCHAR(20),  
              @c_col2         NVARCHAR(20),  
              @c_col3         NVARCHAR(20),  
              @c_col4         NVARCHAR(20),  
              @c_col5         NVARCHAR(20),  
              @c_TraceName    NVARCHAR(80)  
  
   SET @c_col5 = ISNULL(RTRIM(@c_OrderKey)  , '') + ISNULL(RTRIM(@c_oskey)  , '')  
   SET @d_starttime = getdate()  
  
   SET @c_TraceName = 'nspOrderProcessing'  
-- TraceInfo (tlting01) - END  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_oprun NVARCHAR(9)  
      SELECT @b_success = 0  
      EXECUTE   nspg_getkey  
      'OPRUN'  
      , 9  
      , @c_oprun OUTPUT  
      , @b_success OUTPUT  
      , @n_err OUTPUT  
      , @c_errmsg OUTPUT  
   END  
  
   SET @c_ChannelInventoryMgmt = '0'  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      Select @b_success = 0  
      Execute nspGetRight2    --(Wan04)   
      @c_Facility,  
      @c_StorerKey,         -- Storer  
      '',                   -- Sku  
      'ChannelInventoryMgmt',  -- ConfigKey  
      @b_success    output,  
      @c_ChannelInventoryMgmt  output,  
      @n_Err        output,  
      @c_ErrMsg     output  
      If @b_success <> 1  
      BEGIN  
         Select @n_continue = 3, @c_ErrMsg = 'nspOrderProcessing:' + ISNULL(RTRIM(@c_ErrMsg),'')  
      END  
   END               

   --NJOW15 S
   EXEC nspGetRight
        @c_Facility  = @c_Facility,
        @c_StorerKey = @c_StorerKey,
        @c_sku       = NULL,
        @c_ConfigKey = 'OverAllocPickLoc_SP',
        @b_Success   = @b_Success                   OUTPUT,
        @c_authority = @c_OverAllocPickLoc_SP       OUTPUT,
        @n_err       = @n_err                       OUTPUT,
        @c_errmsg    = @c_errmsg                    OUTPUT

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_OverAllocPickLoc_SP) AND type = 'P')       
   BEGIN
        SET @c_OverAllocPickLoc_SP = ''
   END 
   ELSE
   BEGIN
      IF @c_ExtendParms = 'WP'
         SET @c_CallSource = 'WAVEORDER'
      ELSE IF @c_ExtendParms = 'LP'
         SET @c_CallSource = 'LOADORDER'
      ELSE 
         SET @c_CallSource = 'ORDER'                   
   END
   --NJOW15 E                
           
   SET @d_step1 = GETDATE() -- (tlting01)  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 0  
      IF @c_docarton = 'M'  
      BEGIN  
         SELECT @b_debug = 1  
      END  
      IF @c_tblprefix = 'MAS'  
      BEGIN  
         SELECT @c_doroute = '3'  
      END  
  
      IF @b_debug=1  
         SELECT @c_doroute='1'  
  
      --NJOW05  
      EXEC nspGetRight  
           @c_Facility  = @c_Facility,  
           @c_StorerKey = @c_StorerKey,  
           @c_sku       = NULL,  
           @c_ConfigKey = 'SkipPreAllocation',  
           @b_Success   = @b_Success               OUTPUT,  
           @c_authority = @c_SkipPreAllocationFlag OUTPUT,  
           @n_err       = @n_err                   OUTPUT,  
           @c_errmsg    = @c_errmsg                OUTPUT  
  
      IF (@n_Continue = 1 OR @n_Continue = 2) AND ISNULL(@c_SkipPreAllocationFlag,'0') <> '1' --NJOW05  
      BEGIN  
         EXECUTE   dbo.nspPreAllocateOrderProcessing    
           @c_orderkey = @c_OrderKey    
         , @c_oskey = @c_oskey    
         , @c_oprun = @c_oprun    
         , @c_doroute = @c_doroute    
         , @c_xdock = '' -- @c_XDOCK    
         , @c_fromloc = @c_fromloc    
         , @b_Success = @b_success OUTPUT    
         , @n_err = @n_err OUTPUT    
         , @c_errmsg = @c_errmsg OUTPUT    
         , @c_extendparms = @c_extendparms              --(Wan02)    
         , @c_StrategykeyParm = @c_StrategykeyParm      --NJOW14  
      END  
   END  
  
   SET @d_step1 = GETDATE() - @d_step1 -- (tlting01)  
   SET @c_Col1 = 'Stp1-Prealloc' -- (tlting01)  
  
   IF @c_tblprefix = 'DS1' or @c_tblprefix = 'DS2'  
   BEGIN  
      SELECT @b_debug = Convert(Int, Right(dbo.fnc_RTrim(@c_tblprefix), 1))  
   END  
  
   --(Wan06) - START
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF OBJECT_ID('tempdb..#ALLOCATE_CANDIDATES','u') IS NOT NULL
      BEGIN
         DROP TABLE #ALLOCATE_CANDIDATES;
      END

      CREATE TABLE #ALLOCATE_CANDIDATES
      (  RowID          INT            NOT NULL IDENTITY(1,1) 
      ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  QtyAvailable   INT            NOT NULL DEFAULT(0)
      ,  OtherValue     NVARCHAR(500)   NOT NULL DEFAULT('')   --NJOW20
      )
   END
   --(Wan06) - END
   
   IF @b_debug = 1 or @b_debug = 2  
   BEGIN  
      PRINT ''  
      PRINT ''  
      PRINT '*********************************************************'  
      PRINT 'Allocation: Started at ' + CONVERT(VarChar(20), GetDate())  
      PRINT '*********************************************************'  
      PRINT '@c_SkipPreAllocationFlag = ' + @c_SkipPreAllocationFlag  --NJOW05  
   END  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      /* 2001/10/02 CS Added facility for IDSHK FBR063 */  
      CREATE TABLE #OPORDERLINES (  
         [PreAllocatePickDetailKey] [nvarchar](10) ,   
         [OrderKey] [nvarchar](10) ,  
         [OrderLineNumber] [nvarchar](5) NULL  DEFAULT (' '),   
         [Storerkey] [nvarchar](15) NULL  DEFAULT (' '),  
         [Sku] [nvarchar](20) NULL  DEFAULT (' '),  
         [Lot] [nvarchar](10) NULL DEFAULT (' '),  
         [UOM] [nvarchar](5) NULL DEFAULT (' '),   
         [UOMQty] [int] NULL DEFAULT (0),  
         [Qty] [int] NULL DEFAULT (0),   
         [Packkey] [nvarchar](10) NULL DEFAULT (' '),   
         [WaveKey] [nvarchar](10) NULL DEFAULT (' '),  
         [PreAllocateStrategyKey] [nvarchar](10) NULL DEFAULT (' '),  
         [PreAllocatePickCode] [nvarchar](10) NULL DEFAULT (' '),  
         [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),  
         [PickMethod] [nvarchar](1) NULL DEFAULT (' '),  
         [RunKey] [nvarchar](10) NULL DEFAULT (' '),  
         [EffectiveDate] [datetime] NULL DEFAULT (getdate()),  
         [AddDate] [datetime] NULL DEFAULT (getdate()),  
         [AddWho] [nvarchar](128) NULL DEFAULT (suser_sname()),    -- ZG01
         [EditDate] [datetime] NULL DEFAULT (getdate()),  
         [EditWho] [nvarchar](128) NULL DEFAULT (suser_sname()),   -- ZG01
         [TrafficCop] [nvarchar](1) NULL,  
         [ArchiveCop] [nvarchar](1) NULL,  
         [CARTONGROUP] NVARCHAR(10) NULL,  
         [STRATEGYKEY] NVARCHAR(10) NULL,  
         [Facility]  NVARCHAR(5) NULL,   
         [XDockFlag] NVARCHAR(1) NULL,  
         [Channel] NVARCHAR(20) NULL)  
           
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation of Temp Table #op_cartonlines Failed.(nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
   
   -- Get Super Order Flag  
   SELECT @c_SuperFlag = 'N'  
   IF LEN(@c_OrderKey) = 0 OR @c_OrderKey IS NULL  
   BEGIN  
      SELECT @c_SuperFlag = CASE WHEN SuperOrderFlag = 'Y' THEN 'Y'  
                                 ELSE 'N'  
                            END  
      FROM LoadPlan (NOLOCK)  
      WHERE LoadKey = @c_oskey  
      
      --NJOW17
      IF @c_SuperFlag = 'Y'
      BEGIN
         Execute nspGetRight                                
            @c_Facility   = @c_facility,                     
            @c_StorerKey  = @c_StorerKey,                    
            @c_sku        = '',                           
            @c_ConfigKey  = 'AutoUpdSupordflag', -- Configkey         
            @b_Success    = @b_success   OUTPUT,             
            @c_authority  = @c_AutoUpdSupordflag OUTPUT,             
            @n_err        = @n_err       OUTPUT,             
            @c_errmsg     = @c_errmsg     OUTPUT,             
            @c_Option1    = @c_sfoption1  OUTPUT,               
            @c_Option2    = @c_sfoption2  OUTPUT,               
            @c_Option3    = @c_sfoption3  OUTPUT,               
            @c_Option4    = @c_sfoption4  OUTPUT,               
            @c_Option5    = @c_sfoption5  OUTPUT                
         
         IF dbo.fnc_GetParamValueFromString('@c_SkipSuperOrderFlagInDiscAlloc', @c_sfoption5, 'N') = 'Y'
         BEGIN         
            SELECT @c_SuperFlag = 'N'  
         END
      END         
   END  
  
   SET @d_step2 = GETDATE()  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OrderKey)) IS NOT NULL  
      BEGIN  
         /* 2001/10/02 CS Added facility for IDSHK FBR063 by joining Orders AS well */  
         IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  --NJOW05  
         BEGIN  
            INSERT INTO #OPORDERLINES (PreAllocatePickDetailKey, Orderkey, OrderLineNumber, Storerkey, Sku, Lot, UOM, UOMQty, Qty,  
                                       Packkey, Wavekey, PreAllocateStrategykey, PreAllocatePickCode, DoCartonize, PickMethod, Runkey,  
                                       Effectivedate, adddate, addwho, editdate, editwho,  
                                       CartonGroup, Strategykey, Facility, XDockFlag, Channel)  
            SELECT  
               PreAllocatePickDetailKey = '',  
               OD.OrderKey,  
               OD.OrderLineNumber,  
               OD.Storerkey,  
               OD.Sku,  
               LOT = '',  
               UOM = '',  
               UOMQty = '1',  
               Qty = (OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),  
               SKU.Packkey,  
               WaveKey = '',  
               PreAllocateStrategyKey = '',  
               PreAllocatePickCode = '',  
               DoCartonize = 'N',  
               PickMethod = '',     
               Runkey = '',             
               effectivedate = GETDATE(),  
               adddate = GETDATE(),  
               addwho = '',  
               editdate = GETDATE(),  
               editwho = '',                       
               CARTONGROUP = ISNULL(SKU.CartonGroup, ''),  
               StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, ''),  
               ORDERS.Facility,  
               ORDERS.XDockFlag,   
               ISNULL(OD.Channel,'')   
            FROM ORDERDETAIL OD WITH (NOLOCK)  
            JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
            JOIN STRATEGY (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey  
            JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = OD.OrderKey  
            WHERE ORDERS.Orderkey = @c_Orderkey AND  
                  ORDERS.Type NOT IN ( 'M', 'I' ) AND  
                  ORDERS.SOStatus <> 'CANC' AND  
                  ORDERS.Status < '9' AND  
                 (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
         END  
         ELSE  
         BEGIN  
            INSERT #OPORDERLINES  
            SELECT PREALLOCATEPICKDETAIL.* ,  
                   CARTONGROUP = ISNULL(SKU.CartonGroup, ''),  
                   STRATEGYKEY = ISNULL(STRATEGY.AllocateStrategyKey, ''),  
                   ORDERS.Facility,  
                   ORDERS.XDockFlag,   
                   ISNULL(OD.Channel,'')  
            FROM PREALLOCATEPICKDETAIL (NOLOCK)  
            JOIN ORDERS (NOLOCK) ON PREALLOCATEPICKDETAIL.ORDERKEY = ORDERS.ORDERKEY  
            JOIN SKU (NOLOCK) ON PREALLOCATEPICKDETAIL.Storerkey = SKU.Storerkey  
                             AND PREALLOCATEPICKDETAIL.Sku = SKU.Sku  
            JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = Strategy.Strategykey   
            JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = PREALLOCATEPICKDETAIL.OrderKey   
                 AND OD.OrderLineNumber = PREALLOCATEPICKDETAIL.OrderLineNumber  
            WHERE PREALLOCATEPICKDETAIL.ORDERKEY = @c_OrderKey  
            AND ORDERS.OrderKey = @c_OrderKey  
            AND PREALLOCATEPICKDETAIL.QTY > 0  
         END  
      END  
      ELSE  
      BEGIN  
         DECLARE @d_orderdatestart datetime, @d_orderdateend datetime,  
                 @d_deliverydatestart datetime, @d_deliverydateend datetime ,  
                 @c_ordertypestart NVARCHAR(10), @c_ordertypeend NVARCHAR(10) ,  
                 @c_orderprioritystart NVARCHAR(10) , @c_orderpriorityend NVARCHAR(10) ,  
                 @c_storerkeystart NVARCHAR(15), @c_storerkeyend NVARCHAR(15) ,  
                 @c_consigneekeystart NVARCHAR(15), @c_consigneekeyend NVARCHAR(15) ,  
                 @c_carrierkeystart NVARCHAR(15), @c_carrierkeyend NVARCHAR(15) ,  
                 @c_OrderKeystart NVARCHAR(10), @c_OrderKeyend NVARCHAR(10) ,  
                 @c_externorderkeystart NVARCHAR(30), @c_externorderkeyend NVARCHAR(30) ,  
                 @c_ordergroupstart NVARCHAR(20), @c_ordergroupend NVARCHAR(20) ,  
                 @n_maxorders Int,  
                 -- Add by June 05.June.03  
                 @d_LoadingDateStart datetime, @d_LoadingDateEnd datetime,  
                 -- SOS25145, add by June 26.Jul.04  
                 @c_RouteStart NVARCHAR(10), @c_RouteEnd NVARCHAR(10)  
  
         DECLARE @c_XDockPOKeyStart NVARCHAR(20),  
                 @c_XDOCKpokeyend NVARCHAR(20)  
  
         -- FBR019 CDC project  
         -- wally 22.oct.02 >> add facility in mass allocation parameters  
         IF @c_tblprefix = 'MAS'  
         BEGIN -- mass allocation  
            SELECT @d_orderdatestart = orderdatestart ,  
                   @d_orderdateend   = orderdateend ,  
                   @d_deliverydatestart = deliverydatestart ,  
                   @d_deliverydateend = deliverydateend ,  
                   @c_ordertypestart = ordertypestart ,  
                   @c_ordertypeend = ordertypeend ,  
                   @c_orderprioritystart = orderprioritystart ,  
                   @c_orderpriorityend = orderpriorityend ,  
                   @c_storerkeystart = storerkeystart ,  
                   @c_storerkeyend = storerkeyend ,  
                   @c_consigneekeystart = consigneekeystart ,  
                   @c_consigneekeyend = consigneekeyend ,  
                   @c_carrierkeystart = carrierkeystart ,  
                   @c_carrierkeyend = carrierkeyend ,  
                   @c_OrderKeystart = orderkeystart ,  
                   @c_OrderKeyend = orderkeyend ,  
                   @c_externorderkeystart = externorderkeystart ,  
                   @c_externorderkeyend = externorderkeyend ,  
                   @c_ordergroupstart = ordergroupstart ,  
                   @c_ordergroupend = ordergroupend ,  
                   @n_maxorders = maxorders ,  
                   @c_facility = facility,  
                   @d_LoadingDateStart = LoadingDateStart,   -- Add by June 05.June.03  
                   @d_LoadingDateEnd = LoadingDateEnd,       -- Add by June 05.June.03  
                   @c_XDockPOKeyStart = XDockPOKeyStart,  
                   @c_XDOCKpokeyend = XDOCKpokeyend,  
                   @c_RouteStart = RouteStart, -- SOS25145, Add by June 26.Jul.04  
                   @c_RouteEnd = RouteEnd -- SOS25145, Add by June 26.Jul.04  
            FROM OrderSELECTion (NOLOCK)  
            WHERE OrderSELECTionKey = @c_oskey  
  
            -- customized for ULP (Philippines) to cater for mass allocation sorting  
            -- orders should be sorted by priority, delivery date, booked date (OrderDate)  
            -- start: by RICKY 13.Nov.2001  
  
            INSERT #OPORDERLINES  
            SELECT PREALLOCATEPICKDETAIL.*,  
                   CARTONGROUP = ISNULL(SKU.CartonGroup, ''),  
                   STRATEGYKEY = ISNULL(STRATEGY.AllocateStrategyKey, ''),  
                   ORDERS.Facility,  
                   ORDERS.XDockFlag,   
                   ISNULL(ORDERDETAIL.Channel,'')   
            FROM ORDERS (NOLOCK)  
            JOIN PREALLOCATEPICKDETAIL (NOLOCK) ON PREALLOCATEPICKDETAIL.Orderkey = Orders.Orderkey  
            JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey  
                                      AND ORDERDETAIL.Orderkey = PREALLOCATEPICKDETAIL.Orderkey  
                                      AND ORDERDETAIL.OrderLineNumber = PREALLOCATEPICKDETAIL.OrderLineNumber -- SOS38185  
            JOIN SKU (NOLOCK) ON PREALLOCATEPICKDETAIL.Storerkey = SKU.Storerkey  
                             AND PREALLOCATEPICKDETAIL.Sku = SKU.Sku  
            JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = Strategy.Strategykey  
            WHERE ORDERS.Storerkey >=@c_storerkeystart  
            AND ORDERS.Storerkey <= @c_storerkeyend  
            -- Start : SOS38185  
            -- AND ORDERS.Status IN ('0', '1')  
            -- AND ORDERS.SOStatus = '0'  
            AND ORDERS.Status < '9'  
            AND ORDERS.SOStatus <> 'CANC'  
            AND ORDERDETAIL.Status = '0'  
            -- END : SOS38185  
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
            AND ORDERS.Orderkey >= @c_OrderKeyStart  
            AND ORDERS.Orderkey <= @c_OrderKeyEnd  
            AND ORDERS.ExternOrderkey >= @c_ExternOrderkeyStart  
            AND ORDERS.ExternOrderkey <= @c_ExternOrderkeyEnd  
            AND ORDERS.OrderGroup >= @c_ordergroupstart  
            AND ORDERS.OrderGroup <= @c_ordergroupend -- SOS42098  
            AND orders.facility = @c_facility -- CDC Migration  
            AND isnull(ORDERS.Userdefine06, 0) >= isnull(@d_LoadingDateStart,0)   -- Add by June 05.June.03  
            AND isnull(ORDERS.Userdefine06, 0) <= isnull(@d_LoadingDateEnd,0)     -- Add by June 05.June.03  
            AND ORDERS.Route >= @c_RouteStart -- SOS25145  
            AND ORDERS.Route <= @c_RouteEnd  -- SOS25145  
            AND ORDERS.pokey >= @c_XDockPOKeyStart  
            AND ORDERS.pokey <= @c_XDOCKpokeyend  
            AND PREALLOCATEPICKDETAIL.QTY > 0  
  
            SELECT @n_err = @@ERROR  
         END -- @c_tblprefix = 'MAS':mass allocation  
         ELSE  
         BEGIN -- load allocation  
            SELECT @n_cnt = COUNT(*)  
            FROM LoadPlanDetail (NOLOCK)  
            WHERE LoadKey = @c_oskey  
            IF @n_cnt = 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63505  
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": No Orders To Process. (nspOrderProcessing)"  
            END  
  
            IF @n_continue = 1 or @n_continue = 2  
            BEGIN  
               IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  --NJOW05  
               BEGIN  
                  INSERT INTO #OPORDERLINES (PreAllocatePickDetailKey, Orderkey, OrderLineNumber, Storerkey, Sku, Lot, UOM, UOMQty, Qty,  
                                             Packkey, Wavekey, PreAllocateStrategykey, PreAllocatePickCode, DoCartonize, PickMethod, Runkey,  
                                             Effectivedate, adddate, addwho, editdate, editwho,  
                                             CartonGroup, Strategykey, Facility, XDockFlag, Channel)  
                  SELECT                     PreAllocatePickDetailKey = '',  
                     OD.OrderKey,  
                     OD.OrderLineNumber,  
                     OD.Storerkey,  
                     OD.Sku,  
                     LOT = '',  
                     UOM = '',  
                     UOMQty = '1',  
                     Qty = (OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),  
                     SKU.Packkey,  
                     WaveKey = '',  
                     PreAllocateStrategyKey = '',  
                     PreAllocatePickCode = '',  
                     DoCartonize = 'N',  
                     PickMethod = '',           
                     Runkey = '',       
                     effectivedate = GETDATE(),  
                     adddate = GETDATE(),  
                     addwho = '',  
                     editdate = GETDATE(),  
                     editwho = '',                       
                     CARTONGROUP = ISNULL(SKU.CartonGroup, ''),  
                     StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, ''),  
                     ORDERS.Facility,  
                     ORDERS.XDockFlag,   
                     ISNULL(OD.Channel,'')   
                  FROM ORDERDETAIL OD WITH (NOLOCK)  
                  JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
                  JOIN STRATEGY (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey  
                  JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = OD.OrderKey  
                  JOIN LoadPlanDetail (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey  
                  WHERE LoadPlanDetail.LoadKey = @c_oskey AND  
                        ORDERS.Type NOT IN ( 'M', 'I' ) AND  
                        ORDERS.SOStatus <> 'CANC' AND  
                        ORDERS.Status < '9' AND  
                       (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
               END  
               ELSE  
               BEGIN                                    
                  /* 2001/10/02 CS Added facility for IDSHK FBR063 */                 
                  INSERT #OPORDERLINES  
                  SELECT PREALLOCATEPICKDETAIL.*,  
                         CARTONGROUP = ISNULL(SKU.CartonGroup, ''),  
                         STRATEGYKEY = ISNULL(STRATEGY.AllocateStrategyKey, ''),  
                         ORDERS.Facility,  
                         ORDERS.XDockFlag ,  
                         ISNULL(OD.Channel,'')   
                  FROM ORDERS (NOLOCK)  
                  JOIN PREALLOCATEPICKDETAIL (NOLOCK) ON PREALLOCATEPICKDETAIL.Orderkey = ORDERS.Orderkey  
                  JOIN ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = PREALLOCATEPICKDETAIL.OrderKey   
                              AND OD.OrderLineNumber = PREALLOCATEPICKDETAIL.OrderLineNumber  
                  JOIN LoadPlanDetail (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey  
                  JOIN SKU (NOLOCK) ON PREALLOCATEPICKDETAIL.Storerkey = SKU.Storerkey  
                                   AND PREALLOCATEPICKDETAIL.Sku = SKU.Sku  
                  JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = Strategy.Strategykey  
                  WHERE ORDERS.Status < '9'  
                  AND LoadPlanDetail.LoadKey = @c_oskey  
                  AND PREALLOCATEPICKDETAIL.QTY > 0  
               END  
  
------------------------------------------------  
               DECLARE @c_bStorerKey  NVARCHAR(15),  
                       @c_bSKU        NVARCHAR(20),  
                       @c_bLOT        NVARCHAR(10),  
                       @c_bUOM        NVARCHAR(10), -- (ChewKP01)  
                       @n_bQty        Int,  
                       @n_TotPackQty  Int,  
                       @n_bRemindQty  Int,  
  
                       @n_PackQty     Int  
  
               CREATE TABLE #TempBatchPick (  
                  StorerKey    NVARCHAR(15),  
                  SKU          NVARCHAR(20),  
                  LOT          NVARCHAR(10),  
                  UOM          NVARCHAR(10), -- (ChewKP01)  
                  Qty          Int )  
  
               IF @c_SuperFlag = 'Y'  
               BEGIN  
                  -- Modifief by SHONG on 27th Jan 2006                    
                  DECLARE BatchCur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PREALLOCATEPICKDETAIL.StorerKey, PREALLOCATEPICKDETAIL.Sku SKU,  
                            PREALLOCATEPICKDETAIL.Lot LOT,   SUM(PREALLOCATEPICKDETAIL.Qty) QTY  
                     FROM ORDERS (NOLOCK), PREALLOCATEPICKDETAIL (NOLOCK), LoadPlanDetail (NOLOCK)  
                     WHERE PREALLOCATEPICKDETAIL.OrderKey = ORDERS.OrderKey  
                     AND LoadPlanDetail.OrderKey = ORDERS.OrderKey  
                     AND ORDERS.Status < '9'  
                     AND LoadPlanDetail.LoadKey = @c_oskey  
                     AND PREALLOCATEPICKDETAIL.Qty > 0  
                     AND PREALLOCATEPICKDETAIL.Uom <> '1'  
                     GROUP BY PREALLOCATEPICKDETAIL.StorerKey, PREALLOCATEPICKDETAIL.Sku, PREALLOCATEPICKDETAIL.Lot  
  
                  OPEN BatchCur  
  
                  FETCH NEXT FROM BatchCur INTO @c_bStorerKey, @c_bSKU, @c_bLOT, @n_bQty  
                  WHILE @@FETCH_STATUS <> -1  
                  BEGIN  
                     SELECT @c_bUOM = ''  
                     SELECT @n_bRemindQty = @n_bQty  
                     WHILE 1=1  
                     BEGIN  
                        SELECT @c_bUOM = MIN(UOM)  
                        FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                        WHERE UOM > @c_bUOM  
                          AND ALLOCATESTRATEGYKEY = 'SUPERORDER'  
                          AND UOM Between '1' and '5'  
  
                        IF dbo.fnc_RTrim(@c_bUOM) IS NULL OR dbo.fnc_RTrim(@c_bUOM) = ''  
                           BREAK  
  
                        SELECT @n_PackQty = ISNULL(CASE @c_bUOM WHEN '1' Then PACK.Pallet  
                                                         WHEN '2' Then PACK.CaseCnt  
                                                         WHEN '3' Then PACK.InnerPack  
                                            END, 0)  
                        FROM PACK (NOLOCK)  
                        JOIN SKU (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
                        WHERE SKU.StorerKey = @c_bStorerkey  
                          AND SKU.SKU = @c_bSKU  
  
                        IF @n_PackQty > 0 AND @n_bRemindQty >= @n_PackQty  
                        BEGIN  
  
                           SELECT @n_TotPackQty = Floor(@n_bRemindQty / @n_PackQty) * @n_PackQty  
                           SELECT @n_bRemindQty = @n_bRemindQty - @n_TotPackQty  
  
                           INSERT INTO #TempBatchPick (StorerKey, SKU, UOM, LOT, Qty) VALUES  
                              (@c_bStorerKey, @c_bSKU, @c_bUOM, @c_bLOT, @n_TotPackQty)  
                        END  
                     END -- While UOM  
                     IF @n_bRemindQty > 0  
                     BEGIN  
                        INSERT INTO #TempBatchPick (StorerKey, SKU, UOM, LOT, Qty) VALUES  
                           (@c_bStorerKey, @c_bSKU, '6', @c_bLOT, @n_bRemindQty)  
                     END  
                     FETCH NEXT FROM BatchCur INTO @c_bStorerKey, @c_bSKU, @c_bLOT, @n_bQty  
                  END -- While  
                  CLOSE BatchCur  
                  DEALLOCATE BatchCur  
  
               END -- IF superFlag = 'Y'  
----------------------------------------------------------------  
            END -- @n_continue = 1 or @n_continue = 2;INSERT INTO temp table #oporderlines  
         END -- @c_tblprefix <> 'MAS' ; Load Allocation  
      END -- @c_OrderKey Is NULL  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation Of OPORDERLINES Temp Table Failed (nspOrderProcessing)"   
                        + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN  
         SELECT @n_cnt = COUNT(*) FROM #OPORDERLINES  
         IF @n_cnt = 0  
         BEGIN  
            SELECT @n_continue = 4  
            SELECT @n_err = 63511  
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": No Order Lines To Process. (nspOrderProcessing)"  
            EXECUTE nsp_logerror @n_err, @c_errmsg, "nspOrderProcessing"  
         END  
         ELSE IF (@b_debug = 1 or @b_debug = 2)  
         BEGIN  
            PRINT 'Number of Order Lines Pre-Allocated: ' + CAST(@n_cnt AS NVARCHAR(5))  
         END  
      END -- @n_continue = 1 or @n_continue = 2  
   END -- @n_continue = 1 or @n_continue = 2  
  
   SET @d_step2 = GETDATE() - @d_step2 -- (tlting01)  
   SET @c_Col2 = 'Stp2-InsertPrealloc' -- (tlting01)  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_cartonizationgroup NVARCHAR(10) ,  
      @c_routingkey NVARCHAR(10) ,  
      @c_pickcode NVARCHAR(10) ,  
      @c_dorouting NVARCHAR(1) ,  
      @c_docartonization NVARCHAR(1),  
      @c_preallocationgrouping NVARCHAR(10) ,  
      @c_preallocationsort NVARCHAR(10) ,  
      @c_waveoption NVARCHAR(10) ,  
      @n_batchpickmaxcube Int ,  
      @n_batchpickmaxcount Int ,  
      @c_workoskey NVARCHAR(10)  
  
      SELECT @c_dorouting = @c_doroute , @c_docartonization = @c_docarton  
      SELECT @c_cartonizationgroup = cartonizationgroup ,  
            @c_routingkey = routingkey ,  
            @c_pickcode = pickcode ,  
            @c_preallocationgrouping = preallocationgrouping ,  
            @c_preallocationsort = preallocationsort ,  
            @c_waveoption = waveoption ,  
            @n_batchpickmaxcube = batchpickmaxcube ,  
            @n_batchpickmaxcount = batchpickmaxcount ,  
            @c_workoskey = orderSELECTionkey  
        FROM ORDERSELECTION (NOLOCK)  
       WHERE DefaultFlag = "1"  
  
      SELECT @n_cnt = @@ROWCOUNT  
  
      --NJOW01 Start  
      IF @n_cnt = 0  
      BEGIN  
         SELECT  @c_cartonizationgroup = cartonizationgroup,    
                 @c_routingkey = routingkey,   
                 @c_pickcode = pickcode ,  
                 @c_preallocationgrouping = preallocationgrouping,  
                 @c_preallocationsort = preallocationsort,      
                 @c_waveoption = waveoption,   
                 @n_batchpickmaxcube = batchpickmaxcube,  
                 @n_batchpickmaxcount = batchpickmaxcount,  
            @c_workoskey = OrderSelectionkey  
         FROM OrderSelection (NOLOCK)   
         WHERE OrderSelectionkey = 'STD'  
         SELECT @n_cnt = @@ROWCOUNT   
      END  
        
      IF @n_cnt = 0  
      BEGIN  
         SELECT  TOP 1 @c_cartonizationgroup = cartonizationgroup,    
                 @c_routingkey = routingkey,   
                 @c_pickcode = pickcode ,  
                 @c_preallocationgrouping = preallocationgrouping,  
                 @c_preallocationsort = preallocationsort,      
                 @c_waveoption = waveoption,   
                 @n_batchpickmaxcube = batchpickmaxcube,  
                 @n_batchpickmaxcount = batchpickmaxcount,  
                 @c_workoskey = OrderSelectionkey  
         FROM OrderSelection (NOLOCK)   
         ORDER BY OrderSelectionkey  
         SELECT @n_cnt = @@ROWCOUNT   
      END  
        
      IF @n_cnt = 0  
      BEGIN          
          SELECT @c_cartonizationgroup = 'STD'    
          SELECT @c_pickcode = 'USESKUTBL'  
          SELECT @c_preallocationsort = '1'  
          SELECT @c_preallocationgrouping = '1'  
          SELECT @c_waveoption = 'DISCRETE'  
          SELECT @c_routingkey = 'STD'  
         SELECT @n_batchpickmaxcube = 0  
         SELECT @n_batchpickmaxcount = 0  
          SELECT @n_cnt = 1  
      END        
      --NJOW01 End  
  
      IF @n_cnt = 0  
      BEGIN  
         SELECT @n_continue = 3  
       SELECT @n_err = 63512  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Incomplete OrderSELECTion Parameters! (nspOrderProcessing)"  
      END  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
--       UPDATE #OPORDERLINES SET CARTONGROUP = SKU.CartonGroup  
--         FROM #OPORDERLINES,SKU (NOLOCK)  
--        WHERE #OPORDERLINES.Storerkey = SKU.Storerkey  
--          AND #OPORDERLINES.Sku = SKU.Sku  
--          AND #OPORDERLINES.CartonGroup = ''  
--          AND SKU.CartonGroup IS NOT NULL  
  
  
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.CartonGroup = '' )  
      BEGIN  
         UPDATE #OPORDERLINES SET CARTONGROUP = Storer.CartonGroup  
           FROM #OPORDERLINES, Storer (NOLOCK)  
          WHERE #OPORDERLINES.Storerkey = Storer.Storerkey  
            AND #OPORDERLINES.CartonGroup = ''  
            AND Storer.CartonGroup IS NOT NULL  
      END  
  
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.PackKey = '' )  
      BEGIN  
         UPDATE #OPORDERLINES SET PACKKEY = SKU.PackKey  
           FROM #OPORDERLINES,SKU (NOLOCK)  
          WHERE #OPORDERLINES.Storerkey = SKU.Storerkey  
            AND #OPORDERLINES.Sku = SKU.Sku  
            AND #OPORDERLINES.PackKey = ''  
            AND SKU.PackKey IS NOT NULL  
      END  
  
--       UPDATE #OPORDERLINES  
--       SET STRATEGYKEY = STRATEGY.AllocateStrategyKey  
--       FROM #OPORDERLINES, SKU (NOLOCK), STRATEGY (NOLOCK)  
--       WHERE #OPORDERLINES.Storerkey = SKU.Storerkey  
--          AND #OPORDERLINES.Sku = SKU.Sku  
--          AND SKU.Strategykey = Strategy.Strategykey  
  
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.CartonGroup = '')  
      BEGIN  
         UPDATE #OPORDERLINES  
         SET CARTONGROUP = @c_cartonizationgroup  
         WHERE CartonGroup = ''  
      END  
  
      --(Wan02) - START  
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
      IF ISNULL(@c_StrategykeyParm,'') <> ''  --NJOW14   
      BEGIN  
         UPDATE TMP    
         SET StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, '')    
         FROM #OPORDERLINES TMP    
         JOIN STRATEGY     WITH (NOLOCK) ON  STRATEGY.Strategykey = @c_StrategykeyParm           
      END  
      ELSE IF (@c_DefaultStrategykey = 'Y' AND (@c_extendparms = 'LP' OR  @c_oskey <> ''))   
         OR (@c_extendparms <> 'LP')   --NJOW12   if from load plan depend on defaultstrategykey flag to change strategy. if from wave/order is not depend.  
      BEGIN  
          --NJOW03  
         IF @c_extendparms = 'LP' OR @c_oskey <> ''  --from load plan or load conso call from wave  
         BEGIN  
            UPDATE TMP   
               SET Strategykey = CASE   
                                    WHEN ISNULL(RTRIM(STRATEGY.AllocateStrategyKey),'') = '' AND ISNULL(RTRIM(STORERCONFIG.sValue),'') = '' THEN   
                                       TMP.Strategykey  
                                    WHEN ISNULL(RTRIM(STRATEGY.AllocateStrategyKey),'') <> '' THEN   
                                       STRATEGY.AllocateStrategyKey  
                                    WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') <> '' THEN   
                                       STG2.AllocateStrategyKey   
                                    ELSE  
                                       TMP.Strategykey  
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
            -- @c_extendparms <> 'LP  ORDER/WAVE Discrete NJOW12  
            UPDATE TMP  
            SET StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, '')  
            FROM #OPORDERLINES TMP  
            JOIN STORERCONFIG WITH (NOLOCK) ON (StorerConfig.Facility = TMP.Facility)  
                                            AND(StorerConfig.Storerkey= TMP.Storerkey)   
                                            AND(StorerConfig.ConfigKey= 'StorerDefaultAllocStrategy')   
            JOIN STRATEGY     WITH (NOLOCK) ON (StorerConfig.SValue = STRATEGY.Strategykey)  
         END  
  
         /*  
         UPDATE #OPORDERLINES   
            SET Strategykey = ISNULL(RTRIM(STRATEGY.AllocateStrategyKey),'')  
         FROM #OPORDERLINES TMP  
         JOIN STORER   WITH (NOLOCK) ON TMP.Storerkey = STORER.Storerkey  
         JOIN STRATEGY WITH (NOLOCK) ON STORER.Strategykey = STRATEGY.Strategykey  
         */  
      END  
  
      --(Wan02) - END  
   END -- @n_continue = 1 or @n_continue = 2  
 /* END - Customization for IDS - Added by DLIM for FBR24A 20010716 */  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      CREATE TABLE #OPPICKDETAIL (PickDetailKey    NVARCHAR(10) ,  
      PickHeaderKey    NVARCHAR(10) ,  
      OrderKey         NVARCHAR(10) ,  
      OrderLineNumber  NVARCHAR(10) ,  
      Storerkey        NVARCHAR(15) ,  
      Sku              NVARCHAR(20) ,  
      Loc              NVARCHAR(10) ,  
      Lot              NVARCHAR(10) ,  
      Id               NVARCHAR(18) ,  
      Caseid           NVARCHAR(10) ,  
      UOM              NVARCHAR(10) ,  
      UOMQty           Int ,  
      Qty              Int ,  
      PackKey          NVARCHAR(10) ,  
      CartonGroup      NVARCHAR(10) ,  
      DoReplenish      NVARCHAR(1)  NULL,  
      ReplenishZone    NVARCHAR(10) NULL,  
      DoCartonize      NVARCHAR(1),  
      PickMethod       NVARCHAR(1),  
      Channel_ID        BIGINT   
      )  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation Of Temp Table Failed (nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END -- @n_continue = 1 or @n_continue = 2  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_AllowOverAllocations NVARCHAR(1) -- Flag to see IF overallocations are allowed.  
   END  
   -- IF @c_AllowOverAllocations = '1'  
   -- BEGIN  
   IF ( @n_continue = 1 or @n_continue = 2 )  
   BEGIN  
      CREATE TABLE #OP_PICKLOCTYPE (loc  NVARCHAR(10) )  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation Of #OP_PICKLOCTYPE Temp Table Failed (nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
   IF ( @n_continue = 1 or @n_continue = 2 )  
   BEGIN  
      CREATE TABLE #OP_OVERPICKLOCS (rownum  Int IDENTITY,  
                                    loc          NVARCHAR(10) ,  
                             id           NVARCHAR(18) ,  
                                    QtyAvailable Int  
      )  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation Of #OP_OVERPICKLOCS Temp Table Failed (nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
   IF ( @n_continue = 1 or @n_continue = 2 )  
   BEGIN  
      CREATE TABLE #OP_PICKLOCS (StorerKey    NVARCHAR(15) ,  
      Sku          NVARCHAR(20) ,  
      Loc          NVARCHAR(10) ,  
      LocationType NVARCHAR(10)  
      )  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation Of #OP_PICKLOCS Temp Table Failed (nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
   -- END -- @c_AllowOverAllocations = '1'  

   --NJOW20 Start        
   IF ( @n_Continue = 1 OR @n_Continue = 2 )   
   BEGIN
      EXEC isp_AllocateUpd_OPORDERLINES_Wrapper @c_Orderkey = @c_Orderkey,  
                                                @c_Loadkey = @c_oskey,  
                                                @c_Wavekey = '',  
                                                @c_Storerkey = @c_Storerkey,
                                                @c_Facility = @c_Facility,
                                                @c_SourceType = 'nspOrderProcessing',  
                                                @b_Success = @b_Success OUTPUT,            
                                                @n_Err = @n_err OUTPUT,            
                                                @c_Errmsg = @c_errmsg OUTPUT  
                                             
      IF @b_Success <> 1    
      BEGIN    
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'nspOrderProcessing'  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END       
   END
   --NJOW20 End  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_aStorerKey NVARCHAR(15), @c_aSKU NVARCHAR(20), @c_Aorderkey NVARCHAR(10),  
            @c_Aorderlinenumber NVARCHAR(5), @c_aUOM NVARCHAR(10), @n_aUOMQty Int , -- (ChewKP01)  
            @n_aQtyLeftToFulfill Int, @c_aPackKey NVARCHAR(10), @c_Adocartonize NVARCHAR(1) ,  
            @c_aLOT NVARCHAR(10), @c_Apreallocatepickdetailkey NVARCHAR(10) ,  
            @c_aStrategykey NVARCHAR(10), @c_Acartongroup NVARCHAR(10), @c_aPickMethod NVARCHAR(1),  
            @c_cloc NVARCHAR(10) ,@c_cid NVARCHAR(18) , @n_cQtyAvailable Int, @c_endstring NVARCHAR(300) ,  
            @n_cursorcandidates_open Int,  
            @b_candidateexhausted Int, @n_candidateline Int,  
            @n_Available Int, @n_QtyToTake Int, @n_UOMQty Int ,  @n_cPackQty Int,  
            @n_jumpsource Int,  
            @c_sCurrentLineNumber NVARCHAR(5), @c_sAllocatePickCode NVARCHAR(30) ,  
            @c_sLocationTypeOverride NVARCHAR(10), @c_sLocationTypeOverridestripe NVARCHAR(10),  
            @c_pickloc NVARCHAR(10), @b_overcontinue Int, @c_pickId NVARCHAR(18), @n_pickQty Int,  
            @n_rownum Int, @n_qtytoovertake Int, @n_TempBatchPickQty Int,  
            @c_pickdetailkey NVARCHAR(10), @c_pickheaderkey NVARCHAR(5), @n_pickrecscreated Int ,  
            @b_pickupdatesuccess Int, @n_QtyToInsert Int, @n_UOMQtyToInsert Int,  
            @c_uom1pickmethod NVARCHAR(1) , @c_uom2pickmethod NVARCHAR(1) ,  @c_uom3pickmethod NVARCHAR(1) ,  
            @c_uom4pickmethod NVARCHAR(1) , @c_uom5pickmethod NVARCHAR(1) ,  @c_uom6pickmethod NVARCHAR(1) ,  
            @c_uom7pickmethod NVARCHAR(1),  
            @b_TryIfQtyRemain Int, @n_NumberOfRetries Int,  
            @n_caseqty Int, @n_palletqty Int, @n_innerpackqty Int,  
            @n_otherunit1 Int , @n_otherunit2 Int,  
            @c_cartonizeCase NVARCHAR(1), @c_cartonizePallet NVARCHAR(1), @c_cartonizeInner NVARCHAR(1),  
            @c_cartonizeOther1 NVARCHAR(1), @c_cartonizeOther2 NVARCHAR(1), @c_cartonizeEA NVARCHAR(1),  
            @c_LocType NVARCHAR(500), @c_pallettype NVARCHAR(1), @c_OldStrategyKey NVARCHAR(10),   --NJOW20
            @c_OldCurrentLineNumber NVARCHAR(5), @c_oldoriginalstrategykey NVARCHAR(10),  
            @n_PackBalance Int, @n_OriginalPallet Int, @c_OldSKU NVARCHAR(20), @c_HostWHCode NVARCHAR(10)  
            /* 2001/10/02 CS Added facility for IDSHK FBR063 */  
            ,@c_AFacility NVARCHAR(5), @c_oldstorerkey NVARCHAR(15) -- Added by Ricky for IDSV5 to control Overallocation  
  
      DECLARE @cSuperUOM       NVARCHAR(10), -- (ChewKP01)  
              @n_aCaseCnt      float,  
              @n_aPalletCnt    float,  
              @n_aInnerPackCnt float,  
              @c_OldStorer     NVARCHAR(15),  
              @c_OldUOM     NVARCHAR(10), -- (ChewKP01)  
              @c_BatchUOM      NVARCHAR(10)  -- (ChewKP01)  
  
      SELECT @b_candidateexhausted=0, @n_candidateline = 0  
      SELECT @n_Available = 0, @n_QtyToTake = 0, @n_UOMQty = 0, @n_cPackQty = 0  
      SELECT @b_TryIfQtyRemain = 1, @n_NumberOfRetries = 0  
  
    /***** Customised For LI & Fung *****/  
  
      SELECT @n_caseqty = 0, @n_palletqty=0, @n_innerpackqty = 0, @n_otherunit1=0, @n_otherunit2=0  
      SELECT @c_Apreallocatepickdetailkey = '', @c_OldSKU = SPACE(20), @c_OldStorer = SPACE(15)  
      SELECT @c_oldstorerkey = SPACE(15) -- Added by Ricky for IDSV5 to control Overallocation  
      SELECT @c_OldUOM = '' -- (ChewKP01)  
  
      SET @d_step3 = GETDATE()  
  
      DECLARE C_OPORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT #OPORDERLINES.PreAllocatePickDetailKey ,  
               #OPORDERLINES.storerkey ,  
               #OPORDERLINES.sku ,  
               #OPORDERLINES.orderkey,  
               #OPORDERLINES.Orderlinenumber ,  
               #OPORDERLINES.uom ,  
               #OPORDERLINES.uomqty ,  
               #OPORDERLINES.qty ,  
               #OPORDERLINES.packkey ,  
               #OPORDERLINES.cartongroup ,  
               #OPORDERLINES.docartonize,  
               #OPORDERLINES.lot ,  
               #OPORDERLINES.PickMethod ,  
               #OPORDERLINES.Strategykey,  
               OD.Lottable01,  
               #OPORDERLINES.Facility,       -- 2001/10/02 CS Added facility for IDSHK FBR063  
               OD.Lottable02,                -- modified by Jeff  
               #OPORDERLINES.XDockFlag,  
               PACK.CaseCnt,  
               PACK.Pallet,  
               PACK.InnerPack,  
               OD.Lottable01, OD.Lottable03, OD.Lottable04, OD.Lottable05, --NJOW05  
               OD.Lottable06, OD.Lottable07, OD.Lottable08, OD.Lottable09, OD.Lottable10, --NJOW05       
               OD.Lottable11, OD.Lottable12, OD.Lottable13, OD.Lottable14, OD.Lottable15,  --NJOW05  
               #OPORDERLINES.Channel   
           FROM #OPORDERLINES  
           JOIN ORDERDETAIL OD (NOLOCK) ON #OPORDERLINES.OrderKey = OD.OrderKey  
                                    AND #OPORDERLINES.OrderLineNumber = OD.OrderLineNumber  
           JOIN PACK (NOLOCK) ON OD.PackKey = PACK.PackKey  
          ORDER BY CASE WHEN ISNULL(@c_SkipPreAllocationFlag,'0') <> '1' THEN #OPORDERLINES.PreAllocatePickDetailKey ELSE ' ' END,  --NJOW05  
               #OPORDERLINES.orderkey, #OPORDERLINES.Orderlinenumber         
  
      OPEN C_OPORDERLINES  
  
      WHILE (1 = 1) and (@n_continue = 1 or @n_continue = 2)  
      BEGIN  
         SET @n_Channel_ID = 0 --SWT01  
           
         FETCH NEXT FROM C_OPORDERLINES INTO  
               @c_Apreallocatepickdetailkey,  
               @c_aStorerKey,  
               @c_aSKU,  
               @c_Aorderkey,  
               @c_AOrderlinenumber,  
               @c_aUOM,  
               @n_aUOMQty,  
               @n_aQtyLeftToFulfill,  
               @c_aPackKey,  
               @c_Acartongroup,  
               @c_Adocartonize,  
               @c_aLOT,  
               @c_aPickMethod,  
               @c_aStrategykey,  
               @c_HostWHCode,  
               @c_AFacility,       -- 2001/10/02 CS Added facility for IDSHK FBR063  
               @c_lottable02,      -- modified by Jeff  
               @c_XDOCK,  
               @n_aCaseCnt,  
               @n_aPalletCnt,  
               @n_aInnerPackCnt,         
               @c_Lottable01, --NJOW05  
               @c_Lottable03, --NJOW05  
               @d_Lottable04, --NJOW05  
               @d_Lottable05, --NJOW05  
               @c_Lottable06, --NJOW05      
               @c_Lottable07, --NJOW05      
               @c_Lottable08, --NJOW05      
               @c_Lottable09, --NJOW05      
               @c_Lottable10, --NJOW05      
               @c_Lottable11, --NJOW05      
               @c_Lottable12, --NJOW05      
               @d_Lottable13, --NJOW05      
               @d_Lottable14, --NJOW05      
               @d_Lottable15,  --NJOW05    
               @c_Channel  -- SWT01  
  
         IF @@FETCH_STATUS <> 0  
         BEGIN  
            BREAK  
         END  
         ELSE IF ( @b_debug = 1 or @b_debug = 2 )  
         BEGIN  
            PRINT ''  
            PRINT ''  
            PRINT '-----------------------------------------------------'  
            PRINT '-- OrderKey: ' + @c_Aorderkey + ' Line:' + @c_AOrderlinenumber  
            PRINT '-- SKU: ' + RTRIM(@c_aSKU) + ' Qty:' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))  
            PRINT '-- Pack Key :' + RTRIM(@c_aPackKey) + ' UOM:' + @c_aUOM + ' UOM Qty: ' + CAST(@n_aUOMQty AS NVARCHAR(10))  
            PRINT '-- LOT: ' + RTRIM(@c_aLOT)  
         END  
  
         /***** Customised For LI & Fung *****/  
         SELECT @c_oldoriginalstrategykey = @c_aStrategykey  
  
         -- Added by Ricky for IDSV5 to control Overallocation  
         IF @c_oldstorerkey <> @c_aStorerKey  
         BEGIN  
            -- Added By SHONG on 04-Aug-2003  
            -- SOS# 12769  
            -- When StorerConfigKey ("UseOrdKeyAsWHCode") Flag is turn on. Overwrite the HostWHCode to OrderKey.  
            DECLARE @c_UseOrdKeyAsWHCode NVARCHAR(1)  
            SELECT @b_success = 0  
            EXECUTE nspGetRight @c_afacility,   -- facility  
                              @c_aStorerKey,    -- Storerkey  
                              @c_aSKU, -- Sku  
                              'UseOrdKeyAsWHCode', -- Configkey  
                              @b_success     OUTPUT,  
                              @c_UseOrdKeyAsWHCode OUTPUT,  
                              @n_err         OUTPUT,  
                              @c_errmsg      OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            ELSE  
            BEGIN  
               IF @c_UseOrdKeyAsWHCode = '1'  
               BEGIN  
                  SELECT @c_HostWHCode = @c_aOrderkey  
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT 'UseOrdKeyAsWHCode is ON'  
                  END  
               END  
            END  
            -- END  
  
            -- Start : SOS99448  
            SELECT @b_success = 0  
            EXECUTE nspGetRight @c_afacility,  -- facility  
            @c_aStorerKey,   -- StorerKey  
            @c_aSKU,         -- Sku  
            'Orderinfo4Allocation',  -- Configkey  
            @b_success    OUTPUT,  
            @c_Orderinfo4Allocation  OUTPUT,  
            @n_err        OUTPUT,  
            @c_errmsg     OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            -- END : SOS99448  
  
            --NJOW02  
            SELECT @b_success = 0  
            EXECUTE nspGetRight @c_afacility,  -- facility  
            @c_aStorerKey,   -- StorerKey  
            NULL,         -- Sku  
            'PickOverAllocateNoMixLot',  -- Configkey  
            @b_success    OUTPUT,  
            @c_PickOverAllocateNoMixLot  OUTPUT,  
            @n_err        OUTPUT,  
            @c_errmsg     OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)  
            END  
  
            --NJOW04  
            SELECT @b_success = 0  
            Execute nspGetRight @c_afacility,  -- facility  
            @c_AStorerKey,   -- StorerKey  
            null,            -- Sku  
            'AllocateGetCasecntFrLottable',         -- Configkey  
            @b_success    output,  
            @c_AllocateGetCasecntFrLottable output,  
            @n_err        output,  
            @c_errmsg     output  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)  
            END
            
            --NJOW13
            SELECT @b_success = 0  
            Execute nspGetRight @c_afacility,  -- facility  
            @c_AStorerKey,   -- StorerKey  
            null,            -- Sku  
            'UCCAllocation',         -- Configkey  
            @b_success    output,  
            @c_UCCAllocation output,  
            @n_err        output,  
            @c_errmsg     output  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + RTRIM(@c_errmsg)  
            END   
  
            SELECT @b_success = 0  
            EXECUTE nspGetRight @c_afacility,   -- facility  NJOW07  
                              @c_aStorerKey,    -- Storerkey  
                              NULL, -- Sku  
                              'ALLOWOVERALLOCATIONS', -- Configkey  
              @b_success     OUTPUT,  
                              @c_AllowOverAllocations OUTPUT,  
                              @n_err         OUTPUT,  
                              @c_errmsg      OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            ELSE  
            BEGIN  
               IF @c_AllowOverAllocations is null  
               BEGIN  
                  SELECT @c_AllowOverAllocations = '0'  
               END  
               SELECT @c_oldstorerkey = @c_aStorerKey  
            END  
         END  
  
         IF @n_continue = 1 or @n_continue = 2  
         BEGIN  
            IF @c_SuperFlag = 'Y'  
            BEGIN  
               IF EXISTS(SELECT UOM FROM #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM)  
               BEGIN  
                  IF EXISTS(SELECT 1 FROM  #TempBatchPick)  
                  BEGIN  
                       
                     SELECT TOP 1 @n_TempBatchPickQty = Qty,  
                            @c_aUOM = UOM,  
                            @c_BatchUOM = UOM  
                       FROM  #TempBatchPick  
                      WHERE StorerKey = @c_aStorerKey  
                        AND Sku = @c_aSKU  
                        AND LOT = @c_aLOT  
                        AND Qty > 0  
                      ORDER By UOM  
                  END  
               END  
               ELSE  
               BEGIN  
                  SELECT @n_TempBatchPickQty = 0  
               END  
  
  
               IF @c_OldSKU <> @c_aSKU OR @c_OldStorer <> @c_aStorerKey  
               BEGIN  
                  SELECT @c_OldSKU = @c_aSKU, @c_OldStorer = @c_aStorerKey  
                           SELECT @c_OldUOM = @c_aUOM -- SOS38045  
  
                  /* IDSV5 - Leo */  
                  delete from #Tmp_SuperOrder_UOM where UOM in ('3', '7')  
                  SELECT @b_success = 0  
  
                  EXECUTE nspGetRight @c_afacility,  
                                      @c_aStorerKey,  
                                      @c_aSKU,  
                                      'SUPERORDER - UOM 3',      -- ConfigKey  
                                      @b_success    OUTPUT,  
                                      @c_authority  OUTPUT,  
                                      @n_err        OUTPUT,  
                                      @c_errmsg     OUTPUT  
  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3, @c_errmsg = 'nspOrderProcessing:' + dbo.fnc_RTrim(@c_errmsg)  
                  END  
                  ELSE  
                  BEGIN  
                     IF @c_authority = '1'  
                     BEGIN  
                        INSERT INTO #Tmp_SuperOrder_UOM values ('3')  
                     END  
                  END  
  
                  SELECT @b_success = 0  
                  EXECUTE nspGetRight @c_afacility,  
                                      @c_aStorerKey,  
                                      @c_aSKU,  
                                      'SUPERORDER - UOM 7',      -- ConfigKey  
                                      @b_success    OUTPUT,  
                                      @c_authority  OUTPUT,  
                                      @n_err        OUTPUT,  
                                      @c_errmsg     OUTPUT  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3, @c_errmsg = 'nspOrderProcessing:' + dbo.fnc_RTrim(@c_errmsg)  
                  END  
                  ELSE  
                  BEGIN  
                     IF @c_authority = '1'  
                     BEGIN  
                        INSERT INTO #Tmp_SuperOrder_UOM values ('7')  
                     END  
                  END  
  
               END -- @c_OldSKU <> @c_aSKU  
               ELSE  
               BEGIN  
                  IF @n_PackBalance > 0  
                  BEGIN  
                     SELECT @c_aUOM = @c_OldUOM  
                  END  
               END  
            END -- SuperFlag = 'Y'  
  
            SELECT @n_cPackQty = @n_aQtyLeftToFulfill / @n_aUOMQty  
  
            IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
            BEGIN  
               SET @b_TryIfQtyRemain = 0  
            END  
            ELSE  
            BEGIN  
               SELECT @b_TryIfQtyRemain = RetryIfQtyRemain  
               FROM ALLOCATESTRATEGY (NOLOCK)  
               WHERE ALLOCATESTRATEGYKEY = @c_aStrategykey  
            END  
  
            SELECT @c_sCurrentLineNumber = SPACE(5)  
            SELECT @n_NumberOfRetries = 0  
  
         END -- @n_continue = 1 or @n_continue = 2  
  
         LOOPPICKSTRATEGY:  
         WHILE (@n_continue = 1 or @n_continue = 2) and @n_NumberOfRetries <= 7 and @c_aUOM <= 9 and @n_aQtyLeftToFulfill > 0  
         BEGIN  
            IF @c_SuperFlag = 'Y'  
            BEGIN  
               SELECT @b_success = 0  
  
               EXECUTE nspGetRight @c_Afacility,  
                                  @c_aStorerKey,  
                                  @c_aSKU,  
                                  'SUPERORDER - LOC OVERRIDE LOT2',      -- ConfigKey  
                                  @b_success    OUTPUT,  
                                  @c_authority  OUTPUT,  
                                  @n_err        OUTPUT,  
                                  @c_errmsg     OUTPUT  
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3, @c_errmsg = 'nspOrderProcessing:' + dbo.fnc_RTrim(@c_errmsg)  
               END  
               ELSE  
               BEGIN  
                    IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'    
                    BEGIN  
                      --NJOW10  
                      GET_NEXT_STRATEGY_SUPER:  
                     IF @c_authority = '1'  
                     BEGIN  
                        SELECT @c_OldCurrentLineNumber = @c_sCurrentLineNumber  
                        SELECT @c_OldStrategyKey = @c_aStrategykey  
                       
                        SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                               @c_sAllocatePickCode = Pickcode ,  
                               @c_sLocationTypeOverride = LocationTypeOverride,  
                               @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe,  
                               @c_aUOM = UOM  
                          FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                         WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                           AND ALLOCATESTRATEGYKEY = 'SUPERORDER'  
                        ORDER BY AllocateStrategyLineNumber  
                     END  
                     ELSE  
                     BEGIN  
                        SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                               @c_sAllocatePickCode = Pickcode ,  
                               @c_sLocationTypeOverride = LocationTypeOverride,  
                               @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe,  
                               @c_aUOM = UOM                                 
                          FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                         WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                           AND ALLOCATESTRATEGYKEY = @c_aStrategykey  
                        ORDER BY AllocateStrategyLineNumber  
                     END        
  
                     IF @@ROWCOUNT = 0  
                     BEGIN  
                        BREAK  
                     END  
                                    
                     SELECT @n_PalletQty = Pallet, @c_CartonizePallet = CartonizeUOM4,  
                            @n_CaseQty = CaseCnt, @c_CartonizeCase = CartonizeUOM1,  
                            @n_InnerPackQty = InnerPack, @c_CartonizeInner = CartonizeUOM2,  
                            @n_OtherUnit1 = CONVERT(INT,OtherUnit1), @c_CartonizeOther1 = CartonizeUOM8,  
                            @n_OtherUnit2 = CONVERT(INT,OtherUnit2), @c_CartonizeOther2 = CartonizeUOM9,  
                            @c_CartonizeEA = CartonizeUOM3  
                     FROM PACK (NOLOCK)  
                     WHERE PackKey = @c_aPackKey  
                       
                     SELECT @n_aUOMQty =  
                           CASE @c_aUOM  
                              WHEN '1' THEN @n_PalletQty  
                              WHEN '2' THEN @n_CaseQty  
                              WHEN '3' THEN @n_InnerPackQty  
                              WHEN '4' THEN @n_OtherUnit1  
                              WHEN '5' THEN @n_OtherUnit2  
                              WHEN '6' THEN 1  
                              WHEN '7' THEN 1  
                              ELSE 0  
                           END                  
                       
                     SELECT @n_cPackQty = @n_aUOMQty                         
  
                     --Remove to support dynamic uom qty control at pickcode                                             
                     --IF @n_cPackQty > @n_aQtyLeftToFulfill   
                     --  AND @c_aUOM <> '1' --NJOW06 support full pallet by loc/id  
                     --   GOTO GET_NEXT_STRATEGY_SUPER                                           
                    END  
                    ELSE  
                    BEGIN    
                     IF @c_authority = '1'  
                     BEGIN  
                        SELECT @c_OldCurrentLineNumber = @c_sCurrentLineNumber  
                        SELECT @c_OldStrategyKey = @c_aStrategykey  
                       
                        SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                               @c_sAllocatePickCode = Pickcode ,  
                               @c_sLocationTypeOverride = LocationTypeOverride,  
                               @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe  
                          FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                         WHERE UOM = @c_aUOM  
                           AND AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                           AND ALLOCATESTRATEGYKEY = 'SUPERORDER'  
                        ORDER BY AllocateStrategyLineNumber  
                     END  
                     ELSE  
                     BEGIN  
                        SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                               @c_sAllocatePickCode = Pickcode ,  
                               @c_sLocationTypeOverride = LocationTypeOverride,  
                               @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe  
                          FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                         WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                           AND UOM = @c_aUOM  
                           AND ALLOCATESTRATEGYKEY = @c_aStrategykey  
                        ORDER BY AllocateStrategyLineNumber  
                     END  
                     IF @@ROWCOUNT = 0  
                     BEGIN  
                        BREAK  
                     END                       
                  END                    
               END                 
            END -- @c_SuperFlag = 'Y'  
            ELSE  
            BEGIN               
                IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
                BEGIN                 
                  GET_NEXT_STRATEGY:  
                    
                  SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                         @c_sAllocatePickCode = Pickcode ,  
                         @c_sLocationTypeOverride = LocationTypeOverride,  
                         @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe,  
                         @c_aUOM = UOM  
                    FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                   WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                     AND ALLOCATESTRATEGYKEY = @c_aStrategykey                    
                  ORDER BY AllocateStrategyLineNumber  
  
                  IF @@ROWCOUNT = 0  
                  BEGIN  
                     BREAK  
                  END  
                    
                  SELECT @n_PalletQty = Pallet, @c_CartonizePallet = CartonizeUOM4,  
                         @n_CaseQty = CaseCnt, @c_CartonizeCase = CartonizeUOM1,  
                         @n_InnerPackQty = InnerPack, @c_CartonizeInner = CartonizeUOM2,  
                         @n_OtherUnit1 = CONVERT(INT,OtherUnit1), @c_CartonizeOther1 = CartonizeUOM8,  
                         @n_OtherUnit2 = CONVERT(INT,OtherUnit2), @c_CartonizeOther2 = CartonizeUOM9,  
                         @c_CartonizeEA = CartonizeUOM3  
                  FROM PACK (NOLOCK)  
                  WHERE PackKey = @c_aPackKey  
                    
                  SELECT @n_aUOMQty =  
                        CASE @c_aUOM  
                           WHEN '1' THEN @n_PalletQty  
                           WHEN '2' THEN @n_CaseQty  
                           WHEN '3' THEN @n_InnerPackQty  
                           WHEN '4' THEN @n_OtherUnit1  
                           WHEN '5' THEN @n_OtherUnit2  
                           WHEN '6' THEN 1  
                           WHEN '7' THEN 1  
                           ELSE 0  
                        END                  
                            
                  SELECT @n_cPackQty = @n_aUOMQty  
                    
                  --Remove to support dynamic uom qty control at pickcode  
                  --IF @n_cPackQty > @n_aQtyLeftToFulfill   
                  --  -AND @c_aUOM <> '1' --NJOW06 support full pallet by loc/id  
                  --   GOTO GET_NEXT_STRATEGY                    
               END  
               ELSE  
                BEGIN                 
                  SELECT TOP 1 @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                         @c_sAllocatePickCode = Pickcode ,  
                         @c_sLocationTypeOverride = LocationTypeOverride,  
                         @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe  
                    FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                   WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber  
                     AND UOM = @c_aUOM  
                     AND ALLOCATESTRATEGYKEY = @c_aStrategykey                    
                  ORDER BY AllocateStrategyLineNumber  
  
                  IF @@ROWCOUNT = 0  
                  BEGIN  
                     BREAK  
                  END  
                    
               END  
            END -- @c_SuperFlag <> 'Y'  
  
            /*  
            IF @b_debug = 1 or @b_debug = 2  
            BEGIN  
                 PRINT '@c_aStrategykey=' + RTRIM(@c_aStrategykey) + ' @c_aUOM=' + RTRIM(@c_aUOM) + ' @c_sAllocatePickCode='   
                 + RTRIM(@c_sAllocatePickCode) + ' @c_sLocationTypeOverride=' + RTRIM(@c_sLocationTypeOverride) + ' @c_sLocationTypeOverridestripe='  
                 + RTRIM(@c_sLocationTypeOverridestripe)  
            END  
            */  
  
            /***** Customised For LI & Fung *****/  
            IF @c_SuperFlag = 'Y' AND EXISTS(SELECT UOM from #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM)  
            BEGIN  
               IF (@n_aPalletCnt <= @n_TempBatchPickQty AND @n_aPalletCnt > 0  OR  
                   @n_aCaseCnt <= @n_TempBatchPickQty AND @n_aCaseCnt > 0 )  
               BEGIN  
                  IF @n_PackBalance IS NULL OR @n_PackBalance = 0  
                  BEGIN  
                     IF @n_aPalletCnt <= @n_TempBatchPickQty AND @n_aPalletCnt > 0  
                        SELECT @n_PackBalance = @n_aPalletCnt, @n_OriginalPallet = @n_aPalletCnt  
                     ELSE  
                     IF @n_aCaseCnt <= @n_TempBatchPickQty AND @n_aCaseCnt > 0  
                        -- SELECT @n_PackBalance = @n_aCaseCnt, @n_OriginalPallet = @n_aCaseCnt  
                        SELECT @n_PackBalance = @n_TempBatchPickQty, @n_OriginalPallet = @n_TempBatchPickQty  
                  END  
               END  
               ELSE IF (( @n_aPalletCnt > @n_TempBatchPickQty AND @n_aPalletCnt > 0 ) OR  
                       ( @n_aCaseCnt > @n_TempBatchPickQty AND @n_aCaseCnt > 0 ))  
               BEGIN  
                  IF @n_PackBalance IS NULL  
                     SELECT @n_PackBalance = 0  
  
               END -- PACK.Pallet > @n_TempBatchPickQty and Superflag = 'Y'  
            END -- @c_SuperFlag = 'Y'  
  
            -- for XDOCK allocation  
            IF @c_XDOCK = 'Y'  
                 SELECT @c_sCurrentLineNumber = AllocateStrategyLineNumber ,  
                      @c_sAllocatePickCode = Pickcode,  
                      @c_sLocationTypeOverride = LocationTypeOverride,  
                      @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe,  
                      @c_aUOM = uom,  
                      @n_NumberOfRetries = 8  
                 FROM ALLOCATESTRATEGYDETAIL (NOLOCK)  
                WHERE ALLOCATESTRATEGYKEY = 'XDOCK'  
  
            IF ( dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sLocationTypeOverride)) IS NULL) OR (@c_AllowOverAllocations = '0')  
               OR ( ISNULL(@c_SkipPreAllocationFlag,'0') = '1') --NJOW05  
            BEGIN  
               DECLARECURSOR_CANDIDATES:  
               SELECT @n_cursorcandidates_open = 0  
               SELECT @c_endstring = ' @n_uombase = ' + LTRIM(convert(Char(10),@n_cPackQty)) + ", @n_qtylefttofulfill=" + LTRIM(convert(Char(10), @n_aQtyLeftToFulfill))  
  
               --NJOW14  
               IF EXISTS(SELECT 1    
                         FROM sys.parameters AS p    
                         JOIN sys.types AS t ON t.user_type_id = p.user_type_id    
                         WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)    
                         AND   P.name = N'@c_OtherParms')                          
               BEGIN  
                  SET @c_OtherParmsExist = 'Y'  
               END  
               ELSE  
               BEGIN    
                  SET @c_OtherParmsExist = 'N'  
               END     

               --NJOW20 S
               IF EXISTS(SELECT 1    
                         FROM sys.parameters AS p    
                         JOIN sys.types AS t ON t.user_type_id = p.user_type_id    
                         WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)    
                         AND   P.name = N'@c_AllocateStrategyKey')    
               BEGIN    
                  SELECT @c_EndString = RTRIM(@c_EndString) + ',@c_AllocateStrategyKey = N''' +RTRIM(@c_aStrategyKey) + ''''                       
               END                     
               
               IF EXISTS(SELECT 1    
                         FROM sys.parameters AS p    
                         JOIN sys.types AS t ON t.user_type_id = p.user_type_id    
                         WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)    
                         AND   P.name = N'@c_AllocateStrategyLineNumber')    
               BEGIN    
                  SELECT @c_EndString = RTRIM(@c_EndString) + ',@c_AllocateStrategyLineNumber = N''' +RTRIM(@c_sCurrentLineNumber) + ''''                      
               END        
               --NJOW20 E
                           
               IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
               BEGIN  
                  IF @d_Lottable04 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable04, 112) = '19000101'  
                     SELECT @c_Lottable04 = ''  
                  ELSE  
                     SELECT @c_Lottable04 = CONVERT(VARCHAR(20), @d_Lottable04, 112)  
                    
                  IF @d_Lottable05 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable05, 112) = '19000101'  
                     SELECT @c_Lottable05 = ''  
                  ELSE  
                     SELECT @c_Lottable05 = CONVERT(VARCHAR(20), @d_Lottable05, 112)   
                    
                  IF @d_Lottable13 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable13, 112) = '19000101'  
                     SELECT @c_Lottable13 = ''   
                  ELSE  
                     SELECT @c_Lottable13 = CONVERT(VARCHAR(20), @d_Lottable13, 112)  
                    
                  IF @d_Lottable14 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable14, 112) = '19000101'  
                     SELECT @c_Lottable14 = ''  
                  ELSE  
                     SELECT @c_Lottable14 = CONVERT(VARCHAR(20), @d_Lottable14, 112)  
                               
                  IF @d_Lottable15 IS NULL OR CONVERT(VARCHAR(20), @d_Lottable15, 112) = '19000101'  
                     SELECT @c_Lottable15 = ''  
                  ELSE  
                     SELECT @c_Lottable15 = CONVERT(VARCHAR(20), @d_Lottable15, 112)  
                              
                  SET @c_Lottable_Parm = ''  
                  SET @c_OtherParms = dbo.fnc_RTrim(@c_aOrderKey) + dbo.fnc_RTrim(@c_aOrderLineNumber)  + 'O'  --NJOW14  
  
                  SELECT @c_Lottable_Parm = ISNULL(MAX(PARAMETER_NAME),'')  
                  FROM [INFORMATION_SCHEMA].[PARAMETERS]   
                  WHERE SPECIFIC_NAME = @c_sAllocatePickCode  
                    AND PARAMETER_NAME Like '%Lottable%'  
  
                  IF ISNULL(RTRIM(@c_Lottable_Parm), '') <> ''   
                  BEGIN    
                     SET @c_SQLExecute = @c_sAllocatePickCode  
                    
                     DECLARE Cur_Parameters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PARAMETER_NAME, ORDINAL_POSITION  
                     FROM [INFORMATION_SCHEMA].[PARAMETERS]   
                     WHERE SPECIFIC_NAME = @c_sAllocatePickCode   
                     ORDER BY ORDINAL_POSITION  
  
                     OPEN Cur_Parameters  
                     FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition  
                     WHILE @@FETCH_STATUS <> -1  
                     BEGIN  
                        IF @n_OrdinalPosition = 1  
                           SET @c_SQLExecute = RTRIM(@c_SQLExecute) + ' ' +RTRIM(@c_ParameterName) + ' = N''' + @c_aOrderkey   + ''''    
                        ELSE  
                        BEGIN   
                           SET @c_SQLExecute = RTRIM(@c_SQLExecute) +   
                              CASE @c_ParameterName  
                                 WHEN '@c_Facility'   THEN ',@c_Facility   = N''' + RTRIM(@c_Facility) + ''''  
                                 WHEN '@c_StorerKey'  THEN ',@c_StorerKey  = N''' + RTRIM(@c_aStorerKey) + ''''  
                                 WHEN '@c_SKU'        THEN ',@c_SKU        = N''' + RTRIM(@c_aSKU) + ''''   
                                 WHEN '@c_Lottable01' THEN ',@c_Lottable01 = N''' + RTRIM(@c_Lottable01) + ''''   
                                 WHEN '@c_Lottable02' THEN ',@c_Lottable02 = N''' + RTRIM(@c_Lottable02) + ''''   
                                 WHEN '@c_Lottable03' THEN ',@c_Lottable03 = N''' + RTRIM(@c_Lottable03) + ''''   
                                 WHEN '@d_Lottable04' THEN ',@d_Lottable04 = N''' + @c_Lottable04 + ''''    
                                 WHEN '@c_Lottable04' THEN ',@c_Lottable04 = N''' + @c_Lottable04 + ''''    
                                 WHEN '@d_Lottable05' THEN ',@d_Lottable05 = N''' + @c_Lottable05 + ''''    
                                 WHEN '@c_Lottable05' THEN ',@c_Lottable05 = N''' + @c_Lottable05 + ''''    
                                 WHEN '@c_Lottable06' THEN ',@c_Lottable06 = N''' + RTRIM(@c_Lottable06) + ''''   
                                 WHEN '@c_Lottable07' THEN ',@c_Lottable07 = N''' + RTRIM(@c_Lottable07) + ''''   
                                 WHEN '@c_Lottable08' THEN ',@c_Lottable08 = N''' + RTRIM(@c_Lottable08) + ''''   
                                 WHEN '@c_Lottable09' THEN ',@c_Lottable09 = N''' + RTRIM(@c_Lottable09) + ''''    
                                 WHEN '@c_Lottable10' THEN ',@c_Lottable10 = N''' + RTRIM(@c_Lottable10) + ''''    
                                 WHEN '@c_Lottable11' THEN ',@c_Lottable11 = N''' + RTRIM(@c_Lottable11) + ''''   
                                 WHEN '@c_Lottable12' THEN ',@c_Lottable12 = N''' + RTRIM(@c_Lottable12) + ''''   
                                 WHEN '@d_Lottable13' THEN ',@d_Lottable13 = N''' + @c_Lottable13 + ''''      
                                 WHEN '@d_Lottable14' THEN ',@d_Lottable14 = N''' + @c_Lottable14 + ''''      
                                 WHEN '@d_Lottable15' THEN ',@d_Lottable15 = N''' + @c_Lottable15 + ''''      
                                 WHEN '@c_UOM'        THEN ',@c_UOM = N''' + RTRIM(@c_aUOM) + ''''   
                                 WHEN '@c_HostWHCode' THEN ',@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + ''''   
                                 WHEN '@n_UOMBase'   THEN ',@n_UOMBase=''' + CONVERT(VARCHAR(10),@n_cPackQty) + ''''  
                                 WHEN '@n_QtyLeftToFulfill' THEN ',@n_QtyLeftToFulfill=''' + CONVERT(VARCHAR(10), @n_aQtyLeftToFulfill) + '''' 
                                 WHEN '@c_OtherParms' THEN ',@c_OtherParms = N''' +RTRIM(@c_OtherParms) + ''''   --NJOW14                                    
                                 WHEN '@c_AllocateStrategyKey' THEN ',@c_AllocateStrategyKey = N''' + RTRIM(@c_aStrategyKey) + ''''  --NJOW20
                                 WHEN '@c_AllocateStrategyLineNumber' THEN ',@c_AllocateStrategyLineNumber = N''' + RTRIM(@c_sCurrentLineNumber) + ''''  --NJOW20                                 
                              END   
                            --  + '''' + ',' + RTRIM(@c_EndString) 
                        END  
  
                        FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition  
                     END   
                     CLOSE Cur_Parameters  
                     DEALLOCATE Cur_Parameters     
  
                     --NJOW14 Removed  
                     --IF @c_Orderinfo4Allocation = '1' --NJOW07    
                     --   SELECT @c_SQLExecute = RTRIM(@c_SQLExecute) + ',@c_OtherParms = N''' +RTRIM(@c_OtherParms) + ''''                           
                           
                              
                     IF @b_debug = 1 OR @b_debug = 2  
                     BEGIN  
                      PRINT ''  
                        PRINT ''  
                        PRINT '-- Execute Allocate Strategy ' + RTRIM(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)  
                        PRINT '   EXEC ' +  @c_SQLExecute   
                     END  
                                                 
                     EXEC(@c_SQLExecute)  
                  END  
                  ELSE  
                  BEGIN  
                     IF @b_debug = 1 OR @b_debug = 2  
                     BEGIN  
                        PRINT 'Skip Preallocate Pickcode Lottable Parm not found'  
                        PRINT ''  
                        PRINT '-- Execute Allocate Strategy ' + RTRIM(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)  
                        PRINT '   EXEC ' +  RTRIM(@c_sAllocatePickCode) + ' ' + '@c_aFacility=N''' + RTRIM(@c_aFacility)  
                                 + '''' + ',' + '@c_aStorerKey=N''' + RTRIM(@c_aStorerKey)  
                                 + '''' + ',' + '@c_aSKU=N''' + RTRIM(@c_aSKU)  
                                 + '''' + ',' + '@c_UOM=N''' + RTRIM(@c_aUOM) + ''''  
                                 + ',' + '@c_HostWHCode=N''' + RTRIM(@c_HostWHCode) + '''' + ',' + RTRIM(@c_EndString)  
                     END  
  
                     --Select @c_sAllocatePickCode '@c_sAllocatePickCode', @c_EndString '@c_EndString' -- testing  
                     IF EXISTS(SELECT 1  
                               FROM sys.parameters AS p  
                               JOIN sys.types AS t ON t.user_type_id = p.user_type_id  
                               WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)  
                               AND   P.name = N'@c_LOT')  
                     BEGIN  
                        DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
                        FOR SELECT LOT= '', LOC = '', ID='', QTYAVAILABLE = 0, '1'  
                        FROM LOTxLOCxID (NOLOCK)  
                        WHERE 1=2  
                     END  
                     ELSE
                     BEGIN  
                        --IF @c_Orderinfo4Allocation = '1'     
                        IF @c_OtherParmsExist = 'Y' --NJOW14   
                           EXEC(@c_sAllocatePickCode + ' '  
                                 + 'N''' + @c_aOrderKey   + ''''  + ','  
                                 + 'N''' + @c_aFacility + ''''  + ','  
                                 + 'N''' + @c_aStorerKey + '''' + ','  
                                 + 'N''' + @c_aSKU + '''' + ','  
                                 + 'N''' + @c_aUOM + '''' + ','  
                                 + 'N''' + @c_HostWHCode + '''' + ','  
                                 + @c_EndString + ',N''' +  @c_OtherParms + '''')                  
                        ELSE                                   
                           EXEC(@c_sAllocatePickCode + ' '  
                                 + 'N''' + @c_aOrderKey   + ''''  + ','  
                                 + 'N''' + @c_aFacility + ''''  + ','  
                                 + 'N''' + @c_aStorerKey + '''' + ','  
                                 + 'N''' + @c_aSKU + '''' + ','  
                                 + 'N''' + @c_aUOM + '''' + ','  
                                 + 'N''' + @c_HostWHCode + '''' + ','  
                                 + @c_EndString)                  
                     END  
                  END  
                  SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT                  
               END  
               ELSE  
               BEGIN        
                    --NJOW05           
                  IF NOT EXISTS(SELECT 1  
                            FROM sys.parameters AS p  
                            JOIN sys.types AS t ON t.user_type_id = p.user_type_id  
                            WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)  
                  AND   P.name = N'@c_LOT')  
                  BEGIN  
                      print 'lot not found'
                     DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
                     FOR SELECT LOC = '', ID='', QTYAVAILABLE = 0, '1'  
                     FROM LOTxLOCxID (NOLOCK)  
                     WHERE 1=2  
                       
                     IF @b_debug = 1 OR @b_debug = 2  
                     BEGIN                      
                        PRINT 'Allocation Pickcode without @c_Lot Parm. No result'  
                     END  
                  END  
                  ELSE  
                  BEGIN 
                     --IF @c_Orderinfo4Allocation = '1'    
                     IF @c_OtherParmsExist = 'Y' --NJOW14  
                     BEGIN    
                        SELECT @c_OtherParms = dbo.fnc_RTrim(@c_aOrderKey) + dbo.fnc_RTrim(@c_aOrderLineNumber) +'O'  --NJOW14   
                        --EXEC(@c_sAllocatePickCode + " " + "N'" + @c_aLOT + "'" + "," + "N'" + @c_aUOM + "'" + "," + "N'" + @c_HostWHCode + "'" + "," + "N'" + @c_AFacility + "'" + "," + @c_endstring + ",N'" +  @c_OtherParms + "'" )  
                        
                        print @c_sAllocatePickCode + " @c_lot= " + "N'" + @c_aLOT + "'" + "," + " @c_uom = N'" + @c_aUOM + "'" + "," + " @c_HostWHCode = N'" + @c_HostWHCode + "'" + "," + " @c_Facility= N'" + @c_AFacility + "'" + "," + @c_endstring   
                              + ",@c_OtherParms= N'" +  @c_OtherParms + "'" 
                       
                        EXEC(@c_sAllocatePickCode + " @c_lot= " + "N'" + @c_aLOT + "'" + "," + " @c_uom = N'" + @c_aUOM + "'" + "," + " @c_HostWHCode = N'" + @c_HostWHCode + "'" + "," + " @c_Facility= N'" + @c_AFacility + "'" + "," + @c_endstring   
                              + ",@c_OtherParms= N'" +  @c_OtherParms + "'" )  
                       
                        IF @b_debug = 1 OR @b_debug = 2  
                        BEGIN  
                           PRINT ''  
                           PRINT ''  
                           PRINT '-- EXECUTE Allocate Strategy ' + RTrim(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)  
                       
                           PRINT '   EXEC ' +  RTrim(@c_sAllocatePickCode) + " " + "@c_LOT=N'" + RTrim(@c_aLOT) + "'" + "," + "@c_UOM=N'" +  
                            RTrim(@c_aUOM) + "'" + "," + "@c_HostWHCode=N'" + RTrim(@c_HostWHCode) + "'" + "," + "@c_Facility=N'"  
                            + RTrim(@c_AFacility) + "'" + "," + RTRIM(@c_endstring) + "," +  RTrim(@c_OtherParms) + "'"  
                        END  
                     END  
					 ELSE  
                     BEGIN  
                        EXEC(@c_sAllocatePickCode + " @c_lot= " + "N'" + @c_aLOT + "'" + "," + " @c_uom = N'" + @c_aUOM + "'" + "," + " @c_HostWHCode = N'" + @c_HostWHCode + "'" + "," + " @c_Facility= N'" + @c_AFacility + "'" + "," + @c_endstring)  
                       
                        IF @b_debug = 1 OR @b_debug = 2  
                        BEGIN  
                           PRINT ''  
                           PRINT ''  
                           PRINT '-- EXECUTE Allocate Strategy ' + RTrim(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)  
                       
                           PRINT '   EXEC ' +  RTrim(@c_sAllocatePickCode) + " " + "@c_LOT=N'" + RTrim(@c_aLOT) + "'" + "," + "@c_UOM=N'" +  
                            RTrim(@c_aUOM) + "'" + "," + "@c_HostWHCode=N'" + RTrim(@c_HostWHCode) + "'" + "," + "@c_Facility=N'"  
                            + RTrim(@c_AFacility) + "'" + "," + RTRIM(@c_endstring)  
                        END  
                     END  
                     -- END : SOS99448  
                  END  
               END  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err = 16915  
               BEGIN  
                  CLOSE CURSOR_CANDIDATES  
                  DEALLOCATE CURSOR_CANDIDATES  
                  GOTO DECLARECURSOR_CANDIDATES  
               END  
  
               OPEN CURSOR_CANDIDATES  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err = 16905  
               BEGIN  
                  CLOSE CURSOR_CANDIDATES  
                  DEALLOCATE CURSOR_CANDIDATES  
                  GOTO DECLARECURSOR_CANDIDATES  
               END  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Creation/Opening of Candidate Cursor Failed! (nspOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
               END  
               ELSE  
               BEGIN  
                  SELECT @n_cursorcandidates_open = 1  
               END  
  
               IF (@n_continue = 1 or @n_continue = 2) AND @n_cursorcandidates_open = 1  
               BEGIN  
                  SELECT @n_candidateline = 0  

                  SELECT @c_PrevUCCNo = '' --NJOW13 
                  SET    @c_aPrevLot  = '' --NJOW11  
                  WHILE @n_aQtyLeftToFulfill > 0  
                  BEGIN  
                     SELECT @n_fetch_status = 0  
                     SELECT @n_candidateline = @n_candidateline + 1
                     SELECT @c_UCCNo = ''  --NJOW13 
                     SELECT @c_FullPallet = 'N' --NJOW20
                     SELECT @c_DYNUOMQty = ''   --NJOW20                     
                       
                     IF @n_candidateline = 1  
                     BEGIN  
                        SELECT @n_cQtyAvailable = 0, @c_cloc = '', @c_cid='', @c_LocType = ''  
                          
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
                        BEGIN  
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT, @c_cloc, @c_cid, @n_cQtyAvailable, @c_LocType  
                        END  
                        ELSE  
                        BEGIN  
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_cloc, @c_cid, @n_cQtyAvailable, @c_LocType  
                        END  

                        IF CHARINDEX('@', @c_LocType, 1) > 0  --NJOW20
                        BEGIN                                                                                                                            
                           IF @c_UCCAllocation = '1' --NJOW20
                           BEGIN
                              SET @c_UCCNo = dbo.fnc_GetParamValueFromString('@c_UCCNo', @c_LocType, '')
                           END
                        END 
                        ELSE 
                        BEGIN
                           --NJOW13 
                           IF @c_UCCAllocation = '1' AND @c_LocType NOT IN ('1','FULLPALLET') AND LEFT(@c_LocType,4) <> 'UOM='  
                           BEGIN                                
                              SET @c_UCCNo = @c_LocType  
                           END
                        END   
                        PRINT '     LOC: ' + @c_cloc + ' ID: ' + RTRIM(@c_cID) 
                        SELECT @n_fetch_status = @@FETCH_STATUS  
                        SELECT 'LINE2138' , @n_fetch_status
                        IF (@b_debug = 1 OR @b_debug = 2) and @n_fetch_status <> -1  
                        BEGIN  
                           PRINT ''  
                           PRINT '**** Location Found ****'  
                           PRINT '     LOC: ' + @c_cloc + ' ID: ' + RTRIM(@c_cID)  
                           PRINT '     Qty Available: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))  
                           PRINT '     Location Type: ' + RTRIM(@c_LocType)  
                           PRINT '     UCC No: ' + + RTRIM(@c_UCCNo)      --NJOW13  
  
                           IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
                           BEGIN  
                              PRINT '     LOT: ' + @c_aLOT  
                           END  
                        END  
  
                        IF @c_SuperFlag = 'Y'  
                        BEGIN  
                           IF EXISTS(SELECT UOM from #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM) AND @n_PackBalance > 0  
                           BEGIN  
                               IF @n_cQtyAvailable >= @n_PackBalance  
                               BEGIN  
                                  SELECT @n_cQtyAvailable = @n_PackBalance  
                                  SELECT @n_cPackQty = 1  
                               END  
                           END  
                        END -- @c_SuperFlag = 'Y'  
                     END -- @n_candidateline = 1  
                     ELSE  
                     BEGIN  
                        SELECT @n_cQtyAvailable = 0, @c_cloc = '', @c_cid='', @c_LocType = ''  
  
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
                        BEGIN  
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT, @c_cloc, @c_cid, @n_cQtyAvailable, @c_LocType  
                        END  
                        ELSE  
                        BEGIN  
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_cloc, @c_cid, @n_cQtyAvailable, @c_LocType  
                        END  

                        IF CHARINDEX('@', @c_LocType, 1) > 0  --NJOW20
                        BEGIN                                                                                                                            
                           IF @c_UCCAllocation = '1' --NJOW20
                           BEGIN
                              SET @c_UCCNo = dbo.fnc_GetParamValueFromString('@c_UCCNo', @c_LocType, '')
                           END
                        END
                        ELSE 
                        BEGIN
                           --NJOW13 
                           IF @c_UCCAllocation = '1' AND @c_LocType NOT IN ('1','FULLPALLET') AND LEFT(@c_LocType,4) <> 'UOM='  
                           BEGIN                                
                              SET @c_UCCNo = @c_LocType 
                           END
                        END   

                        SELECT @n_fetch_status = @@FETCH_STATUS  
  
                        IF (@b_debug = 1 OR @b_debug = 2) and @n_fetch_status <> -1  
                        BEGIN  
                           PRINT ''  
                           PRINT '**** Location Found ****'  
                           PRINT '     LOC: ' + @c_cloc + ' ID: ' + RTRIM(@c_cID)   
                           PRINT '     Qty Available: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))  
                           PRINT '     Pack Balance: ' + CAST(@n_PackBalance AS NVARCHAR(10))  
                           PRINT '     Location Type: ' + RTRIM(@c_LocType)  
                           PRINT '     UCC No: ' + + RTRIM(@c_UCCNo)      --NJOW13 

                           IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --NJOW05  
                           BEGIN  
                              PRINT '     LOT: ' + @c_aLOT  
                           END  
                        END  
                        IF @c_SuperFlag = 'Y'  
                        BEGIN  
                           IF EXISTS(SELECT UOM from #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM)  
                                     AND @n_PackBalance > 0 AND (@n_cQtyAvailable > @n_PackBalance)  
                           BEGIN  
                              SELECT @n_cQtyAvailable = @n_PackBalance  
                           END  
                           ELSE IF EXISTS(SELECT UOM from #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM) AND  
                                   (@n_PackBalance = 0 OR @n_cQtyAvailable = 0)  
                           BEGIN  
                              BREAK  
                           END  
                        END -- @c_SuperFlag = 'Y'  
                     END -- @n_candidateline <> 1  
                     IF @n_fetch_status < 0  
                     BEGIN  
                        IF @b_debug = 1  
                        BEGIN  
                           PRINT ''  
                           PRINT '**** No Location Found ****'  
                        END  
  
                        BREAK  
                     END  
                     IF @n_fetch_status = 0  
                     BEGIN  
                          --NJOW20 S
                        IF CHARINDEX('@', @c_LocType, 1) > 0  
                        BEGIN
                           SET @c_FullPallet = dbo.fnc_GetParamValueFromString('@c_FULLPALLET', @c_LocType, 'N') 
                           SET @c_DYNUOMQty =  dbo.fnc_GetParamValueFromString('@c_DYNUOMQTY', @c_LocType, '') 
                        END
                        ELSE
                        BEGIN
                            IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  
                            BEGIN                            
                               IF @c_LocType = 'FULLPALLET'
                                  SET @c_FullPallet = 'Y'
                            
                              IF LEFT(@c_LocType,4) = 'UOM=' 
                                 SET @c_DYNUOMQty = SUBSTRING(@c_LocType,5,10)
                            END   
                        END
                        --NJOW20 E
                        
                        --(Wan03) - START  
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'    
                        BEGIN  
                           SET @n_LotAvailableQty = 0  
                           SELECT @n_LotAvailableQty = Qty - QtyAllocated - QtyPicked - QtyPreAllocated  
                           FROM LOT (NOLOCK)   
                           WHERE Lot = @c_aLOT     
        
                           IF @n_cQtyAvailable > @n_LotAvailableQty   
                              SET @n_cQtyAvailable = @n_LotAvailableQty   
  
                           SELECT @n_FacLotAvailQty = SUM(LLI.Qty - LLI.QtyAllocated - LLi.QtyPicked)  
                           FROM LOTxLOCxID  LLI WITH (NOLOCK)   
                           JOIN LOC         LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)  
                           WHERE LLI.Lot =  @c_aLOT    
                           AND   LOC.Facility = @c_AFacility   
  
                           IF @n_FacLotAvailQty < @n_cQtyAvailable  
                           BEGIN   
                              SET @n_cQtyAvailable = @n_FacLotAvailQty    
                           END  
  
                           -- (SWT01)  
                           IF @n_continue = 1 or @n_continue = 2  
                           BEGIN         
                              IF @c_ChannelInventoryMgmt = '1'         
                              BEGIN  
                                 IF @c_aPrevLot <> @c_aLot  --NJOW11  
                                    SET @n_Channel_ID = 0  
                                 
                                 IF ISNULL(RTRIM(@c_Channel), '') <> ''  AND  
                                    ISNULL(@n_Channel_ID,0) = 0  
                                 BEGIN  
                                    SET @n_Channel_ID = 0  
                 
                                    BEGIN TRY  
                                       EXEC isp_ChannelGetID   
                                           @c_StorerKey   = @c_aStorerKey  
                                          ,@c_Sku         = @c_aSKU  
                                          ,@c_Facility    = @c_aFacility  
                                          ,@c_Channel     = @c_Channel  
                                          ,@c_LOT         = @c_aLOT  
                                          ,@n_Channel_ID  = @n_Channel_ID OUTPUT  
                                          ,@b_Success     = @b_Success OUTPUT  
                                          ,@n_ErrNo       = @n_Err OUTPUT  
                                          ,@c_ErrMsg      = @c_ErrMsg OUTPUT           
                                          ,@c_CreateIfNotExist = 'N'  
                                    END TRY  
                                    BEGIN CATCH  
                                          SELECT @n_err = ERROR_NUMBER(),  
                                                 @c_ErrMsg = ERROR_MESSAGE()  
                              
                                          SELECT @n_continue = 3  
                                          SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspOrderProcessing)'   
                                    END CATCH                                            
                                 END   
                                 IF @n_Channel_ID > 0   
                                 BEGIN  
                                    SET @n_Channel_Qty_Available = 0   
                 
                                    SET @n_AllocatedHoldQty = 0   
                                    
                                    --NJOW16 S
                                    SET @c_SourceType = 'nspOrderProcessing'
                                    SET @n_ChannelHoldQty = 0
                                    IF ISNULL(@c_Orderkey,'') = ''                                       
                                       SET @c_SourceKey = SPACE(10) + @c_oskey 
                                    ELSE
                                       SET @c_SourceKey = @c_Orderkey   

                                    EXEC isp_ChannelAllocGetHoldQty_Wrapper  
                                       @c_StorerKey = @c_aStorerkey, 
                                       @c_Sku = @c_aSKU,  
                                       @c_Facility = @c_aFacility,           
                                       @c_Lot = @c_aLOT,
                                       @c_Channel = @c_Channel,
                                       @n_Channel_ID = @n_Channel_ID,   
                                       @n_AllocateQty = @n_cQtyAvailable, --NJOW21
                                       @n_QtyLeftToFulFill = @n_aQtyLeftToFulfill, --NJOW21
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
                                    --NJOW16 E   
                                    
                                    /*(Wan05) - START
                                    SELECT @n_AllocatedHoldQty = ISNULL(SUM(p.Qty),0)   
                                    FROM PICKDETAIL AS p WITH(NOLOCK)   
                                    JOIN LOC AS L WITH (NOLOCK) ON p.LOC = L.LOC AND L.LocationFlag IN ('HOLD','DAMAGE')   
                                    JOIN ChannelInv AS ci WITH(NOLOCK) ON ci.Channel_ID = p.Channel_ID   
                                    WHERE ci.Channel_ID = @n_Channel_ID  
                                    AND p.[Status] <> '9'   
                                    AND p.Storerkey = @c_aStorerKey  
                                    AND p.Sku = @c_aSKU  
                                    AND p.LOT = @c_aLOT  
                                    AND p.Channel_ID = @n_Channel_ID               
                                    (Wan05) - END */
                                         
                                    SELECT @n_Channel_Qty_Available = ci.Qty - (ci.QtyAllocated - @n_AllocatedHoldQty) - ci.QtyOnHold - @n_ChannelHoldQty --NJOW16
                                    FROM ChannelInv AS ci WITH(NOLOCK)  
                                    WHERE ci.Channel_ID = @n_Channel_ID  
                                    IF @n_Channel_Qty_Available < @n_cQtyAvailable  
                                    BEGIN   
                                         IF @c_UCCAllocation = '1' AND ISNULL(@c_UCCNo,'') <> '' AND @c_aUOM = '2' --NJOW19  not to take partial UCC 
                                            SET @n_cQtyAvailable = 0 
                                         ELSE                                          
                                          SET @n_cQtyAvailable = @n_Channel_Qty_Available     
                                    END                 
                                 END   
                                 ELSE IF ISNULL(RTRIM(@c_Channel), '') <> ''   
                                    SET @n_cQtyAvailable = 0  
                              END   
                           END  
                           -- End (SWT01)                                
                        END  
                        --(Wan03) - END  
  
                        IF (@b_debug = 1 OR @b_debug = 2)    
                        BEGIN  
                           PRINT '     Qty Available: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))  
                           PRINT '     FacLotAvailQty: ' + CAST(@n_FacLotAvailQty AS NVARCHAR(10))  
                           PRINT '     LOT Qty: ' +  CAST(@n_LotAvailableQty AS NVARCHAR(10))  
                           PRINT '     Facility: ' + @c_AFacility  
                        END  
                                                  
                        IF @n_cQtyAvailable <= 0   
                           GOTO FETCH_NEXT   
                                
                        --NJOW04  
                        IF ISNULL(@c_AllocateGetCasecntFrLottable,'')   
                           IN ('01','02','03','06','07','08','09','10','11','12') AND @c_aUOM = '2'  
                           AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1' --if skip preallocation need to get casecnt from each retun lot  
                        BEGIN          
                            SET @c_CaseQty = ''  
                            SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +             
                                ' FROM LOTATTRIBUTE(NOLOCK) ' +  
                                ' WHERE LOT = @c_aLot '  
               
                             EXEC sp_executesql @c_SQL,  
                             N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_aLot NVARCHAR(10)',   
                             @c_CaseQty OUTPUT,  
                             @c_alot      
                               
                             IF ISNUMERIC(@c_CaseQty) = 1  
                             BEGIN  
                                SELECT @n_CaseQty = CAST(@c_CaseQty AS INT)  
                                SELECT @n_cPackQty = @n_CaseQty  
                             END         
                        END              
                          
                        --NJOW09  
                        --IF LEFT(@c_LocType,4) = 'UOM=' AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1'    
                        IF ISNUMERIC(@c_DYNUOMQty) = 1 AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  --NJOW20
                        BEGIN  
                           IF ISNUMERIC(SUBSTRING(@c_LocType,5,10)) = 1  
                           BEGIN                              
                              --SET @n_dynUOMQty = CAST(SUBSTRING(@c_LocType,5,10) AS INT)  
                              SET @n_dynUOMQty = CAST(@c_DYNUOMQty AS INT)  --NJOW20
                                
                              IF @c_aUOM = '1'  
                                 SET @n_palletqty = @n_dynUOMQty  
                              IF @c_aUOM = '2'  
                                 SET @n_caseqty = @n_dynUOMQty  
                              IF @c_aUOM = '3'  
                                 SET @n_innerpackqty = @n_dynUOMQty  
                              IF @c_aUOM = '4'  
                                 SET @n_otherunit1 = @n_dynUOMQty  
                              IF @c_aUOM = '5'  
                                 SET @n_otherunit2 = @n_dynUOMQty                         
                                
                              SET @n_cPackQty = @n_dynUOMQty  
                          END            
                        END  

                        --NJOW13  
                        IF @c_UCCAllocation = '1' AND @c_aUOM = '2'  
                        BEGIN  
                             SELECT @n_CaseQty = @n_cQtyAvailable  --set caseqty as UCC qty  
                             SELECT @n_cPackQty = @n_CaseQty                             
                        END

                        IF @c_FullPallet = 'Y' AND @c_aUOM = '1' --NJOW06 Start  --NJOW20
                        BEGIN                             
                           SELECT @n_UOMQty = 1  
                              
                           IF @n_cQtyAvailable >= @n_aQtyLeftToFulfill  
                           BEGIN  
                              SELECT @n_QtyToTake = @n_aQtyLeftToFulfill  
                           END  
                           ELSE  
                           BEGIN  
                              SELECT @n_QtyToTake = @n_cQtyAvailable   
                           END  
  
                           IF @b_debug = 1 OR @b_debug = 2  
                           BEGIN  
                              PRINT 'FULLPALLET WITH UOM 1'                                 
                           END  
                           --NJOW06 End  
                        END  
                        ELSE  
                        BEGIN                        
                           IF @n_cPackQty > 0  
                              SELECT @n_Available = Floor(@n_cQtyAvailable/@n_cPackQty) * @n_cPackQty  
                           ELSE  
                              SELECT @n_Available = 0  
               
                           IF @n_Available >= @n_aQtyLeftToFulfill  
                           BEGIN  
                              SELECT @n_QtyToTake = @n_aQtyLeftToFulfill  
                           END  
                           ELSE  
                           BEGIN  
                              SELECT @n_QtyToTake = @n_Available  
                           END  
                             
                           IF @n_cPackQty > 0  
                           BEGIN  
                              SELECT @n_UOMQty = floor(@n_QtyToTake / @n_cPackQty)  --meng  
                              SELECT @n_QtyToTake = FLOOR(@n_QtyToTake / @n_cPackQty) * @n_cPackQty --NJOW10  
                           END    
                           ELSE  
                              SELECT @n_UOMQty = 0  
                        END  
  
                        IF @b_debug = 1 or @b_debug = 2  
                      BEGIN  
                           PRINT '     Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))  
                        END  
  
                        IF @n_QtyToTake > 0  
                        BEGIN  
                            --NJOW05  
                           IF --(ISNULL(@c_SkipPreAllocationFlag,'0') = '1') AND  
                              (ISNULL(RTRIM(@c_sLocationTypeOverride),'') <>'') AND  
                              (@c_AllowOverAllocations = '1')  
                           BEGIN  
                              --SET @n_cPackQty = @n_QtyToTake  
                              SET @n_NextQtyLeftToFulfill = @n_aQtyLeftToFulfill - @n_QtyToTake  
                              SET @n_aQtyLeftToFulfill = @n_QtyToTake  
  
                              SELECT @n_JumpSource = 3  
                              GOTO OVERALLOCATE_01  
                              RETURNFROMUPDATEINV_03:  
                           END  
                             
                           /* #INCLUDE <SPOP4.SQL> */  
                           IF (ISNULL(RTRIM(@c_sLocationTypeOverride),'') <>'') AND --NJOW05  
                              (@c_AllowOverAllocations = '1')  
                           BEGIN  
                                --NJOW05  
                              IF @b_OverContinue = 1  
                             BEGIN  
                                 SELECT @n_JumpSource = 1  
                                 GOTO UPDATEINV  
                          END  
                           END  
                           ELSE  
                           BEGIN  
                              SELECT @n_jumpsource = 1  
                              GOTO UPDATEINV  
                           END  
                             
                           RETURNFROMUPDATEINV_01:  
                             
                           --NJOW05  
                           IF --(ISNULL(@c_SkipPreAllocationFlag,'0') = '1') AND  
                              (ISNULL(RTRIM(@c_sLocationTypeOverride),'') <>'') AND  
                              (@c_AllowOverAllocations = '1')  
                           BEGIN  
                              IF @b_OverContinue = 0 AND @n_aQtyLeftToFulfill > 0     
                                 SET @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill + @n_NextQtyLeftToFulfill    
                              ELSE  
                                 SET @n_aQtyLeftToFulfill = @n_NextQtyLeftToFulfill  
                           END                                                        
                        END  
                        FETCH_NEXT:   
                        
                        SET @c_PrevUCCNo = @c_UCCNo --NJOW013                            
                        SET @c_aPrevLot = @c_aLot --NJOW11                          
                     END -- fetch status = 0                       
                  END -- WHILE @n_aQtyLeftToFulfill > 0  
               END -- (@n_continue = 1 or @n_continue = 2) AND @n_cursorcandidates_open = 1  
               IF @n_cursorcandidates_open = 1  
               BEGIN  
                  CLOSE CURSOR_CANDIDATES  
                  DEALLOCATE CURSOR_CANDIDATES  
               END  
            END -- (@c_sLocationTypeOverride IS NULL) OR (@c_AllowOverAllocations = '0')  
            ELSE  
            BEGIN  
               SET @n_QtyToTake = 0                                                 --(Wan09)

               OVERALLOCATE_01:  --NJOW05  
               SELECT @b_overcontinue = 1  
               IF @b_overcontinue = 1  
               BEGIN 
                  --WL01 Start
                  SELECT @b_success = 0    
                  EXECUTE nspGetRight @c_afacility,  -- facility    
                  @c_aStorerKey,   -- StorerKey    
                  @c_aSKU,         -- Sku    
                  'OverAllocPickByHostWHCode',  -- Configkey    
                  @b_success    OUTPUT,    
                  @c_OverAllocPickByHostWHCode  OUTPUT,    
                  @n_err        OUTPUT,    
                  @c_errmsg     OUTPUT  
                    
                  IF @b_success <> 1    
                  BEGIN    
                     SELECT @n_continue = 3, @c_errmsg = 'nsporderprocessing' + dbo.fnc_RTrim(@c_errmsg)    
                  END    
                  --WL01 End
                   
                  -- DELETE #OP_OVERPICKLOCS  
                  -- DELETE #OP_PICKLOCTYPE  
  
                  -- Modify by SHONG for Performance Tuning  
                  -- 03-07-2002  
                  -- Use truncate instead of delete, faster  
                  TRUNCATE TABLE #OP_OVERPICKLOCS  
                  TRUNCATE TABLE #OP_PICKLOCTYPE  
                  -- END  
                  
                  SET @c_OverPickLoc = ''                                           --(Wan10) 
                  --NJOW15 S
                  IF ISNULL(@c_OverAllocPickLoc_SP,'') <> ''
                  BEGIN
                      IF ISNULL(@c_SkipPreAllocationFlag,'0') = '0'                     --(Wan09) - START  
                      BEGIN
                        SET @n_OverAlQtyLeftToFulfill = @n_aQtyLeftToFulfill
                        SET @n_QtyToTake = @n_aQtyLeftToFulfill
                      END
                      ELSE                                                              --(Wan09) - END
                        SET @n_OverAlQtyLeftToFulfill = @n_NextQtyLeftToFulfill + @n_QtyToTake
 
                     SET @c_SQL = N'
                     INSERT INTO #OP_PICKLOCTYPE        
                     EXEC ' + RTRIM(@c_overAllocPickLoc_sp) + ' @c_Storerkey=@c_aStorerkey, @c_Sku=@c_aSku, @c_AllocateStrategykey=@c_aAllocateStrategykey, @c_AllocateStrategyLineNumber=@c_aAllocateStrategyLineNumber,   
                                                       @c_LocationTypeOverride=@c_aLocationTypeOverride, @c_LocationTypeOverridestripe=@c_aLocationTypeOverridestripe, @c_Facility=@c_aFacility, @c_HostWHCode=@c_aHostWHCode,   
                                                       @c_Orderkey=@c_aOrderkey,  @c_Loadkey=@c_aLoadkey, @c_Wavekey=@c_aWavekey, @c_Lot=@c_aLot, @c_Loc=@c_aLoc, @c_ID=@c_aID, @c_UOM=@c_aUOM, @n_QtyToTake=@n_aQtyToTake,  
                                                       @n_QtyLeftToFulfill=@n_aQtyLeftToFulfill, @c_CallSource=@c_aCallSource, @b_success=@b_asuccess OUTPUT, @n_err=@n_aerr OUTPUT, @c_errmsg=@c_aerrmsg OUTPUT '
     
                     SET @CUR_AddSQL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      --(Wan11) - START
                     SELECT P.name                                                  --(Wan10) - START
                     FROM sys.parameters AS p    
                     JOIN sys.types AS t ON t.user_type_id = p.user_type_id    
                     WHERE object_id = OBJECT_ID(@c_overAllocPickLoc_sp)    
                     AND   P.name IN ('@c_OverPickLoc', '@n_OverQtyLeftToFulfill')  --(Wan10) - END
                     ORDER BY P.parameter_id
                     OPEN @CUR_AddSQL
                     FETCH NEXT FROM @CUR_AddSQL INTO @c_ParameterName
                     WHILE @@FETCH_STATUS = 0 
                     BEGIN 
                        IF @c_ParameterName = '@c_OverPickLoc'
                           SET @c_SQL = @c_SQL + N', @c_OverPickLoc=@c_OverPickLoc OUTPUT'
                        IF @c_ParameterName = '@n_OverQtyLeftToFulfill'
                           SET @c_SQL = @c_SQL + N', @n_OverQtyLeftToFulfill=@n_OverAlQtyLeftToFulfill OUTPUT'

                        FETCH NEXT FROM @CUR_AddSQL INTO @c_ParameterName
                     END
                     CLOSE @CUR_AddSQL
                     DEALLOCATE @CUR_AddSQL                                          --(Wan11) - END

                     EXEC SP_EXECUTESQL @c_SQL, N'@c_aStorerkey NVARCHAR(15), @c_aSku NVARCHAR(20), @c_aAllocateStrategykey NVARCHAR(10), @c_aAllocateStrategyLineNumber NVARCHAR(5), @c_aLocationTypeOverride NVARCHAR(10), 
                     @c_aLocationTypeOverridestripe NVARCHAR(10), @c_aFacility NVARCHAR(5), @c_aHostWHCode NVARCHAR(10), @c_aOrderkey NVARCHAR(10), @c_aLoadkey NVARCHAR(10), @c_aWavekey NVARCHAR(10), @c_aLot NVARCHAR(10),  
                     @c_aLoc NVARCHAR(10), @c_aID NVARCHAR(18), @c_aUOM NVARCHAR(10), @n_aQtyToTake INT, @n_aQtyLeftToFulfill INT, @c_aCallSource NVARCHAR(20), @b_asuccess INT OUTPUT, @n_aerr INT OUTPUT, @c_aErrMsg NVARCHAR(250) OUTPUT
                    ,@c_OverPickLoc NVARCHAR(10) OUTPUT, @n_OverAlQtyLeftToFulfill INT OUTPUT',      --(Wan10)--(Wan11)
                     @c_aStorerkey,
                     @c_aSku, 
                     @c_aStrategykey,
                     @c_sCurrentLineNumber,
                     @c_sLocationTypeOverride, 
                     @c_sLocationTypeOverridestripe,
                     @c_aFacility, 
                     @c_HostWHCode,                               
                     @c_Orderkey,
                     '', --@c_Loadkey
                     '', --@c_Wavekey
                     @c_aLot,
                     @c_cLoc,
                     @c_cID, 
                     @c_aUOM, 
                     @n_QtyToTake, 
                     @n_OverAlQtyLeftToFulfill,
                     @c_CallSource,  --WAVEORDER, LOADORDER, ORDER          
                     @b_success OUTPUT,      
                     @n_err     OUTPUT,      
                     @c_errmsg  OUTPUT
                  ,  @c_OverPickLoc OUTPUT                                          --(Wan10
                  ,  @n_OverAlQtyLeftToFulfill OUTPUT                               --(Wan11)

                     IF @n_OverAlQtyLeftToFulfill < @n_aQtyLeftToFulfill            --(Wan11)-START
                     BEGIN                                           
                        SET @n_aQtyLeftToFulfill = @n_OverAlQtyLeftToFulfill           
                     END                                                            --(Wan11)-END
                     SELECT @n_cnt = COUNT(1) FROM #OP_PICKLOCTYPE
                    
                  END --NJOW15 E  
                  --(Wan08) - Fixed - 2020-05-21 By Wan - START                   
                  --ELSE
                  --BEGIN                  
                  --   INSERT INTO #OP_PICKLOCTYPE (LOC)   
                  --   SELECT SKUXLOC.LOC  
                  --     FROM SKUxLOC (nolock) join LOC (nolock)  
                  --         on SKUXLOC.loc = LOC.loc  
                  --    WHERE SKUxLOC.STORERKEY = @c_aStorerKey  
                  --      AND SKUxLOC.SKU = @c_aSKU  
                  --      AND SKUxLOC.LOCATIONTYPE = @c_sLocationTypeOverride  
                  --      AND LOC.facility = @c_AFacility     -- SOS 10104 - wally - 5mar03 - to consider facility  
                  --      AND ISNULL(LOC.HostWHCode,'') = CASE WHEN @c_OverAllocPickByHostWHCode = '1' THEN @c_HostWHCode ELSE ISNULL(LOC.HostWHCode,'') END  --WL01 NJOW14
                     
                  --   SELECT @n_cnt = @@ROWCOUNT, @n_err = @@ERROR  
                  --END
                  ELSE IF @c_OverAllocPickByHostWHCode = '1'
                  BEGIN
                     INSERT INTO #OP_PICKLOCTYPE (LOC)   
                     SELECT SKUXLOC.LOC  
                       FROM SKUxLOC (nolock) join LOC (nolock)  
                           on SKUXLOC.loc = LOC.loc  
                     WHERE SKUxLOC.STORERKEY = @c_aStorerKey  
                        AND SKUxLOC.SKU = @c_aSKU  
                        AND SKUxLOC.LOCATIONTYPE = @c_sLocationTypeOverride  
                        AND LOC.facility = @c_AFacility     -- SOS 10104 - wally - 5mar03 - to consider facility 
                        AND LOC.HostWHCode = @c_HostWHCode 

                     SELECT @n_cnt = @@ROWCOUNT, @n_err = @@ERROR                    --(Wan10)
                  END
                  ELSE
                  BEGIN
                     INSERT INTO #OP_PICKLOCTYPE (LOC)   
                     SELECT SKUXLOC.LOC  
                       FROM SKUxLOC (nolock) join LOC (nolock)  
                           on SKUXLOC.loc = LOC.loc  
                      WHERE SKUxLOC.STORERKEY = @c_aStorerKey  
                        AND SKUxLOC.SKU = @c_aSKU  
                        AND SKUxLOC.LOCATIONTYPE = @c_sLocationTypeOverride  
                        AND LOC.facility = @c_AFacility     -- SOS 10104 - wally - 5mar03 - to consider facility 
                     SELECT @n_cnt = @@ROWCOUNT, @n_err = @@ERROR                    --(Wan10)
                  END
                  --(Wan08) - Fixed - 2020-05-21 By Wan - END
                  
                  --SELECT @n_cnt = @@ROWCOUNT, @n_err = @@ERROR                    --(Wan10)

                  IF @n_cnt = 0 or @n_err <> 0  
                  BEGIN  
                     SELECT @b_overcontinue = 0  
                       
                     IF @n_JumpSource = 3 --NJOW05  
                        GOTO RETURNFROMUPDATEINV_03  
                  END  
                  ELSE  
                  BEGIN  
                     -- commented out due to performance problem  
                     /*  
                     INSERT LOTxLOCxID (StorerKey, Sku, Lot, Loc, Id, Qty)  
                     SELECT @c_aStorerKey, @c_aSKU, @c_aLOT, Loc, '', 0  
                     FROM #OP_PickLocType  
                     WHERE not exists ( SELECT * FROM LOTxLOCxID (NOLOCK)  
                     WHERE StorerKey = @c_aStorerKey  
                     AND SKU = @c_aSKU  
                     AND Lot = @c_aLOT  
                     AND Loc = #OP_PickLocType.Loc )  
                     */  
                     -- equivalent statement with minimal performance issue  
                     -- WALLY 30apr02  
  
                     -- SOS# 213668 (Start)  
                     -- IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK) join #OP_PickLocType  
                     --                on lotxlocxid.loc = #op_pickloctype.loc  
                     --    WHERE StorerKey = @c_aStorerKey  
                     --                   AND SKU = @c_aSKU  
                     --                   AND Lot = @c_aLOT)  
                     --             --    AND Loc = #OP_PickLocType.Loc)  
                     -- BEGIN  
                     --    INSERT LOTxLOCxID (StorerKey, Sku, Lot, Loc, Id, Qty)  
                     --    SELECT @c_aStorerKey, @c_aSKU, @c_aLOT, Loc, '', 0  
                     --      FROM #OP_PickLocType  
                     -- END  
  
                     IF EXISTS (SELECT 1 FROM #OP_PickLocType PL   
                                LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK)  
                                       ON  LOTxLOCxID.loc = PL.loc  
                                       AND StorerKey = @c_aStorerKey  
                                       AND SKU = @c_aSKU  
                                       AND Lot = @c_aLOT  
                                WHERE LOTxLOCxID.LOC IS NULL)  
                     BEGIN  
                        INSERT LOTxLOCxID (StorerKey, Sku, Lot, Loc, Id, Qty)  
                        SELECT @c_aStorerKey, @c_aSKU, @c_aLOT, #OP_PickLocType.Loc, '', 0  
                          FROM #OP_PickLocType  
                        LEFT OUTER JOIN LOTxLOCxID WITH (NOLOCK)  
                                       ON  LOTxLOCxID.loc = #op_pickloctype.loc  
                                       AND LOTxLOCxID.StorerKey = @c_aStorerKey  
                                       AND LOTxLOCxID.SKU = @c_aSKU  
                                       AND LOTxLOCxID.Lot = @c_aLOT  
                                WHERE ISNULL(RTRIM(LOTxLOCxID.LOC),'') = ''  
                     END  
                     -- SOS# 213668 (End)  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SELECT @b_overcontinue = 0  
                     END  
                  END -- @n_cnt <> 0 or @n_err = 0  
  
                  IF @b_overcontinue = 1  
                  BEGIN  
                     SELECT @c_pickLoc = ""  
                     IF @c_sLocationTypeOverridestripe = "1"  
                     BEGIN  
                          --IF @c_PickOverAllocateNoMixLot >= "1" --NJOW02  
                          --BEGIN  
                        IF EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit(',',@c_PickOverAllocateNoMixLot)  
                                    WHERE ColValue IN ('01','02','03','04','05','06','07','08','09','10','11','12','13','14','15'))  
                        BEGIN    
                            --NJOW02  
                           --Search pick loc with similar lottable        
                               SET @c_SQL = N'SELECT @c_PickLoc = PL.Loc ' +           
                                   ' FROM #OP_PickLocType PL ' +  
                                 ' JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC ' +  
                                 ' AND (LLI.Qty - LLI.QtyPicked > 0 OR (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty > 0) '  +  
                                 ' JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot ' +  
                                 ' JOIN LOTATTRIBUTE LA2 (NOLOCK) ON LA2.Lot = @c_aLOT ' +  
                                        CASE WHEN CHARINDEX('01',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable01 = LA2.Lottable01 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('02',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable02 = LA2.Lottable02 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('03',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable03 = LA2.Lottable03 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('04',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND ISNULL(LA.Lottable04,'''') = ISNULL(LA2.Lottable04,'''') ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('05',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND ISNULL(LA.Lottable05,'''') = ISNULL(LA2.Lottable05,'''') ' ELSE ' ' END +  
                                      CASE WHEN CHARINDEX('06',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable06 = LA2.Lottable06 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('07',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable07 = LA2.Lottable07 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('08',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable08 = LA2.Lottable08 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('09',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable09 = LA2.Lottable09 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('10',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable10 = LA2.Lottable10 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('11',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable11 = LA2.Lottable11 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('12',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND LA.Lottable12 = LA2.Lottable12 ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('13',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND ISNULL(LA.Lottable13,'''') = ISNULL(LA2.Lottable13,'''') ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('14',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND ISNULL(LA.Lottable14,'''') = ISNULL(LA2.Lottable14,'''') ' ELSE ' ' END +  
                                        CASE WHEN CHARINDEX('15',@c_PickOverAllocateNoMixLot) > 0 THEN ' AND ISNULL(LA.Lottable15,'''') = ISNULL(LA2.Lottable15,'''') ' ELSE ' ' END +  
                                 ' ORDER BY LLI.Qty DESC, PL.Loc '                                                                 
                             
                             EXEC sp_executesql @c_SQL,  
                                N'@c_PickLoc NVARCHAR(10) OUTPUT, @c_aLot NVARCHAR(10)',   
                                @c_PickLoc OUTPUT,  
                                @c_alot                                     
                              
                            /*  
                            IF @c_PickOverAllocateNoMixLot = "4"  
                            BEGIN  
                              SELECT TOP 1 @c_pickloc = PL.LOC  
                              FROM #OP_PickLocType PL  
                              JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC   
                              AND (LLI.Qty - LLI.QtyPicked > 0 OR (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty > 0)  
                              JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot  
                              JOIN LOTATTRIBUTE LA2 (NOLOCK) ON LA2.Lot = @c_aLOT AND LA.Lottable04 = LA2.Lottable04  
                              ORDER BY LLI.Qty DESC, PL.Loc  
                           END  
                           */                            
                              
                            -- Search pick loc with similar lot with qty or overallocated  
                           IF ISNULL(@c_pickloc,'') = ''  
                           BEGIN                            
                              SELECT TOP 1 @c_pickloc = PL.LOC  
                              FROM #OP_PickLocType PL  
                              JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC AND LLI.LOT = @c_aLOT  
                                    AND (LLI.Qty - LLI.QtyPicked > 0 OR (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty > 0)  
                              ORDER BY LLI.Qty DESC, PL.Loc  
                           END  
                             
                           -- search empty pick loc without qty or overallocated  
                           IF ISNULL(@c_pickloc,'') = ''  
                           BEGIN  
                              SELECT TOP 1 @c_pickloc = PL.LOC  
                              FROM #OP_PickLocType PL  
                              JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC  
                              GROUP BY PL.Loc  
                              HAVING (SUM(LLI.Qty - LLI.QtyPicked) = 0 AND SUM((LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty) = 0)  
                              ORDER BY PL.Loc  
                           END  
                             
                           -- no pick location available. proceed to next pickcode (can allocate from bulk)  
                           IF ISNULL(@c_pickloc,'') = ''  
                              SELECT @b_overcontinue = 0                            
                          END                            
                          ELSE  
                          BEGIN                         
                            /* -- SOS#129426 Start  
                           SELECT @c_pickloc = LOC  
                             FROM #OP_PickLocType  
                            WHERE LOC NOT IN (SELECT LOC FROM #OP_PICKLOCS  
                                               WHERE STORERKEY = @c_aStorerKey  
                                                 AND SKU = @c_aSKU  
                                                 AND LocationType = @c_sLocationTypeOverride)  
                           ORDER BY Loc  
                           */  
                           SELECT TOP 1 @c_pickloc = PL.LOC  
                             FROM #OP_PickLocType PL  
                             LEFT OUTER JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC AND LLI.LOT = @c_aLOT  
                                  AND LLI.Qty > 0  
                            WHERE PL.LOC NOT IN (SELECT LOC FROM #OP_PICKLOCS  
                                               WHERE STORERKEY = @c_aStorerKey  
                                                 AND SKU = @c_aSKU  
                                                 AND LocationType = @c_sLocationTypeOverride)  
                           ORDER BY LLI.Qty DESC, PL.Loc  
                           -- SOS#129426 END  
  
                           IF dbo.fnc_LTrim(@c_pickLoc) is Null  
                           BEGIN  
                              DELETE FROM #OP_PICKLOCS  
                               WHERE STORERKEY = @c_aStorerKey  
                                 AND SKU = @c_aSKU  
                                 AND LocationType = @c_sLocationTypeOverride  
                             
                              SELECT TOP 1 @c_pickloc = LOC  
                              FROM #OP_PickLocType  
                              ORDER BY LOC  
                           END  
                             
                           INSERT #OP_PICKLOCS (StorerKey, Sku, Loc, LocationType)  
                           VALUES ( @c_aStorerKey, @c_aSKU, @c_pickloc, @c_sLocationTypeOverride )         
                        END  
                     END  
                     ELSE  
                     BEGIN
                        SELECT TOP 1 @c_pickloc = LOC  
                           FROM #OP_PickLocType  
                        ORDER BY LOC  

                        IF @c_OverPickLoc <> ''                                     --(Wan10) - START
                        BEGIN
                           SET @c_pickloc = @c_OverPickLoc
                        END                                                         --(Wan10) - END    
                     END   
                  END  
  
                  INSERT #OP_OVERPICKLOCS (Loc, Id, QtyAvailable)  
                  SELECT LOTXLOCXID.LOC, LOTXLOCXID.ID,  
                         Floor((LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked)/@n_cPackQty)*@n_cPackQty  
                    FROM LOTXLOCXID (NOLOCK)  
                    JOIN #OP_PickLocType PLT ON LOTXLOCXID.Loc = PLT.Loc  
                   WHERE LOTXLOCXID.STORERKEY = @c_aStorerKey  
                     AND LOTXLOCXID.Sku = @c_aSKU  
                     AND LOTXLOCXID.Lot = @c_aLOT   
                     AND ( Floor((LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked)/@n_cPackQty) > 0  
                     OR  LOTXLOCXID.Loc = @c_pickloc )  
                  ORDER BY CASE when PLT.Loc = @c_pickloc  
                                then 1 ELSE 2 END, 1, 2  
  
                  IF @@ROWCOUNT = 0  
                  BEGIN  
                     SELECT @b_overcontinue = 0  
                  END  
                  ELSE IF @b_debug = 1 or @b_debug = 2  
                  BEGIN  
                     PRINT ''  
                     PRINT '**** Over Allocation - Pick Location ****'  
                  END  
                  IF @b_overcontinue = 1  
                  BEGIN  
                     SELECT @n_qtytoovertake = Sum(CASE when OPL.QtyAvailable > 0  
                                                      then OPL.QtyAvailable ELSE 0 END )  
                     FROM #OP_OVERPICKLOCS OPL   
                     IF @n_aQtyLeftToFulfill <= @n_qtytoovertake  
                     BEGIN  
                        SELECT @n_qtytoovertake = 0  
                     END  
                     ELSE  
                     BEGIN  
                        SELECT @n_qtytoovertake = @n_aQtyLeftToFulfill - @n_qtytoovertake  
                     END  
  
                     SELECT @n_rownum = 0  
                     WHILE @n_aQtyLeftToFulfill > 0  
                     BEGIN  
                        SELECT TOP 1 @n_rownum = RowNum, @c_cloc = LOC, @c_cid = Id,  
                              @n_QtyToTake = CASE when QtyAvailable > 0  
                                                   then QtyAvailable ELSE 0 END  
                          FROM #OP_OVERPICKLOCS  
                         WHERE Rownum >  @n_rownum  
                        ORDER BY Rownum  
  
                        IF @@ROWCOUNT = 0  
                        BEGIN  
                           BREAK  
                        END  
  
                        IF @c_cloc = @c_pickloc  
                        BEGIN  
                           SELECT @n_QtyToTake = @n_QtyToTake + @n_qtytoovertake  
                           SELECT @n_qtytoovertake = 0  
                        END  
                        IF @n_aQtyLeftToFulfill < @n_QtyToTake  
                        BEGIN  
                           SELECT @n_QtyToTake = @n_aQtyLeftToFulfill  
                        END  
                        SELECT @n_UOMQty = @n_QtyToTake / @n_cPackQty  
  
                        IF @b_debug = 1 or @b_debug = 2  
                        BEGIN  
                           PRINT '     Location: ' + RTRIM(@c_cLOC) + ' Pallet ID: ' + @c_cid  
                           PRINT '     Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))  
                           PRINT '     Qty Left: ' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))  
                        END  
                        IF @n_QtyToTake > 0  
                        BEGIN  
                           IF @n_JumpSource = 3 --NJOW05  
                              GOTO RETURNFROMUPDATEINV_03  
                             
                           SELECT @n_jumpsource = 2  
                           GOTO UPDATEINV  
                           RETURNFROMUPDATEINV_02:  
                        END  
                     END  
                  /* #INCLUDE <SPOP5.SQL> */  
                  END -- END of doing a job  
               END  -- END of OVERALLOCATION  
            END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sLocationTypeOverride)) IS NULL  
         END -- LOOP ALLOCATE STRATEGY DETAIL Lines  
  
         TRYIFQTYREMAIN:  
         IF @b_TryIfQtyRemain = 1 and @n_aQtyLeftToFulfill > 0 and @n_NumberOfRetries < 7  
         BEGIN  
            IF @n_NumberOfRetries  = 0  
            BEGIN  
               SELECT @n_palletqty = Pallet, @c_cartonizePallet = CartonizeUOM4,  
                     @n_caseqty = CaseCnt, @c_cartonizeCase = CartonizeUOM1,  
                     @n_innerpackQty = innerpack, @c_cartonizeInner = CartonizeUOM2,  
                     @n_otherunit1 = CONVERT(Int,OtherUnit1), @c_cartonizeOther1 = CartonizeUOM8,  
                     @n_otherUnit2 = CONVERT(Int,Otherunit2), @c_cartonizeOther2 = CartonizeUOM9,  
                     @c_cartonizeEA = CartonizeUOM3  
               FROM PACK (nolock)  
               WHERE PACKKEY = @c_aPackKey  
            END  
  
            SELECT @n_NumberOfRetries = @n_NumberOfRetries + 1  
            SELECT @c_aUOM = dbo.fnc_LTrim(dbo.fnc_RTrim(Convert(Char(5), (Convert(Int,@c_aUOM) + 1))))  
  
            --NJOW04  
            IF ISNULL(@c_AllocateGetCasecntFrLottable,'')   
               IN ('01','02','03','06','07','08','09','10','11','12') AND @c_aUOM = '2'  
               AND ISNULL(@c_SkipPreAllocationFlag,'0') <> '1' --if not skip preallocation need to get casecnt from lot if uom = 2 --NJOW05  
            BEGIN          
                SET @c_CaseQty = ''  
                SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +             
                    ' FROM LOTATTRIBUTE(NOLOCK) ' +  
                    ' WHERE LOT = @c_aLot '  
              
                 EXEC sp_executesql @c_SQL,  
                 N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_aLot NVARCHAR(10)',   
                 @c_CaseQty OUTPUT,  
                 @c_alot      
                   
                 IF ISNUMERIC(@c_CaseQty) = 1  
                 BEGIN  
                    SELECT @n_CaseQty = CAST(@c_CaseQty AS INT)  
                 END         
            END              
  
            SELECT @n_cPackQty =  
               CASE @c_aUOM  
                  WHEN '1' THEN @n_palletqty  
                  WHEN '2' THEN @n_caseqty  
                  WHEN '3' THEN @n_innerpackqty  
                  WHEN '4' THEN @n_otherunit1  
                  WHEN '5' THEN @n_otherunit2  
                  WHEN '6' THEN 1  
                  WHEN '7' THEN 1  
                  ELSE 0  
               END  
  
            SELECT @c_Adocartonize =  
            CASE @c_aUOM  
               WHEN '1' THEN @c_cartonizePallet  
               WHEN '2' THEN @c_cartonizeCase  
               WHEN '3' THEN @c_cartonizeInner  
               WHEN '4' THEN @c_cartonizeOther1  
               WHEN '5' THEN @c_cartonizeOther2  
               WHEN '6' THEN @c_cartonizeEA  
               WHEN '7' THEN @c_cartonizeEA  
               ELSE 'N'  
            END  
  
            IF @b_debug = 1  
            BEGIN  
               PRINT ''  
               PRINT '**** Try IF Qty Remain (ON) ****'  
               PRINT '     Retry-' + CAST(@n_NumberOfRetries AS NVARCHAR(10)) + ', UOM: ' + @c_aUOM  
                     + ' Qty Left:' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))  
                     + ' PackQty:' + CAST(@n_cPackQty AS NVARCHAR(10))  
            END  
  
            IF @n_cPackQty > 0  
            BEGIN  
               GOTO LOOPPICKSTRATEGY  
            END  
            ELSE  
            BEGIN  
               GOTO TRYIFQTYREMAIN  
            END  
         END  
  
      END -- WHILE (1 = 1)  
      CLOSE C_OPORDERLINES  
      DEALLOCATE C_OPORDERLINES  
  
      SET @d_step3 = GETDATE() - @d_step3 -- (tlting01)  
      SET @c_Col3 = 'Stp3-Allocation' -- (tlting01)  
  
   END -- of fun part  
   -- Move from below to here  
   -- END IF move  
   IF @c_docartonization = 'Y'  
   BEGIN  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN  
         DECLARE @c_cartonbatch NVARCHAR(10)  
         SELECT @b_success = 0  
         SELECT @c_cartonbatch = @c_oprun  
  
         INSERT OP_CARTONLINES ( Cartonbatch, pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,  
               loc,lot,id,caseid,uom,uomqty,qty,packkey,cartongroup,DoReplenish, replenishzone, docartonize,PickMethod )  
         ( SELECT @c_cartonbatch,pickheaderkey,pickdetailkey,orderkey,orderlinenumber,storerkey,sku,  
                  loc,lot,id,caseid,uom,uomqty,qty,packkey,cartongroup,DoReplenish, replenishzone, docartonize,PickMethod  
             FROM #OPPICKDETAIL )  
  
         IF @c_docartonization = 'Y'  
         BEGIN  
            SELECT @b_success = 0  
  
            EXECUTE nspCartonization  
                       @c_cartonbatch  
                     , @b_success OUTPUT  
                     , @n_err     OUTPUT  
                     , @c_errmsg  OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END  
      END  
  
      /***** Customised For IDS *****/  
      IF @c_oskey <> '' SELECT @c_waveoption = "NONE"  
      /***** Customised For IDS *****/  
      IF (@n_continue = 1 or @n_continue = 2) AND @c_waveoption <> "NONE"  
      BEGIN  
         SELECT @b_success = 0  
  
         EXECUTE nspOrderProcessingWave  
                    @c_cartonbatch  
                  , @c_workoskey  
                  , @b_success OUTPUT  
                  , @n_err     OUTPUT  
                  , @c_errmsg  OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
      -- Doing CartoniZation here..see whether can skip this  
      IF ( @n_continue =1 OR @n_continue =2 )  
      BEGIN  
         DECLARE @c_currentorder NVARCHAR(10)  
         WHILE (@n_continue = 1 or @n_continue = 2)  
         BEGIN  
  
            SELECT TOP 1 @c_currentorder = Orderkey  
              FROM OP_CARTONLINES  
             WHERE Cartonbatch = @c_cartonbatch  
             Order by Orderkey  
            IF @@ROWCOUNT = 0  
            BEGIN  
               BREAK  
            END  
  
            -- DS: Here was a nested loop by OrderLineNumber which was deleted to speed up the process  
            BEGIN TRANSACTION  
            IF (1=1)  
            BEGIN  
               UPDATE PICKDETAIL SET TrafficCop = Null, ArchiveCop = "9"  
                WHERE PickHeaderKey = 'N'+@c_oprun  
                  AND ORDERKEY = @c_currentorder  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+  
                              ": Update to pickdetail table failed.  Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)" +   
                              " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
  
  
  
               END  
               IF @n_continue = 1 or @n_continue = 2  
               BEGIN  
                  DELETE FROM PICKDETAIL WHERE PickHeaderKey = 'N'+@c_oprun  
                     AND ORDERKEY = @c_currentorder  
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63523   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+  
                              ": Delete From live pickdetail table failed.  Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)" +   
                              " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
                  END  
               END  
            END  
            IF @n_continue = 1 or @n_continue = 2  
            BEGIN  
               IF (1=1)  
               BEGIN  
                  INSERT PICKDETAIL ( PickDetailKey, Caseid, PickHeaderkey, OrderKey, OrderLineNumber, Lot,Storerkey,  
                     Sku,PackKey,UOM,UOMQty,Qty,Loc,ID,Cartongroup,Cartontype,DoReplenish, replenishzone, docartonize,Trafficcop,OptimizeCop,  
                     PickMethod)   
                     (SELECT PickDetailKey,Caseid,PickHeaderkey,OrderKey,OrderLineNumber,Lot,Storerkey,  
                     Sku,PackKey,UOM,UOMQty,Qty,Loc,ID,CartonGroup,Cartontype,DoReplenish, replenishzone, docartonize,"U", "9",PickMethod     
                     FROM OP_CARTONLINES WITH (NOLOCK)   
                    WHERE Cartonbatch = @c_cartonbatch  
                      AND ORDERKEY = @c_currentorder  
                     )  
                  ---only applicable for cartonization but this function will not be used, so temporary remove the channel_id update to pickdetail for this case    
                  /*INSERT PICKDETAIL ( PickDetailKey, Caseid, PickHeaderkey, OrderKey, OrderLineNumber, Lot,Storerkey,  
                     Sku,PackKey,UOM,UOMQty,Qty,Loc,ID,Cartongroup,Cartontype,DoReplenish, replenishzone, docartonize,Trafficcop,OptimizeCop,  
                     PickMethod, Channel_ID)  
                  (SELECT PickDetailKey,Caseid,PickHeaderkey,OrderKey,OrderLineNumber,Lot,Storerkey,  
                     Sku,PackKey,UOM,UOMQty,Qty,Loc,ID,CartonGroup,Cartontype,DoReplenish, replenishzone, docartonize,"U", "9",PickMethod, Channel_ID    
                     FROM OP_CARTONLINES WITH (NOLOCK)   
                    WHERE Cartonbatch = @c_cartonbatch  
                      AND ORDERKEY = @c_currentorder  
                     )*/  
               END  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": INSERT INTO live pickdetail table failed." +   
                       " Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing) " +   
                       " (" + " SQLSvr MESSAGE=" + ISNULL(RTRIM(@c_errmsg),'') + ") "  
               END  
            END  
            IF @n_continue = 1 or @n_continue = 2  
            BEGIN  
               DELETE FROM OP_CARTONLINES  
                WHERE Cartonbatch = @c_cartonbatch  
                  AND ORDERKEY = @c_currentorder  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63525   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Delete From live op_cartonlines failed. " +   
                  " Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)" + " ( " +   
                  " (" + " SQLSvr MESSAGE=" + ISNULL(RTRIM(@c_errmsg),'') + ") "  
               END  
            END  
            IF @n_continue = 1 or @n_continue = 2  
            BEGIN  
               COMMIT TRAN  
            END  
            ELSE  
            BEGIN  
               ROLLBACK TRAN  
            END  
         END -- WHILE continue = 1 or 2  
  
      END  
   END -- IF @c_cartonization = 'Y'  
   -- END of cartonization  
  
   /* #INCLUDE <SPOP2.SQL> */  
   /* Added By SHONG - DElete PreAllocatedPickDetail IF Successfully allocated */  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OrderKey)) IS NOT NULL  
      BEGIN  
         --NJOW08  
         DECLARE cur_DeletePreAllocatePickDetailOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT   PreAllocatePickDetail.PreAllocatePickDetailKey  
         FROM     PreAllocatePickDetail WITH (NOLOCK)  
         WHERE    PreAllocatePickDetail.OrderKey = @c_orderKey   
         AND      PreAllocatePickDetail.Qty = 0  
           
         OPEN cur_DeletePreAllocatePickDetailOrd  
         FETCH NEXT FROM cur_DeletePreAllocatePickDetailOrd INTO @c_PreAllocatePickDetailKey  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            DELETE PreAllocatePickDetail   
            WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey  
              
            FETCH NEXT FROM cur_DeletePreAllocatePickDetailOrd INTO @c_PreAllocatePickDetailKey  
         END  
         CLOSE cur_DeletePreAllocatePickDetailOrd  
         DEALLOCATE cur_DeletePreAllocatePickDetailOrd  
           
          /*  
         DELETE PreAllocatePickDetail  
          WHERE  OrderKey = @c_OrderKey  
            AND    Qty = 0  
         */     
      END  
      ELSE IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey)) IS NOT NULL  
      BEGIN  
         --NJOW08  
         DECLARE cur_DeletePreAllocatePickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT   PreAllocatePickDetail.PreAllocatePickDetailKey  
         FROM     PreAllocatePickDetail WITH (NOLOCK)  
         JOIN     LoadPlanDetail WITH (NOLOCK) ON PreAllocatePickDetail.OrderKey = LoadplanDetail.OrderKey   
         WHERE    LoadplanDetail.LoadKey = @c_osKey   
         AND      PreAllocatePickDetail.Qty = 0  
           
         OPEN cur_DeletePreAllocatePickDetail  
         FETCH NEXT FROM cur_DeletePreAllocatePickDetail INTO @c_PreAllocatePickDetailKey  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            DELETE PreAllocatePickDetail  
            WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey  
              
            FETCH NEXT FROM cur_DeletePreAllocatePickDetail INTO @c_PreAllocatePickDetailKey  
         END  
         CLOSE cur_DeletePreAllocatePickDetail  
         DEALLOCATE cur_DeletePreAllocatePickDetail  
  
          /*  
         DELETE PreAllocatePickDetail  
           FROM PreAllocatePickDetail (NOLOCK), LoadPlanDetail (NOLOCK)  
         WHERE PreAllocatePickDetail.OrderKey = LoadplanDetail.OrderKey  
            AND LoadplanDetail.LoadKey = @c_oskey  
            AND PreAllocatePickDetail.Qty = 0  
         */      
      END  
   END  
   -- END of Added 31-Jan-2001  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OrderKey)) IS NOT NULL  
      BEGIN  
         UPDATE ORDERS  
            SET EditDate = GetDate(),  
                EditWho  = Suser_Sname()  
          WHERE OrderKey = @c_OrderKey  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63535   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Update Trigger On ORDERS Failed. (nsporderprocessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
         END  
      END  
      ELSE IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_oskey)) IS NOT NULL  
      BEGIN  
         -- Added by June 25.Jul.02  
         -- Do not update Orders status for Mass Allocation  
         IF @c_tblprefix = 'MAS'  
         BEGIN -- Mass Allocation  
            UPDATE ORDERS  
               SET EditDate = GetDate()  
              FROM #OPORDERLINES  
             WHERE #OPORDERLINES.Orderkey = ORDERS.Orderkey  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63536   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Update Trigger On ORDERS Failed. (nsporderprocessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            END  
  
            delete p  
            from preallocatepickdetail p join #oporderlines o  
               on p.orderkey = o.orderkey  
                  and p.orderlinenumber = o.orderlinenumber  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
          IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63537   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Update Trigger On ORDERDETAIL Failed. (nsporderprocessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
            END  
         END -- @c_tblprefix = 'MAS' - June 25.Jul.02  
         ELSE  
         BEGIN -- LoadPlan Allocation  
            DECLARE  @c_loadorderkey NVARCHAR(10),  
            @n_originalqty    Int,  
            @n_qtyallocated   Int  
  
            DECLARE order_cur CURSOR FAST_FORWARD READ_ONLY FOR  
            SELECT OrderKey  
              FROM  LoadPlanDetail (NOLOCK)  
             WHERE LoadKey = @c_oskey  
  
            OPEN order_cur  
            FETCH NEXT FROM order_cur INTO @c_loadorderkey  
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue <> 3  
            BEGIN  
               UPDATE ORDERS  
                  SET EditDate = GetDate()  
                WHERE ORDERS.OrderKey = @c_loadorderkey  
  
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 63536   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Update Trigger On ORDERS Failed. (nsporderprocessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
               END  
               FETCH NEXT FROM order_cur INTO @c_loadorderkey  
            END -- @@FETCH_STATUS  
            CLOSE order_cur  
            DEALLOCATE order_cur  
            -- Force to trigger Status update  
            UPDATE Loadplan  
               SET EditDate = GetDate(),  
                   EditWho = 'AllocateGuy'  
             WHERE LoadKey = @c_oskey  
         END -- LoadPlan Allocation  
      END -- @c_oskey IS NOT NULL  
   END -- @n_continue = 1 OR @n_continue = 2  
  
   SET @d_step4 = GETDATE()  
  
   /* Modified for IDS-PH UNILEVER to cater for the Dopping ID after Allocation based on Storer */  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DECLARE @c_svalue NVARCHAR(10)  
      DECLARE @c_prevdropstorer  NVARCHAR(15), @c_itrnkey NVARCHAR(10)  
      DECLARE @c_dropstorer NVARCHAR(15), @c_dropsku NVARCHAR(20), @c_droploc NVARCHAR(10), @c_dropid NVARCHAR(18), @n_dropqty Int  
      SELECT @c_dropstorer = 'NEW'  
      SELECT @c_prevdropstorer = 'OLD'  
  
      DECLARE DROPID_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT #OPPICKDETAIL.Storerkey, #OPPICKDETAIL.Sku, #OPPICKDETAIL.Loc  
        FROM #OPPICKDETAIL, Loc (nolock)  
       WHERE #OPPICKDETAIL.Loc = Loc.Loc  
         AND Loc.LocationType = 'DRIVEIN'  
      GROUP BY #OPPICKDETAIL.Storerkey, #OPPICKDETAIL.Sku, #OPPICKDETAIL.Loc  
  
      OPEN DROPID_CUR  
      FETCH NEXT FROM DROPID_CUR INTO @c_dropstorer, @c_dropsku, @c_droploc  
      WHILE (@@fetch_status <> -1)  
      BEGIN  
         -- SELECT Storer Setting  
         IF @c_prevdropstorer <> @c_dropstorer  
         BEGIN  
            /* IDSV5 - Leo */  
            SELECT @b_success = 0  
            EXECUTE nspGetRight null,  
                       @c_dropstorer,  
                       @c_dropsku,  
                       'DROPID AFTER ALLOCATION',      -- ConfigKey  
                       @b_success    OUTPUT,  
                       @c_authority  OUTPUT,  
                       @n_err        OUTPUT,  
                       @c_errmsg     OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3, @c_errmsg = 'nspOrderProcessing:' + dbo.fnc_RTrim(@c_errmsg)  
            END  
            ELSE IF @c_authority = '1'  
            BEGIN  
               -- Update the LOC.LoseID = '1'  
  
               UPDATE LOC SET LOSEID = '1'  
               WHERE LOC = @c_droploc  
  
               DECLARE DROPLOCID_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
               SELECT ID, SUM(QTY) FROM LOTXLOCXID (NOLOCK)  
                WHERE LOC = @c_droploc AND QTY > 0  
               GROUP BY ID  
  
               OPEN DROPLOCID_CUR  
               FETCH NEXT FROM DROPLOCID_CUR INTO @c_dropid, @n_dropqty  
  
               WHILE (@@fetch_status <> -1)  
               BEGIN  
                  -- EXECUTE ITRNADDMOVE to move the pallet in the allocated location  
  
                  IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_dropid)) > ' ' OR  @c_dropid IS NOT NULL  
                  BEGIN  
                     EXECUTE nspItrnAddMove  
                        NULL,  
                        @c_dropstorer,  
                        @c_dropsku,  
                        " ",  
                        @c_droploc,  
                        @c_dropid,  
                        @c_droploc,  
                        @c_dropid,  
                        "",  
                        "",  
                        "",  
                        "",  
                        NULL,  
                        NULL,  
                        0,  
                        0,  
                        @n_dropqty,  
                        0,  
                        0,  
                        0,  
                        0,  
                        0,  
                        0,  
                        " ",  
                        "DROPID",  
                        "STD",  
                        "EA",  
                        1,  
                        NULL,  
                        @c_itrnkey  OUTPUT,  
                        @b_Success  OUTPUT,  
                        @n_err      OUTPUT,  
                        @c_errmsg   OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue=3  
                        BREAK  
                     END  
                  END -- @c_dropid <> Null or ''  
  
                  FETCH NEXT FROM DROPLOCID_CUR INTO @c_dropid, @n_dropqty  
               END -- END While  
  
               CLOSE DROPLOCID_CUR  
               DEALLOCATE DROPLOCID_CUR  
  
               -- Update back the LOC.LoseID = '0'  
  
               UPDATE LOC SET LOSEID = '0'  
                WHERE LOC = @c_droploc  
  
               IF @n_continue = 3  
               BEGIN  
                  BREAK  
               END  
            END  
            /*  
            SELECT @c_svalue = dbo.fnc_RTrim(dbo.fnc_LTrim(SValue)) FROM STORERCONFIG (NOLOCK)  
            WHERE STORERKEY = @c_dropstorer AND CONFIGKEY = 'DROPID'  
            */  
            SELECT @c_prevdropstorer = @c_dropstorer  
         END  
         FETCH NEXT FROM DROPID_CUR INTO @c_dropstorer, @c_dropsku, @c_droploc  
      END  -- END While  
      CLOSE DROPID_CUR  
      DEALLOCATE DROPID_CUR  
   END  
   /* Modification END here */  
   SET @d_step4 = GETDATE() - @d_step4 -- (tlting01)  
   SET @c_Col4 = 'Stp4-Others' -- (tlting01)  
  
   -- TraceInfo (tlting01) - Start  
   /*  
   SET @d_endtime = GETDATE()  
   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,  
                          Step1, Step2, Step3, Step4, Step5,  
                          Col1, Col2, Col3, Col4, Col5)  
   VALUES  
(RTRIM(@c_TraceName), @d_starttime, @d_endtime  
      ,CONVERT(Char(12),@d_endtime - @d_starttime ,114)  
      ,CONVERT(Char(12),@d_step1,114)  
      ,CONVERT(Char(12),@d_step2,114)  
      ,CONVERT(Char(12),@d_step3,114)  
      ,CONVERT(Char(12),@d_step4,114)  
      ,CONVERT(Char(12),@d_step5,114)  
      ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  
  
      SET @d_step1 = NULL  
      SET @d_step2 = NULL  
      SET @d_step3 = NULL  
      SET @d_step4 = NULL  
      SET @d_step5 = NULL  
    */  
   -- TraceInfo (tlting01) - END  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspOrderProcessing"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
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
  
   UPDATEINV:  
   SELECT @b_pickupdatesuccess = 1  
   IF @b_pickupdatesuccess = 1  
   BEGIN  
      SELECT  @c_uom1pickmethod = uom1pickmethod, -- case  
               @c_uom2pickmethod = uom2pickmethod, -- innerpack  
               @c_uom3pickmethod = uom3pickmethod, -- piece  
               @c_uom4pickmethod = uom4pickmethod, -- pallet  
               @c_uom5pickmethod = uom5pickmethod, -- other 1  
               @c_uom6pickmethod = uom6pickmethod ,-- other 2  
               @c_uom7pickmethod = uom3pickmethod -- Yes,this statement is correct, UOM7 is a special case  
        FROM LOC (nolock), PUTAWAYZONE (nolock)  
       WHERE LOC.Putawayzone = PUtawayzone.Putawayzone  
         AND LOC.LOC = @c_cloc  
  
      SELECT @c_aPickMethod =  
                  CASE @c_aUOM  
                     WHEN '1' THEN @c_uom4pickmethod -- Full Pallets  
                     WHEN '2' THEN @c_uom1pickmethod -- Full Case  
                     WHEN '3' THEN @c_uom2pickmethod -- Inner  
                     WHEN '4' THEN @c_uom5pickmethod -- Other 1  
                     WHEN '5' THEN @c_uom6pickmethod -- Other 2 (uses the same pickmethod AS other1)  
                     WHEN '6' THEN @c_uom3pickmethod -- Piece  
                     WHEN '7' THEN @c_uom3pickmethod -- Piece  
                     ELSE '0'  
                  END  
  
      -- SOS # 45244, Default PickMethod to '3' IF not setup in PutawayZone  
      IF @c_aPickMethod IS NULL  
         SET @c_aPickMethod = '3'  
  
      -- SOS 10581: wally 31.mar.03  
      -- to group inner pack (uom = '3') INTO 1 pickdetail  
      IF @c_SuperFlag = 'Y'  
      BEGIN  
         IF (@c_aUOM = '6' or @c_aUOM = '7' or @c_aUOM = '2' or @c_aUOM = '3' or @c_aUOM = '4')    --(Wan07)   
         BEGIN  
            SELECT @n_QtyToInsert = @n_QtyToTake  
            SELECT @n_UOMQtyToInsert = @n_UOMQty  
         END  
         ELSE  
         BEGIN  
            IF @n_UOMQty > 0                                         --(Wan01)   
               SELECT @n_QtyToInsert = @n_QtyToTake / @n_UOMQty  
            SELECT @n_UOMQtyToInsert = 1  
         END  
      END  
      ELSE  
      BEGIN  
         IF (@c_aUOM = '6' or @c_aUOM = '7' or @c_aUOM = '2' or @c_aUOM = '3' or @c_aUOM = '4')    --(Wan07) 
         BEGIN  
            SELECT @n_QtyToInsert = @n_QtyToTake  
            SELECT @n_UOMQtyToInsert = @n_UOMQty  
         END  
         ELSE  
         BEGIN  
            IF @n_UOMQty > 0                                         --(Wan01)   
               SELECT @n_QtyToInsert = @n_QtyToTake/@n_UOMQty  
            SELECT @n_UOMQtyToInsert = 1  
         END  
      END  
  
      SELECT @n_pickrecscreated = 0  
      WHILE @n_pickrecscreated < @n_UOMQty and @b_pickupdatesuccess = 1  
      BEGIN  
         IF @b_pickupdatesuccess = 1  
         BEGIN  
            SELECT @b_success = 0  
            EXECUTE   nspg_getkey  
            "PickDetailKey"  
            , 10  
            , @c_PickDetailKey OUTPUT  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
         END  
         IF @b_success = 1  
         BEGIN  
            IF @c_ChannelInventoryMgmt = '1'  
            BEGIN  
               IF ISNULL(RTRIM(@c_Channel), '') <> ''  AND  
                  ISNULL(@n_Channel_ID,0) = 0  
               BEGIN  
                  SET @n_Channel_ID = 0  
                  
                  BEGIN TRY  
                     EXEC isp_ChannelGetID   
                         @c_StorerKey   = @c_aStorerKey  
                        ,@c_Sku         = @c_aSKU  
                        ,@c_Facility    = @c_Facility  
                        ,@c_Channel     = @c_Channel  
                        ,@c_LOT         = @c_aLOT  
                        ,@n_Channel_ID  = @n_Channel_ID OUTPUT  
                        ,@b_Success     = @b_Success OUTPUT  
                        ,@n_ErrNo       = @n_Err     OUTPUT  
                        ,@c_ErrMsg      = @c_ErrMsg  OUTPUT                  
                        ,@c_CreateIfNotExist = 'N'  
                  END TRY  
                  BEGIN CATCH  
                        SELECT @n_err = ERROR_NUMBER(),  
                               @c_ErrMsg = ERROR_MESSAGE()  
                              
                        SELECT @n_continue = 3  
                        SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspOrderProcessing)'   
                  END CATCH           
               END  
            END   
            ELSE   
            BEGIN  
               SET @n_Channel_ID = 0                 
            END  
                       
            BEGIN TRANSACTION TROUTERLOOP  
            INSERT #OPPICKDETAIL (PickDetailKey,PickHeaderKey,OrderKey,OrderLineNumber,Lot,Storerkey,Sku,  
                        Qty,Loc,Id,UOMQty, UOM, CaseID, PackKey, CartonGroup, docartonize,doreplenish,  
                        replenishzone,PickMethod, Channel_ID)  
            VALUES (@c_PickDetailKey,"",@c_Aorderkey,@c_Aorderlinenumber,  
                     @c_aLOT,@c_aStorerKey,@c_aSKU,@n_QtyToInsert,@c_cloc,@c_cid,@n_UOMQtyToInsert,  
                     @c_aUOM,"", @c_aPackKey,@c_ACartonGroup, @c_Adocartonize,'N',"",@c_aPickMethod, @n_Channel_ID)  
  
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
            IF not (@n_err = 0 AND @n_cnt = 1)  
            BEGIN  
               SELECT @b_pickupdatesuccess = 0  
            END  
            IF @b_pickupdatesuccess = 1  
            BEGIN  
               -- Added By SHONG -- @c_PHeaderKey  
               IF @c_docartonization <> 'Y'  
               BEGIN  
                  SELECT @c_PHeaderKey = ''  
                  -- Modify by SHONG 03-Dec-2001  
                  -- Task Manager (Pick) Need a case id to do a sorting  
                  -- SELECT @c_caseid = '0' + @c_oprun  
                  SELECT @c_caseid = ' '  
               END  
               ELSE  
               BEGIN  
                  SELECT @c_PHeaderKey = 'N'+@c_oprun  
                  SELECT @c_caseid = 'C'+ @c_oprun  
               END
                                            
               INSERT PICKDETAIL (PickDetailKey,PickHeaderKey,OrderKey,OrderLineNumber,  
                                  Lot,Storerkey,Sku,Qty,Loc,Id,UOMQty,  
                                  UOM, CaseID, PackKey, CartonGroup, DoReplenish, replenishzone,  
                                  docartonize,Trafficcop,PickMethod, Channel_ID, DropID) --NJOW13  
               VALUES ( @c_PickDetailKey,@c_PHeaderKey,@c_Aorderkey,@c_Aorderlinenumber,  
                         @c_aLOT,@c_aStorerKey,@c_aSKU,@n_QtyToInsert,@c_cloc,@c_cid,@n_UOMQtyToInsert,  
                         @c_aUOM, @c_caseid, @c_aPackKey,@c_ACartonGroup, 'N', "",  
                         @c_Adocartonize, "U", @c_aPickMethod, @n_Channel_ID, ISNULL(@c_UCCNo,''))  --NJOW13
  
            SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT  
            SELECT @n_cnt = COUNT(1) FROM PICKDETAIL with (NOLOCK) WHERE PICKDETAILKEY = @c_pickdetailkey  
  
            IF (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)  
            BEGIN  
               PRINT ''  
               PRINT '**** Error - INSERT Pick Detail ****'  
            END  
            IF not (@n_err = 0 AND @n_cnt = 1)  
            BEGIN  
               SELECT @b_pickupdatesuccess = 0  
            END  
            IF @b_pickupdatesuccess = 1  
            BEGIN  
               SELECT @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill - @n_QtyToInsert  
               COMMIT TRAN TROUTERLOOP  
               /***** Customised For IDS *****/  
               IF @c_SuperFlag = 'Y'  
               BEGIN  
                  UPDATE #TempBatchPick  
                     SET Qty = Qty - @n_QtyToInsert,  
                         @n_PackBalance = @n_PackBalance - (CASE WHEN @n_PackBalance = 0  
                                                                     THEN 0  
                                                                     ELSE @n_QtyToInsert  
                                                                 END)  
                   WHERE SKU = @c_aSKU  
                     AND Lot = @c_aLOT  
                     AND UOM = @c_BatchUOM  
                     AND Qty > 0  
  
               END  
  
               IF @b_debug = 1  
               BEGIN  
                  PRINT ''  
                  PRINT '**** Succeed - INSERT Pick Detail ****'  
                  PRINT '     PickDetail#: ' + RTRIM(@c_pickdetailkey) +  
                        ' Qty: ' + CAST(@n_QtyToInsert AS NVARCHAR(10))  
               END  

               --NJOW13 
               IF @c_UCCAllocation = '1' AND @c_UCCNo <> @c_PrevUCCNo AND @c_UCCNo <> ''  
               BEGIN
                  IF EXISTS(SELECT 1 FROM UCC (NOLOCK)  
                               WHERE UCCNo = @c_UCCNo  
                               AND Storerkey = @c_aStorerkey  
                               AND Sku = @c_aSku  
                               AND Status < '3') 
                  BEGIN
                     UPDATE UCC WITH (ROWLOCK)  
                          SET Status = '3',  
                              Orderkey = @c_Orderkey,
                              OrderLineNumber = @c_Aorderlinenumber, --NJOW18
                              PickDetailKey = @c_PickDetailKey  --NJOW18
                          WHERE UCCNo = @c_UCCNo  
                        AND Storerkey = @c_aStorerkey  
                        AND Sku = @c_aSku  
                        AND Status < '3'            
                  END --Exists
               END --NJOW13
            END -- @b_pickupdatesuccess = 1  
            ELSE  
               BEGIN  
                  ROLLBACK TRAN TROUTERLOOP  
                  BREAK  
               END  -- @b_pickupdatesuccess <> 1  
            END -- @b_success = 1 ; Generation Pickdetailkey  
         END  
         ELSE  
         BEGIN  
            SELECT @b_pickupdatesuccess = 0  
         END  -- IF @b_sucess = 1  
         SELECT @n_pickrecscreated = @n_pickrecscreated + 1  
         -- SOS 10581: wally 31.mar.03  
         -- to group inner pack (uom = '3') INTO 1 pickdetail  
         IF @c_aUOM = '6' or @c_aUOM = '7' or @c_aUOM = '2' or @c_aUOM = '3' or @c_aUOM = '4' --(Wan07)
         BEGIN  
            BREAK  
         END  
         -- Added By SHONG for Performance Gain on 23-Sep-2003  
         IF @c_SuperFlag = 'Y'  
         BEGIN  
            IF EXISTS(SELECT UOM from #Tmp_SuperOrder_UOM WHERE UOM = @c_aUOM)  
               BREAK  
         END  
      END -- While @n_pickrecscreated < @n_UOMQty  
   /* #INCLUDE <SPOP6.SQL> */  
   END -- @b_pickupdatesuccess = 1  
  
   IF @n_jumpsource = 1  
   BEGIN  
      GOTO RETURNFROMUPDATEINV_01  
   END  
   IF @n_jumpsource = 2  
   BEGIN  
      GOTO RETURNFROMUPDATEINV_02  
   END  
END  


GO