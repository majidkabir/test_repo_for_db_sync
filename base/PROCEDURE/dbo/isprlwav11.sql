SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV11                                          */  
/* Creation Date: 03-Oct-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-2851 - CN PVH Release Wave                               */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.6                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */ 
/* 17-11-2020  WLChooi  1.2   WMS-15571 - Revise Logic (WL01)            */
/* 04-03-2021  WLChooi  1.3   WMS-15571 - Fix Cater for Channel_ID (WL02)*/ 
/* 21-04-2021  WLChooi  1.4   WMS-16849 - Fix UOM 2 not sent to Pack     */
/*                            Station (WL03)                             */
/* 30-04-2021  WLChooi  1.5   WMS-16849 - Fix UOM 2 Stamp Taskdetailkey  */
/*                            to Pickdetail table (WL04)                 */
/* 31-May-2023 WLChooi  1.6   WMS-22701 - Add new logic (WL05)           */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[ispRLWAV11]      
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

    DECLARE @c_UDF02 NVARCHAR(30)
            ,@c_Storerkey NVARCHAR(15)
            ,@c_Facility NVARCHAR(5)
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@c_ToID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_SourceType NVARCHAR(30)
            ,@c_Orderkey NVARCHAR(10)
            ,@c_OrderLineNumber NVARCHAR(5)
            ,@n_CaseCnt INT
            ,@c_DispatchCasePickMethod NVARCHAR(10)
            ,@c_Packstation NVARCHAR(10)
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
            ,@c_DispatchPalletPickMethod NVARCHAR(10)
            ,@c_DispatchPiecePickMethod NVARCHAR(10)            
            ,@c_Userdefine02 NVARCHAR(20)
            ,@c_Userdefine03 NVARCHAR(20)            
            ,@c_Loadkey NVARCHAR(10)
            ,@c_DeviceId NVARCHAR(20)
            ,@c_IPAddress NVARCHAR(40)
            ,@c_PortNo NVARCHAR(5)
            ,@c_DevicePosition NVARCHAR(10)
            ,@c_PTSLOC NVARCHAR(10)
            ,@c_InLoc NVARCHAR(10)
            ,@c_PTSLoadkey NVARCHAR(10)
            ,@n_InsertQty INT
            ,@c_PickslipNo NVARCHAR(10)
            ,@c_Short NVARCHAR(10)
            ,@n_QtyShort INT
            ,@n_QtyAvailable INT
            ,@n_QtyReplen INT = 0       --WL01
            ,@c_DocType  NVARCHAR(1)    --WL01
            ,@c_Salesman NVARCHAR(30)   --WL01
            ,@c_WaveType  NVARCHAR(36)  --WL01
            ,@c_PTSStatus  NVARCHAR(10) --WL01
            ,@c_PTLWavekey NVARCHAR(10) --WL01 
            ,@c_OrderGroup NVARCHAR(50)   --WL05
            ,@c_UserDefine10 NVARCHAR(50) --WL05
              
    SET @c_SourceType = 'ispRLWAV11'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = 'PP'

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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV11)'       
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV11)'       
        END                 
    END

    --WL01 S
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey 
                   WHERE WD.Wavekey = @c_Wavekey
                   AND OH.DocType = 'E'
                   AND OH.[Status] < '2')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83015   
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ECOM Order does not allow partial allocate. (ispRLWAV11)'       
        END                 
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM WAVEDETAIL WD (NOLOCK) 
                   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
                   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.Storerkey
                   WHERE WD.Wavekey = @c_Wavekey AND S.STDGROSSWGT = 0.00)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83016   
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some of the SKU has StdGrossWgt = 0. Could not proceed further. (ispRLWAV11)'       
        END                 
    END
    --WL01 E
          
    -----Get Storerkey, facility and order group
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                     @c_Short = CL.Short,   --1=Wholesale(D) 2=Retail new launch(C) 3=Retail replenishment(C)
                     @c_UDF02 = CL.UDF02,    --D=Discrete C=Consolidate 
                     @c_DispatchCasePickMethod = W.DispatchCasePickMethod,
                     @c_Userdefine02 = W.UserDefine02,
                     @c_Userdefine03 = W.UserDefine03,
                     @c_WaveType = W.WaveType,   --WL01 --Use Wavetype = PTS to distinguish PTS order --Wholesale(Discrete) Retail(Conso)  
                     @c_OrderGroup = O.OrderGroup,   --WL05
                     @c_UserDefine10 = ISNULL(O.UserDefine10,'')   --WL05
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        JOIN CODELKUP CL (NOLOCK) ON O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey AND CL.Listname = 'ORDERGROUP' 
        AND W.Wavekey = @c_Wavekey 

        --WL05 S
        IF @c_OrderGroup = 'W'
        BEGIN
           SELECT TOP 1 @c_Short = CL.Short
                      , @c_UDF02 = CL.UDF02
           FROM CODELKUP CL (NOLOCK)
           WHERE CL.Code = @c_OrderGroup 
           AND CL.Storerkey = @c_Storerkey 
           AND CL.Listname = 'ORDERGROUP' 
           AND CL.code2 = @c_UserDefine10
         END
        --WL05 E
        
        IF @c_UDF02 NOT IN('C','D')
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 83020    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Consolidate/Discrete setup for the ORDERGROUP. (ispRLWAV11)'       
           GOTO RETURN_SP                      
        END
        
        IF (@c_WaveType = 'PTS') AND (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '')   --WL01   --Removed @c_Short = '2'
        BEGIN         
           SELECT @n_continue = 3  
           SELECT @n_err = 83030    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retail new lauch mut key-in location range at userdefine02&03. (ispRLWAV11)'       
           GOTO RETURN_SP                      
        END                        
    END    

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                 WHERE O.Userdefine09 = @c_Wavekey
                 AND PD.WIP_RefNo = @c_SourceType)
       BEGIN
           DELETE PickDetail_WIP 
           FROM PickDetail_WIP (NOLOCK)
           JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey             
          WHERE ORDERS.Userdefine09 = @c_Wavekey 
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
       END 
       
       INSERT INTO PickDetail_WIP 
       (
         PickDetailKey,     CaseID,             PickHeaderKey,
         OrderKey,          OrderLineNumber,    Lot,
         Storerkey,         Sku,                AltSku,                    UOM,
         UOMQty,            Qty,                QtyMoved,                  [Status],
         DropID,            Loc,                ID,                        PackKey,
         UpdateSource,      CartonGroup,        CartonType,
         ToLoc,             DoReplenish,        ReplenishZone,
         DoCartonize,       PickMethod,         WaveKey,
         EffectiveDate,     AddDate,            AddWho,
         EditDate,          EditWho,            TrafficCop,
         ArchiveCop,        OptimizeCop,        ShipFlag,
         PickSlipNo,        TaskDetailKey,      TaskManagerReasonKey,
         Notes,             MoveRefKey,         WIP_RefNo,
         Channel_ID   --WL02   
       )
       SELECT PD.PickDetailKey,  CaseID,              PD.PickHeaderKey, 
         PD.OrderKey,            PD.OrderLineNumber,  PD.Lot,
         PD.Storerkey,           PD.Sku,              PD.AltSku,           PD.UOM,
         PD.UOMQty,              PD.Qty,              PD.QtyMoved,         PD.[Status],
         PD.DropID,              PD.Loc,              PD.ID,               PD.PackKey,
         PD.UpdateSource,        PD.CartonGroup,      PD.CartonType,
         PD.ToLoc,               PD.DoReplenish,      PD.ReplenishZone,
         PD.DoCartonize,         PD.PickMethod,       WD.Wavekey,
         PD.EffectiveDate,       PD.AddDate,          PD.AddWho,
         PD.EditDate,            PD.EditWho,          PD.TrafficCop,
         PD.ArchiveCop,          PD.OptimizeCop,      PD.ShipFlag,
         PD.PickSlipNo,          PD.TaskDetailKey,    PD.TaskManagerReasonKey,
         PD.Notes,               PD.MoveRefKey,       @c_SourceType,
         PD.Channel_ID   --WL02   
       FROM WAVEDETAIL WD (NOLOCK) 
       JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       
       SET @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END      
    END

    --Remove taskdetailkey 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
       SET PICKDETAIL_WIP.TaskdetailKey = '',
           PICKDETAIL_WIP.TrafficCop = NULL
       FROM WAVEDETAIL (NOLOCK)  
       JOIN PICKDETAIL_WIP ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
       AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
       
       SELECT @n_err = @@ERROR
       IF @n_err <> 0 
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END 
    END
    
   --Get pack statation location for full carton
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN             
       SELECT @c_PackStation = CL.Short
       FROM CODELKUP CL (NOLOCK)
       JOIN LOC (NOLOCK) ON CL.Short = LOC.Loc
       WHERE CL.Listname = 'DICSEPKMTD'
       AND CL.Code =  @c_DispatchCasePickMethod
       
       IF ISNULL(@c_PackStation,'') = ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Pack Station setup. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END
    END              
    
    --PTS reservation for retail new launch(2) from bulk 
    --Updated: All orders (B2B & B2C) may choose PTS in wave, so we use WaveType to decide   --WL01
    --Use @c_Loadkey as Sourcekey, can be loadkey / orderkey depending on @c_UDF02           --WL01
    IF (@n_continue = 1 OR @n_continue = 2) AND (@c_WaveType = 'PTS')                        --WL01
    BEGIN      
       DECLARE cur_load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT DISTINCT O.Storerkey, CASE WHEN @c_UDF02 = 'D' THEN O.OrderKey WHEN @c_UDF02 = 'C' THEN O.Loadkey ELSE '' END   --WL01
          FROM WAVEDETAIL WD (NOLOCK)  
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey   
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
          JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc  
          WHERE WD.Wavekey = @c_Wavekey  
          AND PD.Status = '0'  
          AND PD.WIP_RefNo = @c_SourceType  
          --AND SL.LocationType NOT IN('PICK','CASE')   --WL01  
          --AND LOC.LocationType = 'OTHER'              --WL01
          AND PD.UOM IN('6','7')  
          ORDER BY O.Storerkey, CASE WHEN @c_UDF02 = 'D' THEN O.OrderKey WHEN @c_UDF02 = 'C' THEN O.Loadkey ELSE '' END   --WL01

          OPEN cur_load  
          
          FETCH NEXT FROM cur_load INTO @c_Storerkey, @c_loadkey
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN             
             SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = '', @c_PTSLoadkey = ''
             
             SELECT TOP 1 @c_DeviceId = DP.DeviceID,   
                          @c_IPAddress = DP.IPAddress,   
                          @c_PortNo = DP.PortNo,   
                          @c_DevicePosition = DP.DevicePosition,   
                          @c_PTSLOC = LOC.Loc,  
                          @c_PTSLoadkey = PTL.Loadkey,
                          @c_PTSStatus = CASE WHEN ISNULL(PTL.Sourcekey,'') <> '' THEN 'OLD' ELSE 'NEW' END,   --WL01
                          @c_PTLWavekey = ISNULL(PTL.Wavekey,'')   --WL01
             FROM LOC (NOLOCK)   
             JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc   
             LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc   
             WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                    
             AND LOC.LocationCategory = 'PTS'  
             AND LOC.Facility = @c_Facility  
             AND DP.DeviceType = 'STATION'         
             AND (PTL.RowRef IS NULL   
                  --OR (PTL.Loadkey = @c_Loadkey AND PTL.Wavekey = @c_Wavekey)   --WL01
                  OR ((PTL.Loadkey = @c_loadkey AND PTL.Wavekey = @c_Wavekey) OR (PTL.Orderkey = @c_loadkey AND PTL.Wavekey = @c_Wavekey))     --WL01
                  )  
             --ORDER BY CASE WHEN PTL.Loadkey = @c_Loadkey THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc   --WL01  
             ORDER BY CASE WHEN (PTL.Loadkey = @c_Loadkey OR PTL.OrderKey = @c_Loadkey) THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc   --WL01  
  
             IF ISNULL(@c_PTSLOC,'')=''
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
             END 

             --WL01 S  
             IF @c_PTSStatus = 'NEW' OR @c_Wavekey <> @c_PTLWavekey
             BEGIN
                IF @c_UDF02 = 'D'   --Discrete, by Orderkey
                BEGIN
                   INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Orderkey, Sourcekey, SourceType)  
                   VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, '', @c_Loadkey, @c_Wavekey, 'ispRLWAV11')   
                END
                ELSE IF @c_UDF02 = 'C'   --Conso, by Loadkey
                BEGIN
                   INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Loadkey, Sourcekey, SourceType)  
                   VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, '', @c_Loadkey, @c_Wavekey, 'ispRLWAV11')   
                END
                
                SELECT @n_err = @@ERROR  
                
                IF @n_err <> 0  
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RTD.rdtPTLStationLog Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END   
             END
             
             --IF ISNULL(@c_PTSLoadkey,'') = ''
             --BEGIN                       
             --   INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, Loadkey, SourceType, SourceKey)
             --   VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, @c_Loadkey, @c_SourceType, @c_Wavekey) 

             --   SELECT @n_err = @@ERROR  
             --   IF @n_err <> 0  
             --   BEGIN
             --      SELECT @n_continue = 3  
             --      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             --      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RTD.rdtPTLStationLog Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
             --   END   
             --END
             --WL01 E
            
             FETCH NEXT FROM cur_load INTO @c_Storerkey, @c_loadkey
          END
          CLOSE cur_load
          DEALLOCATE cur_load          
    END
            
    -----Create pick task(RPF) from BULK only to pack statation or Put to store(PTS)
    -----Wholesale(1) full carton(uom2) to pack station
    -----Retail new launch(2) full carton(uom2) to pack station. conso carton(uom6) and partial carton(uom7) to PTS
    -----Retail replenishment(3) full carton(uom2) to pack station.    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN             
       IF (@c_WaveType = 'PTS') --Retail new launch split task by in loc   --Updated: All orders may choose PTS in wave, so we use WaveType to decide   --WL01
       BEGIN
          --SELECT DISTINCT PTL.Loadkey, PZ.InLoc   --WL01
          SELECT DISTINCT CASE WHEN @c_UDF02 = 'D' THEN PTL.OrderKey WHEN @c_UDF02 = 'C' THEN PTL.Loadkey ELSE '' END AS Sourcekey, PZ.InLoc   --WL01
          INTO #LOADINLOC
          FROM LOC (NOLOCK) 
          JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc 
          JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
          JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone
          WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                         
          AND LOC.LocationCategory = 'PTS'
          AND LOC.Facility = @c_Facility
          AND DP.DeviceType = 'STATION'       
          AND PTL.Wavekey = @c_Wavekey
          
          --WL01 S
          IF @c_UDF02 = 'D'
          BEGIN
             DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,
                    CASE WHEN PD.UOM = '2' THEN '2' ELSE '6' END AS UOM,   --WL03 
                    SUM(PD.UOMQty) AS UOMQty, 
                    '',   --WL01
                    '',   --WL01                 
                    PACK.CaseCnt,
                    --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END
                    MAX(O.loadkey) AS Loadkey,
                    ISNULL(IL.InLoc,'') AS InLoc,
                    MAX(O.Salesman) AS Salesman   --WL01
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey             
             JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
             JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
             LEFT JOIN #LOADINLOC IL ON O.Orderkey = IL.Sourcekey   --WL01
             WHERE WD.Wavekey = @c_Wavekey
             AND PD.Status = '0'
             AND PD.WIP_RefNo = @c_SourceType
             AND SL.LocationType NOT IN('PICK','CASE')
             AND LOC.LocationType = 'OTHER'
             --AND PD.UOM NOT IN ('2')   --WL01   --WL03
             GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LogicalLocation, PACK.CaseCnt,
                      --CASE WHEN @c_UDF02 = 'D' THEN PD.Orderkey ELSE '' END,          --WL01
                      --CASE WHEN @c_UDF02 = 'D' THEN PD.OrderLineNumber ELSE '' END,   --WL01
                      ISNULL(IL.InLoc,''), --split the qty by inloc
                      --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END    
                      CASE WHEN PD.UOM = '2' THEN '2' ELSE '6' END   --WL03             
             ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot     
          END
          ELSE IF @c_UDF02 = 'C'
          BEGIN
             DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, 
                    CASE WHEN PD.UOM = '2' THEN '2' ELSE '6' END AS UOM,   --WL03 
                    SUM(PD.UOMQty) AS UOMQty, 
                    '',   --WL01
                    '',   --WL01                 
                    PACK.CaseCnt,
                    --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END
                    MAX(O.loadkey) AS Loadkey,
                    ISNULL(IL.InLoc,'') AS InLoc,
                    MAX(O.Salesman) AS Salesman   --WL01
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey             
             JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
             JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
             LEFT JOIN #LOADINLOC IL ON O.Loadkey = IL.Sourcekey   --WL01
             WHERE WD.Wavekey = @c_Wavekey
             AND PD.Status = '0'
             AND PD.WIP_RefNo = @c_SourceType
             AND SL.LocationType NOT IN('PICK','CASE')
             AND LOC.LocationType = 'OTHER'
             --AND PD.UOM NOT IN ('2')   --WL01   --WL03
             GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LogicalLocation, PACK.CaseCnt,
                      --CASE WHEN @c_UDF02 = 'D' THEN PD.Orderkey ELSE '' END,          --WL01
                      --CASE WHEN @c_UDF02 = 'D' THEN PD.OrderLineNumber ELSE '' END,   --WL01
                      ISNULL(IL.InLoc,''), --split the qty by inloc
                      --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END       
                      CASE WHEN PD.UOM = '2' THEN '2' ELSE '6' END   --WL03       
             ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot    
          END
          --WL01 E
       END   
       ELSE
       BEGIN     
          DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                    CASE WHEN @c_UDF02 = 'D' THEN PD.Orderkey ELSE '' END, 
                    CASE WHEN @c_UDF02 = 'D' THEN PD.OrderLineNumber ELSE '' END,                 
                    PACK.CaseCnt,
                    --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END
                    MAX(O.loadkey) AS Loadkey,
                    '' AS InLoc,
                    MAX(O.Salesman) AS Salesman   --WL01
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
             JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
             JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
             WHERE WD.Wavekey = @c_Wavekey
             AND PD.Status = '0'
             AND PD.WIP_RefNo = @c_SourceType
             AND SL.LocationType NOT IN('PICK','CASE')
             AND LOC.LocationType = 'OTHER'
             GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, PACK.CaseCnt,
                      CASE WHEN @c_UDF02 = 'D' THEN PD.Orderkey ELSE '' END, 
                      CASE WHEN @c_UDF02 = 'D' THEN PD.OrderLineNumber ELSE '' END
                      --CASE WHEN @c_Short = '2' THEN O.Loadkey ELSE '' END          
             ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
       END
       
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_OrderLineNumber, @n_CaseCnt, @c_Loadkey, @c_Inloc
                                   , @c_Salesman   --WL01
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN             
           --Wholesale(1), Retail new launch(2) and replenishment(3) full cartion to pack station. 
           IF @c_UOM = '2'
           BEGIN
             SET @c_ToLoc = @c_PackStation            
             SET @n_TotCtn = FLOOR(@n_Qty / @n_CaseCnt)            
             
             --additional condition to search pickdetail
             --WL04 S
             --IF @c_UDF02 = 'D' --discrete
             --   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.Orderkey = @c_Orderkey AND PICKDETAIL.UOM = @c_UOM' 
             --ELSE
             --   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM' 
             IF @c_UDF02 = 'D' --discrete
                SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM NOT IN (''6'',''7'') ORDER BY ORDERS.Loadkey, ORDERS.Orderkey, PICKDETAIL.UOM ' 
             ELSE
                SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM NOT IN (''6'',''7'') ORDER BY ORDERS.Loadkey' 
             --WL04 E
             
             WHILE @n_TotCtn > 0 AND @n_continue IN(1,2) AND @c_Salesman <> 'TRF'   --WL01           
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
                   ,@c_OrderKey              = @c_Orderkey      
                   ,@c_OrderLineNumber       = @c_OrderLineNumber
                   ,@c_WaveKey               = @c_Wavekey      
                   ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                   ,@c_Message02             = @c_Short  --1=wholesale 2=retail new launch 3=retail replenishment
                   ,@c_Message03             = 'PACKSTATION'
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
           
           --Retail new launch(2) conso(uom6) and partial(uom7) carton to PTS. (1)(3) should not have UOM 6,7 from bulk and should overallocate at pick.
           --PTS booking by loadkey
           --Updated: All orders may choose PTS in wave, so we use WaveType to decide   --WL01
           IF (@c_WaveType = 'PTS') AND @c_UOM IN ('6','7')   --WL01 
           BEGIN
             --SET @c_InLoc = ''
             --SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND LOC.LocationType = ''OTHER'''  --make sure get pickdetial from bulk
             SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM <> ''2'' AND LOC.LocationType = ''OTHER'' ORDER BY ORDERS.Loadkey, ORDERS.Orderkey, PICKDETAIL.UOM '   --WL01
  
             /*
             SELECT TOP 1 @c_InLoc = PZ.InLoc
             FROM LOC (NOLOCK) 
             JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc 
             JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
             JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone
             WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                  
             AND LOC.LocationCategory = 'PTS'
             AND LOC.Facility = @c_Facility
             AND DP.DeviceType = 'STATION'       
             AND PTL.Loadkey = @c_Loadkey  --assume all load from a loc pick of the wave will go to same PTS induction. one pick always go to one in loc
             AND PTL.Wavekey = @c_Wavekey
             */
             
             SET @c_ToLoc = @c_InLoc
             SET @n_TotCtn = CEILING(@n_Qty / (@n_CaseCnt * 1.00))

             WHILE @n_TotCtn > 0 AND @n_Qty > 0 AND @n_continue IN(1,2) AND @c_Salesman <> 'TRF'   --WL01                
             BEGIN
                 IF @n_Qty >= @n_CaseCnt
                    SET @n_InsertQty = @n_CaseCnt
                 ELSE 
                    SET @n_InsertQty = @n_Qty
                    
                 SET @n_Qty = @n_Qty - @n_InsertQty
                
                EXEC isp_InsertTaskDetail   
                    @c_TaskType              = @c_TaskType             
                   ,@c_Storerkey             = @c_Storerkey
                   ,@c_Sku                   = @c_Sku
                   ,@c_Lot                   = @c_Lot 
                   ,@c_UOM                   = @c_UOM      
                   ,@n_UOMQty                = @n_CaseCnt     
                   ,@n_Qty                   = @n_InsertQty      
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
                   ,@c_OrderKey              = @c_Orderkey      
                   ,@c_OrderLineNumber       = @c_OrderLineNumber
                   ,@c_WaveKey               = @c_Wavekey      
                   ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                   ,@c_Message02             = @c_Short  --1=wholesale 2=retail new launch 3=retail replenishment
                   ,@c_Message03             = 'PTS'
                   ,@c_RoundUpQty            = 'FC'  --FC=Round up qty to full carton by packkey
                   ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                   ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                   ,@c_WIP_RefNo             = @c_SourceType
                   --,@n_QtyReplen             = @n_QtyReplen   --WL01
                   ,@c_ReserveQtyReplen      = 'ROUNDUP'   --WL01
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
                                                      
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_OrderLineNumber, @n_CaseCnt, @c_Loadkey, @c_InLoc
                                      , @c_Salesman   --WL01
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END     
       
    -----Create replenishment task    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       SET @c_Priority = '9'
       --Retrieve all lot of the wave from pick loc
       SELECT DISTINCT LLI.Lot             
       INTO #TMP_WAVEPICKLOT
       FROM PICKDETAIL PD (NOLOCK)
       JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
       JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
       JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
       WHERE O.Userdefine09 = @c_Wavekey
       AND SXL.LocationType IN('PICK','CASE')       
       AND LLI.QtyExpected > 0
                          
       --Retreive pick loc with qty < maxpallet
       DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                 PACK.CaseCnt
          FROM LOTXLOCXID LLI (NOLOCK)          
          JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
          JOIN #TMP_WAVEPICKLOT ON LLI.Lot = #TMP_WAVEPICKLOT.Lot 
          WHERE SL.LocationType IN('PICK','CASE')
          AND LLI.Storerkey = @c_Storerkey
          AND LOC.Facility = @c_Facility       
          GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt 
          HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < 0  --overallocate

       OPEN cur_PickLoc
       
       FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN               
           
           IF @n_QtyShort < 0
              SET @n_QtyShort = @n_QtyShort * -1
              
           SET @n_QtyReplen = @n_QtyShort   
           
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
             --AND LOC.LocationType = 'OTHER' 
             AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
             AND LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             AND LLI.Lot = @c_Lot
             ORDER BY SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot
             
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
                   ,@n_UOMQty                = 0     
                   ,@n_Qty                   = @n_InsertQty      
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
                   ,@c_Message02             = @c_Short  -- 1=wholesale 2=retail new launch 3=retail replenishment
                   ,@c_Message03             = 'PICKLOC'
                   ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                   ,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey
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
          
          FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
       END
       CLOSE cur_PickLoc
       DEALLOCATE cur_PickLoc          
    END    
         
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty, 
                 PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno
          FROM PickDetail_WIP (NOLOCK)
          JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey
          WHERE ORDERS.Userdefine09 = @c_Wavekey 
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
          ORDER BY PickDetail_WIP.PickDetailKey 
       
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
             UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET Qty = @n_Qty, 
                 UOMQty = @n_UOMQty, 
                 TaskDetailKey = @c_TaskDetailKey,
                 PickslipNo = @c_Pickslipno,
                 WaveKey = @c_Wavekey,
                 EditDate = GETDATE(),                             
                 TrafficCop = NULL
             WHERE PickDetailKey = @c_PickDetailKey  
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END        
          END
          ELSE 
          BEGIN            
             INSERT INTO PICKDETAIL 
                  (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID )   --WL02 
             SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID   --WL02  
             FROM PICKDETAIL_WIP WITH (NOLOCK)
             WHERE PickDetailKey = @c_PickDetailKey
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey             
    END
      
    -----Validation taskdetail at pickdetail-----
    /*IF @n_continue = 1 or @n_continue = 2  
    BEGIN      
       IF EXISTS(SELECT 1 
                 FROM TASKDETAIL TD (NOLOCK)
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey 
                 WHERE TD.Wavekey = @c_Wavekey                   
                 AND TD.Sourcetype = @c_SourceType 
                 AND TD.Tasktype IN('RFP')                 
                 AND PD.Taskdetailkey IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetailkey To Pickdetail Failed. (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                             
       END          
    END*/
    
    --WL01 START
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       SELECT TOP 1 @c_DocType = OH.DocType
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
       WHERE WD.WaveKey = @c_wavekey
    END
    --WL01 END
       
    -----Generate Pickslip No------
    IF (@n_continue = 1 or @n_continue = 2) AND @c_DocType <> 'E'   --WL01
    BEGIN
       IF @c_UDF02 = 'D' --create discrete pickslip for the wave
       BEGIN
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3    
       END       
       ELSE
       BEGIN --create load conso pickslip for the wave
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_ConsolidateByLoad = 'Y'  --Y=Create load consolidate pickslip
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3    
       END
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
              WHERE O.Userdefine09 = @c_Wavekey
              AND PD.WIP_RefNo = @c_SourceType)
    BEGIN
       DELETE PickDetail_WIP 
       FROM PickDetail_WIP (NOLOCK)
       JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey              
       WHERE ORDERS.Userdefine09 = @c_Wavekey 
       AND PickDetail_WIP.WIP_RefNo = @c_SourceType       
    END        

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV11"  
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