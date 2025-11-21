SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: ispWaveProcessing                                  */      
/* Creation Date:  04-Oct-2012                                          */      
/* Copyright: Maersk                                                    */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 7.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Rev   Purposes                                  */      
/* 27-03-2013   Chee    1.0   Add ispPreProcessing (Chee01)             */      
/* 05-03-2014   Shong   1.1   Added Set CONCAT_NULL_YIELDS_NULL OFF     */      
/* 16-04-2014   Shong   1.2   SQL2012 RaiseError Change                 */      
/* 30-07-2014   Chee    1.3   SOS#315963 Add ispPostProcessing (Chee02) */      
/* 18-09-2014   Shong   1.4   Sort by Order's Priority                  */      
/* 31-10-2014   Shong   1.5   Extend UOM varible from 5 to 10           */      
/* 20-05-2014   NJOW01  1.6   310790-Multi pick loc overallocation with */  
/*                            no mix lot (PickOverAllocateNoMixLot)     */  
/* 13-11-2014   NJOW02  1.7   distribute allocated qty to order sort    */  
/*                            by uom pallet,case,innter & each.         */  
/* 19-Nov-2014  NJOW03  1.8   Remove orderselection default flag check  */  
/*                            error                                     */  
/* 30-Nov-2014  NJOW04  1.9   330996-OTM Plan Mode Allocation Checking  */  
/* 24-Apr-2015  CSCHONG 2.0   Fix bugs (CS01)                           */    
/* 07-Oct-2015  NJOW05  2.1   353920 - Allocation extended validation   */  
/* 20-Nov-2015  NJOW06  2.2   Fix lottable06-15                         */  
/* 20-Nov-2015  NJOW07  2.3   312318-Full pallet determind by pallet    */  
/*                            Id & Loc. Work with skip preallocation.   */  
/*                            @c_OtherValue=FULLPALLET                  */  
/* 20-Nov-2015  NJOW08  2.4   336160-if over allocation can't find pick */  
/*                            loc, able skip to next strategy.          */  
/* 20-Nov-2015  NJOW09  2.5   345748 - Get casecnt from lottable        */  
/* 01-Mar-2016  NJOW10  2.6   Fix - PostProcessingStrategyKey still run */  
/*                            if n_continue=4 no order lines            */  
/* 11-Aug-2016  NJOW11  2.7  374687-Allowoverallocations storerconfig   */  
/*                           control by facility                        */  
/* 20-Sep-2016  NJOW12  2.8   Delete Preallocatepickdetail by looping   */   
/* 24-Feb-2017  Wan01   2.9   WMS-1106 - CN-Nike SDC WMS Allocation     */  
/*                            Strategy                                  */  
/* 18-Jun-2017  NJOW13  3.0   WMS-1577 UCC allocation by pickcode.      */  
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
/* 10-Oct-2017  NJOW14  3.1   WMS-2819 - Add other parameter to calling */  
/*                            pickcode. Try conso carton by load        */  
/* 05-Dec-2017  NJOW15  3.2   Check Facility Lot Qty Available          */  
/* 21-Dec-2017  NJOW16  3.3   WMS-3642 Get dynamic UOM qty from pickcode*/  
/*                            @c_LocType='UOM=xxx'. It will overwrite   */  
/*                            the UOM qty from packkkey. only work for  */  
/*                            skippreallocation.                        */  
/* 30-Mar-2018  NJOW17  3.4   WMS-4293 able to group and send custom    */  
/*                            field to pickcode for custom filtering    */      
/* 17-Apr-2018  NJOW18  3.5   WMS-4345 add allocation pre/post process  */      
/* 19-Jul-2018  NJOW19  3.6   WMS-5745 Standard Pre/Post allocation process*/  
/* 20-Apr-2018  SWT01   3.7   Channel Management Check Qty Available    */     
/* 18-Jan-2019  NJOW20  3.8   Fix get channel id                        */  
/* 07-MAR-2019  NJOW21  3.9   Fix search order line lottable filtering  */  
/*                            for skip preallocation.                   */  
/* 18-Jun-2019  NJOW22  4.0   WMS-8575 Fix - if one loc/id has multiple */  
/*                            pallet will cause conso pallet assign to  */  
/*                            order line duplication problem            */  
/* 10-Sep-2019  NJOW23  4.1   WMS-10479 Allocation based on orderdetail */  
/*                            packkey by config.                        */   
/* 23-JUL-2019  Wan02   4.2   ChannelInventoryMgmt use nspGetRight2     */  
/* 23-JUL-2019  Wan03   4.2   WMS - 9914 [MY] JDSPORTSMY - Channel      */  
/*                            Inventory Ignore QtyOnHold - CR           */  
/* 08-Jan-2020  NJOW24  4.3   WMS-10420 add strategykey parameter.      */    
/*                            Support HOSTWHCODE. Add FULFILLBYORDER    */   
/* 12-Feb-2020  Wan04   4.3   SQLBindParm. Create Temp table to Store   */  
/*                            Preallocate data from pickcode            */   
/* 18-Feb-2020  Wan05   4.3   WMS-11774                                 */           
/* 27-Mar-2020  NJOW25  4.4   WMS-12491 Get Over allocation pick loc by */  
/*                            Custom SP                                 */  
/* 01-Dec-2020  NJOW26  4.5   WMS-15746 get channel hold qty by config  */    
/* 10-Sep-2021  LZG     4.6   JSM-19631 - Wrong PD.Channel bug fix(ZG01)*/
/* 21-Apr-2022  NJOW27  4.7   WMS-19078 support UOM by Load/Order for   */
/*                            skip preallocation only.                  */
/*                            Pass in AllocateStrategyKey and           */
/*                            AllocateStrategyLineNumber to pickcode.   */
/*                            othervalue enhancements.                  */
/*                            Add custom sp config to update OPORDERLINES*/
/* 21-Apr-2022  NJOW27  4.8   DEVOPS Combine script                     */
/* 18-MAY-2022  NJOW28  4.9   WMS-19173 UCC allocation not allow partial*/
/*                            UCC if the channel insufficient stock     */
/* 27-SEP-2022  NJOW29  5.0   WMS-20812 Pass in additional parameters to*/
/*                            isp_ChannelAllocGetHoldQty_Wrapper        */ 
/* 16-May-2024  Wan06   6.0   UWP-19537-Mattel Overallocation           */
/* 23-May-2024  Wan07   7.0   UWP-19537-Bug fixing Insert NULL          */
/* 08-Jul-2024  Wan08   7.1   UWP-19537-Mattel Overallocation           */
/*                            Get OverPickLoc from Sub SP               */
/* 18-Jul-2024  Wan09   7.2   UWP-22202-Mattel Overallocation           */
/*                            Get OverQtyLeftToFulfill from Sub SP      */
/*                            Do Not Overallocate to partial fulfill DPP*/
/************************************************************************/      

CREATE   PROC [dbo].[ispWaveProcessing]        
     @c_WaveKey NVARCHAR(10)        
   , @b_Success INT           OUTPUT        
   , @n_Err     INT           OUTPUT        
   , @c_ErrMsg  NVARCHAR(250) OUTPUT        
   , @b_debug   INT = 0   
   , @c_StrategykeyParm NVARCHAR(10) = '' --NJOW24            
AS        
BEGIN        
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
        
   DECLARE  @n_Continue                 INT,        
            @n_StartTCnt                INT, -- Holds the current transaction count        
            @n_cnt                      INT, -- Holds @@ROWCOUNT after certain operations        
            @c_PreProcess               NVARCHAR(250), -- PreProcess        
            @c_PstProcess               NVARCHAR(250), -- post process        
            @n_Err2                     INT, -- For Additional Error Detection        
            @c_FromLoc                  NVARCHAR(10),        
            @c_ToLoc                    NVARCHAR(10),        
            @c_Facility                 NVARCHAR(10),        
            @n_Fetch_Status             INT,        
            @c_Lottable01               NVARCHAR(18),        
            @c_Lottable02               NVARCHAR(18),        
            @c_Lottable03               NVARCHAR(18),        
            @d_Lottable04               DATETIME,        
            @d_Lottable05               DATETIME,        
            @c_SuperFlag                NVARCHAR(1),        
            @c_OtherParms               NVARCHAR(200),        
            @c_Orderinfo4Allocation     NVARCHAR(1),        
            @c_SkipPreAllocationFlag    NVARCHAR(1),        
            @c_StorerKey                NVARCHAR(15),      
            @c_PreProcessingStrategyKey NVARCHAR(30), -- Chee01      
            @c_AllocateUCCPackSize      NVARCHAR(1),  -- Shong01      
            @c_PostProcessingStrategyKey NVARCHAR(30),  -- Chee02      
            @c_PickOverAllocateNoMixLot NVARCHAR(10), --NJOW01  
            @c_SQL                      NVARCHAR(MAX), --NJOW05  
            @c_AllocateValidationRules  NVARCHAR(30), --NJOW05  
            @c_AllocateGetCasecntFrLottable NVARCHAR(10), --NJOW09  
            @c_CaseQty                  NVARCHAR(30), --NJOW09  
            @c_PreAllocatePickDetailKey NVARCHAR(10), --NJOW12  
            @c_UCCAllocation            NVARCHAR(30), --NJOW13  
            @c_UCCNo                    NVARCHAR(20), --NJOW13  
            @c_PrevUCCNo                NVARCHAR(20),  --NJOW13  
            @c_WaveConsoAllocationOParms NVARCHAR(10), --NJOW14  
            @n_LotAvailableQty          INT, --NJOW15  
            @n_FacLotAvailQty           INT = 0,      --NJOW15  
            @n_dynUOMQty                INT, --NJOW16  
            @c_PostAllocationSP         NVARCHAR(200), --NJOW18      
            @c_PreAllocationSP          NVARCHAR(200),  --NJOW18      
            @c_aPrevLot                 NVARCHAR(10), --NJOW20  
            @c_AllocateByOrderPackkey   NVARCHAR(30), --NJOW23  
            @c_OtherParmsExist          NVARCHAR(10), --NJOW24    
            @c_OverAllocPickByHostWHCode  NVARCHAR(30), --NJOW24                        
            @c_WaveConsoAllocation        NVARCHAR(10), --NJOW24  
            @c_WconsoOption1              NVARCHAR(50), --NJOW24  
            @c_WconsoOption2              NVARCHAR(50), --NJOW24  
            @c_WconsoOption3              NVARCHAR(50), --NJOW04  
            @c_WconsoOption4              NVARCHAR(50), --NJOW24  
            @c_WconsoOption5              NVARCHAR(4000), --NJOW24  
            @c_OverAllocPickLoc_SP        NVARCHAR(30), --NJOW25              
            @n_OverAlQtyLeftToFulfill     INT,          --NJOW25  
            @n_ChannelHoldQty             INT,           --NJOW07  
            @c_Loadkey                    NVARCHAR(10), --NJOW27      
            @c_PrevOrderkey               NVARCHAR(10), --NJOW27
            @c_PrevLoadkey                NVARCHAR(10), --NJOW27
            @n_TotalQty                   INT,          --NJOW27            
            @c_UOMByLoad                  NVARCHAR(10), --NJOW27
            @c_UOMByOrder                 NVARCHAR(10), --NJOW27
            @c_FullPallet                 NVARCHAR(10), --NJOW27
            @c_DYNUOMQty                  NVARCHAR(10)  --NJOW27
                
    --NJOW17  
    DECLARE @c_OparmsOption1             NVARCHAR(50),   
            @c_OparmsOption2             NVARCHAR(50),   
            @c_OparmsOption3             NVARCHAR(50),   
            @c_OparmsOption4             NVARCHAR(50),   
            @c_OparmsOption5             NVARCHAR(4000),   
            @c_SelectField               NVARCHAR(4000),  
            @c_GroupField                NVARCHAR(4000),  
            @c_Oparms                    NVARCHAR(200)              
           ,@c_ChannelInventoryMgmt      NVARCHAR(10) = '0' -- (SWT01)    
           ,@c_Channel                   NVARCHAR(20) = '' --(SWT01)  
           ,@n_Channel_ID                BIGINT = 0        --(SWT01)   
           ,@n_Channel_Qty_Available     INT = 0             
           ,@n_AllocatedHoldQty          INT = 0                             
              
   DECLARE   
         @c_Lottable06 NVARCHAR(30),              @c_Lottable07 NVARCHAR(30),  
         @c_Lottable08 NVARCHAR(30),              @c_Lottable09 NVARCHAR(30),   
         @c_Lottable10 NVARCHAR(30),              @c_Lottable11 NVARCHAR(30),   
         @c_Lottable12 NVARCHAR(30),                
         @d_Lottable13 Datetime,     @d_Lottable14 Datetime,   
         @d_Lottable15 Datetime,                  @c_Lottable13 NVARCHAR(30),                
         @c_Lottable14 NVARCHAR(30),              @c_Lottable15 NVARCHAR(30),   
         @c_Lottable_Parm NVARCHAR(20),           @c_SQLExecute NVARCHAR(4000),  
         @c_Lottable04 NVARCHAR(30),              @c_Lottable05 NVARCHAR(30) --NJOW06            
  
   DECLARE   
         @c_ParameterName NVARCHAR(200),          @n_OrdinalPosition INT   
        
   DECLARE  @c_PHeaderKey NVARCHAR(18),        
            @c_CaseId     NVARCHAR(10) 
            
   DECLARE @c_OverPickLoc              NVARCHAR(10)                                 --(Wan08)       
   DECLARE @CUR_ADDSQL                 CURSOR                                       --(Wan09)       
       
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=0, @n_Err=0,@n_cnt = 0        
   SELECT @c_ErrMsg='',@n_Err2=0        
        
   DECLARE @n_cnt_sql     INT  -- Additional holds for @@ROWCOUNT to try catch a wrong processing        
        
   /* #INCLUDE <SPOP1.SQL> */        
        
   DECLARE @c_authority NVARCHAR(1)        
        
   IF @n_Continue=1 OR @n_Continue=2        
   BEGIN        
      IF ISNULL(RTRIM(@c_WaveKey),'') = ''        
      BEGIN        
         SELECT @n_Continue = 3        
         SELECT @n_Err = 63500        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Parameters Passed (ispWaveProcessing)'        
      END        
   END -- @n_Continue =1 or @n_Continue = 2        
        
   DECLARE @d_StartTime    DATETIME,        
           @d_EndTime      DATETIME,        
           @d_Step1        DATETIME,        
           @d_Step2        DATETIME,        
           @d_Step3        DATETIME,        
           @d_Step4        DATETIME,        
           @d_Step5        DATETIME,        
           @c_Col1         NVARCHAR(20),        
           @c_Col2         NVARCHAR(20),        
           @c_Col3         NVARCHAR(20),        
           @c_Col4         NVARCHAR(20),        
           @c_Col5         NVARCHAR(20),        
           @c_TraceName    NVARCHAR(80)        
        
   SET @d_StartTime = GETDATE()        
        
   SET @c_TraceName = 'ispWaveProcessing'        
   PRINT 'Control Reached at ispWaveProcessing... '
  --NJOW04 Start  
   EXECUTE dbo.isp_OTMPlanModeAllocationCheck   
           '' --@c_OrderKey  
         , '' --@c_LoadKey   
         , @c_Wavekey    
         , @b_Success  OUTPUT    
         , @n_Err      OUTPUT     
         , @c_ErrMsg   OUTPUT    
  
   IF @b_Success <> 1  
   BEGIN    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END    
   --NJOW04 End  
      
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      DECLARE @c_OPRun NVARCHAR(9)        
      SELECT @b_Success = 0        
      EXECUTE nspg_getkey        
            'OPRun'        
            , 9        
            , @c_OPRun   OUTPUT        
            , @b_Success OUTPUT        
            , @n_Err     OUTPUT        
            , @c_ErrMsg  OUTPUT        
   END        
   
   SET @d_Step1 = GETDATE() -- (tlting01)        
        
   SET @c_SkipPreAllocationFlag= '0'        
        
   SELECT TOP 1 @c_StorerKey = O.StorerKey,        
                @c_Facility  = O.Facility        
   FROM   WAVEDETAIL WD WITH (NOLOCK)        
   JOIN   ORDERS o WITH (NOLOCK) ON O.OrderKey = WD.OrderKey        
   WHERE  WD.WaveKey = @c_WaveKey        
   
   --NJOW05 Start                   
   SELECT TOP 1 @c_AllocateValidationRules = SC.sValue  
   FROM STORERCONFIG SC (NOLOCK)  
   JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname  
   WHERE SC.StorerKey = @c_StorerKey  
   AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')  
   AND SC.Configkey = 'PreAllocateExtendedValidation'  
   ORDER BY SC.Facility DESC  
   
   PRINT @c_AllocateValidationRules
   IF ISNULL(@c_AllocateValidationRules,'') <> ''  
   BEGIN  
   
      EXEC isp_Allocate_ExtendedValidation @c_Orderkey = '',  
                                           @c_Loadkey = '',  
                                           @c_Wavekey = @c_Wavekey,  
                                           @c_Mode = 'PRE',  
                                           @c_AllocateValidationRules=@c_AllocateValidationRules,  
                                           @b_Success=@b_Success OUTPUT,   
                                           @c_ErrMsg=@c_ErrMsg OUTPUT           
                                               
      IF @b_Success <> 1    
      BEGIN    
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END    
   END  
   ELSE     
   BEGIN  
      SELECT TOP 1 @c_AllocateValidationRules = SC.sValue      
      FROM STORERCONFIG SC (NOLOCK)   
      WHERE SC.StorerKey = @c_StorerKey   
      AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')  
      AND SC.Configkey = 'PreAllocateExtendedValidation'      
      ORDER BY SC.Facility DESC  
                 
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_AllocateValidationRules) AND type = 'P')            
      BEGIN            
         SET @c_SQL = 'EXEC ' + @c_AllocateValidationRules + ' @c_Orderkey, @c_Loadkey, @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
         EXEC sp_executesql @c_SQL,            
              N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                           
              '',            
              '',  
              @c_Wavekey,  
              @b_Success OUTPUT,            
              @n_Err OUTPUT,            
              @c_ErrMsg OUTPUT  
                    
         IF @b_Success <> 1       
         BEGIN      
            EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
            RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
            RETURN  
         END           
      END    
   END              
   --NJOW05 End     
  
   --NJOW19 Start        
   EXEC isp_PrePostAllocate_Process @c_Orderkey = '',  
                                    @c_Loadkey = '',  
                                    @c_Wavekey = @c_Wavekey,  
                                    @c_Mode = 'PRE',  
                                    @c_extendparms = 'WP',  
                                    @c_StrategykeyParm = @c_StrategykeyParm, --NJOW24                                                                           
                                    @b_Success = @b_Success OUTPUT,            
                                    @n_Err = @n_err OUTPUT,            
                                    @c_Errmsg = @c_errmsg OUTPUT  
	                                      
   IF @b_Success <> 1    
   BEGIN  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END       
   --NJOW19 End                       
  
   --NJOW18 Start  
   SET @c_PreAllocationSP = ''  
                                 
   EXEC nspGetRight    
        @c_Facility  = @c_Facility,   
        @c_StorerKey = @c_StorerKey,    
        @c_sku       = NULL,    
        @c_ConfigKey = 'PreAllocationSP',     
        @b_Success   = @b_Success                  OUTPUT,    
        @c_authority = @c_PreAllocationSP          OUTPUT,     
        @n_err       = @n_err                      OUTPUT,     
        @c_errmsg    = @c_errmsg                   OUTPUT    
  
   SET @c_ChannelInventoryMgmt = '0'  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      Select @b_success = 0  
      Execute nspGetRight2 --(Wan02)    
      @c_Facility,  
      @c_StorerKey,   -- Storer  
      NULL,           -- Sku  
      'ChannelInventoryMgmt',  -- ConfigKey  
      @b_success    output,  
      @c_ChannelInventoryMgmt  output,  
      @n_Err        output,  
      @c_ErrMsg     output  
      If @b_success <> 1  
      Begin  
         Select @n_continue = 3, @c_ErrMsg = 'ispWaveProcessing:' + ISNULL(RTRIM(@c_ErrMsg),'')  
      END  
   END    
     
   IF EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PreAllocationSP AND TYPE = 'P')     
      OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PreAllocationSP)  
   BEGIN    
      SET @b_Success = 0    
        
      EXECUTE dbo.ispPreAllocationWrapper   
              @c_OrderKey = ''  
            , @c_LoadKey  = ''  
            , @c_Wavekey = @c_Wavekey    
            , @c_PreAllocationSP = @c_PreAllocationSP    
            , @b_Success = @b_Success     OUTPUT    
            , @n_Err     = @n_err         OUTPUT     
            , @c_ErrMsg  = @c_errmsg      OUTPUT    
            , @b_debug   = 0   
  SELECT @b_Success, @c_PreAllocationSP, @c_errmsg
      IF @b_Success <> 1    
      BEGIN    
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END       
   END        
   --NJOW18 End       
            
   -- Shong01 AllocateUCCPackSize      
   SET @c_AllocateUCCPackSize = '0'      
   EXEC nspGetRight        
        @c_Facility  = @c_facility,  --NJOW19      
        @c_StorerKey = @c_StorerKey,        
        @c_sku       = NULL,        
        @c_ConfigKey = 'AllocateUCCPackSize',        
        @b_Success   = @b_Success                  OUTPUT,        
        @c_authority = @c_AllocateUCCPackSize      OUTPUT,        
        @n_err       = @n_err                      OUTPUT,        
        @c_errmsg    = @c_errmsg                   OUTPUT           
         
   SET @c_AllocateUCCPackSize = ISNULL(@c_AllocateUCCPackSize, '0')      
      
   -- Chee01      
   IF (@n_Continue = 1 OR @n_Continue = 2)      
   BEGIN        
      EXEC nspGetRight        
           @c_Facility  = @c_Facility,                --(Wan01)   
           @c_StorerKey = @c_StorerKey,           
           @c_sku       = NULL,        
           @c_ConfigKey = 'PreProcessingStrategyKey',        
           @b_Success   = @b_Success                  OUTPUT,        
           @c_authority = @c_PreProcessingStrategyKey OUTPUT,        
           @n_err       = @n_err                      OUTPUT,        
           @c_errmsg    = @c_errmsg                   OUTPUT        
        
      IF (@n_Continue = 1 OR @n_Continue = 2) AND ISNULL(RTRIM(@c_PreProcessingStrategyKey),'') <> ''        
      BEGIN        
         SELECT @b_Success = 0        
      
         EXECUTE dbo.ispPreProcessing        
                 @c_WaveKey         
               , @c_PreProcessingStrategyKey        
               , @b_Success OUTPUT        
               , @n_Err     OUTPUT        
               , @c_ErrMsg  OUTPUT        
               , @b_debug       
      
         SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
         IF @n_Err <> 0        
         BEGIN        
            SELECT @n_Continue = 3        
   --         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
   --         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': ispPreProcessing Failed (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
         END        
      END  -- IF ISNULL(RTRIM(@c_PreProcessingStrategyKey),'') <> ''       
   END -- IF (@n_Continue = 1 OR @n_Continue = 2)      
         
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN      
      EXEC nspGetRight        
           @c_Facility  = @c_Facility, --NJOW19        
           @c_StorerKey = @c_StorerKey,        
           @c_sku       = NULL,        
           @c_ConfigKey = 'SkipPreAllocation',        
           @b_Success   = @b_Success               OUTPUT,        
           @c_authority = @c_SkipPreAllocationFlag OUTPUT,        
           @n_err       = @n_err                   OUTPUT,        
           @c_errmsg    = @c_errmsg                OUTPUT        
           
      IF (@n_Continue = 1 OR @n_Continue = 2) AND ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
      BEGIN        
         SELECT @b_Success = 0        
           
         EXECUTE dbo.ispPreAllocateWaveProcessing          
            @c_WaveKey = @c_WaveKey          
               , @c_oprun = @c_OPRun          
               , @b_Success = @b_Success OUTPUT          
               , @n_err = @n_Err  OUTPUT          
               , @c_errmsg = @c_ErrMsg  OUTPUT          
               , @b_Debug = @b_debug          
               , @c_StrategykeyParm = @c_StrategykeyParm --NJOW24      
      END        
   END -- IF @n_Continue = 1 OR @n_Continue = 2        
     
   --NJOW14  
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN            
   EXEC nspGetRight  
        @c_Facility  = @c_Facility,  
        @c_StorerKey = @c_StorerKey,  
        @c_sku       = NULL,  
        @c_ConfigKey = 'Orderinfo4Allocation',  
        @b_Success   = @b_Success               OUTPUT,  
        @c_authority = @c_Orderinfo4Allocation  OUTPUT,  
        @n_err       = @n_err                   OUTPUT,  
        @c_errmsg    = @c_errmsg                OUTPUT  
  
   EXEC nspGetRight  
        @c_Facility  = @c_Facility,  
        @c_StorerKey = @c_StorerKey,  
        @c_sku       = NULL,  
        @c_ConfigKey = 'WaveConsoAllocationOParms',  
        @b_Success   = @b_Success                   OUTPUT,  
        @c_authority = @c_WaveConsoAllocationOParms OUTPUT,  
        @n_err       = @n_err                       OUTPUT,  
        @c_errmsg    = @c_errmsg                    OUTPUT,  
        @c_Option1 = @c_OparmsOption1 OUTPUT,   --NJOW17  
        @c_Option2 = @c_OparmsOption2 OUTPUT,  
        @c_Option3 = @c_OparmsOption3 OUTPUT,  
        @c_Option4 = @c_OparmsOption4 OUTPUT,  
        @c_Option5 = @c_OparmsOption5 OUTPUT          
   END          
     
   --NJOW23  
   EXEC nspGetRight  
        @c_Facility  = @c_Facility,  
        @c_StorerKey = @c_StorerKey,  
        @c_sku       = NULL,  
        @c_ConfigKey = 'AllocateByOrderPackkey',  
        @b_Success   = @b_Success                OUTPUT,  
        @c_authority = @c_AllocateByOrderPackkey OUTPUT,  
        @n_err       = @n_err                    OUTPUT,  
        @c_errmsg    = @c_errmsg                 OUTPUT           
        
   --NJOW24 S       
   EXEC nspGetRight    
        @c_Facility  = @c_Facility,    
        @c_StorerKey = @c_StorerKey,    
        @c_sku       = NULL,    
        @c_ConfigKey = 'OverAllocPickByHostWHCode',    
        @b_Success   = @b_Success                OUTPUT,    
        @c_authority = @c_OverAllocPickByHostWHCode OUTPUT,    
        @n_err       = @n_err                    OUTPUT,    
        @c_errmsg    = @c_errmsg                 OUTPUT      
  
   EXEC nspGetRight  
        @c_Facility  = @c_Facility,  
        @c_StorerKey = @c_StorerKey,  
        @c_sku       = NULL,  
        @c_ConfigKey = 'WaveConsoAllocation',  
        @b_Success   = @b_Success                   OUTPUT,  
        @c_authority = @c_WaveConsoAllocation       OUTPUT,  
        @n_err       = @n_err                       OUTPUT,  
        @c_errmsg    = @c_errmsg                    OUTPUT,  
        @c_Option1 = @c_WConsoOption1 OUTPUT,     
        @c_Option2 = @c_WConsoOption2 OUTPUT,  
        @c_Option3 = @c_WConsoOption3 OUTPUT,  
        @c_Option4 = @c_WConsoOption4 OUTPUT,  
        @c_Option5 = @c_WConsoOption5 OUTPUT          
   --NJOW24 E       
  
   --NJOW25 S  
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
   --NJOW25 E                  
          
   --(Wan04) - START  
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
      ,  OtherValue     NVARCHAR(500)  NOT NULL DEFAULT('')     --NJOW27
      )  
   END  
   --(Wan04) - END  
            
                
   SET @d_Step1 = GETDATE() - @d_Step1 -- (tlting01)        
   SET @c_Col1 = 'Stp1-Prealloc' -- (tlting01)        
        
   IF @b_debug = 1 OR @b_debug = 2        
   BEGIN        
      PRINT ''        
      PRINT ''        
      PRINT '*********************************************************'        
      PRINT 'Allocation: Started at ' + CONVERT(NVARCHAR(20), GETDATE())        
      PRINT '*********************************************************'        
      PRINT '@c_SkipPreAllocationFlag = ' + @c_SkipPreAllocationFlag        
   END        
        
   SET @d_Step2 = GETDATE()        
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      DECLARE @d_OrderDateStart      DATETIME,        
              @d_OrderDateEnd        DATETIME,        
              @d_DeliveryDateStart   DATETIME,        
              @d_DeliveryDateEnd     DATETIME,        
              @c_OrderTypeStart      NVARCHAR(10),        
              @c_OrderTypeEnd        NVARCHAR(10),        
              @c_OrderPriorityStart  NVARCHAR(10),        
              @c_OrderPriorityEnd    NVARCHAR(10),        
              @c_StorerKeyStart      NVARCHAR(15),        
              @c_StorerKeyEnd        NVARCHAR(15),        
              @c_ConsigneeKeyStart   NVARCHAR(15),        
              @c_ConsigneeKeyEnd     NVARCHAR(15),        
              @c_CarrierKeyStart     NVARCHAR(15),        
              @c_CarrierKeyEnd       NVARCHAR(15),        
              @c_OrderKeyStart       NVARCHAR(10),        
              @c_OrderKeyEnd         NVARCHAR(10),        
              @c_ExternOrderKeyStart NVARCHAR(30),        
              @c_ExternOrderKeyEnd   NVARCHAR(30),        
              @c_OrderGroupStart     NVARCHAR(20),        
              @c_OrderGroupEnd       NVARCHAR(20),        
              @n_MaxOrders           INT,        
              @d_LoadingDateStart    DATETIME,        
              @d_LoadingDateEnd      DATETIME,        
              @c_RouteStart          NVARCHAR(10),        
              @c_RouteEnd            NVARCHAR(10),        
              @c_CaseQtyXFactor      NVARCHAR(10), -- SHONG03        
              @c_OrderType           NVARCHAR(10)  -- SHONG03        
        
      CREATE TABLE #OPORDERLINES (        
         [SeqNo]                  [INT] IDENTITY(1, 1),        
         [PreAllocatePickDetailKey] [NVARCHAR](10) NOT NULL,        
         [OrderKey]                 [NVARCHAR](10) NOT NULL,        
         [OrderLineNumber]          [NVARCHAR](5)  NOT NULL,        
         [Storerkey]                [NVARCHAR](15) NOT NULL,        
         [Sku]                      [NVARCHAR](20) NOT NULL,        
         [Lot]                      [NVARCHAR](10) NOT NULL,        
         [UOM]                      [NVARCHAR](10)  NOT NULL,        
         [UOMQty]            [int]      NOT NULL,        
         [Qty]                      [int]      NOT NULL,        
         [Packkey]                  [NVARCHAR](10) NOT NULL,        
         [WaveKey]                  [NVARCHAR](10) NOT NULL,        
         [PreAllocateStrategyKey]   [NVARCHAR](10) NOT NULL,        
         [PreAllocatePickCode]      [NVARCHAR](10) NOT NULL,        
         [DoCartonize]              [NVARCHAR](1)  NOT NULL,        
         [PickMethod]               [NVARCHAR](1)  NOT NULL,        
         [CARTONGROUP]              [NVARCHAR](10) NOT NULL,        
         [StrategyKey]              [NVARCHAR](10) NOT NULL,        
         [Facility]                 [NVARCHAR](5)  NOT NULL,  
         [Channel]                  [NVARCHAR](20) NOT NULL)        
        
      IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
      BEGIN        
         INSERT #OPORDERLINES        
         SELECT  [PREALLOCATEPICKDETAIL].[PreAllocatePickDetailKey],        
            [PREALLOCATEPICKDETAIL].[OrderKey],        
            [PREALLOCATEPICKDETAIL].[OrderLineNumber],        
            [PREALLOCATEPICKDETAIL].[Storerkey],        
            [PREALLOCATEPICKDETAIL].[Sku],        
            [PREALLOCATEPICKDETAIL].[Lot],        
            [PREALLOCATEPICKDETAIL].[UOM],        
            [PREALLOCATEPICKDETAIL].[UOMQty],        
            [PREALLOCATEPICKDETAIL].[Qty],        
            [PREALLOCATEPICKDETAIL].[Packkey],        
            [PREALLOCATEPICKDETAIL].[WaveKey],        
            [PREALLOCATEPICKDETAIL].[PreAllocateStrategyKey],        
            [PREALLOCATEPICKDETAIL].[PreAllocatePickCode],        
            [PREALLOCATEPICKDETAIL].[DoCartonize],        
            [PREALLOCATEPICKDETAIL].[PickMethod],        
            CARTONGROUP = ISNULL(SKU.CartonGroup, SPACE(10)),        
            StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, SPACE(10)),        
            ORDERS.Facility,  
            Channel = ISNULL(OD.Channel,'') -- SWT01        
         FROM ORDERS (NOLOCK)        
         JOIN PREALLOCATEPICKDETAIL (NOLOCK) ON PREALLOCATEPICKDETAIL.OrderKey = ORDERS.OrderKey      
         JOIN ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = PREALLOCATEPICKDETAIL.OrderKey AND OD.OrderLineNumber = PREALLOCATEPICKDETAIL.OrderLineNumber     
         JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey       
         JOIN SKU (NOLOCK) ON PREALLOCATEPICKDETAIL.StorerKey = SKU.StorerKey        
                          AND PREALLOCATEPICKDETAIL.SKU = SKU.SKU        
         JOIN STRATEGY (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey        
         WHERE ORDERS.Status < '9'        
         AND WAVEDETAIL.WaveKey = @c_WaveKey        
         AND PREALLOCATEPICKDETAIL.Qty > 0        
         ORDER BY ORDERS.Priority, [PREALLOCATEPICKDETAIL].[OrderKey], [PREALLOCATEPICKDETAIL].[OrderLineNumber]      
      END        
      ELSE        
      BEGIN        
         INSERT INTO #OPORDERLINES        
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
            CASE WHEN @c_AllocateByOrderPackkey = '1' THEN   
              OD.Packkey ELSE SKU.Packkey END,  --NJOW23  
            WaveKey = '',        
            PreAllocateStrategyKey = '',        
            PreAllocatePickCode = '',        
            DoCartonize = 'N',        
            PickMethod = '',        
            CARTONGROUP = ISNULL(SKU.CartonGroup, SPACE(10)),        
            StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, SPACE(10)),        
            ORDERS.Facility,  
            Channel = ISNULL(OD.Channel,'') -- SWT01            
         FROM ORDERDETAIL OD WITH (NOLOCK)        
         JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku        
         JOIN STRATEGY (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey        
         JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = OD.OrderKey        
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey      
         WHERE WD.WaveKey = @c_WaveKey AND        
               ORDERS.Type NOT IN ( 'M', 'I' ) AND        
               ORDERS.SOStatus <> 'CANC' AND        
               ORDERS.Status < '9' AND        
           (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0        
         ORDER BY ORDERS.Priority, OD.OrderKey, OD.OrderLineNumber      
      END        
        
      IF ISNULL(@c_StrategykeyParm,'') <> ''  --NJOW24    
      BEGIN    
         UPDATE TMP      
         SET StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, '')      
         FROM #OPORDERLINES TMP      
         JOIN STRATEGY     WITH (NOLOCK) ON  STRATEGY.Strategykey = @c_StrategykeyParm                    
      END    
      ELSE    
      BEGIN          
         -- (Wan01) - START  
         UPDATE TMP  
               SET StrategyKey = ISNULL(STRATEGY.AllocateStrategyKey, '')  
         FROM #OPORDERLINES TMP  
         JOIN STORERCONFIG WITH (NOLOCK) ON (StorerConfig.Facility = TMP.Facility)  
                                         AND(StorerConfig.Storerkey= TMP.Storerkey)   
                                         AND(StorerConfig.ConfigKey= 'StorerDefaultAllocStrategy')   
         JOIN STRATEGY     WITH (NOLOCK) ON (StorerConfig.SValue = STRATEGY.Strategykey)  
         -- (Wan01) - END  
      END  
        
      DECLARE @c_bStorerKey  NVARCHAR(15),        
              @c_bSKU        NVARCHAR(20),        
              @c_bLOT        NVARCHAR(10),        
              @c_bUOM        NVARCHAR(10),        
              @n_bQty        INT,        
              @n_TotPackQty  INT,        
              @n_bRemindQty  INT,        
              @n_PackQty     INT,        
              @n_SeqNo       INT        
        
      IF @n_Continue = 1 OR @n_Continue = 2        
      BEGIN        
         SELECT @n_cnt = COUNT(*) FROM #OPORDERLINES        
         IF @n_cnt = 0        
         BEGIN        
            SELECT   @n_Continue = 4        
            SELECT   @n_Err = 63511        
            SELECT   @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) +        
                                 ': No Order Lines To Process. (ispWaveProcessing)'        
            EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'        
         END        
         ELSE        
         IF ( @b_debug = 1 OR @b_debug = 2 )        
         BEGIN        
            PRINT 'Number of Order Lines Pre-Allocated: ' + CAST(@n_cnt AS NVARCHAR(5))        
         END        
      END -- @n_Continue = 1 or @n_Continue = 2        
   END -- @n_Continue = 1 or @n_Continue = 2        
        
   SET @d_Step2 = GETDATE() - @d_Step2 -- (tlting01)        
   SET @c_Col2 = 'Stp2-InsertPrealloc' -- (tlting01)        
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      DECLARE @c_CartonizationGroup    NVARCHAR(10),        
              @c_RoutingKey            NVARCHAR(10),        
              @c_PickCode              NVARCHAR(10),        
              @c_DoRouting             NVARCHAR(1),        
              @c_DoCartonization       NVARCHAR(1),        
              @c_PreAllocationGrouping NVARCHAR(10),        
              @c_PreAllocationSort     NVARCHAR(10),        
              @c_WaveOption            NVARCHAR(10),        
              @n_BatchPickMaxCube      INT,        
              @n_BatchPickMaxCount     INT,        
              @c_WorkOSKey             NVARCHAR(10)        
        
      SELECT @c_CartonizationGroup = CartonizationGroup ,        
             @c_RoutingKey = RoutingKey ,        
             @c_PickCode = PickCode ,        
             @c_PreAllocationGrouping = PreAllocationGrouping ,        
             @c_PreAllocationSort = PreAllocationSort ,        
             @c_WaveOption = WaveOption ,        
             @n_BatchPickMaxCube = BatchPickMaxCube ,        
             @n_BatchPickMaxCount = BatchPickMaxCount ,        
             @c_WorkOSKey = OrderSelectionKey        
        FROM ORDERSELECTION (NOLOCK)        
       WHERE DefaultFlag = '1'        
        
      SELECT @n_cnt = @@ROWCOUNT        
  
      --NJOW03 Start  
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
      --NJOW03 End  
              
      IF @n_cnt = 0        
      BEGIN        
         SELECT @n_Continue = 3        
         SELECT @n_Err = 63512        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Incomplete Orderselection Parameters! (ispWaveProcessing)'        
      END        
   END -- @n_Continue = 1 or @n_Continue = 2        
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.CartonGroup = SPACE(10) )        
      BEGIN        
         UPDATE #OPORDERLINES SET CARTONGROUP = Storer.CartonGroup        
           FROM #OPORDERLINES, Storer (NOLOCK)        
          WHERE #OPORDERLINES.StorerKey = Storer.StorerKey        
            AND #OPORDERLINES.CartonGroup = SPACE(10)        
            AND Storer.CartonGroup IS NOT NULL        
      END        
        
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.PackKey = SPACE(10) )        
      BEGIN        
         UPDATE #OPORDERLINES SET PackKey = SKU.PackKey        
           FROM #OPORDERLINES,SKU (NOLOCK)        
          WHERE #OPORDERLINES.StorerKey = SKU.StorerKey        
            AND #OPORDERLINES.SKU = SKU.SKU        
            AND #OPORDERLINES.PackKey = SPACE(10)        
            AND SKU.PackKey IS NOT NULL        
    END        
        
      IF EXISTS(SELECT 1 FROM #OPORDERLINES WHERE #OPORDERLINES.CartonGroup = SPACE(10))        
      BEGIN        
         UPDATE #OPORDERLINES        
         SET CARTONGROUP = @c_CartonizationGroup        
         WHERE CartonGroup = SPACE(10)        
      END        
   END -- @n_Continue = 1 or @n_Continue = 2        
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      CREATE TABLE #OPPICKDETAIL (PickDetailKey   NVARCHAR(10) ,        
                                 PickHeaderKey    NVARCHAR(10) ,        
                                 OrderKey         NVARCHAR(10) ,        
                                 OrderLineNumber  NVARCHAR(10) ,        
                                 StorerKey        NVARCHAR(15) ,        
                                 Sku              NVARCHAR(20) ,        
                                 Loc              NVARCHAR(10) ,        
                                 Lot              NVARCHAR(10) ,        
                                 Id               NVARCHAR(18) ,        
                                 Caseid           NVARCHAR(10) ,        
                                 UOM              NVARCHAR(10) ,        
                                 UOMQty           INT ,        
                                 Qty              INT ,        
                                 PackKey          NVARCHAR(10) ,        
                                 CartonGroup      NVARCHAR(10) ,        
                                 DoReplenish      NVARCHAR(1)  NULL,        
                                 ReplenishZone    NVARCHAR(10) NULL,        
                                 DoCartonize      NVARCHAR(1),        
                                 PickMethod       NVARCHAR(1),  
                                 Channel_ID       NVARCHAR(20) NULL )        
      SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
      IF @n_Err <> 0        
      BEGIN        
         SELECT @n_Continue = 3        
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation Of Temp Table Failed (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
      END        
   END -- @n_Continue = 1 or @n_Continue = 2        
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      DECLARE @c_AllowOverAllocations NVARCHAR(1) -- Flag to see if overallocations are allowed.        
   END        
        
   IF ( @n_Continue = 1 OR @n_Continue = 2 )        
   BEGIN        
      CREATE TABLE #OP_PICKLOCTYPE (loc  NVARCHAR(10) )        
      SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
      IF @n_Err <> 0        
      BEGIN        
         SELECT @n_Continue = 3        
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation Of #OP_PICKLOCTYPE Temp Table Failed (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
      END        
   END        
   IF ( @n_Continue = 1 OR @n_Continue = 2 )        
   BEGIN        
      CREATE TABLE #OP_OVERPICKLOCS (RowNum  INT IDENTITY,        
                                 loc          NVARCHAR(10) ,        
                                    id           NVARCHAR(18) ,        
                                    QtyAvailable INT )        
      SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
      IF @n_Err <> 0        
      BEGIN        
         SELECT @n_Continue = 3        
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation Of #OP_OVERPICKLOCS Temp Table Failed (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
      END        
   END        
   IF ( @n_Continue = 1 OR @n_Continue = 2 )        
   BEGIN        
      CREATE TABLE #OP_PICKLOCS (StorerKey   NVARCHAR(15) ,        
                                 Sku          NVARCHAR(20) ,        
                                 Loc          NVARCHAR(10) ,        
                                 LocationType NVARCHAR(10) )        
      SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
      IF @n_Err <> 0        
      BEGIN        
         SELECT @n_Continue = 3        
     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation Of #OP_PICKLOCS Temp Table Failed (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
      END        
   END        
   -- END -- @c_AllowOverAllocations = '1'        
   
   --NJOW27 Start        
   IF ( @n_Continue = 1 OR @n_Continue = 2 )   
   BEGIN
      EXEC isp_AllocateUpd_OPORDERLINES_Wrapper @c_Orderkey = '',  
                                                @c_Loadkey = '',  
                                                @c_Wavekey = @c_Wavekey,  
                                                @c_Storerkey = @c_Storerkey,
                                                @c_Facility = @c_Facility,
                                                @c_SourceType = 'ispWaveProcessing',  
                                                @b_Success = @b_Success OUTPUT,            
                                                @n_Err = @n_err OUTPUT,            
                                                @c_Errmsg = @c_errmsg OUTPUT  
                                             
      IF @b_Success <> 1    
      BEGIN    
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END       
   END
   --NJOW27 End                       
        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN   
      DECLARE @c_aStorerKey                  NVARCHAR(15),        
              @c_aSKU                        NVARCHAR(20),        
              @c_aOrderKey                   NVARCHAR(10),        
              @c_aOrderLineNumber            NVARCHAR(5),        
              @c_aUOM                        NVARCHAR(10),        
              @n_aUOMQty                     INT,        
              @n_aQtyLeftToFulfill           INT,        
              @c_aPackKey                    NVARCHAR(10),        
              @c_AdoCartonize                NVARCHAR(1),        
              @c_aLOT                        NVARCHAR(10),        
              @c_aPreAllocatePickDetailKey   NVARCHAR(10),        
              @c_aStrategyKey                NVARCHAR(10),        
              @c_Acartongroup                NVARCHAR(10),        
              @c_aPickMethod                 NVARCHAR(1),        
              @c_cLOC                        NVARCHAR(10),        
              @c_cid                         NVARCHAR(18),        
              @n_cQtyAvailable               INT,        
              @c_EndString                   NVARCHAR(500),        
              @n_CursorCandidates_Open       INT,        
              @b_CandidateExhausted          INT,        
              @n_CandidateLine               INT,        
              @n_Available                   INT,        
              @n_QtyToTake                   INT,        
              @n_UOMQty                      INT,        
              @n_cPackQty                    INT,        
              @n_JumpSource                  INT,        
              @c_sCurrentLineNumber          NVARCHAR(5),        
              @c_sAllocatePickCode           NVARCHAR(30),    
              @c_sLocationTypeOverride       NVARCHAR(10),        
              @c_sLocationTypeOverridestripe NVARCHAR(10),        
              @c_PickLoc                     NVARCHAR(10),        
              @b_OverContinue                INT,        
              @c_PickID                      NVARCHAR(18),        
              @n_PickQty                     INT,        
              @n_RowNum                      INT,        
              @n_QtyToOverTake               INT,        
              @n_TempBatchPickQty            INT,        
              @c_PickDetailKey               NVARCHAR(10),        
              @c_PickHeaderKey               NVARCHAR(10),        
              @n_PickRecsCreated             INT,        
              @b_PickUpdateSuccess           INT,        
              @n_QtyToInsert                 INT,        
              @n_UOMQtyToInsert              INT,        
              @c_UOM1PickMethod              NVARCHAR(1),        
              @c_UOM2PickMethod              NVARCHAR(1),        
              @c_UOM3PickMethod              NVARCHAR(1),        
              @c_UOM4PickMethod              NVARCHAR(1),        
              @c_UOM5PickMethod              NVARCHAR(1),        
              @c_UOM6PickMethod              NVARCHAR(1),        
              @c_UOM7PickMethod              NVARCHAR(1),        
              @b_TryIfQtyRemain              INT,        
              @n_NumberOfRetries             INT,        
              @n_CaseQty                     INT,        
              @n_PalletQty                   INT,        
              @n_InnerPackQty                INT,        
              @n_OtherUnit1                  INT,        
              @n_OtherUnit2                  INT,        
              @c_CartonizeCase               NVARCHAR(1),        
              @c_CartonizePallet             NVARCHAR(1),        
              @c_CartonizeInner              NVARCHAR(1),        
              @c_CartonizeOther1             NVARCHAR(1),        
              @c_CartonizeOther2             NVARCHAR(1),        
              @c_CartonizeEA                 NVARCHAR(1),        
              @c_OtherValue                  NVARCHAR(500),  --NJOW27      
              @c_Pallettype                  NVARCHAR(1),        
              @c_OldStrategyKey              NVARCHAR(10),        
              @c_OldCurrentLineNumber        NVARCHAR(5),        
              @c_OldOriginalStrategyKey      NVARCHAR(10),        
              @n_PackBalance                 INT,        
              @n_OriginalPallet              INT,        
              @c_OldSKU                      NVARCHAR(20),        
              @c_HostWHCode                  NVARCHAR(10),        
              @c_aFacility NVARCHAR(5),        
              @c_OldStorerKey                NVARCHAR(15) -- Added by Ricky for IDSV5 to control Overallocation        
            , @n_NextQtyLeftToFulfill INT        
        
      DECLARE @cSuperUOM       NVARCHAR(10),        
              @n_aCaseCnt      FLOAT,        
              @n_aPalletCnt    FLOAT,        
              @n_aInnerPackCnt FLOAT,        
              @c_OldStorer     NVARCHAR(15),        
              @c_OriginUOM     NVARCHAR(10),        
              @n_OriginUOMQty  INT,       -- tlting01        
              @c_BatchUOM      NVARCHAR(10)        
        
      SELECT @b_CandidateExhausted=0, @n_CandidateLine = 0        
      SELECT @n_Available = 0, @n_QtyToTake = 0, @n_UOMQty = 0, @n_cPackQty = 0        
      SELECT @b_TryIfQtyRemain = 1, @n_NumberOfRetries = 0        
        
      /***** Customised For LI & Fung *****/        
        
      SELECT @n_CaseQty = 0, @n_PalletQty=0, @n_InnerPackQty = 0, @n_OtherUnit1=0, @n_OtherUnit2=0        
      SELECT @c_APreAllocatePickDetailKey = SPACE(10), @c_OldSKU = SPACE(20), @c_OldStorer = SPACE(15)        
      SELECT @c_OldStorerKey = SPACE(15) -- Added by Ricky for IDSV5 to control Overallocation        
      SELECT @c_OriginUOM = SPACE(10)        
      SELECT @n_OriginUOMQty = 0        
        
      SET @d_Step3 = GETDATE()        
        
      IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
      BEGIN        
         DECLARE C_OPORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
           SELECT #OPORDERLINES.StorerKey ,        
                  #OPORDERLINES.SKU ,        
                  #OPORDERLINES.UOM ,        
                  SUM(#OPORDERLINES.Qty) ,        
                  #OPORDERLINES.PackKey ,        
                  #OPORDERLINES.LOT,        
                  #OPORDERLINES.StrategyKey,        
                  #OPORDERLINES.Facility,        
                  #OPORDERLINES.UOMQty,   
                  #OPORDERLINES.Channel,        
                  ISNULL(OD.Lottable01,'')  --NJOW24  Hostwhcode    
              FROM #OPORDERLINES          
              LEFT JOIN ORDERDETAIL OD (NOLOCK) ON #OPORDERLINES.Orderkey = OD.Orderkey AND #OPORDERLINES.OrderLineNumber = OD.OrderLineNumber  --NJOW24       
           GROUP BY #OPORDERLINES.StorerKey ,        
                  #OPORDERLINES.SKU ,        
                  #OPORDERLINES.UOM ,        
                  #OPORDERLINES.PackKey ,        
                  #OPORDERLINES.LOT,        
                  #OPORDERLINES.StrategyKey,        
                  #OPORDERLINES.Facility,        
                  #OPORDERLINES.UOMQty,  
                  #OPORDERLINES.Channel,  
                  ISNULL(OD.Lottable01,'')  --NJOW20                                   
      END        
      ELSE        
      BEGIN        
         --NJOW17  
         IF ISNULL(@c_WaveConsoAllocationOParms,'') = '1' AND ISNULL(@c_OparmsOption5,'') <> ''  
         BEGIN  
            SET @c_SelectField = ',' + RTRIM(@c_OparmsOption5)  
            SET @c_GroupField = ',' + RTRIM(@c_OparmsOption5)  
         END  
         ELSE  
         BEGIN  
            SET @c_SelectField = ','''' '   
            SET @c_GroupField = ''  
         END     
            
          --NJOW14 NJOW17  
          SELECT @c_SQL =     
         N'DECLARE C_OPORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR  
           SELECT #OPORDERLINES.StorerKey,  
                  #OPORDERLINES.SKU,  
                  #OPORDERLINES.UOM,  
                  SUM(#OPORDERLINES.Qty),  
                  #OPORDERLINES.PackKey,  
                  #OPORDERLINES.LOT,  
                  #OPORDERLINES.StrategyKey,  
                  #OPORDERLINES.Facility,  
                  #OPORDERLINES.UOMQty,  
                  ORDERDETAIL.Lottable01, ORDERDETAIL.Lottable02, ORDERDETAIL.Lottable03, ORDERDETAIL.Lottable04, ORDERDETAIL.Lottable05,  
                  ORDERDETAIL.Lottable06, ORDERDETAIL.Lottable07, ORDERDETAIL.Lottable08, ORDERDETAIL.Lottable09, ORDERDETAIL.Lottable10,        
                  ORDERDETAIL.Lottable11, ORDERDETAIL.Lottable12, ORDERDETAIL.Lottable13, ORDERDETAIL.Lottable14, ORDERDETAIL.Lottable15,  
                  #OPORDERLINES.Channel,    
                  ORDERDETAIL.Lottable01 ' +  --NJOW24  Hostwhcode                                
                  ISNULL(RTRIM(@c_SelectField),'') + ' ' +                                            
            ' FROM #OPORDERLINES  
              JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.OrderKey = #OPORDERLINES.OrderKey AND ORDERDETAIL.OrderLineNumber = #OPORDERLINES.OrderLineNumber  
              JOIN ORDERS WITH (NOLOCK) ON ORDERS.Orderkey = #OPORDERLINES.OrderKey  
              JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = #OPORDERLINES.StorerKey AND SKU.Sku = #OPORDERLINES.SKU  
           GROUP BY #OPORDERLINES.StorerKey ,  
                  #OPORDERLINES.SKU ,  
                  #OPORDERLINES.UOM ,  
                  #OPORDERLINES.PackKey ,  
                  #OPORDERLINES.LOT,  
                  #OPORDERLINES.StrategyKey,  
                  #OPORDERLINES.Facility,  
                  #OPORDERLINES.UOMQty,  
                  ORDERDETAIL.Lottable01, ORDERDETAIL.Lottable02, ORDERDETAIL.Lottable03, ORDERDETAIL.Lottable04, ORDERDETAIL.Lottable05,  
                  ORDERDETAIL.Lottable06, ORDERDETAIL.Lottable07, ORDERDETAIL.Lottable08, ORDERDETAIL.Lottable09, ORDERDETAIL.Lottable10,            
                  ORDERDETAIL.Lottable11, ORDERDETAIL.Lottable12, ORDERDETAIL.Lottable13, ORDERDETAIL.Lottable14, ORDERDETAIL.Lottable15,  
                  #OPORDERLINES.Channel ' +         
                  ISNULL(RTRIM(@c_GroupField),'')               
  
         EXEC(@c_SQL)                                                 
      END        
        
      OPEN C_OPORDERLINES        
        
      WHILE (1 = 1) AND (@n_Continue = 1 OR @n_Continue = 2)        
      BEGIN        
         SET @n_Channel_ID = 0 --SWT01  
  
         IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
         BEGIN          
            FETCH NEXT FROM C_OPORDERLINES INTO        
                  @c_aStorerKey,        
                  @c_aSKU,        
                  @c_aUOM,        
                  @n_aQtyLeftToFulfill,        
                  @c_aPackKey,        
                  @c_aLOT,        
                  @c_aStrategyKey,        
                  @c_aFacility,        
                  @n_aUOMQty,  
                  @c_Channel,   
                  @c_HostWHCode --NJOW24                           
         END        
         ELSE        
         BEGIN        
            FETCH NEXT FROM C_OPORDERLINES INTO        
                  @c_aStorerKey,        
                  @c_aSKU,        
                  @c_aUOM,        
                  @n_aQtyLeftToFulfill,        
                  @c_aPackKey,        
                  @c_aLOT,        
                  @c_aStrategyKey,        
                  @c_aFacility,        
                  @n_aUOMQty,        
                  @c_Lottable01,         
                  @c_Lottable02,        
                  @c_Lottable03,         
                  @d_Lottable04,        
                  @d_Lottable05,  
                  @c_Lottable06,  
                  @c_Lottable07,  
                  @c_Lottable08,  
                  @c_Lottable09,  
                  @c_Lottable10,  
                  @c_Lottable11,  
                  @c_Lottable12,  
                  @d_Lottable13,  
                  @d_Lottable14,  
                  @d_Lottable15,  
                  @c_Channel,  
                  @c_HostWHCode, --NJOW24                                
                  @c_Oparms --NJOW17  
         END        
                 
         IF @@Fetch_Status <> 0        
         BEGIN        
            BREAK        
         END        
         ELSE IF ( @b_debug = 1 OR @b_debug = 2 )        
         BEGIN        
            PRINT ''        
            PRINT ''        
            PRINT '-----------------------------------------------------'        
            PRINT '-- SKU: ' + RTRIM(@c_aSKU) + ' Qty:' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))        
            PRINT '-- Pack Key :' + RTRIM(@c_aPackKey) + ' UOM:' + @c_aUOM + ' UOM Qty: ' + CAST(@n_aUOMQty AS NVARCHAR(10))        
            PRINT '-- LOT: ' + RTRIM(@c_aLOT)    
            PRINT '-- Strategykey : ' + RTRIM(@c_aStrategyKey)      
         END        
        
         SET @c_OldOriginalStrategyKey = @c_aStrategyKey        
         SET @c_OriginUOM = @c_aUOM        
         SET @n_OriginUOMQty = @n_aUOMQty        
        
         IF @c_OldStorerKey <> @c_aStorerKey        
         BEGIN        
            SELECT @b_Success = 0        
            EXECUTE nspGetRight @c_aFacility,       -- Facility   NJOW11  
                    @c_aStorerKey,          -- StorerKey        
                    NULL,                   -- Sku        
                    'ALLOWOVERALLOCATIONS', -- Configkey        
                    @b_Success              OUTPUT,        
                    @c_AllowOverAllocations OUTPUT,        
                    @n_Err                  OUTPUT,        
                    @c_ErrMsg               OUTPUT        
        
            IF @b_Success <> 1        
            BEGIN        
               SELECT @n_Continue = 3, @c_ErrMsg = 'ispWaveProcessing' + RTRIM(@c_ErrMsg)        
            END        
            ELSE        
            BEGIN        
               IF ISNULL(RTRIM(@c_AllowOverAllocations),'') = ''        
               BEGIN        
                  SELECT @c_AllowOverAllocations = '0'        
               END        
               SELECT @c_OldStorerKey = @c_aStorerKey        
            END        
  
            --NJOW01  
            SELECT @b_success = 0  
            EXECUTE nspGetRight @c_aFacility,  -- facility  
            @c_aStorerKey,   -- StorerKey  
            NULL,         -- Sku  
            'PickOverAllocateNoMixLot',  -- Configkey  
            @b_success    OUTPUT,  
            @c_PickOverAllocateNoMixLot  OUTPUT,  
            @n_err        OUTPUT,  
            @c_errmsg     OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_Continue = 3, @c_ErrMsg = 'nspWaveProcessing' + RTRIM(@c_ErrMsg)  
            END  
  
            --NJOW09  
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
               SELECT @n_continue = 3, @c_errmsg = 'nspWaveProcessing' + RTRIM(@c_errmsg)  
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
               SELECT @n_continue = 3, @c_errmsg = 'nspWaveProcessing' + RTRIM(@c_errmsg)  
            END  
  
            -- SHONG03        
            SELECT @b_Success = 0        
            EXECUTE nspGetRight @c_aFacility, -- Facility  NJOW19  
                @c_aStorerKey,          -- StorerKey        
                    NULL,                   -- Sku        
                    'PREPACKBYBOM',         -- Configkey        
                    @b_Success              OUTPUT,        
                    @c_CaseQtyXFactor       OUTPUT,        
                    @n_Err                  OUTPUT,        
                    @c_ErrMsg               OUTPUT        
        
            IF @b_Success <> 1        
            BEGIN        
               SELECT @n_Continue = 3, @c_ErrMsg = 'ispWaveProcessing' + RTRIM(@c_ErrMsg)        
            END        
            ELSE        
            BEGIN        
               IF ISNULL(RTRIM(@c_CaseQtyXFactor),'') = ''        
               BEGIN        
                  SELECT @c_CaseQtyXFactor = '0'        
               END        
            END        
        
         END        
        
         IF @n_Continue = 1 OR @n_Continue = 2        
         BEGIN        
        
            SELECT @n_cPackQty = @n_aQtyLeftToFulfill / @n_aUOMQty        
        
            --NJOW09  
            /*  
            IF ISNULL(@c_AllocateGetCasecntFrLottable,'')   
               IN ('01','02','03','06','07','08','09','10','11','12') AND @c_aUOM = '2'  
               AND ISNULL(@c_SkipPreAllocationFlag,'0') <> '1' --if not skip preallocation need to get casecnt from lot if uom = 2  
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
            */            
        
            IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'        
            BEGIN        
               SET @b_TryIfQtyRemain = 0        
            END        
            ELSE        
            BEGIN        
               SELECT @b_TryIfQtyRemain = ReTryIfQtyRemain        
               FROM AllocateStrategy (NOLOCK)        
               WHERE AllocateStrategyKey = @c_aStrategyKey        
            END        
        
            SELECT @c_sCurrentLineNumber = SPACE(5)        
            SELECT @n_NumberOfRetries = 0        
        
        END -- @n_Continue = 1 or @n_Continue = 2        
        
         LOOPPICKSTRATEGY:        
         WHILE (@n_Continue = 1 OR @n_Continue = 2) AND @n_NumberOfRetries <= 7 AND @c_aUOM <= 9 AND @n_aQtyLeftToFulfill > 0        
         BEGIN        
            IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'        
            BEGIN        
               GET_NEXT_STRATEGY:        
        
               SELECT TOP 1        
                      @c_sCurrentLineNumber = AllocateStrategyLineNumber ,        
                      @c_sAllocatePickCode = PickCode ,        
                      @c_sLocationTypeOverride = LocationTypeOverride,        
                      @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe,        
                      @c_aUOM = UOM        
                 FROM AllocateStrategyDetail (NOLOCK)        
                WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber        
                  AND AllocateStrategyKey = @c_aStrategyKey        
               ORDER BY AllocateStrategyLineNumber         
        
               IF @@ROWCOUNT = 0        
               BEGIN        
                  IF @b_debug = 1 OR @b_debug = 2        
                  BEGIN        
                     PRINT ''        
                     PRINT ''        
                     PRINT '-- Allocate Strategy Not Found For UOM: ' + RTRIM(@c_aUOM)        
                     PRINT '   CurrentLineNumber: ' +  RTRIM(@c_sCurrentLineNumber)        
                     PRINT '   @c_aStrategyKey: ' + RTRIM(@c_aStrategyKey)        
                  END        
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
        
               --SELECT @n_cPackQty = @n_aQtyLeftToFulfill / @n_aUOMQty        
               SELECT @n_cPackQty = @n_aUOMQty        
        
               IF @b_debug = 1 OR @b_debug = 2        
               BEGIN        
                  PRINT ''        
                  PRINT '********** GET_NEXT_STRATEGY **********'        
                  PRINT '--> @n_cPackQty: ' + CAST(@n_cPackQty AS NVARCHAR(10))        
                  PRINT '--> @n_aQtyLeftToFulfill: ' +  CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))        
                  PRINT ''        
               END        
        
               --Remove to support dynamic uom qty control at pickcode  
               --IF @n_cPackQty > @n_aQtyLeftToFulfill --SHONG        
               --   AND @c_aUOM <> '1' --NJOW07 support full pallet by loc/id  
               --   GOTO GET_NEXT_STRATEGY        
            END        
            ELSE        
            BEGIN        
               SELECT TOP 1        
                      @c_sCurrentLineNumber = AllocateStrategyLineNumber ,        
                      @c_sAllocatePickCode = PickCode ,        
                      @c_sLocationTypeOverride = LocationTypeOverride,        
                      @c_sLocationTypeOverridestripe = LocationTypeOverrideStripe        
                 FROM AllocateStrategyDetail (NOLOCK)        
               WHERE AllocateStrategyLineNumber > @c_sCurrentLineNumber        
                  AND UOM = @c_aUOM        
                  AND AllocateStrategyKey = @c_aStrategyKey        
               ORDER BY AllocateStrategyLineNumber        
        
               IF @@ROWCOUNT = 0        
               BEGIN        
                  IF @b_debug = 1 OR @b_debug = 2        
                  BEGIN                         PRINT ''        
                     PRINT ''        
                     PRINT '-- Allocate Strategy Not Found For UOM: ' + RTRIM(@c_aUOM)        
                     PRINT '   CurrentLineNumber: ' +  RTRIM(@c_sCurrentLineNumber)        
                     PRINT '   @c_aStrategyKey: ' + RTRIM(@c_aStrategyKey)        
                  END        
                  BREAK        
              END        
            END        
        
           IF @b_debug = 1 OR @b_debug = 2        
           BEGIN        
               PRINT ''        
               PRINT ''        
               PRINT '-- Allocate Strategy Found For UOM: ' + RTRIM(@c_aUOM)        
               PRINT '   CurrentLineNumber: ' +  RTRIM(@c_sCurrentLineNumber)        
               PRINT '   @c_aStrategyKey: ' + RTRIM(@c_aStrategyKey)        
               PRINT '   @c_sLocationTypeOverride: ' + RTRIM(@c_sLocationTypeOverride)        
               PRINT '   @c_AllowOverAllocations: ' + RTRIM(@c_AllowOverAllocations)        
               PRINT '   @c_SkipPreAllocationFlag: ' + RTRIM(@c_SkipPreAllocationFlag)  
           END        
        
           IF (ISNULL(RTRIM(@c_sLocationTypeOverride),'') ='') OR (@c_AllowOverAllocations = '0') OR        
               ISNULL(@c_SkipPreAllocationFlag,'0') = '1'        
           BEGIN        
               DECLARECURSOR_CANDIDATES:        
               SELECT @n_CursorCandidates_Open = 0        
               SELECT @c_EndString = ', @n_UOMBase = ' + CONVERT(VARCHAR(10),@n_cPackQty) + ', @n_QtyLeftToFulfill = ' + CONVERT(VARCHAR(10), @n_aQtyLeftToFulfill)  
        
               --NJOW24       
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
                        
               --NJOW14  
               /*  
               IF @c_WaveConsoAllocationOParms = '1'  
               BEGIN  
                    IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'  
                     SELECT @c_OtherParms = RTRIM(@c_WaveKey) + '     W'  
                  ELSE     
                     SELECT @c_OtherParms = LTRIM(RTRIM(@c_WaveKey)) + '     W' + LTRIM(RTRIM(ISNULL(@c_Oparms,'')))  --NJOW17  
                  END     
               ELSE  
               BEGIN   
                  SELECT @c_OtherParms = ''                 
               END  
               */  
  
               --NJOW24    
               IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'    
                  SELECT @c_OtherParms = RTRIM(@c_WaveKey) + '     W'    
               ELSE       
                  SELECT @c_OtherParms = LTRIM(RTRIM(@c_WaveKey)) + '     W' + LTRIM(RTRIM(ISNULL(@c_Oparms,'')))  --NJOW17              
                    
               --IF @c_Orderinfo4Allocation = '1' --NJOW14    
               IF @c_OtherParmsExist = 'Y' --NJOW24    
                  SELECT @c_EndString = RTRIM(@c_EndString) + ',@c_OtherParms = N''' +RTRIM(@c_OtherParms) + ''''                          
                  
               --NJOW27 S       
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
               --NJOW27 E             
  
               IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
               BEGIN        
                  IF NOT EXISTS(SELECT 1  
                            FROM sys.parameters AS p  
                            JOIN sys.types AS t ON t.user_type_id = p.user_type_id  
                            WHERE object_id = OBJECT_ID(@c_sAllocatePickCode)  
                            AND   P.name = N'@c_LOT')  
                  BEGIN  
                     DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
                     FOR SELECT LOC = '', ID='', QTYAVAILABLE = 0, '1'  
                     FROM LOTxLOCxID (NOLOCK)  
                     WHERE 1=2  
                  END  
                  ELSE  
                  BEGIN  
                     SET @c_SQLExecute =   
                        @c_sAllocatePickCode + ' '   
                        + '@c_lot = N''' + RTRIM(@c_aLOT) + '''' + ','   
                        + '@c_uom = N''' + RTRIM(@c_aUOM) + '''' + ','  
                        + '@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + '''' + ','   
                        + '@c_Facility = N''' + RTRIM(@c_aFacility) + '''' + RTRIM(@c_EndString)  
                       
                     EXEC(@c_SQLExecute)  
                  END  
                  IF @b_debug = 1 OR @b_debug = 2    
                  BEGIN    
                     PRINT ''    
                     PRINT ''    
                     PRINT '-- Execute Allocate Strategy * ' + RTRIM(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)    
                     PRINT '   EXEC ' +  @c_SQLExecute  
                  END    
               END        
               ELSE        
               BEGIN        
                  --NJOW06 Start  
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
                  --NJOW06 End  
  
                  SET @c_Lottable_Parm = ''  
  
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
                        BEGIN  
                           SET @c_SQLExecute = RTRIM(@c_SQLExecute) + ' ' + RTRIM(@c_ParameterName) + ' = N''' + @c_WaveKey   + ''''  
                        END  
                        ELSE  
                        BEGIN   
                           SET @c_SQLExecute = RTRIM(@c_SQLExecute) +   
                              CASE @c_ParameterName  
                                 WHEN '@c_Facility'   THEN ',@c_Facility   = N''' + RTRIM(@c_aFacility) + ''''  
                                 WHEN '@c_StorerKey'  THEN ',@c_StorerKey  = N''' + RTRIM(@c_aStorerKey) + ''''  
                                 WHEN '@c_SKU'        THEN ',@c_SKU        = N''' + RTRIM(@c_aSKU) + ''''   
                                 WHEN '@c_Lottable01' THEN ',@c_Lottable01 = N''' + RTRIM(@c_Lottable01) + ''''   
                                 WHEN '@c_Lottable02' THEN ',@c_Lottable02 = N''' + RTRIM(@c_Lottable02) + ''''   
                                 WHEN '@c_Lottable03' THEN ',@c_Lottable03 = N''' + RTRIM(@c_Lottable03) + ''''   
                                 --WHEN '@c_Lottable04' THEN ',@c_Lottable04 = N''' + RTRIM(@d_Lottable04) + ''''    
                                 --WHEN '@d_Lottable04' THEN ',@d_Lottable04 = N''' + RTRIM(@d_Lottable04) + ''''        
                                 --WHEN '@c_Lottable05' THEN ',@c_Lottable05 = N''' + RTRIM(@d_Lottable05) + ''''    
                                 --WHEN '@d_Lottable05' THEN ',@d_Lottable05 = N''' + RTRIM(@d_Lottable05) + ''''        
                                 WHEN '@d_Lottable04' THEN ',@d_Lottable04 = N''' + @c_Lottable04 + '''' --NJOW06  
                                 WHEN '@c_Lottable04' THEN ',@c_Lottable04 = N''' + @c_Lottable04 + '''' --NJOW06  
                                 WHEN '@d_Lottable05' THEN ',@d_Lottable05 = N''' + @c_Lottable05 + '''' --NJOW06  
                                 WHEN '@c_Lottable05' THEN ',@c_Lottable05 = N''' + @c_Lottable05 + '''' --NJOW06  
                                 WHEN '@c_Lottable06' THEN ',@c_Lottable06 = N''' + RTRIM(@c_Lottable06) + ''''   
                                 WHEN '@c_Lottable07' THEN ',@c_Lottable07 = N''' + RTRIM(@c_Lottable07) + ''''   
                                 WHEN '@c_Lottable08' THEN ',@c_Lottable08 = N''' + RTRIM(@c_Lottable08) + ''''   
                                 WHEN '@c_Lottable09' THEN ',@c_Lottable09 = N''' + RTRIM(@c_Lottable09) + ''''    
                                 WHEN '@c_Lottable10' THEN ',@c_Lottable10 = N''' + RTRIM(@c_Lottable10) + ''''    
                                 WHEN '@c_Lottable11' THEN ',@c_Lottable11 = N''' + RTRIM(@c_Lottable11) + ''''   
                                 WHEN '@c_Lottable12' THEN ',@c_Lottable12 = N''' + RTRIM(@c_Lottable12) + ''''   
                                 --WHEN '@d_Lottable13' THEN ',@d_Lottable13 = N''' + RTRIM(@d_Lottable13) + ''''   
                                 --WHEN '@d_Lottable14' THEN ',@d_Lottable14 = N''' + RTRIM(@d_Lottable14) + ''''    
                                 --WHEN '@d_Lottable15' THEN ',@d_Lottable15 = N''' + RTRIM(@d_Lottable15) + ''''    
                                 WHEN '@d_Lottable13' THEN ',@d_Lottable13 = N''' + @c_Lottable13 + ''''    --NJOW06  
                                 WHEN '@d_Lottable14' THEN ',@d_Lottable14 = N''' + @c_Lottable14 + ''''    --NJOW06  
                                 WHEN '@d_Lottable15' THEN ',@d_Lottable15 = N''' + @c_Lottable15 + ''''    --NJOW06  
                                 WHEN '@c_UOM'        THEN ',@c_UOM = N''' + RTRIM(@c_aUOM) + ''''       
                                 WHEN '@c_HostWHCode' THEN ',@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + ''''   
                              END   
                        END  
  
                        FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition  
                     END   
                     CLOSE Cur_Parameters  
                     DEALLOCATE Cur_Parameters   
                                            
                     IF @b_debug = 1 OR @b_debug = 2    
                     BEGIN    
                        PRINT ''    
                        PRINT ''    
                        PRINT '-- Execute Allocate Strategy ' + RTRIM(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)    
                        PRINT '   EXEC ' +  @c_SQLExecute + @c_EndString  
                     END    
    
                     EXEC(@c_SQLExecute + @c_EndString)  
                  END  
                  ELSE  
                  BEGIN  
                     --Select @c_sAllocatePickCode '@c_sAllocatePickCode', @c_EndString '@c_EndString' -- testing  
                     IF EXISTS(SELECT 1  
                               FROM [INFORMATION_SCHEMA].[PARAMETERS]   
                               WHERE SPECIFIC_NAME = @c_sAllocatePickCode  
                               AND   PARAMETER_NAME = N'@c_LOT')  
                     BEGIN  
                        DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY  
                        FOR SELECT LOT= '', LOC = '', ID='', QTYAVAILABLE = 0, '1'  
                        FROM LOTxLOCxID (NOLOCK)  
                        WHERE 1=2  
                  END           
                  ELSE    
                  BEGIN    
                     IF @b_debug = 1 OR @b_debug = 2    
                     BEGIN    
                        PRINT ''    
                        PRINT ''    
                        PRINT '-- Execute Allocate Strategy ' + RTRIM(@c_sAllocatePickCode) + ' UOM:' + RTRIM(@c_aUOM)    
                           PRINT 'EXEC ' + @c_SQLExecute  
                     END    
                        SET @c_SQLExecute = @c_sAllocatePickCode + ' '  
                              + '@c_WaveKey = N''' + RTRIM(@c_WaveKey)   + ''''  + ','  
                              + '@c_Facility = N''' + RTRIM(@c_aFacility) + ''''  + ','  
                              + '@c_StorerKey = N''' + RTRIM(@c_aStorerKey) + '''' + ','  
                              + '@c_SKU = N''' + RTRIM(@c_aSKU) + '''' + ','  
                              + '@c_UOM = N''' + RTRIM(@c_aUOM) + '''' + ','  
                              + '@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + ''''    
                              + @c_EndString  
  
                        EXEC(@c_SQLExecute)  
                     END  
                  END  
                  SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT    
  
               END        
        
               IF @n_Err = 16915        
               BEGIN        
                  CLOSE CURSOR_CANDIDATES        
                  DEALLOCATE CURSOR_CANDIDATES        
                  GOTO DECLARECURSOR_CANDIDATES        
               END        
        
               OPEN CURSOR_CANDIDATES        
               SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
               IF @n_Err = 16905        
               BEGIN        
                  CLOSE CURSOR_CANDIDATES        
                  DEALLOCATE CURSOR_CANDIDATES        
                  GOTO DECLARECURSOR_CANDIDATES        
               END        
               IF @n_Err <> 0        
               BEGIN        
                  SELECT @n_Continue = 3        
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.   
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation/Opening of Candidate Cursor Failed! (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
               END        
               ELSE        
               BEGIN        
                  SELECT @n_CursorCandidates_Open = 1        
               END        
        
               IF (@n_Continue = 1 OR @n_Continue = 2) AND @n_CursorCandidates_Open = 1        
               BEGIN        
                  SELECT @n_CandidateLine = 0        
        
                  SELECT @c_PrevUCCNo = '' --NJOW13  
                  SELECT @c_aPrevLot = '' --NJOW20  
                  WHILE @n_aQtyLeftToFulfill > 0        
                  BEGIN        
                     SELECT @n_Fetch_Status = 0        
                     SELECT @n_CandidateLine = @n_CandidateLine + 1  
                     SELECT @c_UCCNo = ''  --NJOW13        
                     SELECT @c_UOMByLoad = 'N'  --NJOW27
                     SELECT @c_UOMByOrder = 'N' --NJOW27
                     SELECT @c_FullPallet = 'N' --NJOW27
                     SELECT @c_DYNUOMQty = ''   --NJOW27
        
                     IF @n_CandidateLine = 1        
                     BEGIN        
                        SELECT @n_cQtyAvailable = 0, @c_cLOC = '', @c_cid='', @c_OtherValue = ''        
        
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
                        BEGIN  
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_cLOC, @c_cID, @n_cQtyAvailable, @c_OtherValue        
                        END        
                        ELSE        
                        BEGIN        
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT, @c_cLOC, @c_cid, @n_cQtyAvailable, @c_OtherValue                                              
                        END  
                                  
                        IF CHARINDEX('@', @c_OtherValue, 1) > 0  --NJOW27
                        BEGIN                                                                                                                            
                           IF @c_UCCAllocation = '1' --NJOW27
                           BEGIN
                              SET @c_UCCNo = dbo.fnc_GetParamValueFromString('@c_UCCNo', @c_OtherValue, '')
                           END
                        END
                        ELSE 
                        BEGIN
                           --NJOW13 
                           IF @c_UCCAllocation = '1' AND @c_OtherValue NOT IN ('1','FULLPALLET') AND LEFT(@c_OtherValue,4) <> 'UOM='  --NJOW16 
                           BEGIN                                
                              SET @c_UCCNo = @c_OtherValue  
                           END
                        END   
        
                        SELECT @n_Fetch_Status = @@Fetch_Status        
        
                        IF (@b_debug = 1 OR @b_debug = 2) AND @n_Fetch_Status <> -1        
                        BEGIN        
                           PRINT ''        
                           PRINT '**** Location Found ****'        
                           PRINT '     LOC: ' + @c_cLOC + ' ID: ' + RTRIM(@c_cID)        
                           PRINT '     Qty Available: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))        
                           PRINT '     Other Value: ' + RTRIM(@c_OtherValue)        
                           PRINT '     UCC No: ' + + RTRIM(@c_UCCNo)      --NJOW13  
        
                           IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'        
                           BEGIN        
                              PRINT '     LOT: ' + @c_aLOT        
                           END        
                        END        
                     END -- @n_CandidateLine = 1        
                     ELSE        
                     BEGIN        
                        SELECT @n_cQtyAvailable = 0, @c_cLOC = '', @c_cid='', @c_OtherValue = ''        
        
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') <> '1'        
                        BEGIN        
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_cLOC, @c_cid, @n_cQtyAvailable, @c_OtherValue        
                        END        
                        ELSE        
                        BEGIN        
                           FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT, @c_cLOC, @c_cid, @n_cQtyAvailable, @c_OtherValue        
                        END        
  
                        IF CHARINDEX('@', @c_OtherValue, 1) > 0  --NJOW27
                        BEGIN                                                                                                                            
                           IF @c_UCCAllocation = '1' --NJOW27
                           BEGIN
                              SET @c_UCCNo = dbo.fnc_GetParamValueFromString('@c_UCCNo', @c_OtherValue, '')
                           END
                        END
                        ELSE 
                        BEGIN
                           --NJOW13 
                           IF @c_UCCAllocation = '1' AND @c_OtherValue NOT IN ('1','FULLPALLET') AND LEFT(@c_OtherValue,4) <> 'UOM='  --NJOW16  
                           BEGIN                                
                              SET @c_UCCNo = @c_OtherValue  
                           END
                        END   
        
                        SELECT @n_Fetch_Status = @@Fetch_Status        
        
                        IF (@b_debug = 1 OR @b_debug = 2) AND @n_Fetch_Status <> -1        
                        BEGIN        
                           PRINT ''        
                           PRINT '**** Location Found ****'        
                           PRINT '     LOC: ' + @c_cLOC + ' ID: ' + RTRIM(@c_cID)        
                           PRINT '     Qty Available: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))        
                           PRINT '     Pack Balance: ' + CAST(@n_PackBalance AS NVARCHAR(10))        
                           PRINT '     UCC No: ' + + RTRIM(@c_UCCNo)      --NJOW13  
        
                           IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'        
                           BEGIN        
                              PRINT '     LOT: ' + @c_aLOT        
                           END        
                        END        
                     END -- @n_CandidateLine <> 1        
                     IF @n_Fetch_Status < 0        
                     BEGIN        
                        IF @b_debug = 1        
                        BEGIN        
                           PRINT ''        
                           PRINT '**** No Location Found ****'        
                        END        
                        BREAK        
                     END        
                     IF @n_Fetch_Status = 0        
                     BEGIN        
                          --NJOW27 S
                        IF CHARINDEX('@', @c_OtherValue, 1) > 0  
                        BEGIN
                            SET @c_UOMByLoad = dbo.fnc_GetParamValueFromString('@c_UOMBYLOAD', @c_OtherValue, 'N') 
                           SET @c_UOMByOrder = dbo.fnc_GetParamValueFromString('@c_UOMBYORDER', @c_OtherValue, 'N') 
                           SET @c_FullPallet = dbo.fnc_GetParamValueFromString('@c_FULLPALLET', @c_OtherValue, 'N') 
                           SET @c_DYNUOMQty =  dbo.fnc_GetParamValueFromString('@c_DYNUOMQTY', @c_OtherValue, '') 
                        END
                        ELSE
                        BEGIN
                            IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  
                            BEGIN                            
                               IF @c_OtherValue = 'FULLPALLET'
                                  SET @c_FullPallet = 'Y'
                            
                              IF LEFT(@c_OtherValue,4) = 'UOM=' 
                                 SET @c_DYNUOMQty = SUBSTRING(@c_OtherValue,5,10)
                            END   
                        END
                        --NJOW27 E
                        
                        --(NJOW15) - START  
                        IF ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  
                        BEGIN         
                           SET @n_LotAvailableQty = 0  
                           SELECT @n_LotAvailableQty = Qty - QtyAllocated - QtyPicked - QtyPreAllocated  
                           FROM LOT (NOLOCK)  
                           WHERE Lot = @c_aLOT     
              
                           IF @n_cQtyAvailable > @n_LotAvailableQty   
                              SET @n_cQtyAvailable = @n_LotAvailableQty   
                             
                           SET @n_FacLotAvailQty = 0   
                           SELECT @n_FacLotAvailQty = SUM(LLI.Qty - LLI.QtyAllocated - LLi.QtyPicked)  
                           FROM LOTxLOCxID  LLI WITH (NOLOCK)   
                           JOIN LOC         LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)  
                           WHERE LLI.Lot =  @c_aLOT    
                           AND   LOC.Facility = @c_aFacility  
  
                           IF @n_FacLotAvailQty < @n_cQtyAvailable  
                           BEGIN   
                              SET @n_cQtyAvailable = @n_FacLotAvailQty    
                           END  
                             
                           -- SWT01  
                           IF @c_ChannelInventoryMgmt = '1'         
                           BEGIN  
                               IF @c_aPrevLot <> @c_aLot  --NJOW20  
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
                                       SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspWaveProcessing)'   
                                 END CATCH                                            
                              END   
                              IF @n_Channel_ID > 0   
                              BEGIN  
                                 SET @n_Channel_Qty_Available = 0   
                                 SET @n_AllocatedHoldQty = 0   
  
                                 --NJOW26 S                                      
                                 SET @n_ChannelHoldQty = 0  
                                 EXEC isp_ChannelAllocGetHoldQty_Wrapper    
                                    @c_StorerKey = @c_aStorerkey,   
                                    @c_Sku = @c_aSKU,    
                                    @c_Facility = @c_aFacility,             
                                    @c_Lot = @c_aLOT,  
                                    @c_Channel = @c_Channel,  
                                    @n_Channel_ID = @n_Channel_ID,     
                                    @n_AllocateQty = @n_cQtyAvailable, --NJOW29       
                                    @n_QtyLeftToFulFill = @n_aQtyLeftToFulfill, --NJOW29                                                                                                     
                                    @c_SourceKey = @c_Wavekey,  
                                    @c_SourceType = 'ispWaveProcessing',   
                                    @n_ChannelHoldQty = @n_ChannelHoldQty OUTPUT,  
                                    @b_Success = @b_Success OUTPUT,  
                                    @n_Err = @n_Err OUTPUT,   
                                    @c_ErrMsg = @c_ErrMsg OUTPUT  
                                    
                                 IF @b_success <> 1
                                 BEGIN
                                    SET @n_continue = 3                                                                                
                                 END                                                                        
                                 --NJOW26 E     
                                                                    
                                  /*(Wan03) - START  
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
                                 (Wan03) - END*/  
                                   
                                 SELECT @n_Channel_Qty_Available = ci.Qty - ( ci.QtyAllocated - @n_AllocatedHoldQty ) - ci.QtyOnHold - @n_ChannelHoldQty --NJOW26                                   
                                 FROM ChannelInv AS ci WITH(NOLOCK)  
                                 WHERE ci.Channel_ID = @n_Channel_ID  
                                   
                                 IF @n_Channel_Qty_Available < @n_cQtyAvailable  
                                 BEGIN   
                                      IF @c_UCCAllocation = '1' AND ISNULL(@c_UCCNo,'') <> '' AND @c_aUOM = '2' --NJOW28  not to take partial UCC 
                                         SET @n_cQtyAvailable = 0 
                                      ELSE   
                                       SET @n_cQtyAvailable = @n_Channel_Qty_Available     
                                 END                 
                              END   
                              ELSE IF ISNULL(RTRIM(@c_Channel), '') <> ''   
                                 SET @n_cQtyAvailable = 0                                   
                           END -- IF @c_ChannelInventoryMgmt = '1'                              
                        END   
                        --(NJOW15) - END          
                          
                        --NJOW09  
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
  
                        --NJOW16  
                        --IF LEFT(@c_OtherValue,4) = 'UOM=' AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1'    
                        --BEGIN  
                           --IF ISNUMERIC(SUBSTRING(@c_OtherValue,5,10)) = 1  
                           IF ISNUMERIC(@c_DYNUOMQty) = 1 AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  --NJOW27
                           BEGIN  
                              --SET @n_dynUOMQty = CAST(SUBSTRING(@c_OtherValue,5,10) AS INT)  
                              SET @n_dynUOMQty = CAST(@c_DYNUOMQty AS INT)  --NJOW27
                                
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
                        --END  
                          
                        --NJOW13  
                        IF @c_UCCAllocation = '1' AND @c_aUOM = '2'  
                        BEGIN  
                           SELECT @n_CaseQty = @n_cQtyAvailable  --set caseqty as UCC qty  
                           SELECT @n_cPackQty = @n_CaseQty                             
                        END   
  
                        IF @b_debug = 1 OR @b_debug = 2        
                        BEGIN        
                           PRINT '     @n_cPackQty Before: ' + CAST(@n_cPackQty AS NVARCHAR(10))        
                           PRINT '     @n_cQtyAvailable: ' + CAST(@n_cQtyAvailable AS NVARCHAR(10))        
                           PRINT '     @n_aQtyLeftToFulfill: ' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))        
                           PRINT '     @c_aUOM: ' + @c_aUOM        
         
                           IF @c_CaseQtyXFactor <> '0' AND ISNUMERIC(@c_CaseQtyXFactor) = 1         
                              PRINT 'PrePackByBOM = ON, Case Qty = ' + @c_OtherValue        
                           ELSE        
                              PRINT 'PrePackByBOM = OFF'         
         
                        END        
        
                        -- Shong01      
                        IF @c_AllocateUCCPackSize = '1' AND @c_aUOM = '2'       
                        BEGIN      
                           SET @n_cPackQty = @c_OtherValue      
                                 
                           IF @b_debug = 1 OR @b_debug = 2        
                           BEGIN        
                              PRINT '     @c_AllocateUCCPackSize: ' + @c_AllocateUCCPackSize        
                              PRINT '     @n_cPackQty: ' + CAST(@n_cPackQty AS NVARCHAR(10))        
                              PRINT '     @c_OtherValue: ' + CAST(@c_OtherValue AS NVARCHAR(10))                                      
                           END                                 
                        END       
      
                        IF @c_FullPallet = 'Y' AND @c_aUOM = '1' --NJOW07 Start   --NJOW27
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
                           --NJOW07 End  
                        END  
                        ELSE  
                        BEGIN  
                           IF @n_cPackQty > 0        
                           BEGIN        
                              SELECT @n_Available = FLOOR(@n_cQtyAvailable / @n_cPackQty) * @n_cPackQty        
                           END        
                           ELSE        
                           BEGIN        
                              SELECT @n_Available = 0        
                           END        
                             
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
                              SELECT @n_UOMQty = FLOOR(@n_QtyToTake / @n_cPackQty)   --meng        
                             
                              -- SHONG03        
                              IF @c_CaseQtyXFactor <> '0' AND ISNUMERIC(@c_CaseQtyXFactor) = 1        
                              BEGIN        
                                 SET @c_OrderType=''        
                                 SELECT TOP 1        
                                 @c_OrderType = CASE WHEN (ISNULL(ORDERS.UserDefine01,'') <> '') THEN 'ECOM' ELSE 'STORE' END        
                                 FROM   WAVEDETAIL WD WITH (NOLOCK)        
                                 JOIN   ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = WD.OrderKey        
                                 WHERE  WD.WaveKey = @c_WaveKey        
                             
                                 IF @c_OrderType <> 'ECOM' AND ISNUMERIC(@c_OtherValue) = 1        
                                 BEGIN        
                                    SET @n_QtyToTake = FLOOR(@n_QtyToTake / CAST(@c_OtherValue AS INT) ) * CAST(@c_OtherValue AS INT)        
                                 END        
                              END        
                              ELSE        
                              BEGIN        
                                 SET @n_QtyToTake = FLOOR(@n_QtyToTake / @n_cPackQty) * @n_cPackQty --SHONG01        
                              END         
                           END        
                           ELSE        
                           BEGIN        
                              SELECT @n_UOMQty = 0        
                           END     
                        END     
        
                        IF @b_debug = 1 OR @b_debug = 2        
                        BEGIN        
                           PRINT '     Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))        
                        END        
        
                        IF @n_QtyToTake > 0        
                        BEGIN        
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
                           IF (ISNULL(RTRIM(@c_sLocationTypeOverride),'') <>'') AND        
                              (@c_AllowOverAllocations = '1')        
                           BEGIN        
                              IF @b_OverContinue = 1        
                              BEGIN        
                                 SELECT @n_JumpSource = 1        
                                 GOTO UPDATEINV        
                              END        
                           END        
                           ELSE        
                           BEGIN        
                              SELECT @n_JumpSource = 1        
                              GOTO UPDATEINV        
                           END        
        
                           RETURNFROMUPDATEINV_01:        
                           IF --(ISNULL(@c_SkipPreAllocationFlag,'0') = '1') AND        
                              (ISNULL(RTRIM(@c_sLocationTypeOverride),'') <>'') AND        
                              (@c_AllowOverAllocations = '1')        
                           BEGIN        
                              IF @b_OverContinue = 0 AND @n_aQtyLeftToFulfill > 0   --NJOW08  
                                 SET @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill + @n_NextQtyLeftToFulfill    
                              ELSE  
                                 SET @n_aQtyLeftToFulfill = @n_NextQtyLeftToFulfill  
                           END        
                        END        
                          
                        SET @c_PrevUCCNo = @c_UCCNo --NJOW13  
                        SET @c_aPrevLot = @c_aLot --NJOW20  
                     END -- fetch status = 0        
                  END -- WHILE @n_aQtyLeftToFulfill > 0        
               END -- (@n_Continue = 1 or @n_Continue = 2) AND @n_CursorCandidates_Open = 1        
               IF @n_CursorCandidates_Open = 1        
               BEGIN        
                  CLOSE CURSOR_CANDIDATES        
                  DEALLOCATE CURSOR_CANDIDATES        
               END        
            END -- (@c_sLocationTypeOverride ='') OR (@c_AllowOverAllocations = '0')        
            ELSE        
            BEGIN 
               SET @n_QtyToTake = 0                                                 --(Wan06)

               OVERALLOCATE_01:        
               SELECT @b_OverContinue = 1        
  
               IF @b_OverContinue = 1        
               BEGIN        
                  -- Use truncate instead of delete, faster        
                  TRUNCATE TABLE #OP_OVERPICKLOCS        
                  TRUNCATE TABLE #OP_PICKLOCTYPE        
                  -- End  
                  
                  SET @c_OverPickLoc = ''                                           --(Wan08) 
                  
                  --NJOW25 S  
                  IF ISNULL(@c_OverAllocPickLoc_SP,'') <> ''  
                  BEGIN  
                     IF ISNULL(@c_SkipPreAllocationFlag,'0') = '0'                     --(Wan06) - START 
                     BEGIN
                        SET @n_OverAlQtyLeftToFulfill = @n_aQtyLeftToFulfill
                        SET @n_QtyToTake = @n_aQtyLeftToFulfill
                     END
                     ELSE                                                              --(Wan06) - END
                        SET @n_OverAlQtyLeftToFulfill = @n_NextQtyLeftToFulfill + @n_QtyToTake  
                                           
                     SET @c_SQL = N'  
                     INSERT INTO #OP_PICKLOCTYPE          
                     EXEC ' + RTRIM(@c_overAllocPickLoc_sp) + ' @c_Storerkey=@c_aStorerkey, @c_Sku=@c_aSku, @c_AllocateStrategykey=@c_aAllocateStrategykey, @c_AllocateStrategyLineNumber=@c_aAllocateStrategyLineNumber,     
                                                       @c_LocationTypeOverride=@c_aLocationTypeOverride, @c_LocationTypeOverridestripe=@c_aLocationTypeOverridestripe, @c_Facility=@c_aFacility, @c_HostWHCode=@c_aHostWHCode,     
                                                       @c_Orderkey=@c_aOrderkey,  @c_Loadkey=@c_aLoadkey, @c_Wavekey=@c_aWavekey, @c_Lot=@c_aLot, @c_Loc=@c_aLoc, @c_ID=@c_aID, @c_UOM=@c_aUOM, @n_QtyToTake=@n_aQtyToTake,    
                                                       @n_QtyLeftToFulfill=@n_aQtyLeftToFulfill, @c_CallSource=@c_aCallSource, @b_success=@b_asuccess OUTPUT, @n_err=@n_aerr OUTPUT, @c_errmsg=@c_aerrmsg OUTPUT '  
                       
                     SET @CUR_AddSQL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      --(Wan09) - START
                     SELECT P.name                                                  --(Wan08) - START
                     FROM sys.parameters AS p    
                     JOIN sys.types AS t ON t.user_type_id = p.user_type_id    
                     WHERE object_id = OBJECT_ID(@c_overAllocPickLoc_sp)    
                     AND   P.name IN ('@c_OverPickLoc', '@n_OverQtyLeftToFulfill')  --(Wan08) - END
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
                     DEALLOCATE @CUR_AddSQL                                          --(Wan09) - END

                     
                     EXEC SP_EXECUTESQL @c_SQL, N'@c_aStorerkey NVARCHAR(15), @c_aSku NVARCHAR(20), @c_aAllocateStrategykey NVARCHAR(10), @c_aAllocateStrategyLineNumber NVARCHAR(5), @c_aLocationTypeOverride NVARCHAR(10),   
                     @c_aLocationTypeOverridestripe NVARCHAR(10), @c_aFacility NVARCHAR(5), @c_aHostWHCode NVARCHAR(10), @c_aOrderkey NVARCHAR(10), @c_aLoadkey NVARCHAR(10), @c_aWavekey NVARCHAR(10), @c_aLot NVARCHAR(10),    
                     @c_aLoc NVARCHAR(10), @c_aID NVARCHAR(18), @c_aUOM NVARCHAR(10), @n_aQtyToTake INT, @n_aQtyLeftToFulfill INT, @c_aCallSource NVARCHAR(20), @b_asuccess INT OUTPUT, @n_aerr INT OUTPUT, @c_aErrMsg NVARCHAR(250) OUTPUT
                    ,@c_OverPickLoc NVARCHAR(10) OUTPUT ,@n_OverAlQtyLeftToFulfill INT OUTPUT',    --(Wan08) --(Wan09)
                     @c_aStorerkey,  
                     @c_aSku,   
                     @c_aStrategykey,  
                     @c_sCurrentLineNumber,  
                     @c_sLocationTypeOverride,   
                     @c_sLocationTypeOverridestripe,  
                     @c_aFacility,   
                     @c_HostWHCode,                                 
                     '', --@c_Orderkey  
                     '', --@c_Loadkey  
                     @c_Wavekey,  
                     @c_aLot,  
                     @c_cLoc,  
                     @c_cID,   
                     @c_aUOM,   
                     @n_QtyToTake,   
                     @n_OverAlQtyLeftToFulfill,  
                     'WAVECONSO',            
                     @b_success OUTPUT,        
                     @n_err     OUTPUT,        
                     @c_errmsg  OUTPUT
                 ,   @c_OverPickLoc OUTPUT                                          --(Wan08) 
                 ,   @n_OverAlQtyLeftToFulfill OUTPUT                               --(Wan09)
                     
                     IF @n_OverAlQtyLeftToFulfill < @n_aQtyLeftToFulfill            --(Wan09)-START
                     BEGIN                                           
                        SET @n_aQtyLeftToFulfill = @n_OverAlQtyLeftToFulfill           
                     END                                                            --(Wan09)-END

                     SELECT @n_cnt = COUNT(1) FROM #OP_PICKLOCTYPE  
                  END --NJOW25 E        
                  ELSE  
                  BEGIN                            
                     INSERT #OP_PICKLOCTYPE        
                     SELECT SKUxLOC.LOC        
                       FROM SKUxLOC (NOLOCK)        
                      JOIN LOC (NOLOCK)        
                           ON SKUxLOC.loc = LOC.loc        
                      WHERE SKUxLOC.StorerKey = @c_aStorerKey        
                        AND SKUxLOC.SKU = @c_aSKU        
                        AND SKUxLOC.LOCATIONTYPE = @c_sLocationTypeOverride        
                        AND LOC.Facility = @c_aFacility     -- SOS 10104 - wally - 5mar03 - to consider Facility   
                        AND ISNULL(LOC.HostWHCode,'') = CASE WHEN @c_OverAllocPickByHostWHCode = '1' THEN @c_HostWHCode ELSE ISNULL(LOC.HostWHCode,'') END  --NJOW24  
                       
                     SELECT @n_cnt = @@ROWCOUNT, @n_Err = @@ERROR        
                  END  
        
                  --SELECT @n_cnt = COUNT(*)        
                  --FROM   #OP_PICKLOCTYPE        
        
                  IF @n_cnt = 0 OR @n_Err <> 0        
                  BEGIN        
                     SELECT @b_OverContinue = 0        
        
                     IF @n_JumpSource = 3        
                        GOTO RETURNFROMUPDATEINV_03        
        
                     IF (@b_debug = 1 OR @b_debug = 2) AND @n_Fetch_Status <> -1        
                     BEGIN        
                        PRINT ''        
                        PRINT '**** No Pick Location Found ****'        
                        PRINT '     Location Type Override: ' + @c_sLocationTypeOverride        
                     END        
                  END        
                  ELSE        
                  BEGIN        
                     -- commented out due to performance problem        
                     -- Fixing Issues SHONG02        
                     IF EXISTS (SELECT 1 FROM #OP_PickLocType        
                                LEFT OUTER JOIN LOTxLOCxID (NOLOCK)        
                                       ON  LOTxLOCxID.loc = #op_pickloctype.loc        
                                       AND StorerKey = @c_aStorerKey        
                                       AND SKU = @c_aSKU        
                                       AND Lot = @c_aLOT        
                                WHERE LOTxLOCxID.LOC IS NULL )        
                     BEGIN        
                        INSERT LOTxLOCxID (StorerKey, Sku, Lot, Loc, Id, Qty)        
                        SELECT @c_aStorerKey, @c_aSKU, @c_aLOT, #OP_PickLocType.Loc, SPACE(10), 0        
                          FROM #OP_PickLocType        
                        LEFT OUTER JOIN LOTxLOCxID (NOLOCK)        
                                       ON  LOTxLOCxID.loc = #op_pickloctype.loc        
                                       AND LOTxLOCxID.StorerKey = @c_aStorerKey        
                                       AND LOTxLOCxID.SKU = @c_aSKU        
                                       AND LOTxLOCxID.Lot = @c_aLOT        
                                WHERE LOTxLOCxID.LOC IS NULL        
                     END        
        
                     IF @@ERROR <> 0        
                     BEGIN        
                        SELECT @b_OverContinue = 0        
                     END        
                  END -- @n_cnt <> 0 or @n_Err = 0        
        
                  IF @b_OverContinue = 1        
                  BEGIN        
                     SELECT @c_PickLoc = ''        
                     IF @c_sLocationTypeOverridestripe = '1'        
                     BEGIN                                
                          --IF @c_PickOverAllocateNoMixLot >= '1' --NJOW01  
                          --BEGIN  
                        IF EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit(',',@c_PickOverAllocateNoMixLot)  
                                    WHERE ColValue IN ('01','02','03','04','05','06','07','08','09','10','11','12','13','14','15'))  
                        BEGIN    
                           --NJOW01  
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
                            IF @c_PickOverAllocateNoMixLot = '4'  
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
                           SELECT TOP 1        
                             @c_PickLoc = PL.LOC        
                             FROM #OP_PickLocType PL        
                             LEFT OUTER JOIN LOTxLOCxID LLI (NOLOCK) ON PL.LOC = LLI.LOC AND LLI.LOT = @c_aLOT        
                                  AND LLI.Qty > 0        
                             WHERE PL.LOC NOT IN (SELECT LOC FROM #OP_PICKLOCS        
                                                 WHERE StorerKey = @c_aStorerKey        
                                                 AND SKU = @c_aSKU        
                                                 AND LocationType = @c_sLocationTypeOverride)        
                             ORDER BY LLI.Qty DESC, PL.Loc        
                           -- SOS#129426 End        
                           IF ISNULL(RTRIM(@c_PickLoc),'') =''        
                           BEGIN        
                              DELETE FROM #OP_PICKLOCS        
                               WHERE StorerKey = @c_aStorerKey        
                                 AND SKU = @c_aSKU        
                                 AND LocationType = @c_sLocationTypeOverride        
                             
                              SELECT TOP 1 @c_PickLoc = LOC        
                                FROM #OP_PickLocType        
                              ORDER BY LOC        
                             
                           END        
                             
                           INSERT #OP_PICKLOCS (StorerKey, Sku, Loc, LocationType)        
                           VALUES ( @c_aStorerKey, @c_aSKU, @c_PickLoc, @c_sLocationTypeOverride )        
                        END  
                     END        
                     ELSE        
                     BEGIN        
                        SELECT TOP 1 @c_PickLoc = LOC        
                          FROM #OP_PickLocType        
                        ORDER BY LOC  
                        
                        IF @c_OverPickLoc <> ''                                     --(Wan08) - START
                        BEGIN
                           SET @c_pickloc = @c_OverPickLoc
                        END                                                         --(Wan08) - END                                 
                     END        
                  END        
        
                  INSERT #OP_OVERPICKLOCS (Loc, Id, QtyAvailable)        
                  SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,        
                         Floor((LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)/@n_cPackQty)*@n_cPackQty        
                    FROM LOTxLOCxID (NOLOCK), #OP_PickLocType        
                   WHERE LOTxLOCxID.STORERKEY = @c_aStorerKey        
                     AND LOTxLOCxID.Sku = @c_aSKU        
                     AND LOTxLOCxID.Lot = @c_aLOT        
                     AND LOTxLOCxID.Loc = #OP_PickLocType.Loc        
                     AND ( Floor((LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)/@n_cPackQty) > 0        
                     OR  LOTxLOCxID.Loc = @c_pickloc )        
                  ORDER BY CASE when #OP_PickLocType.Loc = @c_pickloc        
                                 then 1 ELSE 2 end, 1, 2        
        
                  IF @@ROWCOUNT = 0        
                  BEGIN        
                     SELECT @b_OverContinue = 0        
                     IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN ('0','1')        
                     BEGIN        
                        CLOSE CURSOR_CANDIDATES        
                        DEALLOCATE CURSOR_CANDIDATES        
                     END        
                  END        
                  ELSE IF @b_debug = 1 OR @b_debug = 2        
                  BEGIN        
                     PRINT ''        
                     PRINT '**** Over Allocation - Pick Location ****'        
                  END        
                  IF @b_OverContinue = 1        
                  BEGIN        
        
                     SELECT @n_QtyToOverTake = SUM(CASE WHEN QtyAvailable > 0        
                            THEN QtyAvailable ELSE 0 END )        
                      FROM #OP_OVERPICKLOCS        
        
                     IF @n_aQtyLeftToFulfill <= @n_QtyToOverTake        
                     BEGIN        
                        SELECT @n_QtyToOverTake = 0        
                     END        
                     ELSE        
                     BEGIN        
                        SELECT @n_QtyToOverTake = @n_aQtyLeftToFulfill - @n_QtyToOverTake        
                     END        
                     SELECT @n_RowNum = 0        
                     WHILE @n_aQtyLeftToFulfill > 0        
                     BEGIN        
                        SELECT TOP 1        
                               @n_RowNum = RowNum, @c_cLOC = LOC, @c_cid = Id,        
                               @n_QtyToTake = CASE WHEN QtyAvailable > 0        
                    THEN QtyAvailable ELSE 0 END        
                          FROM #OP_OVERPICKLOCS        
                        WHERE RowNum >  @n_RowNum        
                        ORDER BY RowNum        
        
                        IF @@ROWCOUNT = 0        
                        BEGIN        
                           BREAK        
                        END        
                        IF @c_cLOC = @c_PickLoc        
                        BEGIN        
                           SELECT @n_QtyToTake = @n_QtyToTake + @n_QtyToOverTake        
                           SELECT @n_QtyToOverTake = 0        
                        END        
                        IF @n_aQtyLeftToFulfill < @n_QtyToTake        
                        BEGIN        
                           SELECT @n_QtyToTake = @n_aQtyLeftToFulfill        
                        END        
                        SELECT @n_UOMQty = @n_QtyToTake / @n_cPackQty        
        
                        IF @b_debug = 1 OR @b_debug = 2        
                        BEGIN        
                           PRINT '     Location: ' + RTRIM(@c_cLOC) + ' Pallet ID: ' + @c_cid        
                           PRINT '     Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))        
                           PRINT '     Qty Left: ' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))        
                        END        
        
                        IF @n_QtyToTake > 0        
                        BEGIN        
                           IF @n_JumpSource = 3        
                              GOTO RETURNFROMUPDATEINV_03        
        
                           SELECT @n_JumpSource = 2        
                           GOTO UPDATEINV        
                           RETURNFROMUPDATEINV_02:        
                        END        
                     END -- WHILE @n_aQtyLeftToFulfill > 0        
                  /* #INCLUDE <SPOP5.SQL> */        
                  END -- End of doing a job        
               END  -- End of OVERALLOCATION        
            END -- IF LTrim(RTrim(@c_sLocationTypeOverride)) =''        
         END -- LOOP ALLOCATE STRATEGY DETAIL Lines        
        
         TryIfQtyRemain:        
         IF @b_TryIfQtyRemain = 1 AND @n_aQtyLeftToFulfill > 0 AND @n_NumberOfRetries < 7        
         BEGIN        
            IF @n_NumberOfRetries  = 0        
            BEGIN        
               SELECT @n_PalletQty = Pallet, @c_CartonizePallet = CartonizeUOM4,        
                      @n_CaseQty = CaseCnt, @c_CartonizeCase = CartonizeUOM1,        
                      @n_InnerPackQty = InnerPack, @c_CartonizeInner = CartonizeUOM2,        
                      @n_OtherUnit1 = CONVERT(INT,OtherUnit1), @c_CartonizeOther1 = CartonizeUOM8,        
                      @n_OtherUnit2 = CONVERT(INT,OtherUnit2), @c_CartonizeOther2 = CartonizeUOM9,        
                      @c_CartonizeEA = CartonizeUOM3        
               FROM PACK (NOLOCK)        
               WHERE PackKey = @c_aPackKey        
            END        
        
            SELECT @n_NumberOfRetries = @n_NumberOfRetries + 1        
            SELECT @c_aUOM = LTRIM(RTRIM(CONVERT(NVARCHAR(5), (CONVERT(INT,@c_aUOM) + 1))))        
  
            --NJOW09  
            IF ISNULL(@c_AllocateGetCasecntFrLottable,'')   
               IN ('01','02','03','06','07','08','09','10','11','12') AND @c_aUOM = '2'  
               AND ISNULL(@c_SkipPreAllocationFlag,'0') <> '1' --if not skip preallocation need to get casecnt from lot if uom = 2  
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
                  WHEN '1' THEN @n_PalletQty        
                  WHEN '2' THEN @n_CaseQty        
                  WHEN '3' THEN @n_InnerPackQty        
                  WHEN '4' THEN @n_OtherUnit1        
                  WHEN '5' THEN @n_OtherUnit2        
                  WHEN '6' THEN 1        
                  WHEN '7' THEN 1        
                  ELSE 0        
               END        
        
            SELECT @c_AdoCartonize =        
            CASE @c_aUOM        
               WHEN '1' THEN @c_CartonizePallet        
               WHEN '2' THEN @c_CartonizeCase        
               WHEN '3' THEN @c_CartonizeInner        
               WHEN '4' THEN @c_CartonizeOther1        
               WHEN '5' THEN @c_CartonizeOther2        
               WHEN '6' THEN @c_CartonizeEA        
               WHEN '7' THEN @c_CartonizeEA        
               ELSE 'N'        
            END        
        
            IF @b_debug = 1        
            BEGIN        
               PRINT ''        
               PRINT '**** Try If Qty Remain (ON) ****'        
               PRINT '     UOM-' + CAST(@n_NumberOfRetries AS NVARCHAR(10)) + ': ' + @c_aUOM        
                   + ' Qty Left:' + CAST(@n_aQtyLeftToFulfill AS NVARCHAR(10))        
               PRINT '     Pack Qty:' + CAST(@n_cPackQty AS NVARCHAR(10))        
            END        
        
            IF @n_cPackQty > 0        
            BEGIN        
               GOTO LOOPPICKSTRATEGY        
            END        
            ELSE        
            BEGIN        
              GOTO TryIfQtyRemain        
            END         
         END        
        
      END -- WHILE (1 = 1)        
      CLOSE C_OPORDERLINES        
      DEALLOCATE C_OPORDERLINES        
        
      SET @d_Step3 = GETDATE() - @d_Step3 -- (tlting01)        
      SET @c_Col3 = 'Stp3-Allocation' -- (tlting01)        
        
   END        
        
   /* #INCLUDE <SPOP2.SQL> */        
   /* Added By SHONG - DElete PreAllocatedPickDetail if Successfully allocated */        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      IF ISNULL(RTRIM(@c_WaveKey),'') <> ''        
      BEGIN        
         --NJOW12  
         DECLARE cur_DeletePreAllocatePickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT   PreAllocatePickDetail.PreAllocatePickDetailKey  
         FROM     PreAllocatePickDetail WITH (NOLOCK)  
         JOIN     WaveDetail WITH (NOLOCK) ON PreAllocatePickDetail.OrderKey = WaveDetail.OrderKey   
         WHERE    WaveDetail.WaveKey = @c_WaveKey   
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
         DELETE   PreAllocatePickDetail        
         FROM     PreAllocatePickDetail (NOLOCK),       
                  WaveDetail (NOLOCK)        
        WHERE     PreAllocatePickDetail.OrderKey = WaveDetail.OrderKey AND        
                  WaveDetail.WaveKey = @c_WaveKey AND        
                  PreAllocatePickDetail.Qty = 0        
        */            
      END        
   END        
   IF @n_Continue = 1 OR @n_Continue = 2        
   BEGIN        
      IF ISNULL(RTRIM(@c_WaveKey),'') <> ''        
      BEGIN        
         -- Commented by SHONG 10-Oct-2016, Redundance update of Order header  
         --DECLARE @c_WaveOrderKey NVARCHAR(10),        
         --        @n_originalQty INT,        
         --        @n_Qtyallocated INT        
        
         --DECLARE ORDER_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY        
         --   FOR SELECT  OrderKey        
         --       FROM    WaveDetail (NOLOCK)        
         --       WHERE   WaveKey = @c_WaveKey        
        
         --OPEN ORDER_CUR        
         --FETCH NEXT FROM ORDER_CUR INTO @c_WaveOrderKey        
         --WHILE (@@Fetch_Status <> -1) AND @n_Continue <> 3        
         --BEGIN        
         --   UPDATE ORDERS        
         --      SET EditDate = GETDATE()        
         --    WHERE ORDERS.OrderKey = @c_WaveOrderKey        
        
         --   SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
         --   IF @n_Err <> 0        
         --   BEGIN        
         --      SELECT @n_Continue = 3                     
         --      SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 63536   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         --      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Trigger On ORDERS Failed. (ispWaveProcessing)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '        
         --   END        
         --   FETCH NEXT FROM ORDER_CUR INTO @c_WaveOrderKey        
         --END -- @@Fetch_Status        
         --CLOSE ORDER_CUR        
         --DEALLOCATE ORDER_CUR        
         -- Force to trigger Status update        
         UPDATE Wave        
            SET EditDate = GETDATE(),        
                EditWho = 'AllocateGuy'        
          WHERE WaveKey = @c_WaveKey        
      END -- @c_WaveKey IS NOT NULL        
   END -- @n_Continue = 1 OR @n_Continue = 2        
  
  
   --NJOW18 Start  
   IF (@n_Continue = 1 OR @n_Continue = 2)   
   BEGIN  
      SET @c_PostAllocationSP = ''  
                                    
      EXEC nspGetRight    
           @c_Facility  = @c_Facility,   
           @c_StorerKey = @c_StorerKey,    
           @c_sku       = NULL,    
           @c_ConfigKey = 'PostAllocationSP',     
           @b_Success   = @b_Success                  OUTPUT,    
           @c_authority = @c_PostAllocationSP         OUTPUT,     
           @n_err       = @n_err                      OUTPUT,     
           @c_errmsg    = @c_errmsg                   OUTPUT    
  
      IF EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PostAllocationSP AND TYPE = 'P')     
         OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PostAllocationSP)  
      BEGIN    
         SET @b_Success = 0    
         EXECUTE dbo.ispPostAllocationWrapper   
                 @c_OrderKey = ''  
               , @c_LoadKey  = ''  
               , @c_Wavekey = @c_Wavekey    
               , @c_PostAllocationSP = @c_PostAllocationSP    
               , @b_Success = @b_Success     OUTPUT    
               , @n_Err     = @n_err         OUTPUT     
               , @c_ErrMsg  = @c_errmsg      OUTPUT    
               , @b_debug   = 0   
        
         IF @b_Success <> 1    
         BEGIN    
            EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
            RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
            RETURN  
         END       
      END        
   END   
   --NJOW18 End          
        
   -- Chee02      
   IF (@n_Continue = 1 OR @n_Continue = 2 OR @n_Continue = 4 )  --NJOW10  
   BEGIN        
      EXEC nspGetRight        
         @c_Facility  = @c_Facility,               --(Wan01)    
         @c_StorerKey = @c_StorerKey,        
         @c_sku       = NULL,        
         @c_ConfigKey = 'PostProcessingStrategyKey',        
         @b_Success   = @b_Success                   OUTPUT,        
         @c_authority = @c_PostProcessingStrategyKey OUTPUT,        
         @n_err       = @n_err                      OUTPUT,        
         @c_errmsg    = @c_errmsg                    OUTPUT        
         
      IF ISNULL(RTRIM(@c_PostProcessingStrategyKey),'') <> ''        
      BEGIN        
          SELECT @b_Success = 0        
             
          EXECUTE dbo.ispPostProcessing        
              @c_WaveKey         
            , @c_PostProcessingStrategyKey        
            , @b_Success OUTPUT        
            , @n_Err     OUTPUT        
            , @c_ErrMsg  OUTPUT        
            , @b_debug       
             
          SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT        
          IF @n_Err <> 0        
          BEGIN        
            SELECT @n_Continue = 3      
          END        
       END -- IF ISNULL(RTRIM(@c_PostProcessingStrategyKey),'') <> ''          
   END  -- IF (@n_Continue = 1 OR @n_Continue = 2)                
  
   --NJOW19 Start        
   EXEC isp_PrePostAllocate_Process @c_Orderkey = '',  
                                    @c_Loadkey = '',  
                                    @c_Wavekey = @c_Wavekey,  
                                    @c_Mode = 'POST',  
                                    @c_extendparms = 'WP',  
                                    @c_StrategykeyParm = @c_StrategykeyParm, --NJOW24                                                                           
                                    @b_Success = @b_Success OUTPUT,            
                                    @n_Err = @n_err OUTPUT,            
                                    @c_Errmsg = @c_errmsg OUTPUT  
                                          
   IF @b_Success <> 1    
   BEGIN    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END       
   --NJOW19 End           
  
   --NJOW05 Start                   
   IF (@n_Continue = 1 OR @n_Continue = 2)      
   BEGIN  
      SELECT TOP 1 @c_AllocateValidationRules = SC.sValue  
      FROM STORERCONFIG SC (NOLOCK)  
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname  
      WHERE SC.StorerKey = @c_StorerKey  
      AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')  
      AND SC.Configkey = 'PostAllocateExtendedValidation'  
      ORDER BY SC.Facility DESC  
        
      IF ISNULL(@c_AllocateValidationRules,'') <> ''  
      BEGIN  
         EXEC isp_Allocate_ExtendedValidation @c_Orderkey = '',  
                                              @c_Loadkey = '',  
                                              @c_Wavekey = @c_Wavekey,  
                                              @c_Mode = 'POST',  
                                              @c_AllocateValidationRules=@c_AllocateValidationRules,  
                                              @b_Success=@b_Success OUTPUT,   
                                              @c_ErrMsg=@c_ErrMsg OUTPUT           
                                                
         IF @b_Success <> 1    
         BEGIN    
            EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
            RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
            RETURN  
         END    
      END  
      ELSE     
      BEGIN  
         SELECT TOP 1 @c_AllocateValidationRules = SC.sValue      
         FROM STORERCONFIG SC (NOLOCK)   
         WHERE SC.StorerKey = @c_StorerKey   
         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')  
         AND SC.Configkey = 'PostAllocateExtendedValidation'      
         ORDER BY SC.Facility DESC  
           
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_AllocateValidationRules) AND type = 'P')            
         BEGIN            
            SET @c_SQL = 'EXEC ' + @c_AllocateValidationRules + ' @c_Orderkey, @c_Loadkey, @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
            EXEC sp_executesql @c_SQL,            
                 N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                           
                 '',            
                 '',  
                 @c_Wavekey,  
                 @b_Success OUTPUT,            
                 @n_Err OUTPUT,            
                 @c_ErrMsg OUTPUT  
                       
            IF @b_Success <> 1       
            BEGIN      
               EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'  
               RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
               RETURN  
            END           
         END    
      END            
   END    
   --NJOW05 End  
         
   -- TraceInfo (tlting01) - Start        
   /*        
   SET @d_EndTime = GETDATE()        
   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,        
                          Step1, Step2, Step3, Step4, Step5,        
                          Col1, Col2, Col3, Col4, Col5)        
   VALUES        
      (RTRIM(@c_TraceName), @d_StartTime, @d_EndTime        
      ,CONVERT(NVARCHAR(12),@d_EndTime - @d_StartTime ,114)        
      ,CONVERT(NVARCHAR(12),@d_Step1,114)        
      ,CONVERT(NVARCHAR(12),@d_Step2,114)        
      ,CONVERT(NVARCHAR(12),@d_Step3,114)        
      ,CONVERT(NVARCHAR(12),@d_Step4,114)        
      ,CONVERT(NVARCHAR(12),@d_Step5,114)        
      ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)        
        
      SET @d_Step1 = NULL        
      SET @d_Step2 = NULL        
      SET @d_Step3 = NULL        
      SET @d_Step4 = NULL        
      SET @d_Step5 = NULL        
    */        
   -- TraceInfo (tlting01) - End        
        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_Success = 0        
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END        
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispWaveProcessing'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012       
      RETURN        
   END        
   ELSE        
   BEGIN        
      SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END        
        
   UPDATEINV:        
   SELECT @b_PickUpdateSuccess = 1        
   IF @b_PickUpdateSuccess = 1        
   BEGIN    
      SELECT  @c_UOM1PickMethod = UOM1PickMethod, -- case        
              @c_UOM2PickMethod = UOM2PickMethod, -- InnerPack        
              @c_UOM3PickMethod = UOM3PickMethod, -- piece        
              @c_UOM4PickMethod = UOM4PickMethod, -- Pallet        
              @c_UOM5PickMethod = UOM5PickMethod, -- other 1        
              @c_UOM6PickMethod = UOM6PickMethod ,-- other 2        
              @c_UOM7PickMethod = UOM3PickMethod -- Yes,this statement is correct, UOM7 is a special case        
      FROM LOC (NOLOCK), PUTAWAYZONE (NOLOCK)        
      WHERE LOC.Putawayzone = PUtawayzone.Putawayzone        
        AND LOC.LOC = @c_cLOC        
        
      SELECT @c_aPickMethod =        
                 CASE @c_aUOM        
                     WHEN '1' THEN @c_UOM4PickMethod -- Full Pallets        
                     WHEN '2' THEN @c_UOM1PickMethod -- Full Case        
                     WHEN '3' THEN @c_UOM2PickMethod -- Inner        
                     WHEN '4' THEN @c_UOM5PickMethod -- Other 1        
                     WHEN '5' THEN @c_UOM6PickMethod -- Other 2 (uses the same PickMethod as other1)        
                     WHEN '6' THEN @c_UOM3PickMethod -- Piece        
                     WHEN '7' THEN @c_UOM3PickMethod -- Piece        
                     ELSE '0'        
            END        
        
      IF ISNULL(RTRIM(@c_aPickMethod),'') = ''        
      BEGIN        
         SET @c_aPickMethod = '3'        
      END        
        
      IF (@c_aUOM = '6' OR @c_aUOM = '7' OR @c_aUOM = '2' OR @c_aUOM = '3' OR @c_aUOM = '4'   --(Wan05)  
         OR @c_aUOM = '1')  --NJOW22              
      BEGIN        
         SELECT @n_QtyToInsert = @n_QtyToTake        
         SELECT @n_UOMQtyToInsert = @n_UOMQty        
      END        
      ELSE        
      BEGIN        
         SELECT @n_QtyToInsert = @n_QtyToTake/@n_UOMQty        
         SELECT @n_UOMQtyToInsert = 1        
      END        
    
      IF ISNULL(RTRIM(@c_SkipPreAllocationFlag),'0') <> '1'        
      BEGIN               
         DECLARE CUR_OrderLines CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT o.SeqNo, o.OrderKey, o.OrderLineNumber, o.Qty , o.UOMQty, SO.Loadkey --NJOW27        
            FROM   #OPORDERLINES o       
            JOIN   ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey AND O.OrderLineNumber = OD.OrderLineNumber                  
            JOIN   ORDERS AS SO WITH (NOLOCK) ON SO.OrderKey = o.OrderKey        
            JOIN   SKU (NOLOCK) ON o.Storerkey = SKU.Storerkey AND o.Sku = SKU.Sku --NJOW02  
            JOIN   PACK (NOLOCK) ON o.Packkey = PACK.Packkey --NJOW23             
            --JOIN   PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey --NJOW02             
            WHERE  o.StorerKey = @c_aStorerKey AND        
                   o.SKU = @c_aSKU AND        
                   o.LOT = @c_aLOT AND        
                   o.Facility = @c_aFacility AND        
                   o.UOM = @c_OriginUOM AND        
                   o.Qty > 0 AND        
                   o.StrategyKey = @c_aStrategyKey AND        
                   o.UOMQty = @n_OriginUOMQty AND
                   o.Channel = CASE WHEN @c_ChannelInventoryMgmt = '1' THEN @c_channel ELSE o.Channel END  -- ZG01
            ORDER BY SO.Priority,  --NJOW02  
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND OD.QtyAllocated+OD.QtyPicked > 0 THEN 1 ELSE 2 END,  --NJOW24  
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND O.Qty % @n_QtyToInsert = 0 THEN 1 ELSE 2 END,  --NJOW24  
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND O.Qty <= @n_QtyToInsert THEN 1 ELSE 2 END,  --NJOW24  
                     CASE WHEN PACK.Pallet > 0 THEN FLOOR(o.Qty / PACK.Pallet) ELSE 0 END DESC, --NJOW02  
                     CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(CASE WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END   
                                                           / PACK.CaseCnt) ELSE 0 END DESC, --NJOW02  
                     SO.Loadkey, --NJOW14  
                     CASE WHEN PACK.InnerPack > 0 THEN FLOOR(CASE WHEN PACK.CaseCnt > 0 THEN o.Qty % CAST(PACK.CaseCnt AS INT)  
                                                                  WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END   
                                                             / PACK.InnerPack) ELSE 0 END DESC, --NJOW02  
                     CASE WHEN PACK.InnerPack > 0 THEN o.Qty % CAST(PACK.InnerPack AS INT)  
                          WHEN PACK.CaseCnt > 0 THEN o.Qty % CAST(PACK.CaseCnt AS INT)  
                          WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END DESC, --NJOW02           
                     O.Qty % @n_QtyToInsert  --NJOW13  
            --ORDER BY SO.Priority, o.OrderKey, o.OrderLineNumber      
                 
      END        
      ELSE        
      BEGIN                   
         DECLARE CUR_OrderLines CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT o.SeqNo, o.OrderKey, o.OrderLineNumber, o.Qty , o.UOMQty, SO.Loadkey --NJOW27             
            FROM   #OPORDERLINES o         
            JOIN   ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey AND O.OrderLineNumber = OD.OrderLineNumber      
            JOIN   ORDERS AS SO WITH (NOLOCK) ON SO.OrderKey = o.OrderKey AND SO.OrderKey = OD.OrderKey         
            JOIN   SKU (NOLOCK) ON o.Storerkey = SKU.Storerkey AND o.Sku = SKU.Sku --NJOW02  
            JOIN   PACK (NOLOCK) ON o.Packkey = PACK.Packkey --NJOW23             
            --JOIN   PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey --NJOW02             
            WHERE  o.StorerKey = @c_aStorerKey AND        
                   o.SKU = @c_aSKU AND        
                   o.Facility = @c_aFacility AND        
                   o.UOM = @c_OriginUOM AND        
                   o.Qty > 0 AND        
                   o.StrategyKey = @c_aStrategyKey AND        
                   o.UOMQty = @n_OriginUOMQty AND       
                   o.Channel = CASE WHEN @c_ChannelInventoryMgmt = '1' THEN @c_channel ELSE o.Channel END AND  -- ZG01
                   OD.Lottable01 = @c_Lottable01 AND --NJOW21  
                   OD.Lottable02 = @c_Lottable02 AND  
                   OD.Lottable03 = @c_Lottable03 AND  
                   OD.Lottable04 = @d_Lottable04 AND  
                   OD.Lottable05 = @d_Lottable05 AND  
                   OD.Lottable06 = @c_Lottable06 AND        
                   OD.Lottable07 = @c_Lottable07 AND        
                   OD.Lottable08 = @c_Lottable08 AND        
                   OD.Lottable09 = @c_Lottable09 AND        
                   OD.Lottable10 = @c_Lottable10 AND        
                   OD.Lottable11 = @c_Lottable11 AND        
                   OD.Lottable12 = @c_Lottable12 AND        
                   OD.Lottable13 = @d_Lottable13 AND        
                   OD.Lottable14 = @d_Lottable14 AND        
                   OD.Lottable15 = @d_Lottable15                                       
            ORDER BY CASE WHEN ISNULL(@c_UOMByLoad,'N') = 'Y' THEN SO.Loadkey 
                          WHEN ISNULL(@c_UOMByOrder,'N') = 'Y' THEN SO.Orderkey ELSE '' END,  --NJOW27
                     SO.Priority, --NJOW02  
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND OD.QtyAllocated+OD.QtyPicked > 0 THEN 1 ELSE 2 END,  --NJOW24              
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND O.Qty % @n_QtyToInsert = 0 THEN 1 ELSE 2 END,  --NJOW24  
                     CASE WHEN @c_WConsoOption1 = 'FULFILLBYORDER' AND O.Qty <= @n_QtyToInsert THEN 1 ELSE 2 END,  --NJOW24  
                     CASE WHEN PACK.Pallet > 0 THEN FLOOR(o.Qty / PACK.Pallet) ELSE 0 END DESC, --NJOW02  
                     CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(CASE WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END   
                                                           / PACK.CaseCnt) ELSE 0 END DESC, --NJOW02  
                     SO.Loadkey, --NJOW14              
                     CASE WHEN PACK.InnerPack > 0 THEN FLOOR(CASE WHEN PACK.CaseCnt > 0 THEN o.Qty % CAST(PACK.CaseCnt AS INT)  
                                                                  WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END   
                                                             / PACK.InnerPack) ELSE 0 END DESC, --NJOW02  
                     CASE WHEN PACK.InnerPack > 0 THEN o.Qty % CAST(PACK.InnerPack AS INT)  
                          WHEN PACK.CaseCnt > 0 THEN o.Qty % CAST(PACK.CaseCnt AS INT)  
                          WHEN PACK.Pallet > 0 THEN o.Qty % CAST(PACK.Pallet AS INT) ELSE o.Qty END DESC, --NJOW02           
                     O.Qty % @n_QtyToInsert  --NJOW13  
           --ORDER BY o.SeqNo                         
           --ORDER BY SO.Priority, o.OrderKey, o.OrderLineNumber                     
      END        
       
      OPEN CUR_OrderLines        
        
      FETCH NEXT FROM CUR_OrderLines INTO @n_SeqNo, @c_aOrderKey,        
                                          @c_aOrderLineNumber, @n_PickQty, @n_OriginUOMQty, @c_Loadkey --NJOW27        
      
      SELECT @c_PrevLoadkey = '*', @n_TotalQty = 0, @c_PrevOrderKey = '*' --NJOW27
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyToInsert > 0        
      BEGIN          
          --NJOW27 S
          IF ((ISNULL(@c_UOMByLoad,'N') = 'Y' AND ISNULL(@c_Loadkey,'') <> '') OR ISNULL(@c_UOMByOrder,'N') = 'Y') 
             AND ISNULL(@c_SkipPreAllocationFlag,'0') = '1'  
          BEGIN              
              IF (ISNULL(@c_Loadkey,'') <> ISNULL(@c_PrevLoadkey,'') AND ISNULL(@c_UOMByLoad,'N') = 'Y') 
                 OR (ISNULL(@c_aOrderKey,'') <> ISNULL(@c_PrevOrderKey,'') AND ISNULL(@c_UOMByOrder,'N') = 'Y') 
            BEGIN
                SET @n_TotalQty = 0
                 SELECT @n_TotalQty = SUM(o.Qty)
                 FROM #OPORDERLINES o         
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON o.OrderKey = OD.OrderKey AND o.OrderLineNumber = OD.OrderLineNumber                     
               JOIN ORDERS SO (NOLOCK) ON SO.OrderKey = o.OrderKey AND OD.Orderkey = SO.Orderkey  
               LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON SO.Orderkey = LPD.Orderkey              
               WHERE (LPD.Loadkey = @c_Loadkey OR ISNULL(@c_Loadkey,'') = '')       
               AND (o.Orderkey = @c_aOrderkey OR ISNULL(@c_UOMByOrder,'N') <> 'Y')
               AND o.StorerKey = @c_aStorerKey    
               AND o.SKU = @c_aSKU 
               AND o.Facility = @c_aFacility         
               AND o.UOM = @c_OriginUOM         
               AND o.Qty > 0         
               AND o.StrategyKey = @c_aStrategyKey         
               AND o.UOMQty = @n_OriginUOMQty        
               AND o.Channel = CASE WHEN @c_ChannelInventoryMgmt = '1' THEN @c_channel ELSE o.Channel END 
               AND OD.Lottable01 = @c_Lottable01 
               AND OD.Lottable02 = @c_Lottable02 
               AND OD.Lottable03 = @c_Lottable03 
               AND OD.Lottable04 = @d_Lottable04 
               AND OD.Lottable05 = @d_Lottable05 
               AND OD.Lottable06 = @c_Lottable06      
               AND OD.Lottable07 = @c_Lottable07      
               AND OD.Lottable08 = @c_Lottable08      
               AND OD.Lottable09 = @c_Lottable09      
               AND OD.Lottable10 = @c_Lottable10      
               AND OD.Lottable11 = @c_Lottable11      
               AND OD.Lottable12 = @c_Lottable12      
               AND OD.Lottable13 = @d_Lottable13      
               AND OD.Lottable14 = @d_Lottable14      
               AND OD.Lottable15 = @d_Lottable15      
                              
               SET @n_TotalQty = FLOOR(@n_TotalQty / @n_cPackQty) * @n_cPackQty                                       
            END                       
            
            IF @n_TotalQty = 0 
               GOTO NEXT_ORDLINE
                        
            IF @n_TotalQty < @n_PickQty 
            BEGIN
               SET @n_PickQty = @n_TotalQty
            END  
          END
          --NJOW27 E
            
         IF (@b_debug = 1 OR @b_debug = 2)        
         BEGIN        
            PRINT ' '      
            PRINT 'OrderKey : ' + @c_aOrderKey + ' @n_SeqNo: ' + CAST(@n_SeqNo as NVARCHAR)      
            PRINT 'n_PickQty : ' + CAST(@n_PickQty as NVARCHAR) + '  n_QtyToInsert : ' + Cast( @n_QtyToInsert as NVARCHAR)        
                  
         END        
        
         IF @n_PickQty > @n_QtyToInsert        
         BEGIN        
            SET @n_PickQty = @n_QtyToInsert        
         END    
    
         SELECT @n_PickRecsCreated = 0        
         WHILE @n_PickRecsCreated < @n_UOMQty AND @b_PickUpdateSuccess = 1        
         BEGIN        
            IF @b_PickUpdateSuccess = 1        
            BEGIN        
               SELECT @b_Success = 0        
               EXECUTE nspg_getkey        
                       'PickDetailKey'        
                       , 10        
                       , @c_PickDetailKey OUTPUT        
                       , @b_Success       OUTPUT        
                       , @n_Err           OUTPUT        
                       , @c_ErrMsg        OUTPUT        
            END        
            IF @b_Success = 1        
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
                           SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspLoadProcessing)'   
                     END CATCH           
                  END  
               END   
               ELSE   
               BEGIN  
                  SET @n_Channel_ID = 0                 
               END  
                             
               BEGIN TRANSACTION TROUTERLOOP  
  
               INSERT #OPPICKDETAIL  
                 ( PickDetailKey,        PickHeaderKey,   OrderKey,  
                   OrderLineNumber,      Lot,             StorerKey,  
                   Sku,                  Qty,             Loc,  
                   Id,                   UOMQty,          UOM,  
                   CaseID,               PackKey,         CartonGroup,  
                   doCartonize,          doreplenish,     replenishzone,  
                   PickMethod,           Channel_ID)  
                  VALUES  
                 (  
                   @c_PickDetailKey,     '',              @c_aOrderKey,  
                   @c_AOrderLineNumber,  @c_aLOT,         @c_aStorerKey,  
                   @c_aSKU,              @n_PickQty,      @c_cLOC,  
                   @c_cid,               @n_PickQty,      @c_aUOM,  
                   '',                   @c_aPackKey,     '',  --@c_ACartonGroup,  
                   'N',                  'N',             '',  
                   @c_aPickMethod,       @n_Channel_ID  
                 )  
  
               SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT  
               IF NOT (@n_Err = 0 AND @n_cnt = 1)  
               BEGIN  
                  SELECT @b_PickUpdateSuccess = 0  
               END  
               IF @b_PickUpdateSuccess = 1  
               BEGIN                    -- Added By SHONG -- @c_PHeaderKey  
                  IF @c_DoCartonization <> 'Y'  
                  BEGIN  
                     SELECT @c_PHeaderKey = ''  
                     SELECT @c_caseid = ' '  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @c_PHeaderKey = 'N'+@c_OPRun  
                     SELECT @c_caseid = 'C'+ @c_OPRun  
                  END  
  
                  INSERT PICKDETAIL  
                    (  
                      PickDetailKey,  
                      PickHeaderKey,  
                      OrderKey,  
                      OrderLineNumber,  
                      Lot,  
                      StorerKey,  
                      Sku,  
                      Qty,  
                      Loc,  
                      Id,  
                      UOMQty,  
                      UOM,  
                      CaseID,  
                      PackKey,  
                      CartonGroup,  
                      DoReplenish,  
                      replenishzone,  
                      doCartonize,  
                      Trafficcop,  
                      PickMethod,   
                      WaveKey,  
                      DropID,      --NJOW13   
                      Channel_ID  
                    )  
                  VALUES  
                    (  
                      @c_PickDetailKey,  
                      @c_PHeaderKey,  
                      @c_aOrderKey,  
                      @c_AOrderLineNumber,  
                      @c_aLOT,  
                      @c_aStorerKey,  
                      @c_aSKU,  
                      @n_PickQty,  
                      @c_cLOC,  
                      @c_cid,  
                      @n_PickQty,  
                      @c_aUOM,  
                      @c_caseid,  
                      @c_aPackKey,  
                      '', -- @c_ACartonGroup,  
                      'N',  
                      '',  
                      @c_AdoCartonize,  
                      'U',  
                      @c_aPickMethod,   
                      @c_WaveKey,  
                      ISNULL(@c_UCCNo,''),                                          --Wan07--NJOW13    
                      @n_Channel_ID   
                    )  
  
                  SELECT @n_Err = @@ERROR, @n_cnt_sql = @@ROWCOUNT  
                  SELECT @n_cnt = COUNT(1) FROM PICKDETAIL WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey  
                  
                  IF (@b_debug = 1 OR @b_debug = 2) AND (@n_cnt_sql <> @n_cnt)  
                  BEGIN  
                     PRINT ''  
                     PRINT '**** Error - Insert Pick Detail ****'  
                  END  
                  IF NOT (@n_Err = 0 AND @n_cnt = 1)  
                  BEGIN  
                     SELECT @b_PickUpdateSuccess = 0  
                  END  
                  IF @b_PickUpdateSuccess = 1  
                  BEGIN  
                     UPDATE #OPORDERLINES  
                        SET Qty = Qty - @n_PickQty  
                     WHERE SeqNo = @n_SeqNo  
                  
                     SELECT @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill - @n_PickQty  
                     SET    @n_QtyToInsert = @n_QtyToInsert - @n_PickQty  

                     IF (ISNULL(@c_UOMByLoad,'N')='Y' OR ISNULL(@c_UOMByOrder,'N')='Y') AND ISNULL(@c_SkipPreAllocationFlag,'0')='1'  --NJOW27
                        SET @n_TotalQty = @n_TotalQty - @n_PickQty
                  
                     COMMIT TRAN TROUTERLOOP  
                  
                     IF @b_debug = 3 --@b_debug = 1  
                     BEGIN  
                        PRINT ''  
                        PRINT '**** Succeed - Insert Pick Detail ****'  
                        PRINT '     PickDetail#: ' + RTRIM(@c_PickDetailKey) +  
                              ' Qty: ' + CAST(@n_PickQty AS NVARCHAR(10))  
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
                                 Wavekey = @c_Wavekey  
                             WHERE UCCNo = @c_UCCNo  
                           AND Storerkey = @c_aStorerkey  
                           AND Sku = @c_aSku  
                           AND Status < '3'                       
                        END  
                     END                    
                  END -- @b_PickUpdateSuccess = 1        
                  ELSE        
                  BEGIN        
                        ROLLBACK TRAN TROUTERLOOP        
                        BREAK        
                  END  -- @b_PickUpdateSuccess <> 1        
               END -- @b_Success = 1 ; Generation PickDetailKey        
            END        
            ELSE        
            BEGIN        
               SELECT @b_PickUpdateSuccess = 0        
            END  -- IF @b_sucess = 1        
            SELECT @n_PickRecsCreated = @n_PickRecsCreated + 1        
            IF @c_aUOM = '6' OR @c_aUOM = '7' OR @c_aUOM = '2' OR @c_aUOM = '3' OR @c_aUOM = '4'   --(Wan05)       
               OR @c_aUOM = '1' --NJOW22              
            BEGIN        
               BREAK        
            END        
         END -- While @n_PickRecsCreated < @n_UOMQty        
       
       --NJOW27
       NEXT_ORDLINE:        
       SET @c_PrevLoadkey = @c_Loadkey      
       SET @c_PrevOrderkey = @c_aOrderkey  
                 
       FETCH NEXT FROM CUR_OrderLines INTO @n_SeqNo, @c_aOrderKey,        
                        @c_aOrderLineNumber, @n_PickQty, @n_OriginUOMQty, @c_Loadkey --NJOW27           
      END        
      CLOSE CUR_OrderLines        
      DEALLOCATE CUR_OrderLines        
        
   /* #INCLUDE <SPOP6.SQL> */        
   END -- @b_PickUpdateSuccess = 1        
        
   IF @n_JumpSource = 1        
   BEGIN        
      GOTO RETURNFROMUPDATEINV_01        
   END        
   IF @n_JumpSource = 2        
   BEGIN        
      GOTO RETURNFROMUPDATEINV_02        
   END        
END -- Procedure  



GO