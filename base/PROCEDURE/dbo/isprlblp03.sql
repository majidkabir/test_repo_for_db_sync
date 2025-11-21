SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLBLP03                                          */  
/* Creation Date: 05-Jul-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5572 - CN IKEA Build load release task                   */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 18/10/2018   NJOW01   1.0  addtional Search DPP from codelkup IKVLOC  */
/* 19/11/2018   TLTING01 1.1  performance tune - avoid bulk delete       */  
/* 12/05/2020   NJOW02   1.2  performance tune - avoid bulk update       */  
/*************************************************************************/  
  
CREATE PROC [dbo].[ispRLBLP03]  
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
            ,@c_Message03      NVARCHAR(20) 
            ,@n_TotCtn         INT
            ,@c_Priority       NVARCHAR(10)
            ,@n_InsertQty      INT
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)
            ,@c_Ecom_single_flag NCHAR(1)
            ,@c_AllocateGetCasecntFrLottable NVARCHAR(10)
            ,@c_Putawayzone    NVARCHAR(10)
            ,@c_PutawayZone01  NVARCHAR(10)
            ,@c_PutawayZone02  NVARCHAR(10)
            ,@c_PutawayZone03  NVARCHAR(10)
            ,@c_PutawayZone04  NVARCHAR(10)
            ,@c_PutawayZone05  NVARCHAR(10)
            ,@c_Short_Priority NVARCHAR(10)
    			  ,@c_WIP_PickDetailKey NVARCHAR(18)              
                                                         
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1 ,@n_err = 0 ,@c_ErrMsg = '', @b_Success = 1
   
   SET @c_SourceType = 'ispRLBLP03'
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' Has nothing to release. (ispRLBLP03)'       
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) + ' has beed released. (ispRLBLP03)'       
       END                 
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
   	  SET @c_Sku = ''
   	  
      SELECT TOP 1 @c_Sku = OD.Sku 
      FROM LOADPLANDETAIL LD (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON LD.Orderkey = OD.Orderkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      LEFT JOIN PUTAWAYZONE PZ (NOLOCK) ON SKU.Putawayzone = PZ.Putawayzone 
      WHERE LD.Loadkey = @c_Loadkey
      AND PZ.Putawayzone IS NULL
      ORDER BY OD.Sku                   

      IF ISNULL(@c_Sku,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' Putawyzone not setup for Sku: ' + RTRIM(@c_Sku) + ' (ispRLBLP03)'       
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
       
       SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable') 
   END    
   
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                WHERE O.Loadkey = @c_Loadkey
                AND PD.WIP_RefNo = @c_SourceType)
      BEGIN
      	  /*DELETE PickDetail_WIP 
      	  FROM PickDetail_WIP (NOLOCK)
      	  JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey         	  
          WHERE ORDERS.Loadkey = @c_Loadkey
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType*/
          
           -- tlting01    
          SET @c_WIP_PickDetailKey = ''   
          DECLARE CUR_DELPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
             SELECT PickDetailKey    
             FROM PickDetail_WIP (NOLOCK)    
             JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey                
             WHERE ORDERS.Loadkey = @c_Loadkey    
             AND PickDetail_WIP.WIP_RefNo = @c_SourceType  
  
            OPEN CUR_DELPickDetail    
    
            FETCH FROM CUR_DELPickDetail INTO @c_WIP_PickDetailKey     
    
            WHILE @@FETCH_STATUS = 0    
            BEGIN    
               DELETE PickDetail_WIP     
               WHERE PickDetailKey = @c_WIP_PickDetailKey     
               
               FETCH FROM CUR_DELPickDetail INTO @c_WIP_PickDetailKey     
            END    
    
            CLOSE CUR_DELPickDetail    
            DEALLOCATE CUR_DELPickDetail    
            SET @c_WIP_PickDetailKey = ''              
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
      	PD.PickSlipNo,       		 '',   								PD.TaskManagerReasonKey,  --NJOW02
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Error Insert PickDetail_WIP Table. (ispRLBLP03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END      
   END       

   --Remove taskdetailkey --NJOW02
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
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Update Pickdetail_WIP Table Failed. (ispRLBLP03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   */
   
   --Get Packstation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_PackStation = ''   	 

      SELECT TOP 1 @c_PackStation = Notes2
      FROM CODELKUP (NOLOCK) 
      WHERE Short = @c_Facility
      AND Listname = 'IKEAFAC'
      ORDER BY Code
        
      IF ISNULL(@c_PackStation,'') = ''
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. No PackStation assign for facility (Listname:IKEAFAC) ''' + RTRIM(@c_Facility) +'''. (ispRLBLP03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   --Create case pick task (full/conso case )
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	          	  
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, O.Ecom_single_flag
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot 
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE LPD.Loadkey = @c_Loadkey
         AND PD.Status = '0'
         AND PD.WIP_RefNo = @c_SourceType
         AND LOC.LocationType  <> 'PICK'
         AND PD.UOM IN('2','6') --AND O.Ecom_single_flag = 'S'
         --AND ((PD.UOM = '2' AND O.Ecom_single_flag = 'M') --multi full case
         --    OR (PD.UOM IN('2','6') AND O.Ecom_single_flag = 'S')  --single full/conso case
         --    OR (PD.UOM = '2' AND ISNULL(O.Ecom_single_flag,'') = '')) --retail full case 
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, O.Ecom_single_flag
         ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Ecom_single_flag
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	 
 	  	    SET @c_ToLoc = @c_PackStation
 	  	    SET @c_Message03 = 'PACKSTATION' 
 	  	    SET @c_Priority = '9'
 	  	    SET @c_PickMethod = 'PP'
   	  	  --SET @n_TotCtn = FLOOR(@n_Qty / @n_CaseCnt)       	  	 

      	  --additional condition to search pickdetail
      	  IF @c_Ecom_single_flag = 'M'
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.Ecom_single_flag = ''M'''
    	  	ELSE IF @c_Ecom_single_flag = 'S'     
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.Ecom_single_flag = ''S'''
    	  	ELSE
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ISNULL(ORDERS.Ecom_single_flag,'''') = '''''     	  	       	  	
          	         	  	 
      	  --WHILE @n_TotCtn > 0 AND @n_continue IN(1,2)       	  	
      	  --BEGIN
      	     EXEC isp_InsertTaskDetail   
                @c_TaskType              = @c_TaskType             
               ,@c_Storerkey             = @c_Storerkey
               ,@c_Sku                   = @c_Sku
               ,@c_Lot                   = @c_Lot 
               ,@c_UOM                   = @c_UOM      
               ,@n_UOMQty                = 0     
               ,@n_Qty                   = @n_Qty      
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
               ,@c_LoadKey               = @c_Loadkey      
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
               ,@c_Message03             = @c_Message03
               ,@c_CallSource            = 'LOADPLAN'
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
               ,@c_WIP_RefNo             = @c_SourceType
               ,@c_SplitTaskByCase       = 'Y'
               ,@b_Success               = @b_Success OUTPUT
               ,@n_Err                   = @n_err OUTPUT 
               ,@c_ErrMsg                = @c_errmsg OUTPUT       	
            
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
      	  	
      	     --SET @n_TotCtn = @n_TotCtn - 1
      	  --END       	  	
    
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Ecom_single_flag      	  
      END 
      CLOSE cur_pick  
      DEALLOCATE cur_pick                                                
   END        

   --Create replen task to DPP (loose)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	          	  
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                O.Ecom_single_flag, SKU.Putawayzone
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot 
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE LPD.Loadkey = @c_Loadkey
         AND PD.Status = '0'
         AND PD.WIP_RefNo = @c_SourceType
         AND LOC.LocationType <> 'PICK'
         AND PD.UOM = '7'
         --AND (O.Ecom_single_flag = 'M' OR (O.Ecom_single_flag = 'S' AND PD.UOM = '7') )
         --AND ((PD.UOM IN ('6','7') AND O.Ecom_single_flag = 'M') --multi conso/loose 
         --    OR (PD.UOM = '7' AND O.Ecom_single_flag = 'S')  --single loose
         --    OR (PD.UOM IN('6','7') AND ISNULL(O.Ecom_single_flag,'') = '')) --retail conso/loose 
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, 
                  O.Ecom_single_flag, SKU.Putawayzone
         ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Ecom_single_flag, @c_Putawayzone
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	 
 	  	    SET @c_Message03 = 'PICKLOC' 
 	  	    SET @c_Priority = '9'
 	  	    SET @c_PickMethod = 'PP'
   	  	  --SET @n_TotCtn = CEILING(@n_Qty / @n_CaseCnt)       	  	 
   	  	  SELECT @c_PutawayZone01 = '', @c_PutawayZone02 = '', @c_PutawayZone03 = '', @c_PutawayZone04 = '', @c_PutawayZone05 = ''

          SELECT TOP 1 @c_PutawayZone01 = PA.PutawayZone01, 
                       @c_PutawayZone02 = PA.PutawayZone02, 
          	           @c_PutawayZone03 = PA.PutawayZone03, 
          	           @c_PutawayZone04 = PA.PutawayZone04,
          	           @c_PutawayZone05 = PA.PutawayZone05 
          FROM CODELKUP CL (NOLOCK) 
          JOIN PUTAWAYSTRATEGYDETAIL PA (NOLOCK) ON CL.Code = PA.PutawayStrategyKey 
          WHERE CL.ListName = 'IKEAPA'
          AND PA.LocationTypeRestriction01 = 'PICK'
          AND CL.UDF01 = @c_Putawayzone 
          AND CL.Short = @c_Facility  	  	   
          ORDER BY CASE WHEN ISNULL(PA.PutawayZone01,'') <> '' THEN 1 ELSE 2 END

          IF (ISNULL(@c_PutawayZone01,'') + ISNULL(@c_PutawayZone02,'') + ISNULL(@c_PutawayZone03,'') + ISNULL(@c_PutawayZone04,'') + ISNULL(@c_PutawayZone05,'')) = ''
          BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83045  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Putawayzone not setup for Sku ''' + RTRIM(@c_Sku) + ''' at Facility ''' + RTRIM(@c_Facility) +'''. (ispRLBLP03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END 
          
      	  --additional condition to search pickdetail
      	  IF @c_Ecom_single_flag = 'M'
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.Ecom_single_flag = ''M'''
    	  	ELSE IF @c_Ecom_single_flag = 'S'     
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.Ecom_single_flag = ''S'''
    	  	ELSE
    	  	   SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ISNULL(ORDERS.Ecom_single_flag,'''') = '''''    	  	   
    	  	   
    	  	SELECT @c_ToLoc = ''
    	  	    	  	    	        	  	
    	  	IF EXISTS(SELECT 1  
    	  	          FROM LOTXLOCXID LLI (NOLOCK) 
    	  	          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
    	  	          WHERE LOC.LocationType = 'PICK'
    	  	          AND LOC.Facility = @c_Facility
                    AND LLI.Storerkey = @c_Storerkey
                    AND LLI.Sku = @c_Sku    	  	
                    AND (LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked > 0
                    AND LOC.Putawayzone <> ''
                    AND LOC.Putawayzone IS NOT NULL
                    AND LOC.Putawayzone IN(@c_PutawayZone01, @c_PutawayZone02, @c_PutawayZone03, @c_PutawayZone04, @c_PutawayZone05))
          BEGIN          	
             SET @c_Short_Priority = '2'          	
          END           
          ELSE
             SET @c_Short_Priority = '3'          	
          
          SELECT TOP 1 @c_ToLoc = LOC.Loc
    	  	FROM LOC (NOLOCK) 
        	JOIN CODELKUP CLK (NOLOCK) ON LOC.LocationGroup = CLK.Code AND CLK.ListName = 'IKEALOC' 
    	  	LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey AND LLI.Sku = @c_Sku    
    	  	WHERE LOC.LocationType = 'PICK'
    	  	AND LOC.Facility = @c_Facility
          AND LOC.Putawayzone <> ''
          AND LOC.Putawayzone IS NOT NULL
          AND LOC.Putawayzone IN (@c_PutawayZone01, @c_PutawayZone02, @c_PutawayZone03, @c_PutawayZone04, @c_PutawayZone05) 
          AND CLK.Short >= @c_Short_Priority             
          GROUP BY LOC.Loc, LOC.LogicalLocation, CLK.Short
          ORDER BY CLK.Short, CASE WHEN SUM(ISNULL((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked,0)) > 0 THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc

          --NJOW01        	  	    	  	              	         	  	 
          IF ISNULL(@c_ToLoc,'') = ''
          BEGIN
          	 SELECT top 1 @c_Toloc = UDF01
          	 FROM CODELKUP (NOLOCK)
          	 WHERE Listname = 'IKVLOC'
          	 AND Code = @c_Facility          	          	
          END

          IF ISNULL(@c_ToLoc,'') = ''
          BEGIN
          	 SET @c_ToLoc = 'NOLOC'
          END
              	  	    	  	              	         	  	 
      	  --WHILE @n_TotCtn > 0 AND @n_continue IN(1,2)       	  	
      	  --BEGIN
    	  	-- 	 IF @n_Qty >= @n_CaseCnt
      	  --	   SET @n_InsertQty = @n_CaseCnt
      	  --	 ELSE
      	  --	   SET @n_InsertQty = @n_Qty
      	  	         	  	         	  	 	         	  	 	         	  	 	     
      	  --	 SET @n_Qty = @n_Qty - @n_InsertQty
      	  IF @n_continue IN(1,2)	 
      	  BEGIN
      	     EXEC isp_InsertTaskDetail   
                @c_TaskType              = @c_TaskType             
               ,@c_Storerkey             = @c_Storerkey
               ,@c_Sku                   = @c_Sku
               ,@c_Lot                   = @c_Lot 
               ,@c_UOM                   = @c_UOM      
               ,@n_UOMQty                = 0     
               ,@n_Qty                   = @n_Qty     
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
               ,@c_LoadKey               = @c_Loadkey      
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
               ,@c_Message03             = @c_Message03
               ,@c_CallSource            = 'LOADPLAN'
               ,@c_RoundUpQty            = 'FC'     -- FC=Round up qty to full carton by packkey/ucc 
               ,@c_ReserveQtyReplen      = 'ROUNDUP' -- ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
               ,@c_ReservePendingMoveIn  = 'Y'    -- Y=Update @n_qty to @n_PendingMoveIn
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
               ,@c_SplitTaskByCase       = 'Y'
               ,@c_WIP_RefNo             = @c_SourceType
               ,@b_Success               = @b_Success OUTPUT
               ,@n_Err                   = @n_err OUTPUT 
               ,@c_ErrMsg                = @c_errmsg OUTPUT       	
            
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
      	  END	
      	     --SET @n_TotCtn = @n_TotCtn - 1
      	  --END       	  	
    
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Ecom_single_flag, @c_Putawayzone      	  
      END 
      CLOSE cur_pick  
      DEALLOCATE cur_pick                                                
   END        
      
   -----Update pickdetail_WIP work in progress staging table back to pickdetail                                             
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLBLP03)' + ' ( ' 
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLBLP03)' + ' ( ' 
	  	       END                                                                                                             
         END                                                                                                                
                                                                                                                            
      	  FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno             
      END                                                                                                                   
      CLOSE cur_PickDetailKey                                                                                               
      DEALLOCATE cur_PickDetailKey                                                                                                                                                                                                                      
   END                                    
   
    -----Generate Pickslip No------
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
    	 IF EXISTS(SELECT 1 
    	           FROM LOADPLANDETAIL LD (NOLOCK) 
    	           JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
    	           AND O.ECOM_SINGLE_FLAG='S'
    	           AND LD.Loadkey = @c_Loadkey)
    	 BEGIN          
          EXEC isp_CreatePickSlip
               @c_Loadkey = @c_Loadkey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'Y'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT
       END
       ELSE
       BEGIN
          EXEC isp_CreatePickSlip
               @c_Loadkey = @c_Loadkey
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'N'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT
       END
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END                                                                                    
                                                                                                                          
   RETURN_SP:  
   
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LoadPlan Table Failed. (ispRLBLP03)' + ' ( ' 
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