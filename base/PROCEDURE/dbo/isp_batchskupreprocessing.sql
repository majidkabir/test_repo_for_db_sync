SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_BatchSKUPreProcessing                               */
/* Creation Date: 07-Oct-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Pre-Allocate Load Processing                                */
/*                                                                      */
/* Called By: nspLoadProcessing                                         */
/*                                                                      */
/* PVCS Version: 1.8 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 25-Oct-2017  Shong   1.1   Bug Fixing (SWT01)                        */
/* 03-May-2017  NJOW04  1.2   Fix to prevent incorrect lot qty rtn from */
/*                            pickcode                                  */
/* 15-Nov-2017  Wan01   1.3   Check Facility Lot Qty Available          */
/* 20-Apr-2018  SWT02   1.4   Channel Management Check Qty Available    */
/* 07-Aug-2018  Wan02   1.5   Fixed to get correct Preallocate strategy */
/* 23-JUL-2019  Wan03   1.6   ChannelInventoryMgmt use nspGetRight2     */
/* 23-JUL-2019  Wan04   1.7   WMS - 9914 [MY] JDSPORTSMY - Channel      */
/*                            Inventory Ignore QtyOnHold - CR           */
/* 12-Feb-2020  Wan05   1.8   SQLBindParm. Create Temp table to Store   */
/*                            Preallocate data from pickcode            */
/* 03-Jul-2020  CheeMun 2.0   INC1192122 - Initialize ChannelID = 0     */ 
/* 01-Dec-2020  Shong   2.1   Handle PENDCANC SO Status  (SWT99)        */
/* 01-Dec-2020  NJOW01  2.2   WMS-15746 get channel hold qty by config  */  
/* 04-Jan-2022	NJOW02  2.3   WMS-18620 Allow configure order sorting   */
/*                            by orderdate                              */
/* 04-Jan-2022  NJOW02  2.3   DEVOPS combine script                     */
/* 27-SEP-2022  NJOW03  2.4   WMS-20812 Pass in additional parameters to*/
/*                            isp_ChannelAllocGetHoldQty_Wrapper.       */     
/*                            Pass in PreAllocateStrategyKey and        */
/*                            PreAllocateStrategyLineNumber to pickcode */                           
/************************************************************************/
CREATE PROC  [dbo].[isp_BatchSKUPreProcessing]
   @n_AllocBatchNo BIGINT
,  @c_Facility     NVARCHAR(10) 
,  @c_StorerKey    NVARCHAR(15)
,  @c_SKU          NVARCHAR(20)
,  @c_Strategy     NVARCHAR(20)  
,  @c_oprun        NVARCHAR(9)
,  @b_Success      INT        OUTPUT
,  @n_err          INT        OUTPUT
,  @c_errmsg       NVARCHAR(250)  OUTPUT 
,  @b_Debug        INT = 0 
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE        @n_continue INT        ,
   @n_starttcnt INT        , -- Holds the current transaction count
   @n_cnt INT              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 INT             , -- For Additional Error Detection
   @c_sectionkey NVARCHAR(3)

DECLARE @c_OtherParms NVARCHAR(200),  -- For CDC
   @c_PrevStorer NVARCHAR(15),
   @c_PreAlloc NVARCHAR(1),
   @c_OWITF NVARCHAR(1),
   @cPackUOM1 NVARCHAR(5),
   @cPackUOM2 NVARCHAR(5),
   @cPackUOM3 NVARCHAR(5),
   @cPackUOM4 NVARCHAR(5),
   @nRecordFound INT,
   @cExecSQL NVARCHAR(MAX),
   @c_Del_PreAllocatePickDetailkey  NVARCHAR(10), 
   @c_DefaultStrategykey            NVARCHAR(1),   --(Wan01)
   @c_AllocateGetCasecntFrLottable  NVARCHAR(10),  --NJOW02
   @c_CaseQty                       NVARCHAR(30),  --NJOW02
   @c_SQL                           NVARCHAR(2000), --NJOW02
   @n_LotAvailableQty               INT --NJOW04
  ,@n_FacLotAvailQty                INT = 0      --(Wan01) 

  ,@c_ChannelInventoryMgmt          NVARCHAR(10) = '0' -- (SWT02)  
  ,@c_Channel                       NVARCHAR(20) = ''  -- (SWT02)
  ,@n_Channel_ID                    BIGINT = 0         -- (SWT02) 
  ,@n_Channel_Qty_Available         INT = 0            -- (SWT02)
  ,@n_AllocatedHoldQty              INT = 0            -- (SWT02)
  ,@n_ChannelHoldQty                INT                --NJOW01
  ,@c_AutoAllocSort                 NVARCHAR(30)       --NJOW02
  ,@c_AutoAllocSort_opt1            NVARCHAR(50)       --NJOW02
   
SET @c_DefaultStrategykey = ''               --(Wan01)

SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_Success=0, @n_err=0, @c_errmsg='', @n_err2=0

SELECT @c_PrevStorer = SPACE(10)

IF @n_continue=1 OR @n_continue=2
BEGIN
   IF @n_AllocBatchNo IS NULL OR @n_AllocBatchNo = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78300
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Invalid Parameters Passed (isp_BatchSKUPreProcessing)'
   END
END -- @n_continue =1 or @n_continue = 2

IF @n_continue = 1 OR @n_continue =2
BEGIN
   CREATE TABLE #OPBATCH (OrderKey  NVARCHAR(10))

   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Creation Of Temp Table Failed (isp_BatchSKUPreProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF LTRIM(RTRIM(@c_OPRun)) IS NULL OR LTRIM(RTRIM(@c_OPRun))=''
   BEGIN
      SELECT @b_Success = 0
      EXECUTE   nspg_getkey 'PREOPRUN', 9, @c_OPRun OUTPUT, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   END
END


IF @n_continue=1 OR @n_continue=2
BEGIN

   DECLARE @c_authority NVARCHAR(1), @c_freegoodsallocation NVARCHAR(1)
   SELECT @b_Success = 0, @c_freegoodsallocation = '0'
   EXECUTE nspGetRight NULL,                          
   NULL,               
   NULL,                          
   'FREE GOODS ALLOCATION',
   @b_Success      OUTPUT,
   @c_authority    OUTPUT,
   @n_err          OUTPUT,
   @c_errmsg       OUTPUT
   IF @b_Success <> 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = 'isp_BatchSKUPreProcessing : ' + RTRIM(@c_errmsg)
   END
   ELSE
   BEGIN
      SELECT @c_freegoodsallocation = @c_authority
   END
END

IF @n_continue=1 OR @n_continue=2
BEGIN
   IF @n_AllocBatchNo IS NOT NULL
   BEGIN
      SELECT @b_Success = 0
      EXECUTE nspGetRight NULL,  -- Facility
      NULL,                      -- Storer
      NULL,                      -- Sku
      'BYPASS ORDER - TYPE = M & I',
      @b_Success      OUTPUT,
      @c_authority    OUTPUT,
      @n_err          OUTPUT,
      @c_errmsg       OUTPUT
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = 'isp_BatchSKUPreProcessing : ' + RTRIM(@c_errmsg)
      END
      ELSE
      BEGIN
         IF @c_authority = '1'
         BEGIN
            INSERT #OPBATCH (OrderKey)
            SELECT DISTINCT ORDERS.OrderKey
            FROM   ORDERS (NOLOCK) 
            JOIN   ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = ORDERS.OrderKey
            JOIN   AutoAllocBatchDetail AS aabd WITH (NOLOCK) ON aabd.OrderKey = ORDERS.OrderKey            
            WHERE  aabd.AllocBatchNo = @n_AllocBatchNo AND 
                   ORDERS.Type NOT IN ( 'M', 'I' ) AND
                   ORDERS.SOStatus NOT IN ('CANC', 'PENDCANC') AND -- (SWT99)
                   ORDERS.Status NOT IN ('9','CANC') AND 
                   OD.StorerKey = @c_StorerKey AND 
                   OD.Sku = @c_SKU                                                        
         END
         ELSE
         BEGIN
            -- SWT01 
            INSERT #OPBATCH (OrderKey)
            SELECT DISTINCT ORDERS.OrderKey
            FROM   ORDERS (NOLOCK) 
            JOIN   ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = ORDERS.OrderKey
            JOIN   AutoAllocBatchDetail AS aabd WITH (NOLOCK) ON aabd.OrderKey = ORDERS.OrderKey  
            WHERE  aabd.AllocBatchNo = @n_AllocBatchNo AND 
                   ORDERS.SOStatus NOT IN ('CANC', 'PENDCANC') AND -- (SWT99)
                   ORDERS.Status NOT IN ('9','CANC') AND 
                   OD.StorerKey = @c_StorerKey AND 
                   OD.Sku = @c_SKU          
         END
      END

      SELECT @n_Cnt = COUNT(1) FROM #OPBATCH
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78303   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Creation Of Temp Table Failed (isp_BatchSKUPreProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END -- Allocate By Order Key
END

--(Wan04) - START
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
--(Wan04) - END

IF @b_debug = 1 OR @b_debug = 2
BEGIN
   PRINT 'Pre-Allocation: Started at ' + CONVERT(VARCHAR(20), GETDATE()) 
   PRINT '' 
   PRINT 'Alloc Batch Key: ' + CONVERT(VARCHAR(20), @n_AllocBatchNo) 
   PRINT ''
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   DECLARE @c_AutoDeletePreallocations NVARCHAR(20)
   
   SET @c_AutoDeletePreallocations = '0'

   EXEC nspGetRight  
               @c_Facility  = @c_Facility         
            ,  @c_Storerkey = @c_Storerkey      
            ,  @c_Sku = ''       
            ,  @c_Configkey = 'AutoDeletePreAllocation'        
            ,  @b_Success   = @b_Success OUTPUT    
            ,  @c_authority = @c_AutoDeletePreallocations OUTPUT   
            ,  @n_err       = @n_err     OUTPUT    
            ,  @c_errmsg    = @c_errmsg  OUTPUT

   IF @c_AutoDeletePreAllocations = '1'
   BEGIN
      DECLARE C_PreAllocatePickDetail_Key CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PreAllocatePickDetailKey
      FROM   PreAllocatePickDetail WITH (NOLOCK) 
      JOIN   #OPBATCH OPBATCH ON PreAllocatePickDetail.OrderKey = OPBATCH.OrderKey
      WHERE  PreAllocatePickDetail.Storerkey = @c_StorerKey
      AND    PreAllocatePickDetail.Sku = @c_SKU
         
      OPEN C_PreAllocatePickDetail_Key
      FETCH NEXT FROM C_PreAllocatePickDetail_Key INTO @c_Del_PreAllocatePickDetailkey
                         
      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRANSACTION ITEMLOOP
            
         DELETE dbo.PreAllocatePickDetail with (ROWLOCK) 
         WHERE PreAllocatePickDetailkey = @c_Del_PreAllocatePickDetailkey
         
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78329   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Delete From PreAllocatePickDetail Failed (isp_BatchSKUPreProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
         ELSE
         BEGIN      
            COMMIT TRANSACTION ITEMLOOP
         END
      FETCH NEXT FROM C_PreAllocatePickDetail_Key INTO @c_Del_PreAllocatePickDetailkey
      END
      CLOSE C_PreAllocatePickDetail_Key
      DEALLOCATE C_PreAllocatePickDetail_Key
   END
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF EXISTS(SELECT 1 
             FROM PickDetail WITH (NOLOCK) 
             JOIN #OPBATCH OPBATCH ON PickDetail.OrderKey = OPBATCH.OrderKey
             WHERE PickDetail.Storerkey = @c_StorerKey 
             AND   PickDetail.Sku = @c_SKU  
             AND   PICKDETAIL.CaseID LIKE 'C%')
   BEGIN
      DELETE PICKDETAIL 
      FROM dbo.PICKDETAIL
      JOIN #OPBATCH OPBATCH ON PickDetail.OrderKey = OPBATCH.OrderKey
      WHERE PickDetail.Storerkey = @c_StorerKey 
      AND   PickDetail.Sku = @c_SKU  
      AND   PICKDETAIL.CaseID LIKE 'C%'
   
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78330   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Delete From PickDetail Failed (isp_BatchSKUPreProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END 
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   DECLARE @b_CursorOrderGroups_Open INT, @b_cursorcandidates_open INT, @b_cursorlineitems_open INT

   DECLARECURSOR_ORDERS:

   SELECT @b_CursorOrderGroups_Open = 0, @b_cursorcandidates_open = 0, @b_cursorlineitems_open = 0
      
      
   DECLARE CURSOR_ORDERS CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT   OD.StorerKey,
               OD.Sku,
               OD.Lot,
               OD.Lottable01,
               OD.Lottable02,
               OD.Lottable03,
               OD.Lottable04,
               OD.Lottable05,
               OD.Lottable06,
               OD.Lottable07,
               OD.Lottable08,
               OD.Lottable09,
               OD.Lottable10,
               OD.Lottable11,
               OD.Lottable12,
               OD.Lottable13,
               OD.Lottable14,
               OD.Lottable15,
               O.Facility,
               SKU.PackKey,
               OD.UOM,
               OD.MinShelfLife,
               SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated +
                                  OD.QtyPicked )), 
               ISNULL(OD.Channel, '') -- (SWT02) 
      FROM     #OPBATCH OL WITH (NOLOCK) 
      JOIN     dbo.ORDERDETAIL OD WITH ( NOLOCK ) ON OL.OrderKey = OD.OrderKey 
      JOIN     dbo.ORDERS O WITH ( NOLOCK ) ON OD.OrderKey = O.OrderKey  
      JOIN     dbo.SKU SKU WITH (NOLOCK) ON OD.StorerKey = SKU.StorerKey AND OD.SKU = SKU.SKU
      WHERE    OD.StorerKey = @c_StorerKey 
      AND      OD.Sku = @c_SKU 
      GROUP BY OD.StorerKey,
               OD.Sku,
               OD.Lot,
               OD.Lottable01,
               OD.Lottable02,
               OD.Lottable03,
               OD.Lottable04,
               OD.Lottable05,
               OD.Lottable06,
               OD.Lottable07,
               OD.Lottable08,
               OD.Lottable09,
               OD.Lottable10,
               OD.Lottable11,
               OD.Lottable12,
               OD.Lottable13,
               OD.Lottable14,
               OD.Lottable15,
               O.Facility,
               SKU.PackKey,
               OD.UOM,
               OD.MinShelfLife, 
               ISNULL(OD.Channel, '')
      HAVING SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0 
      

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
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78318   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Could not Open CURSOR_ORDERS (isp_BatchSKUPreProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END
   ELSE  
   BEGIN
      SELECT @b_CursorOrderGroups_Open = 1
   END
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   DECLARE @c_aStorerKey NVARCHAR(15),          
      @c_aSKU NVARCHAR(20),                      @c_aLottable01 NVARCHAR(18),                    
      @c_atype NVARCHAR(10),                     @c_aLottable02 NVARCHAR(18),
      @c_apriority NVARCHAR(10),                 @c_aLottable03 NVARCHAR(18),
      @c_aPreAllocateStrategyKey NVARCHAR(10),   @d_aLottable04 DATETIME,
      @c_aPreAllocatePickCode NVARCHAR(10),      @d_aLottable05 DATETIME,
      @d_adeliverydate DATETIME,                 @c_aLottable04 NVARCHAR(18),
      @c_aintermodalVehicle NVARCHAR(30),        @c_aLottable05 NVARCHAR(18),
      @c_aOrderKey NVARCHAR(10),                 @n_MinShelfLife INT,    
      @c_aOrderLineNumber NVARCHAR(10),          @c_LastStorerSKU NVARCHAR(35),       
      @c_aid NVARCHAR(18),                       @c_OnReceiptCopyPackKey NVARCHAR(10),
      @c_aLOT NVARCHAR(10),                      @c_Lottable01PackKey NVARCHAR(10),   
      @c_OrdUOM NVARCHAR(5),                     @n_QtyLeftToFulfill INT,         
      @c_cStorerKey NVARCHAR(15),                @n_caseqty INT,                  
      @c_csku NVARCHAR(20),                      @n_palletqty INT,                
      @c_clot NVARCHAR(10),                      @n_innerPackQty INT,             
      @n_QtyToInsert INT,                        @n_otherunit1 INT,               
      @c_LastPackKey NVARCHAR(10),               @n_otherunit2 INT,               
      @b_candidateexhausted INT,                 @c_lOrderKey NVARCHAR(10),           
      @n_CandidateLine INT,                      @c_lOrderLineNumber NVARCHAR(5),     
      @c_lcartongroup NVARCHAR(10),              @c_lStorerKey NVARCHAR(15),          
      @c_EndString NVARCHAR(50),                 @c_lsku NVARCHAR(20),                
      @c_DocartonizeUOM1 NVARCHAR(1),            @c_lpriority NVARCHAR(10),           
      @c_DocartonizeUOM2 NVARCHAR(1),            @c_ltype NVARCHAR(10),               
      @c_DocartonizeUOM3 NVARCHAR(1),            @c_lPackKey NVARCHAR(10),            
      @c_DocartonizeUOM4 NVARCHAR(1),            @n_sQtyNeededForUOM1 INT,             
      @c_DocartonizeUOM8 NVARCHAR(1),            @n_sQtyNeededForUOM2 INT,             
      @c_DocartonizeUOM9 NVARCHAR(1),            @n_sQtyNeededForUOM3 INT,             
      @c_lDoCartonize NVARCHAR(1),               @n_sQtyNeededForUOM4 INT,             
      @c_sStorerKey NVARCHAR(15),                @n_sQtyNeededForUOM5 INT,             
      @c_sSKU NVARCHAR(20),                      @n_sQtyNeededForUOM6 INT,             
      @c_sloc NVARCHAR(10),                      @n_sQtyNeededForUOM7 INT,             
      @c_sid NVARCHAR(18),                       @n_sqtyneededwork INT,                
      @n_sqty INT,                               @c_sPickMethod NVARCHAR(1),               
      @c_sLOT NVARCHAR(10),                      @c_PreAllocatePickDetailKey NVARCHAR(10), 
      @n_QtyToTake INT,                         @c_pickheaderkey NVARCHAR(5),             
      @n_QtyAvailable INT,                      @n_pickrecscreated INT,               
      @n_pulltype INT,                          @b_PickUpdateSuccess INT,             
      @n_PackQty INT,                           @c_sCurrentLineNumber NVARCHAR(5),        
      @n_Needed INT,                            @c_sUOM NVARCHAR(10),         
      @n_packavailable INT,                     @c_CursorScripts NVARCHAR(600),            
      @c_sloctype NVARCHAR(10),                      
      @n_UOMQty INT,                            @c_XDockLineNumber NVARCHAR(5),
      @n_OutstandingQty INT,                    @n_TryNextUOM INT,                 
      @n_Available INT,                         @c_OrderGroup NVARCHAR(20),
      @c_OrderType NVARCHAR(20),                @c_LoadConsoAllocationOParms NVARCHAR(1)--  tlitng01

   DECLARE 
      @c_aLottable06 NVARCHAR(30),              @c_aLottable07 NVARCHAR(30),
      @c_aLottable08 NVARCHAR(30),              @c_aLottable09 NVARCHAR(30), 
      @c_aLottable10 NVARCHAR(30),              @c_aLottable11 NVARCHAR(30), 
      @c_aLottable12 NVARCHAR(30),              
      @d_aLottable13 Datetime,                  @d_aLottable14 Datetime, 
      @d_aLottable15 Datetime,                  @c_aLottable13 NVARCHAR(30),              
      @c_aLottable14 NVARCHAR(30),              @c_aLottable15 NVARCHAR(30) 

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

   SELECT  @n_MinShelfLife = 0 -- Added by mmlee for fbr50
   SELECT  @c_OrdUOM = ''

   SELECT   @c_aStorerKey = SPACE(15),
            @c_aSKU = SPACE(20),
            @c_Atype = SPACE(10),
            @c_Apriority = SPACE(10),
            @c_aPreAllocateStrategyKey = SPACE(10),
            @c_aLOT = SPACE(10),
            @c_aLottable01 = SPACE(18),
            @c_aLottable02 = SPACE(18),
            @c_aLottable03 = SPACE(18),
            @d_aLottable04 = NULL,
            @d_aLottable05 = NULL,
            @c_aLottable06 = '',
            @c_aLottable07 = '',
            @c_aLottable08 = '',
            @c_aLottable09 = '',
            @c_aLottable10 = '',
            @c_aLottable11 = '',
            @c_aLottable12 = '',
            @c_aLottable13 = '',
            @c_aLottable14 = '',
            @c_aLottable15 = '',
            @d_aLottable13 = NULL,
            @d_aLottable14 = NULL,
            @d_aLottable15 = NULL,
            @c_Aintermodalvehicle = SPACE(30),
            @c_aOrderKey = SPACE(10),
            @c_LastPackKey = SPACE(10),
            @n_caseqty = 0,
            @n_palletqty = 0,
            @n_innerPackQty = 0,
            @n_otherunit1 = 0,
            @n_otherunit2 = 0,
            @b_candidateexhausted = 0,
            @n_CandidateLine = 0,
            @n_QtyToTake = 0,
            @n_QtyAvailable = 0,
            @n_pulltype = 0,
            @n_PackQty = 0,
            @n_Needed = 0,
            @n_packavailable = 0,
            @c_sloctype = '',
            @n_UOMQty = 0,
            @n_OutstandingQty = 0,
            @n_Available = 0,
            @n_TryNextUOM = 0,
            @n_sQtyNeededForUOM1 = 0,
            @n_sQtyNeededForUOM2 = 0,
            @n_sQtyNeededForUOM3 = 0,
            @n_sQtyNeededForUOM4 = 0,
            @n_sQtyNeededForUOM5 = 0,
            @n_sQtyNeededForUOM6 = 0,
            @n_sQtyNeededForUOM7 = 0,
            @n_sqtyneededwork = 0,
            @c_sPickMethod = '',
            @c_sCurrentLineNumber = SPACE(5),
            @c_sUOM = SPACE(10),
            @c_LoadConsoAllocationOParms = '',
            @c_Channel = '' -- (SWT02) 

   WHILE (1 = 1) AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      FETCH NEXT FROM CURSOR_ORDERS INTO 
         @c_aStorerKey,   
         @c_aSKU,    
         @c_aLot,         
         @c_aLottable01,    
         @c_aLottable02,   
         @c_aLottable03, 
         @d_aLottable04,  
         @d_aLottable05, 
         @c_aLottable06, 
         @c_aLottable07, 
         @c_aLottable08, 
         @c_aLottable09, 
         @c_aLottable10, 
         @c_aLottable11, 
         @c_aLottable12, 
         @d_aLottable13, 
         @d_aLottable14, 
         @d_aLottable15, 
         @c_Facility,
         @c_lPackKey, 
         @c_OrdUOM, 
         @n_MinShelfLife, 
         @n_QtyLeftToFulfill,
         @c_Channel -- (SWT02) 

      IF @@FETCH_STATUS = -1
      BEGIN 
         BREAK 
      END
      ELSE 
      IF @@FETCH_STATUS < -1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 78317
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Cannot Fetch Next Group. (isp_BatchSKUPreProcessing)'
         BREAK
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @c_aStorerKey <> @c_PrevStorer
         BEGIN
            SELECT @c_PrevStorer = @c_aStorerKey
   
            SELECT @b_Success = 0
            EXECUTE nspGetRight 
               NULL,          -- facility
               @c_aStorerKey, -- StorerKey
               NULL,          -- Sku
               'Orderinfo4PreAllocation', -- Configkey
               @b_Success OUTPUT, 
               @c_PreAlloc OUTPUT, 
               @n_err OUTPUT,
               @c_errmsg OUTPUT
               
            IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'isp_BatchSKUPreProcessing' + RTRIM(@c_errmsg)
               END
   
            IF @n_continue = 1 OR @n_continue = 2 
            BEGIN
               SELECT @b_Success = 0
               EXECUTE nspGetRight NULL,  -- facility
               @c_aStorerKey,   -- StorerKey
               NULL,            -- Sku
               'OWITF',         -- Configkey
               @b_Success    OUTPUT,
               @c_OWITF      OUTPUT,
               @n_err        OUTPUT,
               @c_errmsg     OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'isp_BatchSKUPreProcessing' + RTRIM(@c_errmsg)
               END
            END 
            IF @n_continue = 1 OR @n_continue = 2 
            BEGIN
               SELECT @b_Success = 0
               EXECUTE nspGetRight NULL,  -- facility
               @c_aStorerKey,   -- StorerKey
               NULL,            -- Sku
               'LoadConsoAllocationOParms',         -- Configkey
               @b_Success    OUTPUT,
               @c_LoadConsoAllocationOParms      OUTPUT,
               @n_err        OUTPUT,
               @c_errmsg     OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'isp_BatchSKUPreProcessing' + RTRIM(@c_errmsg)
               END
            END 
            
            --NJOW02
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight null,  -- facility
               @c_aStorerKey,   -- StorerKey
               null,            -- Sku
               'AllocateGetCasecntFrLottable',         -- Configkey
               @b_success    output,
               @c_AllocateGetCasecntFrLottable output,
               @n_err        output,
               @c_errmsg     output
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'isp_BatchSKUPreProcessing' + RTRIM(@c_errmsg)
               END
            END  

            -- SWT02
            SET @c_ChannelInventoryMgmt = '0'
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight2  --(Wan03)
               NULL,
               @c_aStorerKey,        -- Storer
               '',                   -- Sku
               'ChannelInventoryMgmt',  -- ConfigKey
               @b_success    output,
               @c_ChannelInventoryMgmt  output,
               @n_Err        output,
               @c_ErrMsg     output
               If @b_success <> 1
               Begin
                  Select @n_continue = 3, @c_ErrMsg = 'isp_BatchSKUPreProcessing:' + ISNULL(RTRIM(@c_ErrMsg),'')
               End
            END            
            
            --NJOW02
            SET @c_AutoAllocSort = ''  
            SET @c_AutoAllocSort_opt1 = ''
               
            EXEC nspGetRight    
                 @c_Facility  = @c_facility,   
                 @c_StorerKey = @c_StorerKey,    
                 @c_sku       = NULL,    
                 @c_ConfigKey = 'AutoAllocSort',     
                 @b_Success   = @b_Success            OUTPUT,    
                 @c_authority = @c_AutoAllocSort      OUTPUT,     
                 @n_err       = @n_err                OUTPUT,     
                 @c_errmsg    = @c_errmsg             OUTPUT,
                 @c_Option1   = @c_AutoAllocSort_Opt1 OUTPUT   
                 
            IF ISNULL(@c_AutoAllocSort,'') <> '1'
               SET @c_AutoAllocSort_opt1 = ''                                  
         END -- IF @c_aStorerKey <> @c_PrevStorer
      END
      IF @n_continue = 1 OR @n_continue = 2    
      BEGIN    
         DECLARE @c_MinShelfLife60Mth NVARCHAR(1)
         SELECT @b_Success = 0
         EXECUTE nspGetRight NULL,                       -- Facility
                      @c_lStorerKey,                 -- Storer
                      NULL,                          -- Sku
                      'MinShelfLife60Mth', 
                      @b_Success                               OUTPUT, 
                      @c_MinShelfLife60Mth  OUTPUT, 
                      @n_err          OUTPUT, 
                      @c_errmsg       OUTPUT 
         IF @b_Success <> 1
         BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = 'isp_BatchSKUPreProcessing : ' + RTRIM(@c_errmsg)
         END
      END
      
      IF @n_continue = 1 OR @n_continue = 2    
      BEGIN    
         DECLARE @c_ShelfLifeInDays NVARCHAR(1)
         SELECT @b_Success = 0
         EXECUTE nspGetRight NULL,   -- Facility
            @c_lStorerKey,      -- Storer
            NULL,               -- Sku
            'ShelfLifeInDays', 
            @b_Success              OUTPUT, 
            @c_ShelfLifeInDays      OUTPUT, 
            @n_err                  OUTPUT, 
            @c_errmsg               OUTPUT 
         IF @b_Success <> 1
         BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = 'isp_BatchSKUPreProcessing : ' + RTRIM(@c_errmsg)
         END
      END
         
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
   
      SELECT @c_sCurrentLineNumber = SPACE(5)
      SELECT @c_XDockLineNumber = SPACE(5)

      IF ( @b_debug = 1 OR @b_debug = 2 )
      BEGIN
         PRINT ''
         PRINT ''
         PRINT '-----------------------------------------------------'
         PRINT '-- OrderKey: ' + @c_lOrderKey + ' Line:' + @c_lOrderLineNumber 
         PRINT '-- SKU: ' + RTRIM(@c_lsku) + ' Open Qty:' + CAST(@n_QtyLeftToFulfill AS NVARCHAR(10))
         PRINT '-- Pack Key :' + RTRIM(@c_lPackKey) + ' UOM:' + @c_OrdUOM 
         PRINT '-- Lottables: (1)= ' + RTRIM(@c_aLottable01) + ' (2)= ' + RTRIM(@c_aLottable02) + 
               ' (3)= ' + RTRIM(@c_aLottable03) 
         PRINT '-- Exp Date: ' +   CASE WHEN @d_aLottable04 IS NOT NULL AND @d_aLottable04 <> '19000101' THEN 
                             CONVERT(VARCHAR(20), @d_aLottable04, 112) ELSE '' END 
               + ' Receipt Dt :' + CASE WHEN @d_aLottable05 IS NOT NULL AND @d_aLottable04 <> '19000101' THEN 
                                        CONVERT(VARCHAR(20), @d_aLottable05, 112) ELSE '' END  
         PRINT '-- Minimum Shelf Life: ' + CAST(@n_MinShelfLife AS NVARCHAR(10)) 
         PRINT '-- Pre-Allocation Strategy Key: ' + @c_aPreAllocateStrategyKey 
      END

      IF EXISTS(SELECT 1 FROM StorerConfig AS sc WITH (NOLOCK)
                WHERE sc.ConfigKey = 'SkipAllocStrategyIfZeroStock' AND sc.SValue = '1')
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK) 
                       JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc 
                       WHERE LOC.STATUS = 'OK' 
                       AND (LOC.Locationflag NOT IN ('HOLD','DAMAGE') OR 
                           (QtyAllocated + QtyPicked) > 0 OR 
                           LOC.LOC = 'WS01')       
                       AND   StorerKey = @c_aStorerKey 
                       AND   Sku = @c_aSKU 
                       AND   LOC.Facility = @c_Facility 
                       GROUP BY Storerkey, SKU 
                       HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) > 0 )
         BEGIN
            -- SKIP Allocation if no Stock
            IF ( @b_debug = 1 OR @b_debug = 2 )
            BEGIN
               PRINT '-- SkipAllocStrategyIfZeroStock: No Stock' 
            END  
            CONTINUE
         END                     
      END

      SELECT @c_DefaultStrategykey = @c_Strategy

      WHILE (@n_QtyLeftToFulfill > 0)  
      BEGIN
         SELECT @n_TryNextUOM = 0
         
         NEXTSTRATEGY:
         SET @c_aPreAllocatePickCode = ''
         IF @c_DefaultStrategykey = 'Y'
         BEGIN
            SET @c_aPreAllocateStrategyKey=''
            
            SELECT @c_aPreAllocateStrategyKey =ISNULL( S.PreAllocateStrategyKey,'') 
            FROM   dbo.STRATEGY S  WITH ( NOLOCK )  
            JOIN   dbo.STORER   ST WITH ( NOLOCK ) ON S.StrategyKey = ST.StrategyKey
            WHERE  ST.StorerKey = @c_aStorerKey 
             
            
            IF ISNULL(RTRIM(@c_aPreAllocateStrategyKey),'') = ''
            BEGIN
               SELECT @c_aPreAllocateStrategyKey =ISNULL( S.PreAllocateStrategyKey,'') 
               FROM   dbo.STORERCONFIG SC WITH ( NOLOCK )  
               JOIN   dbo.STRATEGY S WITH ( NOLOCK ) ON S.StrategyKey = SC.sValue  
               WHERE  SC.StorerKey = @c_aStorerKey
               AND    SC.Facility = @c_Facility   
               AND    SC.ConfigKey = 'StorerDefaultAllocStrategy'
            END

            SELECT   TOP 1
                     @c_sCurrentLineNumber   = ISNULL(RTRIM(PA.PreAllocateStrategyLineNumber),'') 
                  ,  @c_aPreAllocatePickCode = ISNULL(RTRIM(PA.PreAllocatePickCode),'')  
                  ,  @c_sUOM = ISNULL(RTRIM(PA.UOM),'') 
            FROM     dbo.PREALLOCATESTRATEGYDETAIL PA WITH ( NOLOCK ) 
            WHERE    PA.PreAllocateStrategyKey = @c_aPreAllocateStrategyKey 
            AND      PA.PreAllocateStrategyLineNumber > @c_sCurrentLineNumber
            ORDER BY PA.PreAllocateStrategyLineNumber
         END
         ELSE
         BEGIN
           
            SELECT   TOP 1
                     @c_sCurrentLineNumber = PA.PreAllocateStrategyLineNumber,
                     @c_aPreAllocatePickCode = PA.PreAllocatePickCode,
                     @c_aPreAllocateStrategyKey =PA.PreAllocateStrategyKey,
                     @c_sUOM = PA.UOM
            FROM     dbo.PreAllocateStrategyDetail PA WITH ( NOLOCK ) 
            JOIN     dbo.Strategy S WITH ( NOLOCK ) ON S.PreAllocateStrategyKey = PA.PreAllocateStrategyKey 
            JOIN     dbo.SKU SKU WITH ( NOLOCK ) ON  S.StrategyKey = CASE WHEN @c_Strategy = '' THEN SKU.StrategyKey ELSE @c_Strategy END -- (Wan01)
            WHERE    SKU.StorerKey = @c_aStorerKey AND
             SKU.Sku = @c_aSKU AND
                     PreAllocateStrategyLineNumber > @c_sCurrentLineNumber
            ORDER BY PreAllocateStrategyLineNumber
         END      

         --(Shong01)
         IF @@ROWCOUNT = 0 OR ISNULL(RTRIM(@c_aPreAllocatePickCode),'') = ''
         BEGIN
            BREAK
         END
     
         DECLARECURSOR_CANDIDATES:
      
         IF @d_aLottable04 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable04, 112) = '19000101'
            SELECT @c_aLottable04 = ''
         ELSE
            SELECT @c_aLottable04 = CONVERT(VARCHAR(20), @d_aLottable04, 112)
      
         IF @d_aLottable05 IS NULL OR CONVERT(VARCHAR(20), @d_aLottable05, 112) = '19000101'
            SELECT @c_aLottable05 = ''
         ELSE
            SELECT @c_aLottable05 = CONVERT(VARCHAR(20), @d_aLottable05, 112)          --(Wan01)

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

         SELECT @n_PackQty = CASE @c_sUOM
            WHEN 2 THEN CaseCnt
            WHEN 3 THEN InnerPack
            WHEN 1 THEN Pallet
            ELSE 1
            END
            FROM PACK (NOLOCK)
            WHERE PackKey = @c_lPackKey

         SELECT @c_EndString = LTRIM(CONVERT(CHAR(10),@n_PackQty)) + ',' + LTRIM(CONVERT(CHAR(10),@n_QtyLeftToFulfill))
      
         IF  @n_MinShelfLife <> 0 
         BEGIN
            SELECT @c_aLOT = '*' + RTRIM(CONVERT(CHAR(5), @n_MinShelfLife))
         END

         DECLARE @c_PreAllocFullUOM NVARCHAR(1)
         
         SELECT  @b_Success = 0
         EXECUTE nspGetRight NULL,              -- Facility
         @c_aStorerKey,     -- Storer
         NULL,              -- Sku
         'PREALLOCONFULLUOM',
         @b_Success         OUTPUT,
         @c_PreAllocFullUOM OUTPUT,
         @n_err             OUTPUT,
         @c_errmsg           OUTPUT
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'isp_BatchSKUPreProcessing : ' + RTRIM(@c_errmsg)
         END
         ELSE
         BEGIN
            IF @c_PreAllocFullUOM = '1'
            BEGIN
               SELECT @n_PackQty = CASE @c_OrdUOM
                                        WHEN PACKUOM1 THEN CaseCnt
                                        WHEN PACKUOM2 THEN InnerPack
                                        WHEN PACKUOM3 THEN 1
                                        WHEN PACKUOM4 THEN Pallet
                                        WHEN PACKUOM5 THEN CUBE
                                             -- Modify by SHONG 05 May 2002
                                             -- Do not allocate when the PCKUOM not match
                                             -- Set to Max Number
                                        ELSE 99999999
                                   END
               FROM   PACK(NOLOCK)
               WHERE  PackKey = @c_lPackKey

            END
         END

         IF @c_OWITF = '1' 
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

         IF @n_QtyLeftToFulfill < @n_PackQty
            GOTO NEXTSTRATEGY
         

         SET @cExecSQL = @c_APreAllocatePickCode 

         DECLARE Cur_Parameters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PARAMETER_NAME, ORDINAL_POSITION
         FROM [INFORMATION_SCHEMA].[PARAMETERS] 
         WHERE SPECIFIC_NAME = @c_APreAllocatePickCode 
         ORDER BY ORDINAL_POSITION

         OPEN Cur_Parameters
         FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @cExecSQL = RTRIM(@cExecSQL) + CASE WHEN @n_OrdinalPosition = 1 THEN ' ' ELSE ' ,' END + 
               CASE @c_ParameterName 
                  WHEN '@c_Facility'   THEN '@c_Facility = N''' + RTRIM(@c_facility) + ''''
                  WHEN '@c_lot'        THEN '@c_LOT = N''' + RTRIM(@c_Alot) + ''''
                  WHEN '@c_StorerKey'  THEN '@c_StorerKey = N''' + RTRIM(@c_aStorerKey) + ''''
                  WHEN '@c_SKU'        THEN '@c_SKU = N''' + RTRIM(@c_aSKU) + '''' 
                  WHEN '@c_Lottable01' THEN '@c_Lottable01 = N''' + RTRIM(@c_aLottable01) + '''' 
                  WHEN '@c_Lottable02' THEN '@c_Lottable02 = N''' + RTRIM(@c_aLottable02) + '''' 
                  WHEN '@c_Lottable03' THEN '@c_Lottable03 = N''' + RTRIM(@c_aLottable03) + '''' 
                  WHEN '@c_Lottable04' THEN '@c_Lottable04 = N''' + RTRIM(@c_aLottable04) + ''''  
                  WHEN '@d_Lottable04' THEN '@d_Lottable04 = N''' + RTRIM(@c_aLottable04) + ''''  
                  WHEN '@c_Lottable05' THEN '@c_Lottable05 = N''' + RTRIM(@c_aLottable05) + ''''  
                  WHEN '@d_Lottable05' THEN '@d_Lottable05 = N''' + RTRIM(@c_aLottable05) + ''''  
                  WHEN '@c_Lottable06' THEN '@c_Lottable06 = N''' + RTRIM(@c_aLottable06) + '''' 
                  WHEN '@c_Lottable07' THEN '@c_Lottable07 = N''' + RTRIM(@c_aLottable07) + '''' 
                  WHEN '@c_Lottable08' THEN '@c_Lottable08 = N''' + RTRIM(@c_aLottable08) + '''' 
                  WHEN '@c_Lottable09' THEN '@c_Lottable09 = N''' + RTRIM(@c_aLottable09) + ''''  
                  WHEN '@c_Lottable10' THEN '@c_Lottable10 = N''' + RTRIM(@c_aLottable10) + ''''  
                  WHEN '@c_Lottable11' THEN '@c_Lottable11 = N''' + RTRIM(@c_aLottable11) + '''' 
                  WHEN '@c_Lottable12' THEN '@c_Lottable12 = N''' + RTRIM(@c_aLottable12) + '''' 
                  WHEN '@d_Lottable13' THEN '@d_Lottable13 = N''' + RTRIM(@c_aLottable13) + ''''   --(Wan01)
                  WHEN '@d_Lottable14' THEN '@d_Lottable14 = N''' + RTRIM(@c_aLottable14) + ''''   --(Wan01)
                  WHEN '@d_Lottable15' THEN '@d_Lottable15 = N''' + RTRIM(@c_aLottable15) + ''''   --(Wan01)
                  WHEN '@c_UOM'        THEN '@c_UOM = N''' + RTRIM(@c_sUOM) + '''' 
                  WHEN '@c_OtherParms' THEN '@c_OtherParms= N''' + 
                                            RTRIM(@c_aOrderKey) + RTRIM(@c_aOrderLineNumber) + ''' ' 
                  WHEN '@n_UOMBase'    THEN '@n_UOMBase = ' + RTRIM(CONVERT(VARCHAR(10),@n_PackQty)) 
                  WHEN '@n_QtyLeftToFulfill' THEN '@n_QtyLeftToFulfill = ' + RTRIM(CONVERT(VARCHAR(10),@n_QtyLeftToFulfill))
                  WHEN '@c_PreAllocateStrategyKey' THEN ',@c_PreAllocateStrategyKey = N''' + RTRIM(@c_aPreAllocateStrategyKey) + ''''  --NJOW03
                  WHEN '@c_PreAllocateStrategyLineNumber' THEN ',@c_PreAllocateStrategyLineNumber = N''' + RTRIM(@c_sCurrentLineNumber) + ''''  --NJOW03
               END 
            
            FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
         END 
         CLOSE Cur_Parameters
         DEALLOCATE Cur_Parameters
            
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

         OPEN PREALLOCATE_CURSOR_CANDIDATES
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         
         IF @n_err = 16905
         BEGIN
            CLOSE PREALLOCATE_CURSOR_CANDIDATES
            DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
            GOTO DECLARECURSOR_CANDIDATES
         END

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 78315   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (isp_BatchSKUPreProcessing)' 
               + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
         ELSE 
         BEGIN
            SELECT @b_cursorcandidates_open = 1
         END

         
         IF ( @n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @n_CandidateLine = 0
            WHILE @n_QtyLeftToFulfill > 0
            BEGIN
               SELECT @n_CandidateLine = @n_CandidateLine + 1
         
               IF @n_CandidateLine = 1
               BEGIN
                  FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES
                  INTO  @c_sStorerKey, @c_sSKU,@c_sLOT, @n_QtyAvailable
               END
               ELSE 
               BEGIN
                  FETCH NEXT FROM PREALLOCATE_CURSOR_CANDIDATES
                  INTO @c_sStorerKey, @c_sSKU,@c_sLOT, @n_QtyAvailable 
               END
         
            IF @@FETCH_STATUS = -1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  IF @nRecordFound = 0 
                  BEGIN
                     PRINT ''
                     PRINT ''
                     PRINT '**** No Record Found In Strategy ****'
         
                     IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK)
                         JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                         JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.LOT = LotAttribute.LOT
                         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
                         LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                                          FROM   PreAllocatePickDetail p (NOLOCK), ORDERS (NOLOCK)
                                          WHERE  p.OrderKey = ORDERS.OrderKey
                                          AND    p.StorerKey = @c_aStorerKey
                                          AND    p.SKU = @c_aSKU
                                          AND    p.Qty > 0
                                          GROUP BY p.LOT, ORDERS.Facility) 
                                          P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility
                         WHERE LOT.Status = 'OK' AND LOC.Status = 'OK' 
                         AND LOC.Facility = @c_Facility  
                         AND ((LOC.locationflag NOT IN ('DAMAGE', 'HOLD') AND LOTxLOCxID.LOC <> 'WS01') OR LOTxLOCxID.QtyExpected > 0 )  
                         AND LOTxLOCxID.StorerKey = @c_aStorerKey 
                         AND LOTxLOCxID.SKU = @c_aSKU 
                         GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, LOC.Facility 
                         HAVING SUM(LOTxLOCxID.Qty) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0)) > 0)
                     BEGIN
                        PRINT '**** Check Stock Balance **** '
                        SELECT LOC.Facility, LOT.SKU, LOT.LOT,
                              QtyAvailable = SUM(LOTxLOCxID.Qty) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0)),
                               Lottable01, Lottable02, Lottable03, CONVERT(VARCHAR(10), Lottable04, 112) AS Lottable04, 
                               CONVERT(VARCHAR(10), Lottable05, 112) AS Lottable05 
                         FROM LOTxLOCxID (NOLOCK)
                         JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                         JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.LOT = LotAttribute.LOT
                         JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
                         LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                                          FROM   PreAllocatePickDetail p (NOLOCK), ORDERS (NOLOCK)
                                          WHERE  p.OrderKey = ORDERS.OrderKey
                                          AND    p.StorerKey = @c_aStorerKey
                                          AND    p.SKU = @c_aSKU
                                          AND    p.Qty > 0
                                          GROUP BY p.LOT, ORDERS.Facility) 
                                          P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility
                         WHERE LOT.Status = 'OK' AND LOC.Status = 'OK' 
                         AND LOC.Facility = @c_Facility  
                         AND ((LOC.locationflag NOT IN ('DAMAGE', 'HOLD') AND LOTxLOCxID.LOC <> 'WS01') OR LOTxLOCxID.QtyExpected > 0 )  
                         AND LOTxLOCxID.StorerKey = @c_aStorerKey 
                         AND LOTxLOCxID.SKU = @c_aSKU 
                         GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, LOC.Facility 
                         HAVING SUM(LOTxLOCxID.Qty) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0)) > 0 
                         ORDER BY Lottable04, Lottable05 
                     END
                  END 
               END      
               BREAK
            END
         
            IF @@FETCH_STATUS = 0
            BEGIN
               --NJOW04
               SET @n_LotAvailableQty = 0
               SELECT @n_LotAvailableQty = Qty - QtyAllocated - QtyPicked - QtyPreAllocated
               FROM LOT (NOLOCK) 
               WHERE Lot = @c_sLOT   
            
               IF @n_QtyAvailable > @n_LotAvailableQty 
                  SET @n_QtyAvailable = @n_LotAvailableQty 

               --(Wan01) - START
               SELECT @n_FacLotAvailQty = SUM(LLI.Qty - LLI.QtyAllocated - LLi.QtyPicked)
               FROM LOTxLOCxID  LLI WITH (NOLOCK) 
               JOIN LOC         LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
               WHERE LLI.Lot =  @c_sLOT  
               AND   LOC.Facility = @c_facility

               IF @n_FacLotAvailQty < @n_QtyAvailable
               BEGIN 
                  SET @n_QtyAvailable = @n_FacLotAvailQty  
               END

               IF @c_ChannelInventoryMgmt = '1'       
               BEGIN
				  --INC1192122(START)
				  IF ((@c_aStorerKey <> @c_sPrevStorerKey) OR (@c_aSKU <> @c_sPrevSKU) 
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
                            @c_StorerKey   = @c_aStorerKey
                           ,@c_Sku         = @c_aSKU
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
                           SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspPreAllocateLoadProcessing)' 
                     END CATCH                                          
                  END 
                  
				  --INC1192122(START)
				  SET @c_sPrevStorerKey     =  @c_aStorerKey  
				  SET @c_sPrevSKU  		    =  @c_aSKU  
				  SET @c_PrevFACILITY       =  @c_FACILITY  
				  SET @c_PrevChannel        =  @c_Channel  
				  SET @c_sPrevLOT           =  @c_sLOT  		   
				  --INC1192122(END) 
                  
                  IF @n_Channel_ID > 0 
                  BEGIN
                     SET @n_Channel_Qty_Available = 0 
                     SET @n_AllocatedHoldQty = 0 

                     --NJOW01 S              
                     SET @n_ChannelHoldQty = 0                      
                     EXEC isp_ChannelAllocGetHoldQty_Wrapper  
                        @c_StorerKey = @c_aStorerkey, 
                        @c_Sku = @c_aSKU,  
                        @c_Facility = @c_Facility,           
                        @c_Lot = @c_sLOT,
                        @c_Channel = @c_Channel,
                        @n_Channel_ID = @n_Channel_ID,   
                        @n_AllocateQty = @n_QtyAvailable, --NJOW03  
                        @n_QtyLeftToFulFill = @n_QtyLeftToFulfill, --NJOW03                                                                                                                             
                        @c_SourceKey = @n_AllocBatchNo,
                        @c_SourceType = 'isp_BatchSkuPreProcessing', 
                        @n_ChannelHoldQty = @n_ChannelHoldQty OUTPUT,
                        @b_Success = @b_Success OUTPUT,
                        @n_Err = @n_Err OUTPUT, 
                        @c_ErrMsg = @c_ErrMsg OUTPUT
                        
                     IF @b_success <> 1
                     BEGIN
                        SET @n_continue = 3                                                                                
                     END                                                                                                
                     --NJOW01 E   
               
                     /*--(Wan04) - START
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
                     --(Wan04) - END*/
               
                     SELECT @n_Channel_Qty_Available = ci.Qty - ( ci.QtyAllocated - @n_AllocatedHoldQty ) - ci.QtyOnHold - @n_ChannelHoldQty --NJOW01            
                     FROM ChannelInv AS ci WITH(NOLOCK)
                     WHERE ci.Channel_ID = @n_Channel_ID
                     IF @n_Channel_Qty_Available < @n_QtyAvailable
                     BEGIN 
                        SET @n_QtyAvailable = @n_Channel_Qty_Available   
                     END               
                  END 
               END 
            
               IF @n_QtyAvailable <= 0 
               BEGIN
                  GOTO NEXT_FETCH
               END
               --(Wan01) - END

                              
               IF @b_debug = 1
               BEGIN 
                  SET @nRecordFound = 1 
                  PRINT ''
                  PRINT '**** Found Stock ****'
                  PRINT '     LOT: ' + @c_sLOT + ' Qty Available: ' + CAST(@n_QtyAvailable AS NVARCHAR(10))
               END
         
               IF @c_sSKU+@c_sStorerKey <> @c_LastStorerSKU
               BEGIN
                  SELECT @c_OnReceiptCopyPackKey = OnReceiptCopyPackKey, 
                         @c_LastStorerSKU = @c_sStorerKey+@c_sSKU
                  FROM SKU (NOLOCK)
                  WHERE StorerKey = @c_sStorerKey AND SKU = @c_sSKU
               END
         
               IF @c_OnReceiptCopyPackKey = '1'
               BEGIN
                  SELECT @c_Lottable01PackKey=Lottable01
                  FROM LOTATTRIBUTE (NOLOCK)
                  WHERE LOT = @c_sLOT
         
                  IF LTRIM(RTRIM(@c_Lottable01PackKey)) IS NOT NULL
                  BEGIN
                     IF EXISTS (SELECT PackKey FROM PACK (NOLOCK) WHERE PackKey = @c_Lottable01PackKey)
                     BEGIN
                        SELECT @c_lPackKey = @c_Lottable01PackKey
                     END
                  END
               END -- IF @c_OnReceiptCopyPackKey = '1'
         
               IF @c_lPackKey <> @c_LastPackKey
               BEGIN
                  GOTO GETEQUIVALENCES
                  RETURNFROMGETEQUIVALENCES:
               END
         
               IF @c_sUOM = '8' OR @n_TryNextUOM = 1
               BEGIN
                  SELECT @n_TryNextUOM = 1
                  SELECT @c_sUOM = '1'
               END

               --NJOW02
               IF ISNULL(@c_AllocateGetCasecntFrLottable,'') 
                  IN ('01','02','03','06','07','08','09','10','11','12') AND @c_suom = '2'
               BEGIN        
                   SET @c_CaseQty = ''
                   SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +           
                       ' FROM LOTATTRIBUTE(NOLOCK) ' +
                       ' WHERE LOT = @c_sLot '
               
                    EXEC sp_executesql @c_SQL,
                    N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_sLot NVARCHAR(10)', 
                    @c_CaseQty OUTPUT,
                    @c_Slot    
                    
                    IF ISNUMERIC(@c_CaseQty) = 1
                    BEGIN
                       SELECT @n_CaseQty = CAST(@c_CaseQty AS INT)
                    END       
               END 
                       
               NEXTUOM:
               SELECT @n_PackQty = CASE @c_sUOM
               WHEN '1' THEN @n_palletqty
               WHEN '2' THEN @n_caseqty
               WHEN '3' THEN @n_innerPackQty
               WHEN '4' THEN @n_otherunit1
               WHEN '5' THEN @n_otherunit2
               WHEN '6' THEN 1
               WHEN '7' THEN 1
               ELSE 1 END,
               @c_lDoCartonize = CASE @c_sUOM
               WHEN '1' THEN @c_DocartonizeUOM4
               WHEN '2' THEN @c_DocartonizeUOM1
               WHEN '3' THEN @c_DocartonizeUOM2
               WHEN '4' THEN @c_DocartonizeUOM8
               WHEN '5' THEN @c_DocartonizeUOM9
               WHEN '6' THEN @c_DocartonizeUOM3
               WHEN '7' THEN @c_DocartonizeUOM3
               ELSE 'N' END
         
               IF @n_PackQty = 0
               BEGIN
                  IF @n_TryNextUOM = 0
                  BEGIN
                     BREAK
                  END
               ELSE 
               BEGIN
                  SELECT @c_sUOM = CONVERT(NVARCHAR(1), CONVERT(INT,@c_sUOM)+1 )
                  IF @c_sUOM < '7'
                  BEGIN
                     GOTO NEXTUOM
                  END
                  ELSE BEGIN
                     CONTINUE
                  END
               END
            END -- IF @n_PackQty = 0
         
            SELECT @n_Needed = FLOOR(@n_QtyLeftToFulfill/@n_PackQty) * @n_PackQty
            SELECT @n_Available = FLOOR(@n_QtyAvailable/@n_PackQty) * @n_PackQty

           IF @b_debug = 1
           BEGIN 
              SET @nRecordFound = 1 
              PRINT ''
              PRINT '     Needed: ' + CAST(@n_Needed as NVARCHAR(10)) + ' Qty LeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR(10))
           END
         
            IF @n_Available >= @n_Needed 
            BEGIN
               SELECT  @n_QtyToTake = @n_Needed
            END
            ELSE 
            BEGIN
               SELECT  @n_QtyToTake = @n_Available
            END
         
            SELECT @n_UOMQty = @n_QtyToTake / @n_PackQty
            
            IF @b_debug = 1
            BEGIN
               PRINT '     UOM to Take:' + RTRIM(@c_sUOM) + ' Pack Qty: ' + CAST(@n_PackQty AS NVARCHAR(10))
               PRINT '     Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))
            END
         
         /* #INCLUDE <SPPREOP3.SQL> */
         
            IF @n_QtyToTake > 0
            BEGIN
               GOTO UPDATEINV
               RETURNFROMUPDATEINV_01:
            END
         
            IF @n_TryNextUOM = 1 AND @n_QtyLeftToFulfill > 0 AND @n_QtyAvailable > 0
            BEGIN
               SELECT @c_sUOM = CONVERT(NVARCHAR(1), CONVERT(INT,@c_sUOM)+1 )
               IF @c_sUOM < '7'
               BEGIN
                  GOTO NEXTUOM
               END
            END

            NEXT_FETCH:          --(Wan01)
         END -- IF @@FETCH_STATUS = 0
      END -- WHILE @n_QtyLeftToFulfill > 0
   END -- IF ( @n_continue = 1 or @n_continue = 2)

   IF @b_cursorcandidates_open = 1
   BEGIN
      CLOSE PREALLOCATE_CURSOR_CANDIDATES
      DEALLOCATE PREALLOCATE_CURSOR_CANDIDATES
   END
   END -- WHILE (@n_QtyLeftToFulfill > 0)
   SET ROWCOUNT 0
      END -- (1 = 1) and (@n_continue = 1 or @n_continue = 2)
   
   SET ROWCOUNT 0
END

IF @b_CursorOrderGroups_Open = 1
BEGIN
   CLOSE CURSOR_ORDERS
   DEALLOCATE CURSOR_ORDERS
END

/* #INCLUDE <SPPREOP2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_Success = 0
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BatchSKUPreProcessing'
RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
RETURN
END
ELSE BEGIN
   SELECT @b_Success = 1
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
         @n_innerPackQty = innerpack,
         @n_otherunit1 = CONVERT(INT, OtherUnit1),
         @n_otherUnit2 = CONVERT(INT, Otherunit2),
         @c_DocartonizeUOM1 = cartonizeuom1,
         @c_DocartonizeUOM2 = cartonizeuom2,
         @c_DocartonizeUOM3 = cartonizeuom3,
         @c_DocartonizeUOM4 = cartonizeuom4,
         @c_DocartonizeUOM8 = cartonizeuom8,
         @c_DocartonizeUOM9 = cartonizeuom9
FROM     PACK (NOLOCK)
WHERE    PackKey = @c_lPackKey

SELECT @c_LastPackKey = @c_lPackKey
GOTO RETURNFROMGETEQUIVALENCES

/***********************************************************************************************************************************
*
*  This is the UPDATEINV SubRoutine.
*
***********************************************************************************************************************************/
UPDATEINV:
SELECT @b_PickUpdateSuccess = 1

IF @b_PickUpdateSuccess = 1
BEGIN
   IF @b_Debug = 1 
   BEGIN 
      SELECT @n_Cnt = COUNT(1)
      FROM   dbo.ORDERS O WITH (NOLOCK)
      JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
      JOIN #OPBATCH PL ON PL.OrderKey = O.OrderKey
      WHERE OD.StorerKey = @c_sStorerKey AND
            OD.SKU = @c_sSKU AND
            OD.Lottable01 = @c_aLottable01 AND
            OD.Lottable02 = @c_aLottable02 AND
            OD.Lottable03 = @c_aLottable03 AND
            OD.Lottable04 = @d_aLottable04 AND
            OD.Lottable05 = @d_aLottable05 AND
            OD.Lottable06 = @c_aLottable06 AND
       OD.Lottable07 = @c_aLottable07 AND
            OD.Lottable08 = @c_aLottable08 AND
            OD.Lottable09 = @c_aLottable09 AND
            OD.Lottable10 = @c_aLottable10 AND
            OD.Lottable11 = @c_aLottable11 AND
            OD.Lottable12 = @c_aLottable12 AND
            OD.Lottable13 = @d_aLottable13 AND
            OD.Lottable14 = @d_aLottable14 AND
            OD.Lottable15 = @d_aLottable15 AND
            OD.LOT        = CASE WHEN LEFT(@c_aLOT,1) = '*' THEN OD.LOT ELSE @c_aLOT END AND
            O.Facility    = @c_Facility AND
            OD.UOM        = @c_OrdUOM AND
            OD.MinShelfLife = @n_MinShelfLife AND
            (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) > 0  
               
      IF (@n_Cnt) =0
      BEGIN
        PRINT '**** Order Detail NOT Found ****'
         SELECT @c_aLottable01 '@c_aLottable01', 
          @c_aLottable02 '@c_aLottable02', 
          @c_aLottable03 '@c_aLottable03',
          @d_aLottable05 '@d_aLottable05', 
          @d_aLottable04 '@d_aLottable04', 
          @c_OrdUOM '@c_OrdUOM', 
          @n_MinShelfLife '@n_MinShelfLife',
          @c_aLOT '@c_aLOT'
      END
   END             

   DECLARE CUR_PREALLOCATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OD.OrderKey, OD.OrderLineNumber, (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) 
   FROM   dbo.ORDERS O WITH (NOLOCK)
   JOIN   dbo.ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN   #OPBATCH PL ON PL.OrderKey = O.OrderKey
   JOIN   SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku --NJOW01
   JOIN   PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey --NJOW01              
   WHERE OD.StorerKey = @c_sStorerKey AND
         OD.SKU = @c_sSKU AND
         OD.Lottable01 = @c_aLottable01 AND
         OD.Lottable02 = @c_aLottable02 AND
         OD.Lottable03 = @c_aLottable03 AND
         OD.Lottable04 = @d_aLottable04 AND
         OD.Lottable05 = @d_aLottable05 AND
         OD.Lottable06 = @c_aLottable06 AND
         OD.Lottable07 = @c_aLottable07 AND
         OD.Lottable08 = @c_aLottable08 AND
         OD.Lottable09 = @c_aLottable09 AND
         OD.Lottable10 = @c_aLottable10 AND
         OD.Lottable11 = @c_aLottable11 AND
         OD.Lottable12 = @c_aLottable12 AND
         OD.Lottable13 = @d_aLottable13 AND
         OD.Lottable14 = @d_aLottable14 AND
         OD.Lottable15 = @d_aLottable15 AND
         OD.LOT        = CASE WHEN LEFT(@c_aLOT,1) = '*' THEN OD.LOT ELSE @c_aLOT END AND
         O.Facility    = @c_Facility AND
         OD.UOM        = @c_OrdUOM AND
         OD.MinShelfLife = @n_MinShelfLife AND
         (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) > 0  
   ORDER BY O.Priority, --NJOW01
            CASE WHEN @c_AutoAllocSort_Opt1 = 'ORDERS.OrderDate' THEN O.OrderDate ELSE '' END,  --NJOW02
            CASE WHEN PACK.Pallet > 0 THEN FLOOR((OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) / PACK.Pallet) ELSE 0 END DESC, --NJOW01
            CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(CASE WHEN PACK.Pallet > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.Pallet AS INT) 
                                                       ELSE (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) END 
                                                  / PACK.CaseCnt) ELSE 0 END DESC, --NJOW01
            CASE WHEN PACK.InnerPack > 0 THEN FLOOR(CASE WHEN PACK.CaseCnt > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.CaseCnt AS INT)
                                                         WHEN PACK.Pallet > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.Pallet AS INT) 
                                                         ELSE (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) END 
                                                    / PACK.InnerPack) ELSE 0 END DESC, --NJOW01
            CASE WHEN PACK.InnerPack > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.InnerPack AS INT)
                 WHEN PACK.CaseCnt > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.CaseCnt AS INT)
                 WHEN PACK.Pallet > 0 THEN (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) % CAST(PACK.Pallet AS INT) 
                 ELSE (OD.OpenQty - OD.QtyPreAllocated - OD.QtyAllocated - OD.QtyPicked) END DESC --NJOW01                                                 
   
   OPEN CUR_PREALLOCATE
   
   FETCH NEXT FROM CUR_PREALLOCATE INTO @c_lOrderKey, @c_lOrderLineNumber, @n_OutStandingQty 
   
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      IF @n_QtyToTake = 0 
         BREAK 
         
      SET @n_QtyToInsert = 0 
      
      IF @n_QtyToTake > @n_OutStandingQty
         SET @n_QtyToInsert = @n_OutStandingQty
      ELSE
         SET @n_QtyToInsert = @n_QtyToTake
         
      
      SET @b_Success = 0
   
      EXECUTE nspg_getkey 'PreAllocatePickDetailKey', 10,
         @c_PreAllocatePickDetailKey OUTPUT, @b_Success OUTPUT, @n_err OUTPUT,
         @c_errmsg OUTPUT
         
      IF @b_Success = 1
      BEGIN
         BEGIN TRANSACTION TROUTERLOOP
         
         IF @b_PickUpdateSuccess = 1
         BEGIN
            INSERT   PreAllocatePickDetail
             ( PreAllocatePickDetailKey,  OrderKey,            OrderLineNumber,
               PreAllocateStrategyKey,    PreAllocatePickCode, Lot,
               StorerKey,                 Sku,                 Qty,
               UOMQty,                    UOM,                 PackKey,
               DOCartonize,               Runkey,              PickMethod )
            VALUES 
            (  @c_PreAllocatePickDetailKey, @c_lOrderKey,            @c_lOrderLineNumber,
               @c_aPreAllocateStrategyKey,  @c_aPreAllocatePickCode, @c_sLOT,
               @c_sStorerKey,               @c_sSKU,                 @n_QtyToInsert,
               @n_UOMQty,                   @c_sUOM,                 @c_lPackKey,
               @c_lDoCartonize,             @c_OPRun,                @c_sPickMethod )
               
            SELECT @n_err = @@ERROR 
            
            SELECT @n_cnt = COUNT(1) 
            FROM PreAllocatePickDetail (NOLOCK) 
            WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey
            IF NOT (@n_err = 0 AND @n_cnt = 1)
            BEGIN
               SELECT @b_PickUpdateSuccess = 0
            END
         END
      END  -- IF @b_sucess = 1      
      IF @b_PickUpdateSuccess = 1
      BEGIN
         COMMIT TRAN TROUTERLOOP
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToInsert
         SET @n_QtyAvailable = @n_QtyAvailable - @n_QtyToInsert
         SET @n_QtyToTake = @n_QtyToTake - @n_QtyToInsert 
      END
      ELSE 
      BEGIN
         ROLLBACK TRAN TROUTERLOOP
         SELECT @n_err = 0
      END
     
      FETCH NEXT FROM CUR_PREALLOCATE INTO @c_lOrderKey, @c_lOrderLineNumber, @n_OutStandingQty 
   END -- while 
   CLOSE CUR_PREALLOCATE
   DEALLOCATE CUR_PREALLOCATE 


   /* #INCLUDE <SPPREOP4.SQL> */

END
GOTO RETURNFROMUPDATEINV_01

GO