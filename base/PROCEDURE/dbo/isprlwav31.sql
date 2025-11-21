SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/  
/* Stored Procedure: ispRLWAV31                                             */  
/* Creation Date: 30-OCT-2019                                               */  
/* Copyright: LFL                                                           */  
/* Written by:                                                              */  
/*                                                                          */  
/* Purpose: WMS-10647 - CN PVH QHW Release Wave update batch to pick        */
/*                                                                          */  
/* Called By: wave                                                          */  
/*                                                                          */  
/* PVCS Version: 1.1                                                        */  
/*                                                                          */  
/* Version: 7.0                                                             */  
/*                                                                          */  
/* Data Modifications:                                                      */  
/*                                                                          */  
/* Updates:                                                                 */  
/* Date        Author   Ver  Purposes                                       */  
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                             */
/* 28-12-2020  NJOW01   1.2   WMS-15891 add logic cater for new brand       */
/* 07-04-2021  NJOW02   1.3   Fix error control and transaction             */
/****************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV31]      
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
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE  @c_Storerkey NVARCHAR(15)
            ,@c_Facility NVARCHAR(5)
            ,@c_SourceType NVARCHAR(30)
            ,@c_PickDetailKey NVARCHAR(10)            
            ,@c_OrderGroup NVARCHAR(10)
            ,@c_Short_group NVARCHAR(10)
            ,@c_Prev_Short_group NVARCHAR(10)
   
    --NJOW01 
    DECLARE  @c_Sku NVARCHAR(20)
            ,@c_Userdefine02 NVARCHAR(20) 
            ,@c_Userdefine03 NVARCHAR(20) 
            ,@c_Userdefine04 NVARCHAR(20) 
            ,@c_WaveType NVARCHAR(10)
            ,@n_LocLimitPerDevice INT  
            ,@c_DeviceID NVARCHAR(20)
            ,@c_DevicePosition NVARCHAR(10)
            ,@c_IPAddress NVARCHAR(40)
            ,@c_SQL NVARCHAR(4000)
            ,@c_Pickslipno NVARCHAR(10)
            ,@c_CaseID NVARCHAR(20) 
            ,@n_PTLRequire INT
            ,@n_PTLAvailable INT
            ,@c_Loc NVARCHAR(10)
            ,@c_CartonizationGroup NVARCHAR(10)
            ,@n_CartonNo    INT
            ,@c_LabelNo     NVARCHAR(20)
            ,@n_CartonCube  DECIMAL(12,5)
            ,@c_CartonType  NVARCHAR(10)
            ,@n_ChgCartonCube  DECIMAL(12,5)
            ,@c_ChgCartonType  NVARCHAR(10)
            ,@n_TotalCube   DECIMAL(12,5)
            ,@n_StdCube     DECIMAL(12,5)
            ,@n_StdGrossWgt DECIMAL(12,5)
            ,@n_QtyPack     INT            
            ,@n_Qty         INT
            ,@n_LabelLineNo INT
            ,@c_LabelLineNo NVARCHAR(5)
            ,@n_QtyCanFit   INT
            ,@c_NewCarton   NVARCHAR(5)     
            ,@c_LogicalLocation NVARCHAR(18) 
            ,@c_Style       NVARCHAR(20) 
            ,@c_Color       NVARCHAR(10)
            ,@c_Measurement NVARCHAR(5)
            ,@c_Size        NVARCHAR(10)        
            ,@c_skuloctype  NVARCHAR(1)
            ,@c_Notes       NVARCHAR(30)                       
            ,@c_AssignPackLabelToOrdCfg NVARCHAR(30)
            ,@n_CurrCartonCube DECIMAL(12,5)
                              
    SET @c_SourceType = 'ispRLWAV31'    

    IF @@TRANCOUNT = 0  --NJOW02
       BEGIN TRAN

    -----Wave Validation-----                  
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey            
                   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                   WHERE WD.Wavekey = @c_Wavekey    
                   AND ISNULL(PD.Notes,'') <> ''
                   ) 
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV31)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE WD.Wavekey = @c_Wavekey
                  AND (O.Loadkey = '' OR O.loadkey IS NULL))
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some order without load planning yet. (ispRLWAV31)'       
       END
    END   
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE WD.Wavekey = @c_Wavekey
                  AND O.Status = '0')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some order in the wave is not allocated yet. (ispRLWAV31)'       
       END
    END   

    /* --NJOW01 Removed
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                  JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
                  LEFT JOIN CODELKUP CL (NOLOCK) ON SKU.Storerkey = CL.Storerkey AND SUBSTRING(SKU.Busr2,15,4) = CL.Code AND CL.Listname = 'PVHITEMGRP'
                  WHERE WD.Wavekey = @c_Wavekey
                  AND CL.Code IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83040    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some sku product group not setup at PVHITEMGRP. (ispRLWAV31)'       
       END
    END
    */   
 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  JOIN STORER S (NOLOCK) ON S.Storerkey = 'PVH-' + O.Billtokey AND S.Consigneefor = O.Storerkey
                  LEFT JOIN CODELKUP CL (NOLOCK) ON S.ISOCntryCode = CL.Code AND CL.Storerkey = O.Storerkey AND CL.Listname = 'PVHCOUNTRY'
                  WHERE WD.Wavekey = @c_Wavekey
                  AND CL.Code IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83050    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some country not setup in PVHCOUNTRY. (ispRLWAV31)'       
       END
    END   
               
    -----Get Storerkey, facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                    @c_Facility = O.Facility,
                    @c_OrderGroup = CL.Code,
                    @c_Userdefine02 = W.Userdefine02,  --NJOW01
                    @c_Userdefine03 = W.Userdefine03,   --NJOW01
                    @c_Userdefine04 = W.Userdefine04,   --NJOW01
                    @c_WaveType = W.WaveType,  --NJOW01
                    @c_CartonizationGroup = CartonGroup --NJOW01
       FROM WAVE W (NOLOCK)
       JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       JOIN STORER S (NOLOCK) ON O.Storerkey = S.Storerkey
       JOIN CODELKUP CL (NOLOCK) ON O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey AND ListName = 'ORDERGROUP'
       AND W.Wavekey = @c_Wavekey 
       
       --NJOW01 
       EXECUTE nspGetRight   
         @c_facility,    
         @c_StorerKey,                
         '',                      
         'AssignPackLabelToOrdCfg', -- Configkey  
         @b_success    OUTPUT,  
         @c_AssignPackLabelToOrdCfg OUTPUT,  
         @n_err        OUTPUT,  
         @c_errmsg     OUTPUT        

       IF @c_AssignPackLabelToOrdCfg = '1'                                
       BEGIN                                                              
          UPDATE STORERCONFIG WITH (ROWLOCK)                              
          SET Option4 = 'SKIPSTAMPED',                      
              Option3 = 'FullLabelNo',
              Option2 = 'CASEID'
          WHERE Configkey = 'AssignPackLabelToOrdCfg'                     
          AND Storerkey = @c_Storerkey                                    
          AND (Option4 <> 'SKIPSTAMPED' OR Option3 <> 'FullLabelNo' OR Option2 <> 'CASEID')                                    
          AND (Facility = @c_Facility OR Facility = '')                   
       END                                                                            
    END

    --NJOW01  
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
    	 SET @c_Sku = ''
       SELECT TOP 1 @c_Sku = SKU.Sku 
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
       JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
       WHERE WD.Wavekey = @c_Wavekey
       AND SKU.Stdcube = 0    	

       IF ISNULL(@c_Sku,'') <> ''       
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83060    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found sku ' + RTRIM(@c_Sku) +' is not setup stdcude. (ispRLWAV31)'       
       END
    END   
   
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = 'PTS'
    BEGIN
      IF ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '' 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83070    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. From and To Device must be provided at Userdefine02 & 03 for PTS Wave. (ispRLWAV31)'       
      END
      ELSE IF EXISTS(SELECT 1
                     FROM DEVICEPROFILE DP (NOLOCK)
                     JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc
                     JOIN rdt.rdtPTLStationLog PTL (NOLOCK) ON DP.DeviceID = PTL.Station AND DP.DevicePosition = PTL.Position 
                     WHERE DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03          
                     AND DP.Storerkey = @c_Storerkey           
                     AND LOC.LocationCategory = 'PTS'
                     AND LOC.Facility = @c_Facility)                                     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83080   
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. The PTS Device is in use. (ispRLWAV31)'                       
      END    	
    END
               
    --Create pickdetail Work in progress temporary table
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
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
    END
   
    --Get batch number and update to pickdetail for B2B 
    IF (@n_continue = 1 or @n_continue = 2) 
    BEGIN
       --Cleare notes
       UPDATE #PickDetail_WIP
       SET Notes = '', CaseID = ''  --NJOW01
           --Pickslipno = ''

       DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                 
          SELECT PD.Pickdetailkey, CL.Short
          FROM #PickDetail_WIP PD
          JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
          JOIN STORER S (NOLOCK) ON S.Storerkey = 'PVH-' + O.Billtokey AND S.Consigneefor = O.Storerkey
          JOIN SKUCONFIG SKC (NOLOCK) ON  PD.Storerkey = SKC.Storerkey AND PD.Sku = SKC.Sku AND SKC.ConfigType = 'HTSCODE-PVH'       
          JOIN CODELKUP CL (NOLOCK) ON PD.Storerkey = CL.Storerkey AND LEFT(SKC.Data,4) = CL.Long AND CL.Listname = 'PVHHTSCODE' AND S.ISOCntryCode = CL.UDF01

       OPEN CUR_PICK  
         
       FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @c_Short_group  
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN  
           UPDATE #PickDetail_WIP
           SET Notes = @c_Short_group --NJOW01
               --CaseID = @c_Short_group --NJOW01
           WHERE Pickdetailkey = @c_Pickdetailkey

          FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @c_Short_group
       END
       CLOSE CUR_PICK
       DEALLOCATE CUR_PICK
                  
       DECLARE CUR_PICK2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.Pickdetailkey, CL.Short  --NJOW01
          FROM #PickDetail_WIP PD
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN CODELKUP CL ON CL.Listname = 'QHWORDTP' AND LEFT(SKU.Busr2,2) = CL.Code AND SKU.Storerkey = CL.Storerkey
          WHERE ISNULL(PD.Notes,'') = ''
                 
       OPEN CUR_PICK2  
         
       FETCH NEXT FROM CUR_PICK2 INTO @c_Pickdetailkey, @c_Short_group  
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN  
           UPDATE #PickDetail_WIP
           SET Notes = @c_Short_group --NJOW01
               --CaseID = @c_Short_group --NJOW01
           WHERE Pickdetailkey = @c_Pickdetailkey

          FETCH NEXT FROM CUR_PICK2 INTO @c_Pickdetailkey, @c_Short_group
       END
       CLOSE CUR_PICK2
       DEALLOCATE CUR_PICK2

       /* --NJOW01 Removed
       DECLARE CUR_PICK2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
          SELECT PD.Pickdetailkey, CL.Short
          FROM #PickDetail_WIP PD
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN CODELKUP CL (NOLOCK) ON SKU.Storerkey = CL.Storerkey AND SUBSTRING(SKU.Busr2,15,4) = CL.Code AND CL.Listname = 'PVHITEMGRP'
          AND PD.Notes = ''
                   
       OPEN CUR_PICK2  
                
       FETCH NEXT FROM CUR_PICK2 INTO @c_Pickdetailkey, @c_Short_group  
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN             
           UPDATE #PickDetail_WIP
           SET Notes = @c_Short_group
           WHERE Pickdetailkey = @c_Pickdetailkey

          FETCH NEXT FROM CUR_PICK2 INTO @c_Pickdetailkey, @c_Short_group        
       END
       CLOSE CUR_PICK2
       DEALLOCATE CUR_PICK2
       */

    END
                                     
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
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
    	 --NJOW01
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_ConsolidateByLoad = 'Y'
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3

    	 /* --NJOW01 Removed
       IF @c_OrderGroup = 'W'  --Wholesale
       BEGIN    
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'N'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3
       END       

       IF @c_OrderGroup = 'R'  --Retail
       BEGIN    
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'Y'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3
       END
       */       
    END
        
    -----Generate PTS    NJOW01
    IF (@n_continue = 1 or @n_continue = 2) AND @c_WaveType = 'PTS'
    BEGIN
    	 CREATE TABLE #TMP_DEVICE (DeviceID NVARCHAR(20) NULL, 
    	                           DevicePosition NVARCHAR(10) NULL,
    	                           IPAddress NVARCHAR(40) NULL,
    	                           Loc NVARCHAR(10) NULL)
    	 
    	 IF ISNUMERIC(@c_Userdefine04) = 1
    	    SET @n_LocLimitPerDevice = CAST(@c_Userdefine04 AS INT)
    	 ELSE 
    	    SET @n_LocLimitPerDevice = 99999
    	
       DECLARE CUR_DEVICE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT DP.DeviceID
          FROM DEVICEPROFILE DP (NOLOCK)
          JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc
          WHERE DP.DeviceID BETWEEN @c_Userdefine02 AND @c_Userdefine03
          AND LOC.Facility = @c_Facility
          AND LOC.LocationCategory = 'PTS'
          AND DP.Storerkey = @c_Storerkey
          GROUP BY DP.DeviceID
          ORDER BY DP.DeviceID
          
       OPEN CUR_DEVICE
        
       FETCH NEXT FROM CUR_DEVICE INTO @c_DeviceID
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN
       	  SET @c_SQL = N'INSERT INTO #TMP_DEVICE (DeviceID, DevicePosition, IPAddress, Loc) ' +
       	                'SELECT TOP ' + CAST(@n_LocLimitPerDevice AS NVARCHAR) + ' DP.DeviceID, DP.DevicePosition, DP.IPAddress, DP.Loc ' +
                         'FROM DEVICEPROFILE DP (NOLOCK) ' +
                         'JOIN LOC (NOLOCK) ON DP.Loc = LOC.Loc ' +
                         'WHERE DP.DeviceID = @c_DeviceID ' +
                         'AND LOC.Facility = @c_Facility ' +
                         'AND LOC.LocationCategory = ''PTS'' ' +
                         'AND DP.Storerkey = @c_Storerkey ' +
                         'ORDER BY DP.DevicePosition ' 

          EXEC sp_executesql @c_SQL,
               N'@c_DeviceID NVARCHAR(20), @c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15)', 
               @c_DeviceID,
               @c_Facility,
               @c_Storerkey
                                
          FETCH NEXT FROM CUR_DEVICE INTO @c_DeviceID
       END
       CLOSE CUR_DEVICE
       DEALLOCATE CUR_DEVICE       	            
       
       SELECT PD.Pickslipno, PD.Notes 
       INTO #TMP_PTLREQ
       FROM PICKDETAIL PD (NOLOCK)
       JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.UOM IN('6','7')
       GROUP BY PD.Pickslipno, PD.Notes
       ORDER BY PD.Pickslipno, PD.Notes
       
       SELECT @n_PTLAvailable  = COUNT(1)
       FROM #TMP_DEVICE
       
       SELECT @n_PTLRequire = COUNT(1)
       FROM #TMP_PTLREQ

       IF @n_PTLRequire > @n_PTLAvailable      
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83090    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insufficient PTL Location. Require:' + RTRIM(CAST(@n_PTLRequire AS NVARCHAR)) + ' Available:' + RTRIM(CAST(@n_PTLRequire AS NVARCHAR)) + ' (ispRLWAV31)'                       
       END
       ELSE
       BEGIN    	                     	        	       
          DECLARE CUR_PTSPICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTL.Pickslipno, PTL.Notes 
            FROM #TMP_PTLREQ PTL
            ORDER BY PTL.Pickslipno, PTL.Notes
            
          OPEN CUR_PTSPICK  
                   
          FETCH NEXT FROM CUR_PTSPICK INTO @c_Pickslipno, @c_Notes  
            
          WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
          BEGIN
          	 SELECT TOP 1 @c_DeviceID = DeviceID, 
          	              @c_DevicePosition = DevicePosition, 
          	              @c_IPAddress = IPAddress, 
          	              @c_Loc = Loc
          	 FROM #TMP_DEVICE
          	 ORDER BY DeviceID, DevicePosition
          	 
          	 INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Pickslipno, Loadkey, Wavekey, Storerkey, SourceType, Sourcekey, Batchkey)
          	 VALUES (@c_DeviceID, @c_IPAddress, @c_DevicePosition, @c_Loc, @c_Pickslipno, '', @c_Wavekey, @c_Storerkey, 'ispRLWAV31', @c_Wavekey, @c_Notes)

             SET @n_err = @@ERROR
            
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38100     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On RDT.rdtPTLStationLog Table. (ispLPPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
             END          	 
          	 
          	 DELETE FROM #TMP_DEVICE
          	 WHERE DeviceID = @c_DeviceID
          	 AND DevicePosition = @c_DevicePosition 
          	               
             FETCH NEXT FROM CUR_PTSPICK INTO @c_Pickslipno, @c_Notes           
          END
          CLOSE CUR_PTSPICK
          DEALLOCATE CUR_PTSPICK           
       END           	
    END
            
    -----Pre-cartonization    NJOW01
    IF (@n_continue = 1 or @n_continue = 2) AND @c_WaveType = 'PC'
    BEGIN       
    	DECLARE CUR_PICKSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    	   SELECT PD.PickslipNo, SUM(PD.Qty * SKU.StdCube)
    	   FROM WAVEDETAIL WD (NOLOCK)
    	   JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
    	   JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
    	   WHERE WD.Wavekey = @c_Wavekey
    	   GROUP BY PD.Pickslipno
    	   ORDER BY PD.Pickslipno 
    	 
      OPEN CUR_PICKSLIP  
                   
      FETCH NEXT FROM CUR_PICKSLIP INTO @c_Pickslipno, @n_TotalCube
            
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
         BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
               SELECT TOP 1 ISNULL(LP.Route,''), '', '', LP.LoadKey, '', @c_Storerkey, @c_PickSlipNo       
               FROM  PICKHEADER PH (NOLOCK)      
               JOIN  LOADPLAN LP (NOLOCK) ON PH.ExternOrderkey = LP.Loadkey    
               WHERE PH.PickHeaderKey = @c_PickSlipNo
                     
            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38110     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKHEADER Table. (ispLPPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            END
         END   
         
         IF NOT EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
         BEGIN
            DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT P.SKU, SKU.StdCube, SKU.StdGrossWgt, SUM(P.Qty), P.Notes, '1', '' AS LogLoc, '' AS Loc, SKU.Style, SKU.Color, SKU.Measurement, SKU.Size   --pack multi loc sku first and sort by sytle,color, measurement, size
               FROM PICKDETAIL P (NOLOCK)  
               JOIN LOC (NOLOCK) ON P.Loc = LOC.Loc
               JOIN SKU (NOLOCK) ON P.Storerkey = SKU.Storerkey AND P.Sku = SKU.Sku
               WHERE P.Pickslipno = @c_Pickslipno
               AND P.Qty > 0                 
               GROUP BY P.Notes, P.SKU, SKU.StdCube, SKU.StdGrossWgt, SKU.Style, SKU.Color, SKU.Measurement, SKU.Size 
               HAVING COUNT(DISTINCT LOC.Loc) > 1  --Multip loc sku
               UNION ALL
               SELECT P.SKU, SKU.StdCube, SKU.StdGrossWgt, SUM(P.Qty), P.Notes, '2', MAX(LOC.LogicalLocation) AS logLoc, MAX(LOC.Loc) AS Loc, SKU.Style, SKU.Color, SKU.Measurement, SKU.Size --pack sinle loc sku and sort by logicalloc
               FROM PICKDETAIL P (NOLOCK)  
               JOIN LOC (NOLOCK) ON P.Loc = LOC.Loc
               JOIN SKU (NOLOCK) ON P.Storerkey = SKU.Storerkey AND P.Sku = SKU.Sku
               WHERE P.Pickslipno = @c_Pickslipno
               AND P.Qty > 0                 
               GROUP BY P.Notes, P.SKU, SKU.StdCube, SKU.StdGrossWgt, SKU.Style, SKU.Color, SKU.Measurement, SKU.Size 
               HAVING COUNT(DISTINCT P.Loc) = 1  --Single loc sku
               ORDER BY 5, 6, 7, 8, 9, 10, 11, 12
              
            OPEN CUR_PICKDETAIL            
                          
            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_StdCube, @n_StdGrossWgt, @n_Qty, @c_Short_group, @c_skuloctype, @c_LogicalLocation, @c_Loc, @c_Style, @c_Color, @c_Measurement, @c_Size
            
            SET @c_NewCarton = 'Y'            
            SET @n_CartonNo = 0
            DELETE FROM PACKINFO WHERE Pickslipno = @c_PickslipNo 
            
            SET @c_Prev_Short_group = ''
            WHILE @@FETCH_STATUS<>-1  AND @n_continue IN(1,2)
            BEGIN        	            	  
    	      	 IF @n_debug = 1 
            	    Print '@c_SKU=' + RTRIM(@c_SKU) + ' @n_StdCube=' + CAST(@n_StdCube AS NVARCHAR) + ' @n_StdGrossWgt=' + CAST(@n_StdGrossWgt AS NVARCHAR) + ' @n_Qty=' + CAST(@n_Qty AS NVARCHAR) + ' @c_Newcarton=' + RTRIM(@c_newcarton) 
            	    
            	 IF @c_Prev_Short_group <> @c_Short_group
            	 BEGIN   
            	    SET @c_NewCarton = 'Y'
            	    
            	    IF @n_CartonNo > 0  --if change group, revise current carton to use best fit carton
            	    BEGIN
            	       SELECT @n_CurrCartonCube = SUM(PKD.Qty * SKU.StdCube)
            	       FROM PACKDETAIL PKD (NOLOCK)
            	       JOIN SKU (NOLOCK) ON PKD.Storerkey = SKU.Storerkey AND PKD.Sku  = SKU.Sku
            	       WHERE PKD.Pickslipno = @c_Pickslipno
            	       AND PKD.CartonNo = @n_CartonNo
            	       
            	       SELECT @c_ChgCartonType = '', @n_ChgCartonCube = 0
                     SELECT TOP 1 @c_ChgCartonType = CZ.CartonType, @n_ChgCartonCube = CZ.Cube
                     FROM CARTONIZATION CZ (NOLOCK)
                     WHERE CZ.CartonizationGroup = @c_CartonizationGroup
                     AND CZ.Cube >= @n_CurrCartonCube
                     ORDER BY CZ.Cube
                     
                     IF @c_ChgCartonType <> @c_CartonType AND ISNULL(@n_ChgCartonCube, 0) > 0 
                     BEGIN
                     	  UPDATE PACKINFO WITH (ROWLOCK)
                     	  SET CartonType = @c_ChgCartonType,
                     	      Cube = @n_ChgCartonCube
                     	  WHERE Pickslipno = @c_Pickslipno
                     	  AND CartonNo = @n_CartonNo                         	      
                     END            	       
            	    END
            	 END 
            	    
            	 WHILE @n_Qty > 0 AND @n_continue IN(1,2)
            	 BEGIN            	 	            	  
            	    IF @c_NewCarton = 'Y'
            	    BEGIN
            	    	 SET @c_LabelNo = ''
            	    	 SET @n_CartonCube = 0
            	    	 SET @c_CartonType = ''
            	    	 SET @n_LabelLineNo = 0
                     SET @c_NewCarton = 'N'   
            	    	 SET @n_CartonNo = @n_CartonNo + 1
            	    	  
                     EXEC isp_GenUCCLabelNo_Std
                        @cPickslipNo  = @c_Pickslipno,
                        @nCartonNo    = @n_CartonNo,
                        @cLabelNo     = @c_LabelNo OUTPUT, 
                        @b_success    = @b_Success OUTPUT,
                        @n_err        = @n_err OUTPUT,
                        @c_errmsg     = @c_errmsg OUTPUT
                     
                     IF @b_Success <> 1
                        SET @n_continue = 3            	     	       

                     SELECT TOP 1 @c_cartonType = CZ.CartonType, @n_CartonCube = CZ.Cube
                     FROM CARTONIZATION CZ (NOLOCK)
                     WHERE CZ.CartonizationGroup = @c_CartonizationGroup
                     AND CZ.Cube >= @n_TotalCube
                     ORDER BY CZ.Cube

                     IF ISNULL(@n_CartonCube,0) = 0 
                     BEGIN
                        SELECT TOP 1 @c_cartonType = CZ.CartonType, @n_CartonCube = CZ.Cube
                        FROM CARTONIZATION CZ (NOLOCK)
                        WHERE CZ.CartonizationGroup = @c_CartonizationGroup
                        ORDER BY CZ.Cube DESC
                     END  
                                                                                  
                     IF ISNULL(@n_CartonCube,0) = 0 
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38120     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to find carton type. (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                        BREAK         
                     END

                     IF @n_StdCube > @n_CartonCube
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38130     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SKU StdCube greater than carton cube. SKU: ' + RTRIM(@c_Sku) + ' (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                        BREAK         
                     END                     

          	      	 IF @n_debug = 1 
                  	    Print  '@c_CartonizationGroup=' + RTRIM(@c_CartonizationGroup) + ' @c_cartonType=' + RTRIM(@c_cartonType) + ' @n_CartonCube=' + CAST(@n_CartonCube AS NVARCHAR) + ' @n_CartonNo=' + CAST(@n_CartonNo AS NVARCHAR)  
                     
                     INSERT INTO PACKINFO (PickSlipNo, Cartonno, CartonType, Cube, Weight, Qty, RefNo)
                     VALUES (@c_PickSlipno, @n_CartonNo, @c_CartonType, @n_CartonCube, 0, 0, '')             
                     
                     SET @n_err = @@ERROR
                     
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38140     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKINFO Table. (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                        BREAK         
                     END                      
            	    END
            	    
            	    SET @n_QtyCanFit = FLOOR(@n_CartonCube / @n_StdCube)
            	    
            	    IF @n_QtyCanFit = 0
            	    BEGIN
            	    	  SET @c_NewCarton = 'Y'
            	    	  CONTINUE
            	    END
            	    
            	    IF @n_Qty >= @n_QtyCanFit
            	    BEGIN
            	       SET @n_QtyPack = @n_QtyCanFit 
            	       SET @c_NewCarton = 'Y'  --Open new carton for remaining qty
            	    END   
            	    ELSE 
            	       SET @n_QtyPack = @n_Qty

       	      	  IF @n_debug = 1 
                  	 Print '@n_QtyCanFit=' + CAST(@n_QtyCanFit AS NVARCHAR) + ' @n_QtyPack=' + CAST(@n_QtyPack AS NVARCHAR) + ' @n_CartonCube=' + CAST(@n_CartonCube AS NVARCHAR)  + ' @n_OrderCube=' + CAST(@n_TotalCube AS NVARCHAR) + ' @n_Qty=' + CAST(@n_Qty AS NVARCHAR)        
            	    
            	    SET @n_CartonCube = @n_CartonCube - (@n_QtyPack * @n_StdCube)
            	    SET @n_TotalCube = @n_TotalCube - (@n_QtyPack * @n_StdCube)
            	    SET @n_Qty = @n_Qty - @n_QtyPack            	     
            	    
            	    --update packinfo
            	    UPDATE PACKINFO WITH (ROWLOCK)
            	    SET Weight = Weight + (@n_QtyPack * @n_StdGrossWgt)
            	        --Qty = Qty + @n_QtyPack
            	    WHERE Pickslipno = @c_PickslipNo
            	    AND CartonNo = @n_CartonNo
                  
                  SET @n_err = @@ERROR
                  
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38150     
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKINFO Table. (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                     BREAK     
                  END
            	    
            	    --Create packdetail
            	    IF NOT EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = @c_Pickslipno AND CartonNo = @n_CartonNo AND Sku = @c_Sku)
            	    BEGIN            	     
            	       SET @n_LabelLineNo = @n_LabelLineNo + 1
            	       SET @c_LabelLineNo = RIGHT('00000' + RTRIM(CAST(@n_LabelLineNo AS NVARCHAR)),5)
            	    
                     INSERT INTO PACKDETAIL(PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)    
                     VALUES     (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_StorerKey, @c_SKU,   
                                 @n_QtyPack, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())            	
                     
                     SET @n_err = @@ERROR
                     
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38160     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKDETAIL Table. (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
                        BREAK      
                     END
                  END  
                  ELSE
                  BEGIN
                  	  UPDATE PACKDETAIL WITH (ROWLOCK)
                  	  SET Qty = Qty + @n_QtyPack
                  	      --ArchiveCop = NULL
                  	  WHERE Pickslipno = @c_Pickslipno
                  	  AND CartonNo = @n_CartonNo
                  	  AND Sku = @c_Sku                   	
                  
                     SET @n_err = @@ERROR
                     
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38170     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKDETAIL Table. (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                        BREAK       
                     END
                  END                                     
               END -- @n_Qty > 0
               
               SET @c_Prev_Short_group = @c_Short_group
                               
               FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_StdCube, @n_StdGrossWgt, @n_Qty, @c_Short_group, @c_skuloctype, @c_LogicalLocation, @c_Loc, @c_Style, @c_Color, @c_Measurement, @c_Size 
            END
            CLOSE CUR_PICKDETAIL 
            DEALLOCATE CUR_PICKDETAIL         	         	   
         END
         
         IF @c_AssignPackLabelToOrdCfg = '1' AND @n_continue IN(1,2)  --NJOW02
         BEGIN         
            EXEC isp_AssignPackLabelToOrderByLoad
              @c_PickslipNo = @c_PickslipNo,     
              @b_Success = @b_Success OUTPUT,  
              @n_err = @n_Err OUTPUT,  
              @c_errmsg = @c_Errmsg OUTPUT
              
            IF @b_Success <> 1
               SET @n_continue = 3
         END   
                           	 
         FETCH NEXT FROM CUR_PICKSLIP INTO @c_Pickslipno, @n_TotalCube
      END    	       	     
      CLOSE CUR_PICKSLIP
      DEALLOCATE CUR_PICKSLIP   	       	      
    END
    
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    IF @n_continue IN (1,2)
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END
    
    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV31"  
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