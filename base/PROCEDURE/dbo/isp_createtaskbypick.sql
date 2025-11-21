SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CreateTaskByPick                               */
/* Creation Date: 13-Jul-2018                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Create Task by pickdetail                                   */   
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 12/10/2018   NJOW01   1.0  Fix error message not correct             */
/* 04/10/2018   NJOW02   1.1  cater for #pickdetail_wip temp table      */
/* 27/10/2019   NJOW03   1.2  support split task by order/Load, allow   */
/*                            task ignore lot no and add taskuom        */
/* 03/06/2019   NJOW04   1.3  WMS-9196 Merge task allow set priority    */
/* 22/04/2020   WLChooi  1.4  Fix table linkage (WL01)                  */
/************************************************************************/

CREATE PROC [dbo].[isp_CreateTaskByPick]   
    @c_TaskType              NVARCHAR(10)   = ''
   --,@c_PresetCode            NVARCHAR(1000)   = ''    --Preset code to auto configure the parameters and filtering.    
   --                                                   --FULLCASE_BULKTOPACK, CONSOCASE_BULKTOPACK, PIECE_BULKTOPICK, PIECE_PICKTOPACK
   ,@c_Loadkey               NVARCHAR(10)   = ''
   ,@c_Wavekey               NVARCHAR(10)   = ''  
   ,@c_ToLoc                 NVARCHAR(10)   = ''    
   ,@c_ToLoc_Strategy        NVARCHAR(30)   = ''     -- preset strategy or custom stored proc to get putaway location. will overwrite @c_Toloc
                                                     -- PICK=Auto get the pick location of the sku.
   ,@c_ToLoc_StrategyParam   NVARCHAR(4000) = ''     -- addition parameter for c_ToLoc_Strategy
   ,@c_PickMethod            NVARCHAR(10)   = ''     -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
   ,@c_Priority              NVARCHAR(10)   = ''      
   ,@c_SourcePriority        NVARCHAR(10)   = '9'      
   ,@c_Message01             NVARCHAR(20)   = ''       
   ,@c_Message02             NVARCHAR(20)   = ''       
   ,@c_Message03             NVARCHAR(20)   = ''       
   ,@c_SourceType            NVARCHAR(30)   = 'isp_CreateTaskByPick'      
   ,@c_SourceKey             NVARCHAR(30)   = ''         
   ,@c_CallSource            NVARCHAR(20)   = 'WAVE' -- WAVE / LOADPLAN 
   ,@c_PickCondition_SQL     NVARCHAR(4000)   = ''   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
   ,@c_LinkTaskToPick        NVARCHAR(5)    = 'N'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
   ,@c_LinkTaskToPick_SQL    NVARCHAR(4000) = ''     -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
   ,@c_WIP_RefNo             NVARCHAR(30)   = ''     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
   ,@c_RoundUpQty            NVARCHAR(5)    = ''     -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
   ,@c_ReserveQtyReplen      NVARCHAR(10)   = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
   ,@c_ReservePendingMoveIn  NVARCHAR(5)    = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn
   ,@c_CombineTasks          NVARCHAR(5)    = 'N'    -- N=No combine Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                                                     -- Combine qty is depend on whether the first task extra qty (qty-systemqty) is sufficient for subsequence tasks of different load/wave. Will increase task qty if insufficient.
                                                     -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                                                     -- M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
   ,@c_CasecntbyLocUCC       NVARCHAR(5)    = 'N'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
   ,@c_SplitTaskByCase       NVARCHAR(5)    = 'N'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
   ,@c_ZeroSystemQty         NVARCHAR(5)    = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
   ,@c_SplitTaskByOrder      NVARCHAR(5)    = 'N'    -- N=No slip by order Y=Split TASK by Order. 
   ,@c_SplitTaskByLoad       NVARCHAR(5)    = 'N'    -- N=No slip by load Y=Split TASK by load. Usually applicaple when create task by wave.
   ,@c_TaskIgnoreLot         NVARCHAR(5)    = 'N'    -- N=Task with lot  Y=Task ignore lot        
   ,@c_TaskUOM               NVARCHAR(10)   = ''     -- Fix UOM value for task    
   ,@c_MergedTaskPriority    NVARCHAR(10)   = '2'    -- Set the priority of merged task based on @c_combineTasks setting.  --NJOW04   
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
           @c_Storerkey          NVARCHAR(15), 
           @c_Sku                NVARCHAR(20), 
           @c_Lot                NVARCHAR(10), 
           @c_FromLoc            NVARCHAR(10), 
           @c_ID                 NVARCHAR(18), 
           @n_Qty                INT, 
           @c_UOM                NVARCHAR(10),
           @c_PickTableName      NVARCHAR(20),
           @c_ToLocStgIsSP       NVARCHAR(5),
           @n_QtyRemain          INT,
           @n_TaskQTy            INT,
           @c_Facility           NVARCHAR(5),
           @c_Orderkey           NVARCHAR(10)
                                                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @c_ToLocStgIsSP = 'N'
	 
	 IF ISNULL(@c_ToLoc_Strategy,'') <> ''
	 BEGIN	 
	 	  IF @c_ToLoc_Strategy NOT IN('PICK')
	 	  BEGIN
         IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_ToLoc_Strategy AND TYPE = 'P')
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82100   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid toloc strategy stored proc ''' + RTRIM(@c_ToLoc_Strategy)+ ''' (isp_CreateTaskByPick)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
         END    
         ELSE
            SET @c_ToLocStgIsSP = 'Y'
      END   
   END
   
   IF ISNULL(@c_Wavekey,'') = '' AND ISNULL(@c_Loadkey,'') <> '' AND @c_CallSource = 'WAVE'
      SET @c_CallSource = 'LOADPLAN'
   	 
   IF @n_continue IN(1,2)
   BEGIN
      IF @c_LinkTaskToPick = 'WIP' OR ISNULL(@c_WIP_RefNo,'') <> ''
         IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL  --NJOW02
  	        SET @c_PickTableName = '#PICKDETAIL_WIP'
  	     ELSE   
            SET @c_PickTableName = 'PICKDETAIL_WIP'	    
	    ELSE
	       SET @c_PickTableName = 'PICKDETAIL'
	   
	    /*    
	    IF CHARINDEX('FULLCASE_BULKTOPACK', @c_PresetCode) > 0
	    BEGIN
	       SET @c_PickCondition_SQL = RTRIM(ISNULL(@c_PickCondition_SQL,'')) + ' AND PICKDETAIL.UOM = ''2'' AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'',''DYNPICKP'')'
	       SET @c_LinkTaskToPick = 'Y'
         SET @c_LinkTaskToPick_SQL = ' AND PICKDETAIL.UOM = @c_UOM'         
         SET @c_PickMethod = '?'     
	    END

	    IF CHARINDEX('CONSOCASE_BULKTOPACK', @c_PresetCode) > 0
	    BEGIN
	       SET @c_PickCondition_SQL = RTRIM(ISNULL(@c_PickCondition_SQL,'')) + ' AND PICKDETAIL.UOM IN(''2'',''6'') AND PICKDETAIL.Pickmethod = ''C'' AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'',''DYNPICKP'')'
	       SET @c_LinkTaskToPick = 'Y'
         SET @c_LinkTaskToPick_SQL = ' AND PICKDETAIL.UOM = @c_UOM'         
         SET @c_PickMethod = '?'     
	    END

	    IF CHARINDEX('PIECE_BULKTOPICK', @c_PresetCode) > 0
	    BEGIN
	       SET @c_PickCondition_SQL = RTRIM(ISNULL(@c_PickCondition_SQL,'')) + ' AND PICKDETAIL.UOM IN(''6'',''7'') AND PICKDETAIL.Pickmethod <> ''C'' AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'',''DYNPICKP'')'
	       SET @c_LinkTaskToPick = 'Y'
         SET @c_LinkTaskToPick_SQL = ' AND PICKDETAIL.UOM = @c_UOM'         
         SET @c_ReserveQtyReplen = 'ROUNDUP'
         SET @c_ReservePendingMoveIn = 'Y'
         SET @c_PickMethod = '?ROUNDUP'     

         IF ISNULL(@c_RoundUpQty,'') = ''
            SET @c_RoundUpQty = 'FC'
	    END
	       
	    IF CHARINDEX('PIECE_PICKTOPACK', @c_PresetCode) > 0
	    BEGIN
	       SET @c_PickCondition_SQL = RTRIM(ISNULL(@c_PickCondition_SQL,'')) + ' AND PICKDETAIL.UOM IN(''6'',''7'')  AND (SKUXLOC.LocationType IN(''PICK'',''CASE'') OR LOC.LocationType IN(''PICK'',''DYNPPICK'',''DYNPICKP''))'
	       SET @c_LinkTaskToPick = 'Y'
         SET @c_LinkTaskToPick_SQL = ' AND PICKDETAIL.UOM = @c_UOM'         
	    END
	    */
	       	      
      SET @c_SQL = N'DECLARE CUR_Pickrec CURSOR FAST_FORWARD READ_ONLY FOR                                                                 
                     SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, ' + 
                            CASE WHEN @c_TaskIgnoreLot = 'Y' THEN ' '''' ' ELSE 'PICKDETAIL.Lot' END +
                          ' ,PICKDETAIL.Loc, PICKDETAIL.ID, SUM(PICKDETAIL.Qty) AS Qty, PICKDETAIL.UOM, ORDERS.Facility, ' +
                            CASE WHEN @c_SplitTaskByOrder = 'Y' THEN 'ORDERS.Orderkey,' ELSE ' '''', ' END +
                            CASE WHEN @c_SplitTaskByLoad = 'Y' THEN 'ORDERS.Loadkey' ELSE ' @c_Loadkey ' END +
                   ' FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK) 
                     JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey                                                                   
                     JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
                     JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc                                                                                 
                     JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku                                                
                     JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc                       
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +                                                                      
                     CASE WHEN @c_CallSource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +
                     CASE WHEN @c_CallSource = 'WAVE' THEN ' JOIN WAVE (NOLOCK) ON WAVEDETAIL.Wavekey = WAVE.Wavekey ' ELSE ' ' END +
                     CASE WHEN @c_CallSource = 'LOADPLAN' THEN ' JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey ' ELSE ' ' END +        
                     CASE WHEN @c_CallSource = 'LOADPLAN' THEN ' JOIN LOADPLAN (NOLOCK) ON LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey ' ELSE ' ' END +   --WL01
                   ' WHERE PICKDETAIL.Status = ''0'' ' + 
                     CASE WHEN @c_LinkTaskToPick = 'WIP' OR ISNULL(@c_WIP_RefNo,'') <> '' THEN                                                                                               
                          ' AND PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' 
                     ELSE ' ' END  +                                                                                     
                     CASE WHEN @c_CallSource = 'WAVE' THEN ' AND WAVE.Wavekey = @c_Wavekey ' ELSE ' ' END +
                     CASE WHEN @c_CallSource = 'LOADPLAN' THEN ' AND LOADPLAN.Loadkey = @c_Loadkey ' ELSE ' ' END +
                     RTRIM(ISNULL(@c_PickCondition_SQL,'')) +
                   ' GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku' + 
                              CASE WHEN @c_TaskIgnoreLot = 'Y' THEN '' ELSE ',PICKDETAIL.Lot' END +
                             ', PICKDETAIL.Loc, PICKDETAIL.ID, PICKDETAIL.UOM, LOC.LogicalLocation, ORDERS.Facility ' +
                              CASE WHEN @c_SplitTaskByOrder = 'Y' THEN ',ORDERS.Orderkey' ELSE '' END +
                              CASE WHEN @c_SplitTaskByLoad = 'Y' THEN ',ORDERS.Loadkey' ELSE '' END +
                   ' ORDER BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, LOC.LogicalLocation, PICKDETAIL.Loc' +
                     CASE WHEN @c_TaskIgnoreLot = 'Y' THEN '' ELSE ',PICKDETAIL.Lot' END 
      
      EXEC sp_executesql @c_SQL,
           N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
           @c_Loadkey,
           @c_Wavekey,
           @c_WIP_RefNo 

      OPEN CUR_Pickrec  
      
      FETCH NEXT FROM CUR_Pickrec INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_Facility, @c_Orderkey, @C_Loadkey
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	       	         	  	          
      	 IF ISNULL(@c_TaskUOM,'') <> ''           
      	    SET @c_UOM = @c_TaskUOM
      	    
      	 IF @c_ToLocStgIsSP = 'Y' --Toloc strategy by stored procedure
      	 BEGIN
      	    SET @c_ToLoc = '' 
      	    SET @n_QtyRemain = @n_Qty
      	    
      	    WHILE @n_QtyRemain > 0 AND @n_continue IN(1,2)  --split the qty by toloc based on locate limit if set
      	    BEGIN
      	    	 SET @n_TaskQty = @n_QtyRemain
      	    	 
               SET @c_SQL = N'                                                         
                  EXECUTE ' + @c_ToLoc_Strategy + CHAR(13) +                        
                  '  @c_Loadkey = @c_Loadkey_P ' + CHAR(13) +                       
                  ', @c_WaveKey = @c_Wavekey_P ' + CHAR(13) +                       
                  ', @c_Orderkey = @c_Orderkey_P ' + CHAR(13) +                       
                  ', @c_Storerkey = @c_StorerKey_P '  + CHAR(13) +                       
                  ', @c_Sku = @c_Sku_P '  + CHAR(13) +                       
                  ', @c_Lot = @c_Lot_P '  + CHAR(13) +                       
                  ', @c_Loc = @c_FromLoc_P '  + CHAR(13) +                       
                  ', @c_ID = @c_ID_P '  + CHAR(13) +                       
                  ', @c_UOM = @c_UOM_P '  + CHAR(13) +                              
                  ', @n_Qty = @n_Qty_P '  + CHAR(13) +                         
                  ', @c_ToLoc_StrategyParam = @c_ToLoc_StrategyParam_P ' + CHAR(13) +               
                  ', @c_ToLoc     = @c_ToLoc_P       OUTPUT ' + CHAR(13) +               
                  ', @n_QtyRemain = @n_QtyRemain_P   OUTPUT ' + CHAR(13) +                 
                  ', @b_Success   = @b_Success_P     OUTPUT ' + CHAR(13) +               
                  ', @n_Err       = @n_Err_P         OUTPUT ' + CHAR(13) +               
                  ', @c_ErrMsg    = @c_ErrMsg_P      OUTPUT '                            
               
               EXEC sp_executesql @c_SQL,
                   N'@c_Loadkey_P NVARCHAR(10), @c_Wavekey_P NVARCHAR(10), @c_Orderkey_P NVARCHAR(10), @c_Storerkey_P NVARCHAR(15), @c_Sku_P NVARCHAR(20), @c_Lot_P NVARCHAR(10), 
                     @c_FromLoc_P NVARCHAR(10), @c_ID_P NVARCHAR(18), @c_UOM_P NVARCHAR(10), @n_Qty_P INT, @c_ToLoc_StrategyParam_P NVARCHAR(4000), 
                     @c_ToLoc_P NVARCHAR(10) OUTPUT, @n_QtyRemain_P INT OUTPUT, @b_Success_P INT OUTPUT, @n_Err_P INT OUTPUT, @c_ErrMsg_P NVARCHAR(255) OUTPUT', 
                   @c_Loadkey,
                   @c_Wavekey,
                   @c_Orderkey,
                   @c_Storerkey,
                   @c_Sku,
                   @c_Lot,
                   @c_FromLoc,
                   @c_ID,
                   @c_UOM,
                   @n_Qty,
                   @c_ToLoc_StrategyParam,
                   @c_ToLoc OUTPUT,
                   @n_QtyRemain OUTPUT,
                   @b_Success OUTPUT,
                   @n_Err OUTPUT,
                   @c_ErrMsg OUTPUT
                                                                                    
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END      	  		          	 	
               ELSE
               BEGIN
               	  SET @n_TaskQty = @n_TaskQty - @n_QtyRemain

                  EXEC isp_InsertTaskDetail   
                     @c_TaskType              = @c_TaskType             
                    ,@c_Storerkey             = @c_Storerkey
                    ,@c_Sku                   = @c_Sku
                    ,@c_Lot                   = @c_Lot 
                    ,@c_UOM                   = @c_UOM      
                    ,@n_UOMQty                = 0     
                    ,@n_Qty                   = @n_TaskQty     
                    ,@c_FromLoc               = @c_Fromloc      
                    ,@c_LogicalFromLoc        = @c_FromLoc 
                    ,@c_FromID                = @c_ID     
                    ,@c_ToLoc                 = @c_ToLoc       
                    ,@c_LogicalToLoc          = @c_ToLoc 
                    ,@c_ToID                  = @c_ID       
                    ,@c_PickMethod            = @c_PickMethod
                    ,@c_Priority              = @c_Priority     
                    ,@c_SourcePriority        = @c_SourcePriority      
                    ,@c_SourceType            = @c_SourceType      
                    ,@c_SourceKey             = @c_SourceKey      
                    ,@c_LoadKey               = @c_Loadkey      
                    ,@c_Wavekey               = @c_Wavekey
                    ,@c_Orderkey              = @c_Orderkey
                    ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                    ,@c_Message01             = @c_Message01
                    ,@c_Message02             = @c_Message02
                    ,@c_Message03             = @c_Message03
                    ,@c_CallSource            = @c_CallSource
                    ,@c_ReserveQtyReplen      = @c_ReserveQtyReplen     
                    ,@c_ReservePendingMoveIn  = @c_ReservePendingMoveIn 
                    ,@c_CombineTasks          = @c_CombineTasks                                                                                                
                    ,@c_CasecntbyLocUCC       = @c_CasecntbyLocUCC      
                    ,@c_LinkTaskToPick        = @c_LinkTaskToPick
                    ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                    ,@c_RoundUpQty            = @c_RoundUpQty
                    ,@c_WIP_RefNo             = @c_WIP_RefNo
                    ,@c_SplitTaskByCase       = @c_SplitTaskByCase
                    ,@c_ZeroSystemQty         = @c_ZeroSystemQty
                    ,@c_MergedTaskPriority    = @c_MergedTaskPriority  --NJOW04
                    ,@b_Success               = @b_Success OUTPUT
                    ,@n_Err                   = @n_err OUTPUT 
                    ,@c_ErrMsg                = @c_errmsg OUTPUT       	
                  
                  IF @b_Success <> 1 
                  BEGIN
                     SELECT @n_continue = 3  
                  END      	  	               	
               END
            END
      	 END
      	 ELSE
      	 BEGIN
            IF @c_ToLoc_Strategy = 'PICK'
            BEGIN
               SELECT TOP 1 @c_ToLoc = LOC.Loc 
               FROM SKUXLOC(NOLOCK)
               JOIN LOC (NOLOCK) ON SKUXLOC.Loc = LOC.Loc
               WHERE SKUXLOC.Storerkey = @c_Storerkey
               AND SKUXLOC.Sku = @c_Sku
               AND SKUXLOC.LocationType IN('PICK','CASE')
               AND LOC.Facility = @c_Facility
               ORDER BY LOC.Loc
               
               IF ISNULL(@c_ToLoc,'') = ''
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82110   
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find pick location for Sku ''' + RTRIM(@c_Sku)+ ''' (isp_CreateTaskByPick)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
               END
            END      	 
      	    
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
                 ,@c_SourcePriority        = @c_SourcePriority            
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_SourceKey      
                 ,@c_LoadKey               = @c_Loadkey      
                 ,@c_Wavekey               = @c_Wavekey
                 ,@c_Orderkey              = @c_Orderkey
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message01             = @c_Message01
                 ,@c_Message02             = @c_Message02
                 ,@c_Message03             = @c_Message03
                 ,@c_CallSource            = @c_CallSource
                 ,@c_ReserveQtyReplen      = @c_ReserveQtyReplen     
                 ,@c_ReservePendingMoveIn  = @c_ReservePendingMoveIn 
                 ,@c_CombineTasks          = @c_CombineTasks                                                                                                
                 ,@c_CasecntbyLocUCC       = @c_CasecntbyLocUCC      
                 ,@c_LinkTaskToPick        = @c_LinkTaskToPick
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_RoundUpQty            = @c_RoundUpQty
                 ,@c_WIP_RefNo             = @c_WIP_RefNo
                 ,@c_SplitTaskByCase       = @c_SplitTaskByCase
                 ,@c_ZeroSystemQty         = @c_ZeroSystemQty
                 ,@c_MergedTaskPriority    = @c_MergedTaskPriority  --NJOW04                 
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT       	
               
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END
            END      	  	
         END
         
         FETCH NEXT FROM CUR_Pickrec INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_Facility, @c_Orderkey, @c_Loadkey
      END 
      CLOSE CUR_Pickrec  
      DEALLOCATE CUR_Pickrec                                                
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_CreateTaskByPick'		
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