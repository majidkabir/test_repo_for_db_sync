SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Stored Procedure: isp_CreatePickdetail_WIP                             */
/* Creation Date: 23-Jul-2018                                             */
/* Copyright: LFL                                                         */
/* Written by: NJOW                                                       */
/*                                                                        */
/* Purpose: Create pickdetail_wip from pickdetail.                        */   
/*          Use as staging table for pickdetail updating mainly for       */ 
/*          release task process.                                         */
/*                                                                        */
/* Called By: Release Task Stored Proc                                    */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 7.0                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */  
/* 04/10/2018   NJOW01   1.0  cater for #pickdetail_wip temp table        */
/* 08/10/2019   NJOW02   1.1  update pickdetail include notes,dropid      */
/*                            caseid and pickmethod field                 */
/* 15/08/2019   NJOW03   1.2  WMS-9825 add moverefkey, replenishzone      */
/* 13/02/2020   NJOW04   1.3  WMS-11399 add option 'T' for enable trigger */
/*                            when insert/update pickdetail. Add toloc,   */
/*                            CartonGroup, CartonType, Channel_ID,        */
/*                            DoReplenish                                 */
/* 07/07/2023   NJOW05   1.4  WMS-23043 add uom, orderkey, orderlinenumber*/
/* 07/07/2023   NJOW05   1.4  DEVOPS Combine Script                       */
/**************************************************************************/
CREATE PROC [dbo].[isp_CreatePickdetail_WIP]
    @c_Loadkey               NVARCHAR(10)   = ''
   ,@c_Wavekey               NVARCHAR(10)   = ''  
   ,@c_WIP_RefNo             NVARCHAR(30)   = ''
   ,@c_PickCondition_SQL     NVARCHAR(4000) = ''     --Additional condition to filter pickdetail records
   ,@c_Action                NVARCHAR(5)    = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
   ,@c_RemoveTaskdetailkey   NVARCHAR(5)    = 'Y'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
   ,@b_Success               INT            OUTPUT
   ,@n_Err                   INT            OUTPUT 
   ,@c_ErrMsg                NVARCHAR(250)  OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT,
           @n_Cnt                INT,
           @n_StartTCnt          INT,          
           @c_SQL                NVARCHAR(4000),
           @c_CallSource         NVARCHAR(30),
           @c_PickDetailKey      NVARCHAR(10), 
           @n_Qty                INT, 
           @n_UOMQty             INT, 
           @c_TaskDetailkey      NVARCHAR(10), 
           @c_PickslipNo         NVARCHAR(10),
           @c_PickTableName      NVARCHAR(20),
           @c_Notes              NVARCHAR(MAX),
           @c_CaseId             NVARCHAR(20),
           @c_DropId             NVARCHAR(20),
           @c_PickMethod         NVARCHAR(1),
           @c_MoveRefKey         NVARCHAR(10), --NJOW03
           @c_ReplenishZone      NVARCHAR(10), --NJOW03
           @c_ToLoc              NVARCHAR(10), --NJOW04
           @c_CartonGroup        NVARCHAR(10), --NJOW04
           @c_CartonType         NVARCHAR(10), --NJOW04
           @n_Channel_ID         BIGINT,       --NJOW04
           @c_DoReplenish        NCHAR(1),     --NJOW04
           @c_OptimizeCop        NCHAR(1),     --NJOW04
           @c_TrafficCop         NCHAR(1),     --NJOW04
           @c_IncludeChannel_ID  NCHAR(1),     --NJOW04
           @c_Loc                NVARCHAR(10), --NJOW04
           @c_ID                 NVARCHAR(18),  --NJOW04
           @c_Lot                NVARCHAR(10),   --NJOW04         
           @c_Storerkey          NVARCHAR(15),   --NJOW04
           @c_Sku                NVARCHAR(20),   --NJOW04
           @c_Orderkey           NVARCHAR(10),   --NJOW05
           @c_OrderLineNumber    NVARCHAR(5),    --NJOW05
           @c_UOM                NVARCHAR(10)    --NJOW05
                                                                                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @c_IncludeChannel_ID = 'Y'
	 
	 IF ISNULL(@c_Wavekey,'') <> ''
	    SET @c_Callsource = 'WAVE'

   IF ISNULL(@c_Loadkey,'') <> ''
	    SET @c_Callsource = 'LOADPLAN'
	    
   IF ISNULL(LTRIM(@c_PickCondition_SQL), '') <> '' AND LEFT(@c_PickCondition_SQL, 4) <> 'AND '
      SET @c_PickCondition_SQL  = 'AND ' + RTRIM(LTRIM(@c_PickCondition_SQL))
      
   SET @c_PickTableName = 'PICKDETAIL_WIP'
      
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      SET @c_PickTableName = '#PICKDETAIL_WIP'
         
   --NJOW04
   IF @c_PickTableName = '#PICKDETAIL_WIP'
   BEGIN
   	  IF NOT EXISTS (SELECT 1
                     FROM tempdb.dbo.syscolumns
                     JOIN tempdb.dbo.sysobjects ON (tempdb.dbo.sysobjects.id = tempdb.dbo.syscolumns.id)
                     AND tempdb.dbo.sysobjects.type = 'U'
                     AND tempdb.dbo.sysobjects.id = OBJECT_ID('tempdb..#PICKDETAIL_WIP') 
                     AND tempdb.dbo.syscolumns.name = 'Channel_ID')
         SET @c_IncludeChannel_ID = 'N'       	  
   END
   ELSE
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM syscolumns
                     JOIN sysobjects ON (sysobjects.id = syscolumns.id)
                     AND sysobjects.type = 'U'
                     AND sysobjects.name = 'PICKDETAIL_WIP' 
                     AND syscolumns.name = 'Channel_ID')    
         SET @c_IncludeChannel_ID = 'N'       	     	
   END
	 
	 --WIP Initialization. Create Pickdetail_WIP record from pickdetial and remove taskdetailkey
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Action = 'I'
   BEGIN
      --Delete WIP records if exists and make sure it is clear
      SET @c_SQL = N'DELETE PICKDETAIL
                     FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK) 
                     JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                     JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                     JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                     JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                   ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + 
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                     RTRIM(ISNULL(@c_PickCondition_SQL,''))
      
      EXEC sp_executesql @c_SQL,
           N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
           @c_Loadkey,
           @c_Wavekey,
           @c_WIP_RefNo
   
      SET @n_cnt = 0
      SET @c_SQL = N'SELECT @n_cnt = COUNT(1) FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK)
                     JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                     JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                     JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                     JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                   ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + 
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                     RTRIM(ISNULL(@c_PickCondition_SQL,''))

      EXEC sp_executesql @c_SQL,
           N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30), @n_Cnt INT OUTPUT', 
           @c_Loadkey,
           @c_Wavekey,
           @c_WIP_RefNo,
           @n_Cnt OUTPUT  
                     
      IF @n_Cnt > 0 
      BEGIN
         SET @c_SQL = N'DELETE PICKDETAIL
                        FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK) 
                        JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                        JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                        JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                        JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                        CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                        CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                      ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + 
                        CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                        CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                        RTRIM(ISNULL(@c_PickCondition_SQL,''))

         EXEC sp_executesql @c_SQL,
              N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
              @c_Loadkey,
              @c_Wavekey,
              @c_WIP_RefNo
      END 
      
      SET @c_SQL = N'INSERT INTO ' + RTRIM(@c_PickTableName) + '
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
                     	Notes,      	      MoveRefKey,			 WIP_Refno ' +
                      CASE WHEN @c_IncludeChannel_ID = 'Y' THEN  ',Channel_ID ' ELSE ' ' END +  --NJOW04
                    ' )
                      SELECT PICKDETAIL.PickDetailKey, PICKDETAIL.CaseID,   				PICKDETAIL.PickHeaderKey, 
                     	PICKDETAIL.OrderKey,         		 PICKDETAIL.OrderLineNumber,  PICKDETAIL.Lot,
                     	PICKDETAIL.Storerkey,        		 PICKDETAIL.Sku,      	      PICKDETAIL.AltSku,        PICKDETAIL.UOM,
                     	PICKDETAIL.UOMQty,      	   		 PICKDETAIL.Qty,      	      PICKDETAIL.QtyMoved,      PICKDETAIL.[Status],
                     	PICKDETAIL.DropID,      	   		 PICKDETAIL.Loc,      	      PICKDETAIL.ID,      	    PICKDETAIL.PackKey,
                     	PICKDETAIL.UpdateSource,     		 PICKDETAIL.CartonGroup,      PICKDETAIL.CartonType,
                     	PICKDETAIL.ToLoc,      	     		 PICKDETAIL.DoReplenish,      PICKDETAIL.ReplenishZone,
                     	PICKDETAIL.DoCartonize,      		 PICKDETAIL.PickMethod,       @c_Wavekey,
                     	PICKDETAIL.EffectiveDate,    		 PICKDETAIL.AddDate,      	  PICKDETAIL.AddWho,
                     	PICKDETAIL.EditDate,         		 PICKDETAIL.EditWho,      	  PICKDETAIL.TrafficCop,
                     	PICKDETAIL.ArchiveCop,       		 PICKDETAIL.OptimizeCop,      PICKDETAIL.ShipFlag,
                     	PICKDETAIL.PickSlipNo,       		 PICKDETAIL.TaskDetailKey,    PICKDETAIL.TaskManagerReasonKey,
                     	PICKDETAIL.Notes,      	     		 PICKDETAIL.MoveRefKey,				@c_WIP_RefNo ' +
                      CASE WHEN @c_IncludeChannel_ID = 'Y' THEN ',PICKDETAIL.Channel_ID ' ELSE ' ' END +  --NJOW04
                    ' FROM PICKDETAIL (NOLOCK) 
                      JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                      JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                      JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                      CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                      CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                    ' WHERE 1=1 ' +
                      CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                      CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                      RTRIM(ISNULL(@c_PickCondition_SQL,''))                     	
                     
      EXEC sp_executesql @c_SQL,
           N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
           @c_Loadkey,
           @c_Wavekey,
           @c_WIP_RefNo
                                                               
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81010     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END      
      
      --Remove taskdetailkey 
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_RemoveTaskdetailkey = 'Y'
      BEGIN
         SET @c_SQL = N'UPDATE PICKDETAIL WITH (ROWLOCK)          
                        SET PICKDETAIL.TaskdetailKey = '''',        
                            PICKDETAIL.TrafficCop = NULL          
                       FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL  
                       JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                       JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                       JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                       JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                       CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                       CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                     ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' +
                       CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                       CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                       RTRIM(ISNULL(@c_PickCondition_SQL,''))                     	

         EXEC sp_executesql @c_SQL,
              N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
              @c_Loadkey,
              @c_Wavekey,
              @c_WIP_RefNo
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
      END      
   END

   --WIP Update. Update Pickdetial_WIP back to pickdetial table
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Action = 'U'
   BEGIN
       SET @c_SQL = N' DECLARE cur_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR
                       SELECT PICKDETAIL.PickDetailKey, PICKDETAIL.Qty, PICKDETAIL.UOMQty, 
                              PICKDETAIL.TaskDetailKey, PICKDETAIL.Pickslipno, PICKDETAIL.Notes,
                              PICKDETAIL.DropId, PICKDETAIL.CaseID, PICKDETAIL.PickMethod, PICKDETAIL.MoveRefKey,
                              PICKDETAIL.ReplenishZone, 
                              PICKDETAIL.ToLoc, PICKDETAIL.CartonGroup, PICKDETAIL.CartonType, ' +
                              CASE WHEN @c_IncludeChannel_ID = 'Y' THEN 'PICKDETAIL.Channel_ID, ' ELSE ' 0, ' END + --NJOW04
                            ' PICKDETAIL.DoReplenish,
                              PICKDETAIL.Trafficcop, PICKDETAIL.OptimizeCop, 
                              PICKDETAIL.Loc, PICKDETAIL.ID, PICKDETAIL.Lot, PICKDETAIL.Storerkey, PICKDETAIL.Sku,
                              PICKDETAIL.UOM, PICKDETAIL.Orderkey, PICKDETAIL.OrderLineNumber
                       FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL  
                       JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                       JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                       JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                       JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                       CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                       CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                     ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' +
                       CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                       CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                       RTRIM(ISNULL(@c_PickCondition_SQL,'')) +
                     ' ORDER BY PICKDETAIL.Pickdetailkey'                      	

       EXEC sp_executesql @c_SQL,
            N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
            @c_Loadkey,
            @c_Wavekey,
            @c_WIP_RefNo
                              
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo, @c_Notes, @c_DropID, @c_CaseId, @c_PickMethod, @c_MoveRefKey, @c_ReplenishZone,
                                         @c_ToLoc, @c_CartonGroup, @c_CartonType, @n_Channel_ID, @c_DoReplenish, @c_Trafficcop, @c_OptimizeCop, @c_Loc, @c_ID, @c_Lot, @c_Storerkey, @c_Sku , --NJOW04
                                         @c_UOM, @c_Orderkey, @c_OrderLineNumber  --NJOW05
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
          	 IF @c_Trafficcop = 'T'
          	 BEGIN          	 	
          	 	  --Enable trigger
          	 	  
          	 	  IF NOT EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE Lot = @c_Lot AND Loc = @c_Loc AND ID = @c_Id)
          	 	  BEGIN
          	 	  	 INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, ID, Qty)
          	 	  	 VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, 0)

                   SELECT @n_err = @@ERROR
                   
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3  
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert LOTXLOCXID Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
   		             END   		          	 	  	 
          	 	  END

          	 	  IF NOT EXISTS (SELECT 1 FROM SKUXLOC (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND Loc = @c_Loc)
          	 	  BEGIN
          	 	  	 INSERT INTO SKUXLOC (Storerkey, Sku, Loc, Qty)
          	 	  	 VALUES (@c_Storerkey, @c_Sku, @c_Loc, 0)

                   SELECT @n_err = @@ERROR
                   
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3  
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81027   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert SKUXLOC Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
   		             END   		          	 	  	 
          	 	  END
          	 	  
          	    UPDATE PICKDETAIL WITH (ROWLOCK) 
          	    SET Qty = @n_Qty, 
          	        UOMQty = @n_UOMQty, 
          	        TaskDetailKey = @c_TaskDetailKey,
          	        PickslipNo = @c_Pickslipno,
          	        WaveKey = CASE WHEN @c_CallSource = 'WAVE' THEN @c_Wavekey ELSE '' END,
          	        Notes = @c_Notes, --NJOW02
          	        DropId = @c_DropID, --NJOW02
          	        CaseId = @c_CaseID, --NJOW02
          	        PickMethod = @c_PickMethod, --NJOW02
          	        MoveRefKey = @c_MoveRefKey, --NJOW03
          	        ReplenishZone = @c_ReplenishZone, --NJOW03
          	        Toloc = @c_ToLoc, --NJOW04
                    CartonGroup = @c_CartonGroup, --NJOW04
                    CartonType = @c_CartonType,  --NJOW04
                    Channel_ID = CASE WHEN @c_IncludeChannel_ID = 'Y' THEN @n_Channel_ID ELSE Channel_ID END,  --NJOW04
                    DoReplenish = @c_DoReplenish,  --NJOW04
                    LOC = @c_Loc, --NJOW04  Only for @c_Trafficcop = 'T'
                    ID = @c_ID, --NJOW04  Only for @c_Trafficcop = 'T'
          	        UOM = @c_UOM,  --NJOW05
          	        Orderkey = @c_Orderkey,  --NJOW05
          	        OrderLineNumber = @c_OrderLineNumber, --NJOW05
          	        EditDate = GETDATE(),
          	        EditWho = SUSER_SNAME()
          	    WHERE PickDetailKey = @c_PickDetailKey  
          	 END
          	 ELSE
          	 BEGIN
          	 	  --default disable trigger trafficcop = NULL
                UPDATE PICKDETAIL WITH (ROWLOCK)           	              	 	  
                SET Qty = @n_Qty, 
          	        UOMQty = @n_UOMQty, 
          	        TaskDetailKey = @c_TaskDetailKey,
          	        PickslipNo = @c_Pickslipno,
          	        WaveKey = CASE WHEN @c_CallSource = 'WAVE' THEN @c_Wavekey ELSE '' END,
          	        Notes = @c_Notes, --NJOW02
          	        DropId = @c_DropID, --NJOW02
          	        CaseId = @c_CaseID, --NJOW02
          	        PickMethod = @c_PickMethod, --NJOW02
          	        MoveRefKey = @c_MoveRefKey, --NJOW03
          	        ReplenishZone = @c_ReplenishZone, --NJOW03
          	        Toloc = @c_ToLoc, --NJOW04
                    CartonGroup = @c_CartonGroup, --NJOW04
                    CartonType = @c_CartonType,  --NJOW04
                    Channel_ID = CASE WHEN @c_IncludeChannel_ID = 'Y' THEN @n_Channel_ID ELSE Channel_ID END,  --NJOW04
                    DoReplenish = @c_DoReplenish,  --NJOW04
          	        UOM = @c_UOM,  --NJOW05
          	        Orderkey = @c_Orderkey,  --NJOW05
          	        OrderLineNumber = @c_OrderLineNumber, --NJOW05                    
          	        EditDate = GETDATE(),  
          	        EditWho = SUSER_SNAME(),          	           	       
          	        TrafficCop = NULL
                WHERE PickDetailKey = @c_PickDetailKey  
          	 END
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
   		       END   		
          END
          ELSE 
          BEGIN        
             --NJOW01
             SET @c_SQL = N' 	
                INSERT INTO PICKDETAIL 
                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                      Taskdetailkey, TaskManagerReasonkey, Notes, MoveRefKey, Channel_ID)
                SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                    WaveKey, EffectiveDate, ' + CASE WHEN @c_OptimizeCop = 'T' THEN 'NULL' ELSE '''9''' END + ', ShipFlag, PickSlipNo, 
                      Taskdetailkey, TaskManagerReasonkey, Notes, MoveRefkey, ' +
                      CASE WHEN @c_IncludeChannel_ID = 'Y' THEN 'Channel_ID ' ELSE '0 ' END +   --NJOW04                   
              ' FROM ' + RTRIM(@c_PickTableName) + ' WITH (NOLOCK)
                WHERE PickDetailKey = @c_PickDetailKey' 

                EXEC sp_executesql @c_SQL,
                     N'@c_Pickdetailkey NVARCHAR(10)', 
                     @c_pickdetailkey
                   
                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
   		          END         
          END
       
       	  FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno, @c_Notes, @c_DropID, @c_CaseId, @c_PickMethod, @c_MoveRefKey, @c_ReplenishZone,
                                            @c_ToLoc, @c_CartonGroup, @c_CartonType, @n_Channel_ID, @c_DoReplenish, @c_Trafficcop, @c_OptimizeCop, @c_Loc, @c_ID, @c_Lot, @c_Storerkey, @c_Sku,  --NJOW04
                                            @c_UOM, @c_Orderkey, @c_OrderLineNumber  --NJOW05
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey                   
   END

   --Delete WIP records 
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Action = 'D'
   BEGIN
      SET @c_SQL = N'DELETE PICKDETAIL
                     FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK) 
                     JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                     JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc    
                     JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                     JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku ' +
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey ' END +
                   ' WHERE PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + 
                     CASE WHEN @c_Callsource = 'WAVE' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' END +
                     CASE WHEN @c_Callsource = 'LOADPLAN' THEN ' AND LOADPLANDETAIL.Loadkey = @c_Loadkey ' END +
                     RTRIM(ISNULL(@c_PickCondition_SQL,''))
      
      EXEC sp_executesql @c_SQL,
           N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
           @c_Loadkey,
           @c_Wavekey,
           @c_WIP_RefNo      

      SELECT @n_err = @@ERROR
       
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickdetail_WIP Table Failed. (ispRLWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END            
   END
                         
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_CreatePickdetail_WIP'		
	    RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END  

GO