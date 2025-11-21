SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/      
/* Stored Procedure: ispRLWAV35                                             */      
/* Creation Date: 08-SEP-2020                                               */      
/* Copyright: LFL                                                           */      
/* Written by:                                                              */      
/*                                                                          */      
/* Purpose: WMS-14747 - KR Levis release task                               */    
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
/****************************************************************************/       
    
CREATE   PROCEDURE [dbo].[ispRLWAV35]          
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
    
    DECLARE  @c_Storerkey          NVARCHAR(15)    
            ,@c_Sku                NVARCHAR(20)    
            ,@c_Facility           NVARCHAR(5)    
            ,@c_SourceType         NVARCHAR(30)    
            ,@c_WaveType           NVARCHAR(10)    
            ,@c_Lot                NVARCHAR(10)    
            ,@c_FromLoc            NVARCHAR(10)    
            ,@c_ToLoc              NVARCHAR(10)    
            ,@c_ID                 NVARCHAR(18)    
            ,@c_ToID               NVARCHAR(18)    
            ,@c_Packkey            NVARCHAR(10)     
            ,@c_PackUOM            NVARCHAR(10)    
            ,@c_UOM                NVARCHAR(10)    
            ,@n_Qty                INT     
            ,@c_ReplenishmentKey   NVARCHAR(10)        
            ,@n_RowID              INT    
            ,@n_UCCQty             INT    
            ,@c_UCCNo              NVARCHAR(20)    
            ,@n_OrderCnt           INT                
            ,@c_ReplenType         NVARCHAR(10)    
            ,@c_DeviceID           NVARCHAR(20)     
            ,@c_IPAddress          NVARCHAR(40)     
            ,@c_DevicePosition     NVARCHAR(10)     
            ,@c_DevLoc             NVARCHAR(10)    
            ,@c_LabelNo            NVARCHAR(20)    
            ,@c_Orderkey           NVARCHAR(10)    
            ,@c_Pickslipno         NVARCHAR(10)    
            ,@c_Loadkey            NVARCHAR(10)    
            ,@c_DocType            NVARCHAR(1)    
            ,@c_OrderType          NVARCHAR(10)    
            ,@c_Consigneekey       NVARCHAR(15)    
            ,@c_PrevConsigneekey   NVARCHAR(15)    
            ,@c_Userdefine03       NVARCHAR(20)    
            ,@n_Position           INT    
    --,@c_FirstSC            NCHAR(1)               
                                              
    SET @c_SourceType = 'ispRLWAV35'        
    
    -----Get Storerkey, facility    
    IF  (@n_continue = 1 OR @n_continue = 2)    
    BEGIN    
        SELECT TOP 1 @c_Storerkey     = O.Storerkey,     
                     @c_Facility      = O.Facility,    
                     @c_WaveType      = W.WaveType    
        FROM WAVE W (NOLOCK)    
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey    
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey    
        AND W.Wavekey = @c_Wavekey              
    END    
    
    -----Wave Validation-----                
    IF @n_continue = 1 OR @n_continue = 2    
    BEGIN    
        IF EXISTS (SELECT 1     
                   FROM REPLENISHMENT RP (NOLOCK)    
                   WHERE RP.Wavekey = @c_Wavekey        
                   )     
        BEGIN    
          SELECT @n_continue = 3      
          SELECT @n_err = 83010        
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV35)'           
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
              
       CREATE TABLE #DEVICEPOS (RowId INT IDENTITY(1,1),    
                                DevicePosition NVARCHAR(10) NULL,    
                                IPAddress NVARCHAR(40) NULL,     
                                Loc NVARCHAR(10) NULL)              
    END    
    
    BEGIN TRAN    
        
    --Initialize Pickdetail work in progress staging table    
    IF @n_continue = 1 OR @n_continue = 2    
    BEGIN                        
       EXEC isp_CreatePickdetail_WIP    
            @c_Loadkey = ''    
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
           
       UPDATE #PickDetail_WIP SET Toloc = ''    
    END    
    
    -----Create replenishment task for pick face picking    
    IF (@n_continue = 1 OR @n_continue = 2)       
    BEGIN                                     
      --Retreive UCC pick     
       DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, SUM(PD.Qty), UCC.Qty, PACK.Packkey, PACK.PackUOM3, UCC.UCCNo, COUNT(DISTINCT PD.Orderkey) AS ordercnt,    
                 PD.Uom, MAX(O.DocType)    
          FROM WAVEDETAIL WD (NOLOCK)     
          JOIN #PickDetail_WIP PD ON WD.Orderkey = PD.Orderkey    
          JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey    
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku    
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey    
          JOIN UCC (NOLOCK) ON PD.Storerkey = UCC.Storerkey AND PD.Sku = UCC.Sku AND PD.DropID = UCC.UCCNo AND PD.LOT = UCC.LOT AND PD.LOC = UCC.LOC AND PD.ID = UCC.ID     
          WHERE WD.Wavekey = @c_Wavekey    
          AND PD.DropID <> ''    
          AND PD.DropID IS NOT NULL    
          AND PD.UOM IN('2','6','7')    
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, UCC.Qty, PACK.Packkey, PACK.PackUOM3, UCC.UCCNo, PD.UOM    
          ORDER BY PD.UOM, PD.Sku, PD.Loc    
    
       OPEN cur_Pick    
           
       FETCH FROM cur_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @n_UCCQty, @c_Packkey, @c_PackUOM, @c_UCCNo, @n_OrderCnt, @c_UOM, @c_DocType    
           
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)    
       BEGIN    
          SET @c_ToID =  @c_ID    
          SET @c_PackUOM = 'CA'    
          SET @c_ToLoc = ''    
              
          IF @c_UOM = '7'    
          BEGIN    
            IF EXISTS(SELECT 1 FROM REPLENISHMENT REP (NOLOCK)    
                      WHERE RefNo = @c_UCCNo     
                      AND Storerkey = @c_Storerkey     
                      AND Sku = @c_Sku      
                      AND FromLoc = @c_FromLoc    
                       AND Lot = @c_Lot    
                       AND ID = @c_Id)    
             BEGIN    
                GOTO NEXT_PICK    
             END              
          END    
              
          IF @c_UOM = '2' AND @n_OrderCnt = 1    
          BEGIN    
             SET @c_ReplenType = 'FCP'    
    
             SELECT TOP 1 @c_Toloc = Short     
             FROM CODELKUP (NOLOCK)    
             WHERE Storerkey = @c_Storerkey    
             AND Listname = 'RDTREPLEN'    
             AND UDF01 = 'FCP'    
             AND UDF02 = @c_DocType    
          END       
          ELSE IF @c_UOM = '2' AND @n_OrderCnt > 1    
          BEGIN    
             SET @c_ReplenType = 'FCS'    
    
             SELECT TOP 1 @c_Toloc = Short     
             FROM CODELKUP (NOLOCK)    
             WHERE Storerkey = @c_Storerkey    
             AND Listname = 'RDTREPLEN'    
             AND UDF01 = 'FCS'    
          END    
          ELSE    
          BEGIN     
             SET @c_ReplenType = 'RPL'    
    
             SELECT TOP 1 @c_ToLoc = L.Loc    
             FROM SKUXLOC SL (NOLOCK)                 
             JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc    
             WHERE L.Facility = @c_Facility    
             AND L.LocationType = 'DYNPPICK'    
             AND L.LocationFlag = 'NONE'    
             AND SL.Storerkey = @c_Storerkey     
             AND SL.Sku = @c_Sku    
             AND (SL.Qty-SL.QtyPicked) + SL.QtyExpected > 0      
             AND SL.Qty + SL.QtyExpected > 0    
             ORDER BY (SL.Qty-SL.QtyPicked) + SL.QtyExpected, L.LogicalLocation, L.Loc    
                 
             --Find loc with zero stock with putawayzone priority in skuconfig    
             IF ISNULL(@c_ToLoc,'') = ''    
             BEGIN    
                SELECT TOP 1 @c_ToLoc = L.Loc    
                FROM LOC L (NOLOCK)    
                LEFT JOIN SKUXLOC SL (NOLOCK) ON L.Loc = SL.Loc AND SL.Storerkey = @c_Storerkey --AND SL.Sku = @c_Sku    
                LEFT JOIN SKUCONFIG SC (NOLOCK) ON L.Putawayzone = SC.Data AND SC.Storerkey = @c_Storerkey AND SC.Sku = @c_Sku    
                WHERE L.Facility = @c_Facility    
                AND L.LocationType = 'DYNPPICK'    
                AND L.LocationFlag = 'NONE'  
                AND L.LOC NOT IN (SELECT TOLOC FROM REPLENISHMENT WITH(NOLOCK) WHERE STORERKEY = @c_Storerkey AND CONFIRMED = 'N' and sku <> @c_Sku)  
                --AND ISNULL((SL.Qty-SL.QtyPicked) + SL.QtyExpected,0) = 0       
                GROUP BY L.Loc,SC.Data,L.LogicalLocation  
                HAVING SUM(ISNULL((SL.Qty-SL.QtyPicked) + SL.QtyExpected,0)) = 0  
                ORDER BY CASE WHEN SC.Data IS NOT NULL THEN 1 ELSE 2 END, L.LogicalLocation, L.Loc    
             END    
                 
             --Find loc by putawayzone in codelkup    
             IF ISNULL(@c_ToLoc,'') = ''    
             BEGIN    
                SELECT TOP 1 @c_ToLoc = L.Loc    
                FROM LOC L (NOLOCK)    
                LEFT JOIN SKUXLOC SL (NOLOCK) ON L.Loc = SL.Loc AND SL.Storerkey = @c_Storerkey AND SL.Sku = @c_Sku    
                WHERE L.Facility = @c_Facility    
                AND L.LocationType <> 'OTHER'    
                AND L.LocationFlag = 'NONE'    
                AND L.Putawayzone IN (SELECT CL.Short FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = 'LSMIXLOC' AND CL.Storerkey = @c_Storerkey)    
                --AND ISNULL(SL.Qty,0) = 0     
                ORDER BY L.LogicalLocation, L.Loc    
             END                 
          END    
                             
         IF @c_ToLoc = ''    
          BEGIN    
             SELECT @n_continue = 3      
             SELECT @n_err = 83020        
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find destination loc for ' + RTRIM(@c_ReplenType) + ' for Sku ' + RTRIM(@c_Sku)  + '. (ispRLWAV35)'            
             BREAK                 
          END                              
                 
          EXECUTE nspg_getkey    
             'REPLENISHKEY'    
             , 10    
             , @c_ReplenishmentKey OUTPUT    
             , @b_success OUTPUT    
             , @n_err OUTPUT    
             , @c_errmsg OUTPUT    
                 
          IF NOT @b_success = 1    
          BEGIN    
             SELECT @n_continue = 3    
          END    
    
          INSERT INTO REPLENISHMENT(    
                   Replenishmentgroup, ReplenishmentKey, StorerKey,    
                   Sku,                FromLoc,          ToLoc,    
                   Lot,                Id,               Qty,    
                   UOM,                PackKey,          Confirmed,     
                   MoveRefKey,         ToID,             PendingMoveIn,     
                   QtyReplen,          QtyInPickLoc,     RefNo,     
                   Wavekey,       Remark,      ReplenNo,    
                   OriginalQty,    OriginalFromLoc,  DropId)    
          VALUES ('DYNAMIC',      @c_ReplenishmentKey, @c_StorerKey,     
                   @c_SKU,            @c_FromLOC,          @c_ToLOC,     
                   @c_LOT,            @c_ID,               @n_UCCQty,     
                   @c_PackUOM,        @c_PackKey,          'N',     
                   '',           @c_ToID,             0,     
                   0,         0,             @c_UCCNo,    
                   @c_Wavekey,    '',          @c_ReplenType,     
                   @n_Qty,      @c_SourceType,    @c_UCCNo)      
    
          IF @@ERROR <> 0    
          BEGIN    
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          END                                    
              
          IF @c_ReplenType = 'RPL'    
          BEGIN    
             UPDATE #PICKDETAIL_WIP    
             SET Toloc = @c_ToLoc    
             WHERE DropId = @c_UCCNo    
             AND Storerkey = @c_Storerkey    
             AND Sku = @c_Sku    
          END    
              
          NEXT_PICK:    
              
          FETCH FROM cur_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @n_UCCQty, @c_Packkey, @c_PackUOM, @c_UCCNo, @n_OrderCnt, @c_UOM, @c_DocType            
       END    
       CLOSE cur_Pick    
       DEALLOCATE cur_Pick    
    END    
    
    -----Generate Pickslip No------        
    IF @n_continue = 1 or @n_continue = 2     
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
           
    -----Update PTL    
    IF (@n_continue = 1 or @n_continue = 2) AND @c_WaveType = 'LVS-PTL'        
    BEGIN    
      SET @c_DeviceID = ''    
          
       SELECT TOP 1 @c_DeviceID = DeviceID    
       FROM DEVICEPROFILE (NOLOCK)    
       WHERE DeviceType = 'STATION'    
       AND Storerkey = @c_Storerkey    
       AND Status = '0'    
       AND Priority = '1'    
       ORDER BY DeviceID    
           
       IF ISNULL(@c_DeviceID,'') = ''    
       BEGIN    
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No available DeviceID found. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
       END    
       ELSE    
       BEGIN    
          UPDATE DEVICEPROFILE WITH (ROWLOCK)    
          SET Status = '9'    
          WHERE DeviceId = @c_DeviceID    
              
          IF @@ERROR <> 0    
          BEGIN    
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update DEVICEPROFILE Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          END                            
              
          INSERT INTO #DEVICEPOS (DevicePosition, IPAddress, Loc)    
          SELECT DV.DevicePosition, DV.IPAddress, DV.Loc    
          FROM DEVICEPROFILE DV (NOLOCK)    
          WHERE DV.DeviceID = @c_DeviceID    
          ORDER BY DV.LogicalName, DV.DevicePosition    
           
          SELECT PD.DropID    
    INTO #CONSO_UCC                           
          FROM WAVEDETAIL WD (NOLOCK)     
          JOIN #PickDetail_WIP PD ON WD.Orderkey = PD.Orderkey    
          WHERE WD.Wavekey = @c_Wavekey    
          AND PD.DropID <> ''    
          AND PD.DropID IS NOT NULL    
          AND PD.UOM = '2'    
          GROUP BY PD.DropID    
          HAVING COUNT(DISTINCT PD.Orderkey) > 1    
              
          DECLARE cur_PTLORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
             SELECT PD.Orderkey, O.Type    
             FROM #PICKDETAIL_WIP PD    
             JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey    
             LEFT JOIN #CONSO_UCC CU ON PD.DropID = CU.DropID    
             WHERE (CU.Dropid IS NOT NULL OR PD.UOM IN('6','7')) --Only conso carton and piece. exclude full carton.    
             --AND O.Doctype = 'N'    
             GROUP BY PD.Orderkey, O.Type    
             ORDER BY SUM(PD.Qty) DESC    
              
          OPEN cur_PTLORD    
              
          FETCH FROM cur_PTLORD INTO @c_Orderkey, @c_OrderType    
              
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)    
          BEGIN    
             SELECT @c_Pickslipno = PickHeaderkey    
             FROM PICKHEADER (NOLOCK)    
             WHERE Orderkey = @c_Orderkey    
             AND Storerkey = @c_Storerkey                
                 
             SET @c_LabelNo = ''    
                              
             EXEC isp_GenUCCLabelNo_Std    
                @cPickslipNo = @c_Pickslipno,    
                @nCartonNo   = 0,    
                @cLabelNo    = @c_LabelNo OUTPUT,     
                @b_success   = @b_Success OUTPUT,    
                @n_err       = @n_err OUTPUT,    
                @c_errmsg    = @c_errmsg OUTPUT                
                    
             IF @b_success <> 1    
                SET @n_continue = 3       
                 
             RESUME_NEXT:                
                 
             SELECT TOP 1 @n_RowID = RowID,    
                          @c_IPAddress = IPAddress,    
                          @c_DevicePosition = DevicePosition,    
                          @c_DevLoc = Loc    
             FROM #DEVICEPOS    
             ORDER BY RowID    
                 
             IF @@ROWCOUNT = 0    
             BEGIN                 
               SET @c_DeviceID = ''    
               SELECT TOP 1 @c_DeviceID = DeviceID    
                 FROM DEVICEPROFILE (NOLOCK)    
                 WHERE DeviceType = 'STATION'    
                 AND Storerkey = @c_Storerkey    
                 AND Status = '0'    
                 AND Priority = '1'                    
                 ORDER BY DeviceID    
                     
                 IF ISNULL(@c_DeviceID,'') <> ''    
                 BEGIN    
                    TRUNCATE TABLE #DEVICEPOS    
                    INSERT INTO #DEVICEPOS (DevicePosition, IPAddress, Loc)    
                    SELECT DV.DevicePosition, DV.IPAddress, DV.Loc    
                    FROM DEVICEPROFILE DV (NOLOCK)    
                    WHERE DV.DeviceID = @c_DeviceID    
                    ORDER BY DV.LogicalName, DV.DevicePosition    
                     
                    UPDATE DEVICEPROFILE WITH (ROWLOCK)    
                    SET Status = '9'    
                    WHERE DeviceId = @c_DeviceID    
                        
                    IF @@ERROR <> 0    
                    BEGIN    
                       SELECT @n_continue = 3      
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update DEVICEPROFILE Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
                    END               
                    ELSE    
                       GOTO RESUME_NEXT                                                 
                 END    
         
              SELECT @n_continue = 3      
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insufficient Device Position. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
             END    
                 
             INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Method, CartonID, Orderkey, Wavekey, Storerkey)    
             VALUES (@c_DeviceID, @c_IPAddress, @c_DevicePosition, @c_DevLoc, '1', @c_LabelNo, @c_Orderkey, @c_Wavekey, @c_Storerkey)    
                 
             SET @n_err = @@ERROR                
           
             IF @n_err <> 0    
             BEGIN    
                SELECT @n_continue = 3      
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert rdtPTLStationLog Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
             END    
                             
             DELETE FROM #DEVICEPOS WHERE RowID = @n_RowID                           
               
             FETCH FROM cur_PTLORD INTO @c_Orderkey, @c_OrderType    
          END    
          CLOSE cur_PTLORD    
          DEALLOCATE cur_PTLORD                             
       END                      
    END           
        
    --Update load plan    
    IF (@n_continue = 1 or @n_continue = 2) AND @c_WaveType = 'LVS-PTL'       
    BEGIN    
       DECLARE cur_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
          SELECT DISTINCT LPD.Loadkey    
          FROM #PICKDETAIL_WIP PD    
          JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey    
           
       OPEN cur_LOAD    
              
       FETCH FROM cur_LOAD INTO @c_Loadkey    
              
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)    
       BEGIN    
          UPDATE LOADPLAN WITH (ROWLOCK)    
          SET LoadPickMethod = 'C'    
          WHERE Loadkey = @c_Loadkey    
    
          SET @n_err = @@ERROR    
              
          IF @n_err <> 0    
          BEGIN    
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update LOADPLAN Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          END                             
            
          FETCH FROM cur_LOAD INTO @c_Loadkey    
       END    
       CLOSE cur_LOAD    
       DEALLOCATE cur_LOAD                 
    END    
              
    --Create packtask record               
    IF (@n_continue = 1 or @n_continue = 2)     
    BEGIN    
       DECLARE cur_PackTaskOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
          SELECT O.Orderkey, O.Consigneekey, O.Userdefine03    
          FROM #PICKDETAIL_WIP PD    
          JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey    
          WHERE O.DocType = 'N'              
          GROUP BY O.Userdefine03, O.Consigneekey, O.Orderkey    
          ORDER BY CASE WHEN O.Userdefine03 = 'NC' THEN 1 WHEN O.Userdefine03 = 'SC' THEN 2 ELSE 3 END, O.Consigneekey, O.Orderkey    
           
       OPEN cur_PackTaskOrd    
              
       FETCH FROM cur_PackTaskOrd INTO @c_Orderkey, @c_Consigneekey, @c_Userdefine03    
           
       SET @n_Position = 0       
       SET @c_PrevConsigneekey = '*'    
       --SET @c_FirstSC = 'Y'    
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)    
       BEGIN    
          IF @c_Userdefine03 = 'NC'     
             SET @n_Position = 1    
          ELSE IF @c_Userdefine03 = 'SC'    
             SET @n_Position = 2    
    /*ELSE IF @c_Userdefine03 = 'SC' AND @n_Position = 0 AND @c_FirstSC = 'Y'    
          BEGIN    
             SET @n_Position = 1    
             SET @c_FirstSC = 'N'    
          END    
          ELSE IF @c_Userdefine03 = 'SC' AND @n_Position = 1 AND @c_FirstSC = 'Y'    
          BEGIN    
             SET @n_Position = 2    
             SET @c_FirstSC = 'N'    
          END*/    
          ELSE    
          BEGIN    
            IF @n_Position < 2    
               SET @n_Position = 2    
                   
            IF @c_PrevConsigneekey <> @c_Consigneekey    
                SET @n_Position = @n_Position +  1                   
          END       
               
          INSERT INTO PACKTASK (TaskBatchNo, Orderkey, DevicePosition)    
          VALUES (@c_Wavekey, @c_Orderkey, CAST(@n_Position AS NVARCHAR))    
    
          SET @n_err = @@ERROR    
              
          IF @n_err <> 0    
          BEGIN    
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100     -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PACKTASK Table. (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
          END                             
              
          SET @c_PrevConsigneekey = @c_Consigneekey    
              
          FETCH FROM cur_PackTaskOrd INTO @c_Orderkey, @c_Consigneekey, @c_Userdefine03    
       END         
     CLOSE cur_PackTaskOrd    
       DEALLOCATE cur_PackTaskOrd    
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
    
    -----Update Wave Status-----    
    IF @n_continue = 1 or @n_continue = 2      
    BEGIN      
      UPDATE WAVE       
          SET TMReleaseFlag = 'Y'    
           ,  TrafficCop = NULL      
           ,  EditWho = SUSER_SNAME()     
           ,  EditDate= GETDATE()         
       WHERE WAVEKEY = @c_wavekey        
                  
       SELECT @n_err = @@ERROR      
       IF @n_err <> 0      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV35)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV35"      
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