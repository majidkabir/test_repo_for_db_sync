SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLBLP01                                          */  
/* Creation Date: 20-Jun-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-4484 - CN UA Build load release task (B2C)               */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 01/04/2019   NJOW01   1.0  Change WIP using temp table and fix        */
/* 15/05/2019   NJOW02   1.1  WMS-9070 Replenish addition carton if the  */
/*                            location no more available qty after pick  */
/* 25/08/2021   WLChooi  1.2  WMS-17812 - Set Priority to 4 for UA(WL01) */ 
/* 15/07/2022   NJOW03   1.3  fix to filter facility for replenishment   */ 
/*************************************************************************/  
  
CREATE PROC [dbo].[ispRLBLP01]  
   @c_LoadKey     NVARCHAR(10),  
   @b_Success     INT = 1            OUTPUT,
   @n_err         INT = 0            OUTPUT,  
   @c_ErrMsg      NVARCHAR(250) = '' OUTPUT,
   @c_Storerkey   NVARCHAR(15) = '' 
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   @n_continue       INT  
            ,@n_StartTranCnt   INT  
            ,@c_Sku            NVARCHAR(20)
            ,@c_Lot            NVARCHAR(10)
            ,@c_FromLoc        NVARCHAR(10)
            ,@c_ToLoc          NVARCHAR(10)
            ,@c_ID             NVARCHAR(18)
            ,@c_ToID           NVARCHAR(18)
            ,@n_Qty            INT
            ,@n_QtyReplen      INT
            ,@c_UOM            NVARCHAR(10)
            ,@c_TaskType       NVARCHAR(10)            
            ,@c_PickMethod     NVARCHAR(10)
            ,@c_SourceType     NVARCHAR(30)   
            ,@c_Facility       NVARCHAR(5) 
            ,@c_PickDetailKey  NVARCHAR(10)
            ,@n_UOMQty         NVARCHAR(10)
            ,@c_TaskDetailkey  NVARCHAR(10)
            ,@c_Pickslipno     NVARCHAR(10)
            ,@c_PackStation    NVARCHAR(10)
            ,@c_Message01      NVARCHAR(20) 
            ,@c_Message02      NVARCHAR(20) 
            ,@c_Message03      NVARCHAR(20) 
            ,@n_TotCtn         INT
            ,@n_CaseCnt        INT                
            ,@c_Priority       NVARCHAR(10)
            ,@n_QtyShort       INT
            ,@n_QtyAvailable   INT
            ,@n_InsertQty      INT
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)
                                             
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1 ,@n_err = 0 ,@c_ErrMsg = '', @b_Success = 1
   
   SET @c_SourceType = 'ispRLBLP01'
   SET @c_TaskType = 'RPF'
   SET @n_UOMQty = 0
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN
           
   -----Load Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF NOT EXISTS (SELECT 1 
                     FROM LOADPLANDETAIL LD (NOLOCK)
                     JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = 'RPF'
                     WHERE LD.Loadkey = @c_Loadkey                   
                     AND PD.Status = '0'
                     AND TD.Taskdetailkey IS NULL
                    )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' Has nothing to release. (ispRLBLP01)'       
      END
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Loadkey = @c_Loadkey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype = 'RPF')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) + ' has beed released. (ispRLBLP01)'       
       END                 
   END

   -----Get Storerkey, facility
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey,
                    @c_Facility = O.Facility
       FROM LOADPLAN L (NOLOCK)
       JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
       JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
       WHERE L.Loadkey = @c_Loadkey       
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
         
         --CREATE INDEX PDWIP_Order ON #PickDetail_WIP (Orderkey)           	         
   END

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = @c_Loadkey
           ,@c_Wavekey               = ''
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
   
   --Initialize Pickdetail work in progress staging table
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                WHERE O.Loadkey = @c_Loadkey
                AND PD.WIP_RefNo = @c_SourceType)
      BEGIN
      	  DELETE PickDetail_WIP 
      	  FROM PickDetail_WIP (NOLOCK)
      	  JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey         	  
          WHERE ORDERS.Loadkey = @c_Loadkey
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
      END 
      
      INSERT INTO PickDetail_WIP 
      (
      	PickDetailKey,      CaseID,      		 PickHeaderKey,
      	OrderKey,           OrderLineNumber, Lot,
      	Storerkey,          Sku,      	   	 AltSku,     UOM,
      	UOMQty,      	      Qty,      	   	 QtyMoved,   [Status],
      	DropID,      	      Loc,      	     ID,      	 PackKey,
      	UpdateSource,       CartonGroup,     CartonType,
      	ToLoc,      	      DoReplenish,     ReplenishZone,
      	DoCartonize,        PickMethod,      WaveKey,
      	EffectiveDate,      AddDate,      	 AddWho,
      	EditDate,           EditWho,      	 TrafficCop,
      	ArchiveCop,         OptimizeCop,     ShipFlag,
      	PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
      	Notes,      	      MoveRefKey,			 WIP_RefNo
      )
      SELECT PD.PickDetailKey,  CaseID,   						PD.PickHeaderKey, 
      	PD.OrderKey,         		 PD.OrderLineNumber,  PD.Lot,
      	PD.Storerkey,        		 PD.Sku,      	      PD.AltSku,        PD.UOM,
      	PD.UOMQty,      	   		 PD.Qty,      	      PD.QtyMoved,      PD.[Status],
      	PD.DropID,      	   		 PD.Loc,      	      PD.ID,      	    PD.PackKey,
      	PD.UpdateSource,     		 PD.CartonGroup,      PD.CartonType,
      	PD.ToLoc,      	     		 PD.DoReplenish,      PD.ReplenishZone,
      	PD.DoCartonize,      		 PD.PickMethod,       PD.Wavekey,
      	PD.EffectiveDate,    		 PD.AddDate,      	  PD.AddWho,
      	PD.EditDate,         		 PD.EditWho,      	  PD.TrafficCop,
      	PD.ArchiveCop,       		 PD.OptimizeCop,      PD.ShipFlag,
      	PD.PickSlipNo,       		 PD.TaskDetailKey,    PD.TaskManagerReasonKey,
      	PD.Notes,      	     		 PD.MoveRefKey,       @c_SourceType 
      FROM LOADPLANDETAIL LD (NOLOCK) 
      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE LD.Loadkey = @c_Loadkey     
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Error Insert PickDetail_WIP Table. (ispRLBLP01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END      
   END
   */       

   --Remove taskdetailkey 
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
      SET PICKDETAIL_WIP.TaskdetailKey = '',
          PICKDETAIL_WIP.TrafficCop = NULL
      FROM LOADPLANDETAIL (NOLOCK)  
      JOIN PICKDETAIL_WIP ON LOADPLANDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
      AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Update Pickdetail_WIP Table Failed. (ispRLBLP01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   */
   
   --Get packstation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_PackStation = ''   	 
   	  SELECT @c_PackStation = CL.Long
   	  FROM CODELKUP CL (NOLOCK)   	    	  
   	  JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
   	  WHERE CL.Listname = 'UALOC' 
   	  AND CL.Code = '3'
   	     	  
      IF ISNULL(@c_PackStation,'') = ''
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Invalid Packstation setup at listname UALOC. (ispRLBLP01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   
   --Get message02
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
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

   --Create case pick task
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	          	  
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                PACK.CaseCnt
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE LPD.Loadkey = @c_Loadkey
         AND PD.Status = '0'
         AND PD.WIP_RefNo = @c_SourceType
         AND SL.LocationType NOT IN('PICK','CASE')
         AND PD.UOM = '2' 
         --AND LOC.LocationType = 'OTHER'
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, PACK.CaseCnt
         ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt
      
      SET @c_ToLoc = @c_PackStation
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	 
 	  	    SET @c_ToLoc = @c_PackStation
 	  	    SET @c_Message01 = ''
 	  	    SET @c_Message03 = 'PACKSTATION' 
 	  	    --SET @c_Priority = '8'   --WL01
          SET @c_Priority = CASE WHEN @c_Storerkey = 'UA' THEN '4' ELSE '8' END     --WL01
 	  	    SET @c_PickMethod = 'PP'
   	  	  SET @n_TotCtn = FLOOR(@n_Qty / @n_CaseCnt)       	  	 
   	  	  
       	  SELECT TOP 1 @c_Message01 = ISNULL(Short,'')
       	  FROM CODELKUP (NOLOCK) 
       	  WHERE ListName = 'UATASKSQ'
       	  AND Code = @c_Message03
       	  AND Storerkey = @c_Storerkey       	  	 

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
               ,@c_SourceKey             = @c_Loadkey      
               ,@c_CallSource            = 'LOADPLAN'
               ,@c_LoadKey               = @c_Loadkey      
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

          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt      	     
      END 
      CLOSE cur_pick  
      DEALLOCATE cur_pick                                                
   END        
   
   -----Create replenishment task    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	 --Retrieve all lot of the load from pick loc
      SELECT DISTINCT LLI.Lot             
      INTO #TMP_LOADPICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      WHERE O.Loadkey = @c_Loadkey
      AND SXL.LocationType IN('PICK','CASE')    	 
      AND LLI.QtyExpected > 0
                         
   	 --Retreive pick loc with overallocated
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                PACK.CaseCnt
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN #TMP_LOADPICKLOT ON LLI.Lot = #TMP_LOADPICKLOT.Lot 
         WHERE SL.LocationType IN('PICK','CASE')
         AND LLI.Storerkey = @c_Storerkey
         AND LOC.Facility = @c_Facility       
         GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt 
         HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) < 0  --overallocate         
         UNION ALL --NJOW02
         SELECT SL.Storerkey, SL.Sku, '', SL.Loc, '', 0, PACK.CaseCnt
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
      
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN       	            	  
          SET @c_Message01 = ''
 	  	    SET @c_Message03 = 'PICKLOC' 
 	  	    --SET @c_Priority = '8'   --WL01
          SET @c_Priority = CASE WHEN @c_Storerkey = 'UA' THEN '4' ELSE '8' END     --WL01
 	  	    SET @c_PickMethod = 'PP'

       	  SELECT TOP 1 @c_Message01 = ISNULL(Short,'')
       	  FROM CODELKUP (NOLOCK) 
       	  WHERE ListName = 'UATASKSQ'
       	  AND Code = @c_Message03
       	  AND Storerkey = @c_Storerkey       
       	          	
      	  IF @n_QtyShort < 0
      	     SET @n_QtyShort = @n_QtyShort * -1
      	     
      	  SET @n_QtyReplen = @n_QtyShort   
      	  
      	  --NJOW02
      	  IF @n_Casecnt > 0
      	  BEGIN
      	     IF @n_QtyShort % @n_Casecnt = 0 OR @n_QtyShort = 0
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
            --AND LOC.LocationType = 'OTHER' 
            AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku
            AND LOC.Facility = @c_Facility  --NJOW03
            --AND LLI.Lot = @c_Lot  --NJOW02 removed
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

      	  	 	  IF @n_QtyAvailable >= @n_CaseCnt
      	  	 	     SET @n_Qty = @n_CaseCnt
      	  	 	  ELSE   
      	  	 	     SET @n_Qty = @n_QtyAvailable    
      	  	 	         	  	 	     
      	  	 	  SET @n_QtyReplen = @n_QtyReplen - @n_InsertQty
      	  	 	  SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty
      	  	 	            
      	  	    EXEC isp_InsertTaskDetail   
                   @c_TaskType              = @c_TaskType             
                  ,@c_Storerkey             = @c_Storerkey
                  ,@c_Sku                   = @c_Sku
                  ,@c_Lot                   = @c_Lot 
                  ,@c_UOM                   = '2'      
                  ,@n_UOMQty                = @n_InsertQty     
                  ,@n_Qty                   = @n_Qty      
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
                  ,@c_SourceKey             = @c_Loadkey      
                  ,@c_CallSource            = 'LOADPLAN'
                  ,@c_LoadKey               = @c_Loadkey      
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
         
         FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc          
   END    

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	 
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = @c_Loadkey
           ,@c_Wavekey               = ''  
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
    
   -----Update pickdetail_WIP work in progress staging table back to pickdetail--                                 
   /*
   IF @n_continue = 1 or @n_continue = 2                                                                                    
   BEGIN                                                                                                                    
      DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                     
      SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty,                                       
             PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno                                                        
      FROM PickDetail_WIP (NOLOCK)                                                                                          
      JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey                                                     
      WHERE ORDERS.Loadkey = @c_Loadkey                                                                                
      AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType            
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
         	     EditDate = GETDATE(),   	   		        	                                                                   
         	     TrafficCop = NULL                                                                                           
         	 WHERE PickDetailKey = @c_PickDetailKey                                                                          
                                                                                                                            
            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLBLP01)' + ' ( ' 
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
                  Taskdetailkey, TaskManagerReasonkey, Notes )                                                              
            SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                    
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,                                               
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                          
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                  WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                        
                  Taskdetailkey, TaskManagerReasonkey, Notes                                                                
            FROM PICKDETAIL_WIP WITH (NOLOCK)                                                                               
            WHERE PickDetailKey = @c_PickDetailKey        
            AND PickDetail_WIP.WIP_RefNo = @c_SourceType                                                                  
                                                                                                                            
            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLBLP01)' + ' ( ' 
	  	       END                                                                                                             
         END                                                                                                                
                                                                                                                            
      	  FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno             
      END                                                                                                                   
      CLOSE cur_PickDetailKey                                                                                               
      DEALLOCATE cur_PickDetailKey                                                                                                                                                                                                                      
   END                                    
   */
   
    -----Generate Pickslip No------
    /*IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Loadkey = @c_Loadkey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT       	
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END*/                                                                                    
                                                                                                                          
   RETURN_SP:  
   IF OBJECT_ID('tempdb..#PickDetail_WIP','u') IS NOT NULL
      DROP TABLE #PickDetail_WIP

   /*
   IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
             WHERE O.Loadkey = @c_Loadkey
             AND PD.WIP_RefNo = @c_SourceType)
   BEGIN
   	  DELETE PickDetail_WIP 
   	  FROM PickDetail_WIP (NOLOCK)
   	  JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey         	  
      WHERE ORDERS.Loadkey = @c_Loadkey
      AND PickDetail_WIP.WIP_RefNo = @c_SourceType            
   END
   */
   
   IF @n_continue IN(1,2)
   BEGIN
   	  UPDATE LOADPLAN WITH (ROWLOCK)
   	  SET Status = '3',
   	      TrafficCop = NULL
   	  WHERE Loadkey = @c_Loadkey
   	  AND Status IN('1','2')

      SELECT @n_err = @@ERROR                                                                                         
                                                                                                                      
      IF @n_err <> 0                                                                                                  
      BEGIN                                                                                                           
         SELECT @n_continue = 3                                                                                       
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080   -- Should Be Set To The SQL Errmessage but
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LoadPlan Table Failed. (ispRLBLP01)' + ' ( ' 
	  	END                                                                                                                	  
   END
         
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTranCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV16"  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTranCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END                                                                                         
END

GO