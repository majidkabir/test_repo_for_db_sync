SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispRLWAV16                                            */  
/* Creation Date: 20-APR-2018                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-4345 - CN UA Release Wave (B2B)                            */
/*                                                                         */  
/* Called By: wave                                                         */  
/*                                                                         */  
/* PVCS Version: 1.5                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */  
/* 08-Apr-2019 NJOW01   1.0   Fix - make sure uom 2 converted to uom 6     */
/*                            for conso carton                             */ 
/* 15-May-2019 NJOW02   1.1   WNMS-8924 Change PTS assign logic.           */
/*                            Replenish addition carton if the             */
/*                            location no more available qty after pick.   */
/* 15-Aug-2019 NJOW03   1.2   WMS-9825 create replenishment records by     */
/*                            ucc for manual replenshment as backup plan   */
/* 23-Oct-2019 NJOW04   1.3   Fix split pickdetail issue                   */
/* 01-04-2020  Wan01    1.4   Sync Exceed & SCE                            */ 
/* 25-08-2021  WLChooi  1.5   WMS-17812 - Set Priority to 4 (WL01)         */ 
/* 21-Mar-2022 NJOW05   1.6   WMS-19267 if facility=UABJ gen pickslip only */
/* 21-Mar-2022 NJOW05   1.6   DEVOPS Combine script                        */
/* 02-Aug-2023 NJOW06   1.7   WMS-23269 add UAGZ facility filtering        */
/***************************************************************************/   

CREATE   PROCEDURE [dbo].[ispRLWAV16]      
  @c_wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
            
    IF @n_err = 1
       SET @n_debug = 1
    ELSE    
       SET @n_debug = 0
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    
    DECLARE @c_Storerkey NVARCHAR(15)
            ,@c_Facility NVARCHAR(5)
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@c_ToID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_SourceType NVARCHAR(30)
            ,@c_Orderkey NVARCHAR(10)
            ,@n_CaseCnt INT
            ,@c_Packstation NVARCHAR(10)
            ,@c_PTSStaging NVARCHAR(10)
            ,@c_TaskType NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_PickMethod NVARCHAR(10)            
            ,@c_Priority NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@n_TotCtn INT
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)
            ,@c_Pickdetailkey NVARCHAR(10)
            ,@c_Userdefine02 NVARCHAR(20)
            ,@c_Userdefine03 NVARCHAR(20)            
            ,@c_Loadkey NVARCHAR(10)
            ,@c_DeviceId NVARCHAR(20)
            ,@c_IPAddress NVARCHAR(40)
            ,@c_PortNo NVARCHAR(5)
            ,@c_DevicePosition NVARCHAR(10)
            ,@c_PTSLOC NVARCHAR(10)
            ,@n_InsertQty INT
            ,@c_PickslipNo NVARCHAR(10)
            ,@n_QtyShort INT
            ,@n_QtyAvailable INT
            ,@n_QtyReplen INT
            ,@c_Message01 NVARCHAR(20) 
            ,@c_Message02 NVARCHAR(20) 
            ,@c_Message03 NVARCHAR(20) 
            ,@n_PTSRequire INT
            ,@n_PTSCount INT
            ,@c_SkuGroup NVARCHAR(10)
            ,@c_WaveConsoAllocation NVARCHAR(10)
            ,@c_WCS NVARCHAR(10)
            ,@c_Door NVARCHAR(10)
            ,@c_WaveConsoAllocation_option1 NVARCHAR(50)
            ,@c_OneSkuPerCarton NVARCHAR(10)
            ,@c_PrevOrderkey NVARCHAR(10) --NJOW02
            ,@n_CurrDeviceNo INT --NJOW02
            ,@n_PrevDeviceNo INT --NJOW02
            ,@n_TotalDevice INT --NJOW02
            ,@c_PackUOM NVARCHAR(10) --NJOW03
            
     --NJOW03       
     DECLARE @c_WaveType NVARCHAR(18)
            ,@c_UCCNo NVARCHAR(20) 
            ,@n_UCCQty INT 
            ,@n_PickQty INT 
            ,@c_NewPickDetailKey NVARCHAR(10)
            ,@n_SplitQty INT 
            ,@c_ReplenishmentKey NVARCHAR(10) 
            ,@n_QtyToTake INT 
            ,@c_PackKey NVARCHAR(10)
            ,@c_MoveRefKey NVARCHAR(10) 
            ,@c_ReplenishmentGroup NVARCHAR(10) 
            ,@c_ReplenNo NVARCHAR(10) 
            ,@c_FromID NVARCHAR(18)             
            ,@n_QtyInPickLoc INT
                        
    SET @c_SourceType = 'ispRLWAV16'    
    --SET @c_Priority = '8'   --WL01
    SET @c_Priority = '4'     --WL01
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = 'PP'

    --NJOW05
    IF EXISTS(SELECT 1
              FROM WAVE W (NOLOCK)
              JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
              JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
              AND W.Wavekey = @c_Wavekey
              AND O.Facility IN ('UABJ','UAGZ')) --NJOW06
     BEGIN               
        EXEC isp_CreatePickSlip
                  @c_Wavekey = @c_Wavekey
                 ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
                 ,@b_Success = @b_Success OUTPUT
                 ,@n_Err = @n_err OUTPUT 
                 ,@c_ErrMsg = @c_errmsg OUTPUT     
                        
        GOTO UPDATE_WAVE        
     END            

    -----Wave Validation-----               
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('RPF')
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV16)'       
       END      
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN('RPF'))
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV16)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) 
                   JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey
                   WHERE WAVEDETAIL.Wavekey = @c_Wavekey
                   AND ISNULL(ORDERS.Loadkey,'')='')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found order no load plan. (ispRLWAV16)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1
                 FROM WAVEDETAIL WD (NOLOCK)                                                             
                 JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                 JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku       
                 LEFT JOIN CODELKUP CL (NOLOCK) ON SKU.Storerkey = CL.Storerkey AND SKU.Susr3 = CL.Code AND CL.Listname = 'SKUGROUP'                      
                 WHERE WD.Wavekey = @c_Wavekey                                                           
                 AND PD.Status = '0'                                                                     
                 --AND PD.WIP_RefNo = @c_SourceType                                                        
                 --AND PD.UOM IN('6','7')
                 AND PD.UOM = '6'
                 AND ISNULL(CL.Short,'') = ''                 
                 )     
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found sku without skugroup setup at codelkup.short. (ispRLWAV16)'       
       END          
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1
                  FROM WAVEDETAIL WD (NOLOCK)            
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey                                                 
                  WHERE WD.Wavekey = @c_Wavekey
                  HAVING COUNT(DISTINCT O.Type) > 1)                  
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Reject Release. More than 1 order type in a Wave is not allowed. (ispRLWAV16)'       
       END          
    END
      
    -----Get Storerkey, facility and order group
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                      @c_Userdefine02 = W.UserDefine02,
                     @c_Userdefine03 = W.UserDefine03,
                     @c_WaveType = W.WaveType --NJOW03                      
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        --JOIN CODELKUP CL (NOLOCK) ON O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey AND CL.Listname = 'ORDERGROUP' 
        AND W.Wavekey = @c_Wavekey 

        --SELECT @c_WaveConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveConsoAllocation')   
               
        EXECUTE nspGetRight                                
          @c_Facility  = @c_facility,                     
          @c_StorerKey = @c_StorerKey,                    
          @c_sku       = '',                          
          @c_ConfigKey = 'WaveConsoAllocation',         
          @b_Success   = @b_success   OUTPUT,             
          @c_authority = @c_WaveConsoAllocation OUTPUT,             
          @n_err       = @n_err       OUTPUT,             
          @c_errmsg    = @c_errmsg    OUTPUT,             
          @c_Option1   = @c_WaveConsoAllocation_option1 OUTPUT               
        
        SELECT @c_WCS= dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WCS')           
        
        IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '') AND @c_WaveConsoAllocation = '1'
        BEGIN         
           SELECT @n_continue = 3  
           SELECT @n_err = 83040    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in PTS Station at userdefine02&03. (ispRLWAV16)'       
           GOTO RETURN_SP                      
        END 
        
        EXEC dbo.nspg_GetKey                
            @KeyName = 'UATASK'    
           ,@fieldlength = 10    
           ,@keystring = @c_message02 OUTPUT    
           ,@b_Success = @b_success OUTPUT    
           ,@n_err = @n_err OUTPUT    
           ,@c_errmsg = @c_errmsg OUTPUT
           ,@b_resultset = 0    
           ,@n_batch     = 1           
         
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
            GOTO RETURN_SP
         END                                                   
    END    
    
    --NJOW03
    IF @n_continue IN(1,2) AND @c_WaveType = 'PAPER'
    BEGIN
        IF EXISTS (SELECT 1 FROM REPLENISHMENT (NOLOCK)
                   WHERE Wavekey = @c_Wavekey
                   AND Storerkey = @c_Storerkey)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83050    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released for paper replenishment. (ispRLWAV16)'       
        END                 
    END
        
    --Make sure UOM 2 Have converted to UOM 6 for conso carton --NJOW01
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1
                  FROM WAVEDETAIL WD (NOLOCK) 
                  JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                  JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
                  JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
                  WHERE PD.UOM = '2'
                  AND WD.Wavekey = @c_Wavekey
                  GROUP BY PD.Orderkey, PD.Sku, PACK.Casecnt
                  HAVING SUM(PD.qty) % CASE WHEN PACK.Casecnt > 0 THEN CAST(PACK.Casecnt AS INT) ELSE 1 END <> 0)       
       BEGIN
          EXEC ispPOA03    
              @c_OrderKey = '' 
             ,@c_LoadKey = ''
             ,@c_Wavekey = @c_Wavekey
             ,@b_Success = @b_Success OUTPUT    
             ,@n_Err     = @n_Err     OUTPUT    
             ,@c_ErrMsg  = @c_ErrMsg  OUTPUT    
       END          
    END

    --Create pickdetail Work in progress temporary table AND Other temp table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       CREATE TABLE #PickDetail_WIP(
          [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
          [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
          [PickHeaderKey] [nvarchar](18) NOT NULL,
          [OrderKey] [nvarchar](10) NOT NULL,
          [OrderLineNumber] [nvarchar](5) NOT NULL,
          [Lot] [nvarchar](10) NOT NULL,
          [Storerkey] [nvarchar](15) NOT NULL,
          [Sku] [nvarchar](20) NOT NULL,
          [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
          [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
          [UOMQty] [int] NOT NULL DEFAULT ((0)),
          [Qty] [int] NOT NULL DEFAULT ((0)),
          [QtyMoved] [int] NOT NULL DEFAULT ((0)),
          [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
          [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
          [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
          [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
          [PackKey] [nvarchar](10) NULL DEFAULT (' '),
          [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
          [CartonGroup] [nvarchar](10) NULL,
          [CartonType] [nvarchar](10) NULL,
          [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
          [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
          [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
          [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
          [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
          [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
          [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
          [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [TrafficCop] [nvarchar](1) NULL,
          [ArchiveCop] [nvarchar](1) NULL,
          [OptimizeCop] [nvarchar](1) NULL,
          [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
          [PickSlipNo] [nvarchar](10) NULL,
          [TaskDetailKey] [nvarchar](10) NULL,
          [TaskManagerReasonKey] [nvarchar](10) NULL,
          [Notes] [nvarchar](4000) NULL,
          [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
          [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
          [Channel_ID] [bigint] NULL DEFAULT ((0)))    
          
          CREATE INDEX PDWIP_Order ON #PickDetail_WIP (Orderkey)              
          
          CREATE TABLE #ONESKUPERCTNORDER (
           [Orderkey] [nvarchar](10) NULL)
    END
           
    IF @@TRANCOUNT = 0
       BEGIN TRAN
           
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WCS = '1'
    BEGIN
       SET @c_Loadkey = ''
       SELECT TOP 1 @c_Loadkey = O.Loadkey 
       FROM WAVEDETAIL WD (NOLOCK)            
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey                                                 
       LEFT JOIN LOADPLANLANEDETAIL LPL (NOLOCK) ON O.Loadkey = LPL.Loadkey AND LPL.Status = '0'
       WHERE WD.Wavekey = @c_Wavekey
       AND LPL.Loadkey IS NULL
       AND O.loadkey <> ''
       AND O.Type = 'UAOBD'
       ORDER BY O.Loadkey
                 
       IF ISNULL(@c_Loadkey,'') <> ''     
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83060    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Reject Release. Found Load# ''' + RTRIM(@c_Loadkey) + ''' not yet assign lane. (ispRLWAV16)'       
       END          
    END    
    
    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey  
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'Y'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END                   
    END
        
   --Get pack statation location for full carton and PTS Staging for multi order conso carton
    IF @n_continue = 1 OR @n_continue = 2 
    BEGIN             
       SELECT @c_PackStation = CL.Long
       FROM CODELKUP CL (NOLOCK)
       JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
       WHERE CL.Listname = 'UALOC'
       AND CL.Storerkey = @c_Storerkey
       AND CL.Code =  '1'
       
       IF ISNULL(@c_PackStation,'') = ''
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Pack Station setup. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END
       ELSE IF @c_WaveConsoAllocation = '1'
       BEGIN             
          SELECT @c_PTSStaging = CL.Long
          FROM CODELKUP CL (NOLOCK)
          JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
          WHERE CL.Listname = 'UALOC'
          AND CL.Storerkey = @c_Storerkey
          AND CL.Code =  '2'
          
          IF ISNULL(@c_PTSStaging,'') = ''
          BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid PTS Staging setup. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END
       END
    END              

    --PTS reservation Conso(UOM 6) 
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveConsoAllocation = '1'
    BEGIN
       --Get One sku per carton order
       IF @c_WaveConsoAllocation_OPTION1 = 'SKUPERCTNSKIPPTS'
       BEGIN
          INSERT INTO #ONESKUPERCTNORDER (Orderkey)
          SELECT DISTINCT PD.Orderkey     
          FROM WAVEDETAIL WD (NOLOCK)                                                             
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          --JOIN ORDERDETAIL OD (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
          JOIN DOCINFO DI (NOLOCK) ON DI.TableName = 'ORDERDETAIL' AND PD.Storerkey = DI.Storerkey AND PD.Orderkey = DI.Key1 
          WHERE WD.Wavekey = @c_Wavekey               
          AND SUBSTRING (DI.Data, 1,30) = 'Packing Instructions'
          AND SUBSTRING (DI.Data, 31,30) = '30' 
          AND SUBSTRING (DI.Data, 61,30) = '61'
          AND SUBSTRING (DI.Data, 91,30) = '1 SKU/Carton' 
          AND DI.Key2 = '00001'
          
          IF @n_debug = 1
             SELECT * FROM #ONESKUPERCTNORDER
       END            
             
       --Get PTS station empty loc Count
       SELECT @n_PTSCount = COUNT(DP.Loc)                
       FROM LOC (NOLOCK) 
       JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc        
       LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc
       WHERE DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03                    
       AND LOC.Facility = @c_Facility
       --AND LOC.LocationCategory = 'PTS'
       AND DP.DeviceType = 'STATION'       
       AND DP.Storerkey = @c_Storerkey
       AND DP.Status = '0'
       AND PTL.RowRef IS NULL

       --Conso carton to PTS loc requirement
       SELECT @n_PTSRequire = COUNT(DISTINCT PD.Orderkey) * 2       
       FROM WAVEDETAIL WD (NOLOCK)                                                             
       JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
       LEFT JOIN #ONESKUPERCTNORDER OSO ON PD.Orderkey = OSO.Orderkey 
       WHERE WD.Wavekey = @c_Wavekey                                                           
       AND PD.Status = '0'                                                                     
       AND PD.WIP_RefNo = @c_SourceType
       AND PD.UOM = '6'                          
       AND OSO.Orderkey IS NULL                              
       --AND PD.UOM IN('6','7')                     

       IF @n_PTSCount < @n_PTSRequire   
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough PTS Location. (ispRLWAV16)'           
       END                                                                                                     
    END
          
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveConsoAllocation = '1'
    BEGIN
       IF @n_debug = 1
       BEGIN
           PRINT 'Assign PTS location'
       END
       
       --NJOW02
       SELECT IDENTITY(INT,1,1) AS DeviceNo, DP.DeviceID        
       INTO #TMP_DEVICE
       FROM DEVICEPROFILE DP (NOLOCK) 
       JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc 
       LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
       WHERE DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03      
       AND DP.DeviceType = 'STATION'
       AND DP.Status = '0'
       AND DP.Storerkey = @c_Storerkey
       --AND LOC.LocationCategory = 'PTS'
       AND LOC.Facility = @c_Facility
       AND PTL.RowRef IS NULL 
       GROUP BY DP.DeviceID
       ORDER BY DP.DeviceID       
       
       SELECT @n_TotalDevice = COUNT(1)
       FROM #TMP_DEVICE              
       --NJOW02 End
       
       --Assign PTS loc sorting by load                                        
       DECLARE cur_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT  O.Orderkey, O.Loadkey, ISNULL(CL.Short,'')
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
          OUTER APPLY (SELECT SUM(Qty) AS Qty FROM #PICKDETAIL_WIP PW WHERE PW.Orderkey = O.Orderkey AND PW.UOM = '6' AND PW.Status = '0') AS ORDSUM  --NJOW02
          LEFT JOIN CODELKUP CL (NOLOCK) ON SKU.Storerkey = CL.Storerkey AND SKU.Susr3 = CL.Code AND CL.Listname = 'SKUGROUP'
          LEFT JOIN #ONESKUPERCTNORDER OSO ON PD.Orderkey = OSO.Orderkey                                 
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.WIP_RefNo = @c_SourceType
          AND PD.UOM = '6'        
          AND OSO.Orderkey IS NULL                                                
          --AND PD.UOM IN('6','7')          
          GROUP BY ISNULL(ORDSUM.Qty,0), O.Orderkey, ISNULL(CL.Short,''), O.Loadkey  --NJOW02
          ORDER BY ISNULL(ORDSUM.Qty,0), O.Orderkey, ISNULL(CL.Short,'')

          OPEN cur_Order  
          
          FETCH NEXT FROM cur_Order INTO @c_Orderkey, @c_Loadkey, @c_SkuGroup
          
          SET @c_PrevOrderkey = '' --NJOW02
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN                        
             
             --NJOW02
             IF @c_PrevOrderkey <> @c_Orderkey
             BEGIN
                 IF @c_PrevOrderkey = ''  --Frist order
                 BEGIN                         
                   SET @n_PrevDeviceNo = 0           
                    SET @n_CurrDeviceNo = 1                   
                 END
                 ELSE
                 BEGIN
                   --logic to construct S sharp rounting to assign order to multiple devices
                   IF @n_TotalDevice = 1  --only one device 
                   BEGIN
                        SET @n_PrevDeviceNo = 1                                        
                     SET @n_CurrdeviceNo = 1                        
                   END
                   ELSE IF @n_CurrDeviceNo = @n_TotalDevice AND @n_PrevDeviceno < @n_currDeviceNo --assign same device if previous order is at last device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo 
                   END
                   ELSE IF @n_currDeviceNo = @n_TotalDevice AND @n_PrevDeviceno = @n_currDeviceNo  --assign prevous device if last two orders are at last device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo - 1
                   END
                   ELSE IF @n_CurrDeviceNo = 1 AND @n_PrevDeviceno > @n_currDeviceNo --assign same device if previouse order is at first device 
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo 
                   END
                   ELSE IF @n_CurrDeviceNo = 1 AND @n_PrevDeviceno = @n_currDeviceNo  --assign next device if last two orders are at first device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo  + 1
                   END
                   ELSE IF @n_PrevDeviceNo < @n_CurrDeviceNo  -- assign next device if current device greater than previous device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo + 1
                   END
                   ELSE IF @n_PrevDeviceNo > @n_CurrDeviceNo --assign previous device if current device smaller than previous device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo - 1
                   END                                       
                 END                  
             END            
            
             SET @n_cnt = 0  --NJOW02
             SET @c_DeviceID = ''  --NJOW02        
             ---Search available device 
             WHILE @n_cnt < (@n_TotalDevice + 1) AND @n_TotalDevice > 0  AND ISNULL(@c_DeviceId,'') = '' --NJOW02
             BEGIN
                SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = ''
                --
                IF @n_cnt > 0  --if cannot find loc from the assigned device, try other devices
                BEGIN   
                   IF @n_TotalDevice = 1  --only one device 
                   BEGIN
                        SET @n_PrevDeviceNo = 1                                        
                     SET @n_CurrdeviceNo = 1                        
                   END
                   ELSE IF @n_CurrDeviceNo = @n_TotalDevice AND @n_PrevDeviceno < @n_currDeviceNo --assign same device if previous order is at last device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo 
                   END
                   ELSE IF @n_currDeviceNo = @n_TotalDevice AND @n_PrevDeviceno = @n_currDeviceNo  --assign prevous device if last two orders are at last device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo - 1
                   END
                   ELSE IF @n_CurrDeviceNo = 1 AND @n_PrevDeviceno > @n_currDeviceNo --assign same device if previouse order is at first device 
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo 
                   END
                   ELSE IF @n_CurrDeviceNo = 1 AND @n_PrevDeviceno = @n_currDeviceNo  --assign next device if last two orders are at first device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo  + 1
                   END
                   ELSE IF @n_PrevDeviceNo < @n_CurrDeviceNo  -- assign next device if current device greater than previous device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo + 1
                   END
                   ELSE IF @n_PrevDeviceNo > @n_CurrDeviceNo --assign previous device if current device smaller than previous device
                   BEGIN
                        SET @n_PrevDeviceNo = @n_CurrDeviceNo                                         
                     SET @n_CurrdeviceNo = @n_CurrDeviceNo - 1
                   END               
                 END                             
                
               --Get same location group already assigned for the same order
               SELECT TOP 1 @c_DeviceId = DP.DeviceID, 
                            @c_IPAddress = DP.IPAddress, 
                            @c_PortNo = DP.PortNo, 
                            @c_DevicePosition = DP.DevicePosition, 
                            @c_PTSLOC = LOC.Loc
               FROM DEVICEPROFILE DP (NOLOCK) 
               JOIN #TMP_DEVICE TD ON DP.DeviceID = TD.DeviceID --NJOW02
               JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc 
               LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
               WHERE TD.DeviceNo = @n_CurrDeviceNo  --NJOW02
               --AND DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03      
               AND DP.DeviceType = 'STATION'
               AND DP.Status = '0'
               AND DP.Storerkey = @c_Storerkey
               --AND LOC.LocationCategory = 'PTS'
               AND LOC.Facility = @c_Facility
               AND PTL.RowRef IS NULL 
               AND LOC.LocationHandling = @c_SkuGroup
               AND EXISTS (SELECT 1  
                           FROM RDT.rdtPTLStationLog R (NOLOCK) 
                           JOIN LOC L (NOLOCK) ON R.Loc = L.LOC
                           AND L.LocationGroup = LOC.LocationGroup
                           AND R.Station = DP.DeviceID
                           AND R.Orderkey = @c_Orderkey) 
               ORDER BY LOC.LogicalLocation, LOC.Loc
               --ORDER BY DP.DeviceID, LOC.LogicalLocation, LOC.Loc
               
               --Get empty location group
               IF ISNULL(@c_PTSLOC,'') = ''
               BEGIN
                  SELECT TOP 1 @c_DeviceId = DP.DeviceID, 
                               @c_IPAddress = DP.IPAddress, 
                               @c_PortNo = DP.PortNo, 
                               @c_DevicePosition = DP.DevicePosition, 
                               @c_PTSLOC = LOC.Loc
                  FROM DEVICEPROFILE DP (NOLOCK) 
                  JOIN #TMP_DEVICE TD ON DP.DeviceID = TD.DeviceID  --NJOW02
                  JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc 
                  LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
                  WHERE TD.DeviceNo = @n_CurrDeviceNo  --NJOW02
                  --AND DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03      
                  AND DP.DeviceType = 'STATION'
                  AND DP.Status = '0'
                  AND DP.Storerkey = @c_Storerkey
                  --AND LOC.LocationCategory = 'PTS'
                  AND LOC.Facility = @c_Facility
                  AND PTL.RowRef IS NULL 
                  AND LOC.LocationHandling = @c_SkuGroup
                  AND NOT EXISTS (SELECT 1  
                                  FROM RDT.rdtPTLStationLog R (NOLOCK) 
                                  JOIN LOC L (NOLOCK) ON R.Loc = L.LOC
                                  AND L.LocationGroup = LOC.LocationGroup
                           AND R.Station = DP.DeviceID) 
                  ORDER BY LOC.LogicalLocation, LOC.Loc
                  --ORDER BY DP.DeviceID, LOC.LogicalLocation, LOC.Loc          
               END
               
               SET @n_cnt = @n_cnt + 1
             END
                                              
             IF ISNULL(@c_PTSLOC,'')=''
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
             END
             ELSE                 
             BEGIN                       
                INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, Loadkey, SourceType, SourceKey, Orderkey, UserDefine02)
                VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, @c_Loadkey, @c_SourceType, @c_Wavekey, @c_Orderkey, @c_SkuGroup) 

                SELECT @n_err = @@ERROR  
                IF @n_err <> 0  
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RTD.rdtPTLStationLog Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END                   
             END
             
             SET @c_PrevOrderkey = @c_Orderkey --NJOW02
            
             FETCH NEXT FROM cur_Order INTO @c_Orderkey, @c_Loadkey, @c_SkuGroup
          END
          CLOSE cur_Order
          DEALLOCATE cur_Order        
    END
            
    -----Create full carton pick task(RPF) from BULK to pack statation
    -----Create multi order conso carton pick task(RPF) from BULK to PTS Staging. if @c_WaveConsoAllocation_OPTION1 = 'SKUPERCTNSKIPPTS' Conso carton pick task from BULK to Pick location.
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN             
       IF @n_debug = 1
       BEGIN
           PRINT 'Create full/Conso carton task'
       END

       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                 PACK.CaseCnt, MAX(CASE WHEN OSO.Orderkey IS NOT NULL THEN 'Y' ELSE 'N' END),
                 PACK.Packkey, PACK.PackUOM3 --NJOW03
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          LEFT JOIN #ONESKUPERCTNORDER OSO ON PD.Orderkey = OSO.Orderkey           
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.WIP_RefNo = @c_SourceType
          AND SL.LocationType NOT IN('PICK','CASE')
          AND (PD.UOM = '2'  
             OR (PD.UOM = '6' AND @c_WaveConsoAllocation = '1') --conso carton to PTS
             --OR (PD.UOM = '6' AND OSO.Orderkey IS NOT NULL)  --1 sku per carton still replen to pick loc if @c_WaveConsoAllocation = '0'
              )
          --AND LOC.LocationType = 'OTHER'
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, PACK.CaseCnt, PACK.Packkey, PACK.PackUOM3
          ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
       
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt, @c_OneSkuPerCarton, @c_Packkey, @c_PackUOM
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN             
           --Full carton to pack station.  (UOM2)
           --Multi order conso carton to PTS Staging (UOM6)
           IF @c_UOM IN('2','6')
           BEGIN
             SET @c_Message01 = ''
             SET @c_Message03 = '' 

             IF @c_UOM = '2'            
             BEGIN
               SET @c_ToLoc = @c_PackStation
              SET @c_Message03 = 'PACKSTATION'
             END           

             IF @c_UOM = '6'
             BEGIN             
                IF @c_OneSkuPerCarton = 'Y' AND  (@c_WaveConsoAllocation_OPTION1 = 'SKUPERCTNSKIPPTS')-- OR @c_WaveConsoAllocation = '0')  --sku/carton order go to pick face
                BEGIN
                   SET @c_ToLoc = ''
                   SET @c_Message03 = 'PICKLOC'
                   
                   SELECT TOP 1 @c_ToLoc = SL.Loc
                   FROM SKUXLOC SL (NOLOCK)
                   JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
                   WHERE SL.Storerkey = @c_Storerkey
                   AND SL.Sku = @c_Sku
                   AND SL.LocationType = 'PICK'
                   AND LOC.Facility = @c_Facility --NJOW05

                   IF ISNULL(@c_ToLoc,'') = ''
                   BEGIN
                      SELECT @n_continue = 3  
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83145   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SKU/Carton replenisment Unable find pick loc for sku ' + RTRIM(@c_SKU) + ' (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                      END                                                               
                END 
                ELSE
                BEGIN
                   SET @c_ToLoc = @c_PTSStaging
                   SET @c_Message03 = 'PTS'
                END 
             END              
             
             SELECT TOP 1 @c_Message01 = ISNULL(Short,'')
             FROM CODELKUP (NOLOCK) 
             WHERE ListName = 'UATASKSQ'
             AND Code = @c_Message03
             AND Storerkey = @c_Storerkey              
             
             IF @c_WaveType = 'PAPER' --NJOW03
             BEGIN
                 --Get ucc available
                DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                   SELECT UCCNo, Qty
                   FROM UCC WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                   AND SKU = @c_SKU
                   AND Lot = @c_Lot
                   AND Loc = @c_FromLoc
                   AND ID = @c_Id
                   AND Status < '3'
                   AND Qty <= @n_Qty
                   ORDER BY EditDate DESC, UCCNo
                
                OPEN CUR_UCC
                
                FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty         
                   
                WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
                BEGIN            
                    SET @n_QtyToTake = @n_UCCQty
                    SET @c_MoveRefKey = RIGHT(RTRIM(@c_UCCNo),10)   
                    SET @c_ReplenishmentGroup = @c_Message03
                    SET @c_ReplenNo = @c_Message01
                    
                    IF @n_Qty < @n_UCCQty
                       BREAK
                
                   --Assing UCC to pick
                   DECLARE CUR_UCCPick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                      SELECT P.Pickdetailkey, P.Qty 
                      FROM #PICKDETAIL_WIP AS p WITH (NOLOCK) 
                      LEFT JOIN UCC (NOLOCK) ON P.Lot = UCC.Lot AND P.Loc = UCC.Loc AND P.Id = UCC.Id AND UCC.UCCNo = P.DropID      
                      WHERE P.[Status] = '0'                
                      AND P.UOM = @c_UOM 
                      AND UCC.UCCNo IS NULL
                      AND P.Lot = @c_Lot
                      AND P.Loc = @c_FromLoc
                      AND P.Id = @c_ID             
                    
                   OPEN CUR_UCCPick
                
                   FETCH NEXT FROM CUR_UCCPick INTO @c_Pickdetailkey, @n_PickQty         
                   
                   WHILE @@FETCH_STATUS = 0 AND @n_UCCQty > 0 AND @n_continue IN(1,2)
                   BEGIN                 
                      IF @n_UCCQty >= @n_PickQty
                      BEGIN
                          UPDATE #PICKDETAIL_WIP 
                          SET DropID = @c_UCCNo,
                              MoveRefKey = @c_MoveRefKey
                          WHERE Pickdetailkey = @c_Pickdetailkey
                
                         IF @@ERROR <> 0 
                         BEGIN
                            SELECT @n_continue = 3
                            SELECT @n_err = 78315
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV16)'
                         END 
                          
                          SET @n_UCCQty = @n_UCCQty - @n_PickQty                                                                             
                          SET @n_Qty =  @n_Qty - @n_PickQty 
                      END
                      ELSE
                      BEGIN
                         SET @c_NewPickDetailKey = ''
                                              
                         EXECUTE dbo.nspg_GetKey  
                            'PICKDETAILKEY',   
                            10 ,  
                            @c_NewPickDetailKey  OUTPUT,  
                            @b_success        OUTPUT,  
                            @n_err            OUTPUT,  
                            @c_errmsg         OUTPUT  
                         
                         IF @b_success <> 1  
                         BEGIN  
                            SET @n_Err = 63885  
                            SET @c_ErrMsg = 'Get Pickdetail Key'
                            SET @n_Continue = 3
                         END 
                                           
                         SET @n_SplitQty = @n_PickQty - @n_UCCQty
                
                         INSERT INTO #PICKDETAIL_WIP
                         (
                             PickDetailKey    ,CaseID           ,PickHeaderKey
                            ,OrderKey         ,OrderLineNumber  ,Lot
                            ,Storerkey        ,Sku              ,AltSku
                            ,UOM              ,UOMQty           ,Qty
                            ,QtyMoved         ,STATUS           ,DropID
                            ,Loc              ,ID               ,PackKey
                            ,UpdateSource     ,CartonGroup      ,CartonType
                            ,ToLoc            ,DoReplenish      ,ReplenishZone
                            ,DoCartonize      ,PickMethod       ,WaveKey
                            ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                            ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                            ,WIP_Refno
                            )
                         SELECT @c_NewPickDetailKey  AS PickDetailKey
                               ,CaseID           ,PickHeaderKey    ,OrderKey
                               ,OrderLineNumber  ,@c_Lot           ,Storerkey
                               ,Sku              ,AltSku           ,@c_UOM
                               ,UOMQty           ,@n_SplitQty
                               ,QtyMoved         ,[STATUS]         ,DropID       
                               ,Loc               ,ID               ,PackKey      
                               ,UpdateSource     ,CartonGroup      ,CartonType      
                               ,@c_PickDetailKey ,DoReplenish       ,ReplenishZone='SplitToUCC'      
                               ,DoCartonize      ,PickMethod       ,WaveKey      
                               ,EffectiveDate    ,TrafficCop         ,ArchiveCop      
                               ,'9'              ,ShipFlag         ,PickSlipNo
                               ,@c_SourceType  --NJOW04
                         FROM   #PICKDETAIL_WIP WITH (NOLOCK)  --NJOW04
                         WHERE  PickDetailKey = @c_PickDetailKey 
                
                         IF @@ERROR <> 0 
                         BEGIN
                            SELECT @n_continue = 3
                            SELECT @n_err = 78313
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispRLWAV16)'
                         END                   
                                           
                         UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)
                         SET DropID = @c_UCCNo,   
                             Qty = @n_UCCQty, 
                             MoveRefKey = @c_MoveRefKey,
                             TrafficCop = NULL,
                             ReplenishZone='SplitFrUCC'
                         WHERE PickDetailKey = @c_PickDetailKey
                
                         IF @@ERROR <> 0 
                         BEGIN
                            SELECT @n_continue = 3
                            SELECT @n_err = 78315
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV16)'
                         END 
                          
                         SET @n_Qty = @n_Qty - @n_UCCQty 
                         SET @n_UCCQty = 0                   
                      END
                                     
                      FETCH NEXT FROM CUR_UCCPick INTO @c_Pickdetailkey, @n_PickQty         
                   END
                   CLOSE CUR_UCCPick
                   DEALLOCATE CUR_UCCPick
                   
                   --if n_uccqty > 0 mean can't find pickdetail
                   --Update UCC
                   IF @n_UCCQty = 0
                   BEGIN
                      EXECUTE nspg_GetKey
                         'REPLENISHKEY'
                      ,  10
                      ,  @c_ReplenishmentKey  OUTPUT
                      ,  @b_Success           OUTPUT 
                      ,  @n_Err               OUTPUT 
                      ,  @c_ErrMsg            OUTPUT
                      
                      IF @b_Success <> 1 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83100
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispRLWAV16)'
                      END

                      INSERT INTO REPLENISHMENT(
                            Replenishmentgroup, ReplenishmentKey, StorerKey,
                            Sku,                FromLoc,          ToLoc,
                            Lot,                Id,               Qty,
                            UOM,                PackKey,          Confirmed, 
                            MoveRefKey,         ToID,             PendingMoveIn, 
                            QtyReplen,          QtyInPickLoc,     RefNo,
                            Wavekey,                  Remark,                 ReplenNo)
                      VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                               @c_SKU,                @c_FromLOC,          @c_ToLoc, 
                               @c_Lot,                @c_ID,               @n_QtyToTake, 
                               @c_PackUOM,            @c_PackKey,          'N', 
                               @c_MoveRefKey,         @c_ID,               @n_QtyToTake, 
                               0,                          @n_QtyToTake,          @c_UCCNo,
                               @c_Wavekey,                  '',                            @c_ReplenNo)  
                               
                      IF @@ERROR <> 0 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83110
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (isp_GenEOrder_Replenishment)'
                      END                         
                       
                      UPDATE UCC WITH (ROWLOCK)
                      SET Status = '5',
                          Userdefined10 = @c_ReplenishmentKey      
                      WHERE UCCNo = @c_UCCNo
                      AND Status < '3'
                
                      IF @@ERROR <> 0 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83120
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Failed! (ispRLWAV16)'
                      END                               
                   END
                                                           
                   FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty         
                END
                CLOSE CUR_UCC
                DEALLOCATE CUR_UCC
                
                --if n_qty > 0 mean can't find ucc     
                IF @n_Qty > 0
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @n_err = 83130
                   SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to find UCC from Loc: ' + RTRIM(@c_FromLoc) + ' Lot: ' + RTRIM(@c_Lot) + '. (ispRLWAV16)'
                END                                                   
             END
             ELSE
             BEGIN
                SET @n_TotCtn = FLOOR(@n_Qty / @n_CaseCnt)            
                
                --additional condition to search pickdetail
                SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM' 
                            
                WHILE @n_TotCtn > 0 AND @n_continue IN(1,2)             
                BEGIN
                   EXEC isp_InsertTaskDetail   
                       @c_TaskType              = @c_TaskType             
                      ,@c_Storerkey             = @c_Storerkey
                      ,@c_Sku                   = @c_Sku
                      ,@c_Lot                   = @c_Lot 
                      ,@c_UOM                   = @c_UOM      
                      ,@n_UOMQty                = @n_CaseCnt     
                      ,@n_Qty                   = @n_CaseCnt      
                      ,@c_FromLoc               = @c_Fromloc      
                      ,@c_LogicalFromLoc        = @c_FromLoc 
                      ,@c_FromID                = @c_ID     
                      ,@c_ToLoc                 = @c_ToLoc       
                      ,@c_LogicalToLoc          = @c_ToLoc 
                      ,@c_ToID                  = @c_ID       
                      ,@c_PickMethod            = @c_PickMethod
                      ,@c_Priority              = @c_Priority     
                      ,@c_SourcePriority        = '9'      
                      ,@c_SourceType            = @c_SourceType      
                      ,@c_SourceKey             = @c_Wavekey      
                      ,@c_WaveKey               = @c_Wavekey      
                      ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                      ,@c_Message01             = @c_Message01
                      ,@c_Message02             = @c_Message02
                      ,@c_Message03             = @c_Message03
                      ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                      ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                      ,@c_WIP_RefNo             = @c_SourceType
                      ,@b_Success               = @b_Success OUTPUT
                      ,@n_Err                   = @n_err OUTPUT 
                      ,@c_ErrMsg                = @c_errmsg OUTPUT         
                   
                   IF @b_Success <> 1 
                   BEGIN
                      SELECT @n_continue = 3  
                   END
                  
                    SET @n_TotCtn = @n_TotCtn - 1                
                END  
             END           
           END       
              
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt, @c_OneSkuPerCarton, @c_Packkey, @c_PackUOM
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END     

    -----Create replenishment task    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF @n_debug = 1
       BEGIN
           PRINT 'Create replenishment task'
       END

       --SET @c_Priority = '8'   --WL01
       SET @c_Priority = '4'     --WL01
       SET @c_Message03 = 'PICKLOC'
       SET @c_Message01 = ''
       
       SELECT TOP 1 @c_Message01 = ISNULL(Short,'')
       FROM CODELKUP (NOLOCK) 
       WHERE ListName = 'UATASKSQ'
       AND Code = @c_Message03
       AND Storerkey = @c_Storerkey              
       
       --NJOW03
       SET @c_MoveRefKey = ''
       SET @c_ReplenishmentGroup = @c_Message03
       SET @c_ReplenNo = @c_Message01      
       
       --Retrieve all lot of the wave from pick loc
       SELECT DISTINCT LLI.Lot             
       INTO #TMP_WAVEPICKLOT
       FROM PICKDETAIL PD (NOLOCK)
       JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
       JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
       JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
       JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       AND SXL.LocationType IN('PICK','CASE')       
       AND LLI.QtyExpected > 0
                          
       --Retreive pick loc with overallocated
       DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                 PACK.CaseCnt, PACK.Packkey, PACK.PACKUOM3
          FROM LOTXLOCXID LLI (NOLOCK)          
          JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
          JOIN #TMP_WAVEPICKLOT ON LLI.Lot = #TMP_WAVEPICKLOT.Lot 
          WHERE SL.LocationType IN('PICK','CASE')
          AND LLI.Storerkey = @c_Storerkey
          AND LOC.Facility = @c_Facility       
          GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt, PACK.Packkey, PACK.PACKUOM3 
          HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) < 0  --overallocate
          UNION ALL --NJOW02
          SELECT SL.Storerkey, SL.Sku, '', SL.Loc, '', 0, PACK.CaseCnt, PACK.Packkey, PACK.PACKUOM3
          FROM SKUXLOC SL (NOLOCK)
          JOIN SKU (NOLOCK) ON SL.Storerkey = SKU.Storerkey AND SL.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
          OUTER APPLY dbo.fnc_SKUXLOC_Extended(SL.StorerKey, SL.Sku, SL.Loc) AS SLEX      
          WHERE SL.LocationType IN('PICK','CASE')
          AND SL.Storerkey = @c_Storerkey
          AND LOC.Facility = @c_Facility
          AND SL.QtyExpected = 0
          AND (SL.Qty - SL.QtyAllocated - SL.QtyPicked) + ISNULL(SLEX.PendingMoveIn,0) = 0 

       OPEN cur_PickLoc
       
       FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt, @c_Packkey, @c_PackUOM
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN               
           
           IF @n_QtyShort < 0
              SET @n_QtyShort = @n_QtyShort * -1
              
           SET @n_QtyReplen = @n_QtyShort   
         
          IF @c_WaveType = 'PAPER' --NJOW03
          BEGIN
             WHILE @n_QtyReplen > 0 AND @n_continue IN(1,2) 
             BEGIN                     
                SET @c_FromLOC = ''
                SET @c_FromID  = ''
                SET @n_UCCQty = 0            
                SET @c_UCCNo = ''
                
                SELECT TOP 1  
                   @c_FromLOC = LLI.LOC, 
                   @c_FromID  = LLI.ID, 
                   @n_UCCQty = UCC.Qty, 
                   @c_UCCNo = UCC.UCCNo
                FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
                JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
                JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
                JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
                JOIN ID (NOLOCK) ON (LLI.ID = ID.ID) 
                JOIN UCC WITH (NOLOCK) ON UCC.StorerKey = LLI.StorerKey AND UCC.SKU = LLI.SKU AND 
                                          UCC.LOT = LLI.LOT AND UCC.LOC = LLI.LOC AND UCC.ID = LLI.ID AND UCC.Status < '3'
                WHERE LOT.STATUS = 'OK' 
                AND L.STATUS = 'OK' 
                AND ID.STATUS = 'OK' 
                AND L.LocationFlag = 'NONE' 
                AND L.LocationType NOT IN ('VIRTUAL') 
                AND (SL.LocationType NOT IN ('PICK','CASE') ) 
                AND LLI.Lot = @c_Lot
                AND L.Facility = @c_Facility
                AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) > 0
                ORDER BY CASE WHEN LLI.Lot = @c_Lot THEN 1 ELSE 2 END, --NJOW02
                            L.LocationGroup, L.Loclevel, LLI.Qty, L.Logicallocation, L.Loc, UCC.Qty, UCC.UCCNo 
                                    
                IF @c_FromLOC <> '' AND @n_UCCQty > 0 
                BEGIN
                   SET @n_QtyToTake = @n_UCCQty 
                   
                   IF @n_QtyToTake > 0 
                   BEGIN
                      EXECUTE nspg_GetKey
                         'REPLENISHKEY'
                      ,  10
                      ,  @c_ReplenishmentKey  OUTPUT
                      ,  @b_Success           OUTPUT 
                      ,  @n_Err               OUTPUT 
                      ,  @c_ErrMsg            OUTPUT
                      
                      IF @b_Success <> 1 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83140
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispRLWAV16)'
                      END
                                      
                      IF @n_QtyReplen > @n_QtyToTake
                         SET @n_QtyInPickLoc = @n_QtyToTake
                      ELSE 
                         SET @n_QtyInPickLoc = @n_QtyReplen          
                                                                                                       
                      INSERT INTO REPLENISHMENT(
                            Replenishmentgroup, ReplenishmentKey, StorerKey,
                            Sku,                FromLoc,          ToLoc,
                            Lot,                Id,               Qty,
                            UOM,                PackKey,          Confirmed, 
                            MoveRefKey,         ToID,             PendingMoveIn, 
                            QtyReplen,          QtyInPickLoc,     RefNo, 
                            Wavekey,                  Remark,                 ReplenNo)
                      VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                               @c_SKU,                @c_FromLOC,          @c_ToLOC, 
                               @c_LOT,                   @c_FromID,           @n_QtyToTake, 
                               @c_PackUOM,            @c_PackKey,          'N', 
                               @c_MoveRefKey,         @c_ToID,             @n_QtyToTake, 
                               @n_QtyToTake,          @n_QtyInPickLoc,     @c_UCCNo,
                               @c_Wavekey,                  '',                            @c_ReplenNo )  
                                                                                
                      IF @@ERROR <> 0 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83150
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (ispRLWAV16)'
                      END                         
                
                      UPDATE UCC WITH (ROWLOCK)
                      SET Status = '5',
                          Userdefined10 = @c_ReplenishmentKey
                      WHERE UCCNo = @c_UCCNo
                      AND Status < '3'
                      
                      IF @@ERROR <> 0 
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 83160
                         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Failed! (isp_GenEOrder_Replenishment)'
                      END                               
                   END                                    
                            
                   SET @n_QtyReplen = @n_QtyReplen - @n_QtyToTake                                         
                END 
                ELSE
                BEGIN
                   SET @n_QtyReplen = 0                
                   BREAK
                END            
             END   
          END
          ELSE
          BEGIN
              --NJOW02
              IF @n_Casecnt > 0
              BEGIN
                 IF @n_QtyShort % @n_Casecnt = 0  OR @n_QtyShort = 0
                    SET @n_QtyReplen = @n_QtyReplen + @n_Casecnt
              END
              
              --retrieve stock from bulk 
             DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
                FROM LOTXLOCXID LLI (NOLOCK)          
                JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
                JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                JOIN ID (NOLOCK) ON LLI.Id = ID.Id
                WHERE SL.LocationType NOT IN('PICK','CASE')
                AND LOT.STATUS = 'OK' 
                AND LOC.STATUS = 'OK' 
                AND ID.STATUS = 'OK'  
                AND LOC.LocationFlag = 'NONE' 
                AND LOC.LocationType <> 'VIRTUAL'
                --AND LOC.LocationType = 'OTHER' 
                AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
                AND LLI.Storerkey = @c_Storerkey
                AND LLI.Sku = @c_Sku
                AND LOC.Facility = @c_Facility --NJOW05
                --AND LLI.Lot = @c_Lot --NJOW02 removed
                ORDER BY CASE WHEN LLI.Lot = @c_Lot THEN 1 ELSE 2 END, --NJOW02
                         LOC.LocationGroup, LOC.Loclevel, QtyAvailable, LOC.Logicallocation, LOC.Loc
                
             OPEN cur_Bulk
             
             FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
             
             WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0            
             BEGIN          
                IF @n_QtyAvailable >= @n_QtyReplen             
                   SET @n_TotCtn = CEILING(@n_QtyReplen / (@n_CaseCnt * 1.00))
                ELSE
                   SET @n_TotCtn = FLOOR(@n_QtyAvailable / (@n_CaseCnt * 1.00))
                
                WHILE @n_TotCtn > 0 AND @n_QtyReplen > 0 AND @n_continue IN(1,2)             
                BEGIN
                    IF @n_QtyReplen >= @n_CaseCnt
                       SET @n_InsertQty = @n_CaseCnt
                    ELSE
                       SET @n_InsertQty = @n_QtyReplen
                                         
                    SET @n_QtyReplen = @n_QtyReplen - @n_InsertQty
                              
                   EXEC isp_InsertTaskDetail   
                       @c_TaskType              = @c_TaskType             
                      ,@c_Storerkey             = @c_Storerkey
                      ,@c_Sku                   = @c_Sku
                      ,@c_Lot                   = @c_Lot 
                      ,@c_UOM                   = '2'      
                      ,@n_UOMQty                = @n_InsertQty     
                      ,@n_Qty                   = @n_Casecnt      
                      ,@c_FromLoc               = @c_Fromloc      
                      ,@c_LogicalFromLoc        = @c_FromLoc 
                      ,@c_FromID                = @c_ID     
                      ,@c_ToLoc                 = @c_ToLoc       
                      ,@c_LogicalToLoc          = @c_ToLoc 
                      ,@c_ToID                  = @c_ToID       
                      ,@c_PickMethod            = @c_PickMethod
                      ,@c_Priority              = @c_Priority     
                      ,@c_SourcePriority        = '9'      
                      ,@c_SourceType            = @c_SourceType      
                      ,@c_SourceKey             = @c_Wavekey      
                      ,@c_WaveKey               = @c_Wavekey      
                      ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
                      ,@c_Message01             = @c_Message01
                      ,@c_Message02             = @c_Message02
                      ,@c_Message03             = @c_Message03
                      ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                      --,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey
                      ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
                      ,@c_ReservePendingMoveIn  =  'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
                      ,@b_Success               = @b_Success OUTPUT
                      ,@n_Err                   = @n_err OUTPUT 
                      ,@c_ErrMsg                = @c_errmsg OUTPUT         
                               
                   IF @b_Success <> 1 
                   BEGIN
                      SELECT @n_continue = 3  
                   END
             
                    SET @n_TotCtn = @n_TotCtn - 1                
                END
                
                FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
             END
             CLOSE cur_Bulk
             DEALLOCATE cur_Bulk
          END
          
          FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt, @c_Packkey, @c_PackUOM
       END
       CLOSE cur_PickLoc
       DEALLOCATE cur_PickLoc          
    END    
         
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       IF @n_debug = 1
       BEGIN
           PRINT 'Update Pickdetail'
       END
       
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END
      
    -----Generate Pickslip No------
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       IF @n_debug = 1
       BEGIN
           PRINT 'Create Pickslip'
       END  
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3
    END    
    
    -----Update loadplanlane--------
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN        
       DECLARE cur_LPLane CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT LPD.Loadkey, MAX(LLD.Loc) 
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
            JOIN LOADPLANLANEDETAIL LLD (NOLOCK) ON LPD.Loadkey = LLD.Loadkey 
            WHERE WD.Wavekey =  @c_Wavekey          
            GROUP BY LPD.Loadkey
            ORDER BY LPD.Loadkey 
            
          OPEN cur_LPLane  
          
          FETCH NEXT FROM cur_LPLane INTO @c_Loadkey, @c_Door
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN            
             DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT ORDERS.Orderkey 
                FROM ORDERS (NOLOCK)
                JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey
                WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
                
             OPEN CUR_ORD    
             
             FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
             
             WHILE @@FETCH_STATUS = 0
             BEGIN               
                 UPDATE ORDERS WITH (ROWLOCK)
                 SET Door = @c_Door,
                     Trafficcop = NULL
                 WHERE Orderkey = @c_Orderkey
                 
                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                   END                         
                  
                FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
             END
             CLOSE CUR_ORD
             DEALLOCATE CUR_ORD
                             
             FETCH NEXT FROM cur_LPLane INTO @c_Loadkey, @c_Door
          END
          CLOSE cur_LPLane
          DEALLOCATE cur_LPLane            
    END

UPDATE_WAVE:        
    
    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE 
          --SET STATUS = '1' -- Released        --(Wan01) 
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01)
       WHERE WAVEKEY = @c_wavekey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
         
RETURN_SP:

   IF OBJECT_ID('tempdb..#PickDetail_WIP','u') IS NOT NULL
      DROP TABLE #PickDetail_WIP

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV16"  
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
 END --sp end

GO