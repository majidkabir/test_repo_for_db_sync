SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspLPRTSK9                                          */  
/* Creation Date: 25-JUL-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-9045 - ID Fonterra load plan release pick task           */
/*                                                                       */  
/* Called By: Load                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 09-Jun-2002  NJOW01   1.1  Fix to filter by storerkey                 */
/* 27-Oct-2020  NJOW02   1.2  WMS-15601 Support multi load per booking   */
/* 04-Feb-2020  NJOW03   1.3  WMS-16307 Remove groupkey mapping          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[nspLPRTSK9]      
  @c_LoadKey     NVARCHAR(10) 
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 ,@c_Storerkey    NVARCHAR(15) = '' 
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @b_success INT,  
            @n_cnt int
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE  @c_Facility            NVARCHAR(5)
            ,@c_TaskType            NVARCHAR(10)            
            ,@c_SourceType          NVARCHAR(30)
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_Toloc               NVARCHAR(10)                                    
            ,@c_Priority            NVARCHAR(10)            
            ,@c_PickMethod          NVARCHAR(10)            
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_SQL                 NVARCHAR(MAX)
            ,@n_PLTBalQty           INT
            ,@n_PLTQtyAllocated     INT
            ,@c_LocationType        NVARCHAR(10)
            ,@c_Consigneekey        NVARCHAR(15)
            ,@c_Company             NVARCHAR(45)
            ,@c_Orderkey            NVARCHAR(10)
            ,@c_InsertOrderkey      NVARCHAR(10)
            ,@c_BookToLoc           NVARCHAR(10)
            ,@n_OrderCnt            INT
            ,@c_TransitLOC          NVARCHAR(10)
                            
    SET @c_SourceType = 'nspLPRTSK9'    
    SET @c_Priority = '8'

    -----Load Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM LOADPLANDETAIL LD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                      WHERE LD.Loadkey = @c_Loadkey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                      AND (PD.Storerkey = @c_Storerkey OR ISNULL(@c_Storerkey,'') = '')  --NJOW01
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (nspLPRTSK9)'       
       END      
    END
       
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)
                  WHERE TD.Loadkey = @c_Loadkey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype IN('FCP','FPK')
                  AND (TD.Storerkey = @c_Storerkey OR ISNULL(@c_Storerkey,'') = '')) --NJOW01
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Load has beed released. (nspLPRTSK9)'       
       END                 
    END   
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey and facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 --@c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility
        FROM LOADPLAN L (NOLOCK)
        JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
        JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
        AND L.LOadkey = @c_Loadkey                 
        AND (O.Storerkey = @c_Storerkey OR ISNULL(@c_Storerkey,'') = '') --NJOW01    
        
        SELECT TOP 1 @c_BookToLoc = BO.Loc
        FROM BOOKING_OUT BO (NOLOCK)
        JOIN LOC (NOLOCK) ON BO.Loc = LOC.Loc
        WHERE BO.Loadkey = @c_Loadkey
        ORDER BY BO.Loc
        
        --NJOW02
        IF ISNULL(@c_BookToLoc,'') = ''
        BEGIN
        	 SELECT TOP 1 @c_BookToLoc = BO.Loc
        	 FROM LOADPLAN LP (NOLOCK)
        	 JOIN BOOKING_OUT BO (NOLOCK) ON LP.BookingNo = BO.BookingNo
           JOIN LOC (NOLOCK) ON BO.Loc = LOC.Loc
           WHERE LP.Loadkey = @c_Loadkey
           ORDER BY BO.Loc
        END
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
            
    IF @n_continue IN(1,2)
    BEGIN
    	 SET @c_SQL = '
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
    	    SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
    	           MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty, '''' AS Consigneekey, PD.Loc AS ToLoc,
    	           ISNULL(PLT.PLTBalQty,0), ISNULL(PLT.PLTQtyAllocated,0), SL.LocationType, CON.Company, MAX(O.Orderkey), COUNT(DISTINCT O.Orderkey)  
          FROM LOADPLANDETAIL LD (NOLOCK)
          JOIN LOADPLAN L (NOLOCK) ON LD.Loadkey = L.Loadkey
          JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
          JOIN STORER CON (NOLOCK) ON O.Consigneekey = CON.Storerkey
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
          OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS PLTBalQty,
                       SUM(LLI.QtyAllocated + LLI.QtyPicked) AS PLTQtyAllocated
                       FROM LOTXLOCXID LLI (NOLOCK) 
                       WHERE LLI.Loc = PD.Loc AND LLI.Id = PD.Id) AS PLT
          WHERE LD.Loadkey = @c_Loadkey
          AND PD.Status = ''0''
          AND PD.WIP_RefNo = @c_SourceType
          AND (O.Storerkey = @c_Storerkey OR ISNULL(@c_Storerkey,'''') = '''')
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, Loc.LogicalLocation, ISNULL(PLT.PLTBalQty,0), ISNULL(PLT.PLTQtyAllocated,0), SL.LocationType, CON.Company                    
          ORDER BY PD.Storerkey, Loc.LogicalLocation, PD.Loc '       
       
       EXEC sp_executesql @c_SQL,
          N'@c_Loadkey NVARCHAR(10), @c_SourceType NVARCHAR(30), @c_Storerkey NVARCHAR(15)', 
          @c_Loadkey,
          @c_SourceType,
          @c_Storerkey   --NJOW01
             
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Consigneekey, 
                                     @c_ToLoc, @n_PLTBalQty, @n_PLTQtyAllocated, @c_LocationType, @c_Company, @c_Orderkey, @n_OrderCnt
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN          	        	
  	  	 	 SET @c_LinkTaskToPick_SQL = ''  --'AND ORDERS.Consigneekey = ''' + RTRIM(ISNULL(@c_Consigneekey,'')) + ''' '  --NJOW03 removed
      	   SET @c_UOM = ''
      	   SET @n_UOMQty = 0
      	   SET @c_TaskType = 'FCP'
      	   SET @c_PickMethod = 'PP'
      	   
      	   IF ISNULL(@c_BookToLoc,'') <> ''
      	      SET @c_Toloc = @c_BookToLoc
      	   
           IF @c_LocationType NOT IN('PICK','CASE')
           BEGIN
           	  IF @n_PLTBalQty = 0 AND @n_PLTQtyAllocated = @n_Qty
           	  BEGIN
           	     SET @c_TaskType = 'FPK'
            	   SET @c_PickMethod = 'FP'
           	  END
           END   
           
           IF @c_TaskType = 'FCP'
              SET @c_TransitLOC = ISNULL(@c_BookToLoc,'') 
           ELSE 
              SET @c_TransitLOC = ''
           
           IF @c_TaskType = 'FPK' AND @n_OrderCnt = 1
             SET @c_InsertOrderkey = @c_Orderkey
           ELSE
             SET @c_InsertOrderkey = ''   	   
            	         	    
       	   EXEC isp_InsertTaskDetail   
               @c_TaskType              = @c_TaskType             
              ,@c_Storerkey             = @c_Storerkey
              ,@c_Sku                   = @c_Sku
              ,@c_Lot                   = @c_Lot 
              ,@c_UOM                   = @c_UOM      
              ,@n_UOMQty                = @n_UOMQty     
              ,@n_Qty                   = @n_Qty      
              ,@c_FromLoc               = @c_Fromloc      
              ,@c_LogicalFromLoc        = @c_FromLoc 
              ,@c_FromID                = @c_ID     
              ,@c_ToLoc                 = @c_ToLoc       
              ,@c_LogicalToLoc          = @c_ToLoc 
              ,@c_ToID                  = @c_ID       
              ,@c_PickMethod            = @c_PickMethod
              ,@c_Priority              = @c_Priority
              ,@c_StatusMsg             = @c_Company     
              ,@c_SourcePriority        = '9'      
              ,@c_SourceType            = @c_SourceType      
              ,@c_SourceKey             = @c_Loadkey      
              ,@c_Orderkey              = @c_InsertOrderkey
              ,@c_TransitLOC            = @c_TransitLOC
              ,@c_CallSource            = 'LOADPLAN'
              ,@c_LoadKey               = @c_Loadkey      
              ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
              ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
              ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
              ,@c_Groupkey              = '' --@c_Consigneekey  --NJOW03 Removed
              ,@c_WIP_RefNo             = @c_SourceType
              ,@b_Success               = @b_Success OUTPUT
              ,@n_Err                   = @n_err OUTPUT 
              ,@c_ErrMsg                = @c_errmsg OUTPUT       	
           
           IF @b_Success <> 1 
           BEGIN
              SELECT @n_continue = 3  
           END
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Consigneekey, @c_ToLoc, 
                                        @n_PLTBalQty, @n_PLTQtyAllocated, @c_LocationType, @c_Company, @c_Orderkey, @n_OrderCnt
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick
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
                      
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    IF @n_continue IN (1,2)
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = @c_Loadkey
            ,@c_Wavekey               = ''  
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

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
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
       execute nsp_logerror @n_err, @c_errmsg, "nspLPRTSK9"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END      
 END --sp end

GO