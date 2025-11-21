SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_InsertTaskDetail                               */
/* Creation Date: 25-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: WMS-1846 Insert Taskdetail                                  */   
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
/* 05/07/2017   NJOW01   1.0  Fix system qty and add dropid to SQL      */
/* 06/07/2017   NJOW02   1.1  Fix pickdetail search support orderkey    */
/* 15/07/2017   TLTING   1.2  revise DynamicSQL                         */
/* 03/08/2017   NJOW03   1.3  Fix full case roundup and add wip_refno   */ 
/* 30/08/2017   NJOW04   1.4  WMS-1965 Combine tasks of same stock      */
/* 07/08/2017   NJOW05   1.5  WMS-3178 Round up to full loc qty         */
/* 17/01/2018   NJOW06   1.6  WMS-3652 add combine task option 'C' allow*/
/*                            combine task per carton                   */
/* 08/03/2018   NJOW07   1.7  WMS-4020 Get casecnt by location's uccqty.*/
/*                            all ucc must same qty                     */
/* 06/07/2018   NJOW08   1.8  WMS-5572 Get casecnt from lottable        */
/* 13/07/2018   NJOW09   1.9  Cater for split task by carton.           */
/* 04/07/2018   NJOW10   2.0  cater for #pickdetail_wip temp table      */
/* 15/03/2019   NJOW11   2.1  If @c_CombineTasks='C'. if extra qty not  */
/*                            sufficien but still allow combine if after*/
/*                            combine is full pallet/carton/full location*/
/* 17/04/2019   NJOW12   2.2  if last caron is partially allocated by more*/
/*                            than a wave/load. the first task will not */
/*                            have roundup & qtyreplen. if combine 'c' is*/
/*                            enable, next wave is able to combine the  */
/*                            last carton                               */
/* 03/06/2019   NJOW13   2.3  WMS-9196 Merge task allow set priority    */
/* 11-07-2019   SPChin   2.4  INC0769209 - Extend The Length Of @c_SQL  */  
/*                                         And @c_LinkTaskToPick_SQL    */
/* 04-03-2021   WLChooi  2.5  Fixes - Insert Channel_ID into Pickdetail */
/*                            Table (WL01)                              */
/* 14-12-2021   NJOW14   2.6  WMS-18495 if qty 0 still allow insert     */
/* 14-14-2021   NJOW14   2.6  DEVOPS combine script                     */
/************************************************************************/

CREATE     PROC [dbo].[isp_InsertTaskDetail]   
    @c_TaskDetailKey         NVARCHAR(10)   = '' OUTPUT     
   ,@c_TaskType              NVARCHAR(10)   = ''      
   ,@c_Storerkey             NVARCHAR(15)   = ''      
   ,@c_Sku                   NVARCHAR(20)   = ''      
   ,@c_Lot                   NVARCHAR(10)   = ''      
   ,@c_UOM                   NVARCHAR(5)    = ''     -- if UOM=1,2,6. @n_UOMQty=0 or @c_RoundUpQty=FC/FP then auto calculate uomqty based on sku packkey
   ,@n_UOMQty                INT            = 0      
   ,@n_Qty                   INT            = 0      
   ,@c_FromLoc               NVARCHAR(10)   = ''      
   ,@c_LogicalFromLoc        NVARCHAR(10)   = '?'    -- ?=Auto default logical from loc   
   ,@c_FromID                NVARCHAR(18)   = ''     
   ,@c_ToLoc                 NVARCHAR(10)   = ''       
   ,@c_LogicalToLoc          NVARCHAR(10)   = '?'    -- ?=Auto default logical to loc   
   ,@c_ToID                  NVARCHAR(18)   = ''       
   ,@c_Caseid                NVARCHAR(20)   = ''       
   ,@c_PickMethod            NVARCHAR(10)   = ''     -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
   ,@c_Status                NVARCHAR(10)   = '0'      
   ,@c_StatusMsg             NVARCHAR(255)  = ''      
   ,@c_Priority              NVARCHAR(10)   = ''      
   ,@c_SourcePriority        NVARCHAR(10)   = ''      
   ,@c_Holdkey               NVARCHAR(10)   = ''      
   ,@c_UserKey               NVARCHAR(18)   = ''      
   ,@c_UserPosition          NVARCHAR(10)   = '1'      
   ,@c_UserKeyOverRide       NVARCHAR(18)   = ''      
   ,@d_StartTime             DATETIME       = NULL      
   ,@d_EndTime               DATETIME       = NULL
   ,@c_SourceType            NVARCHAR(30)   = ''      
   ,@c_SourceKey             NVARCHAR(30)   = ''      
   ,@c_PickDetailKey         NVARCHAR(10)   = ''      
   ,@c_OrderKey              NVARCHAR(10)   = ''      
   ,@c_OrderLineNumber       NVARCHAR(5)    = ''      
   ,@c_ListKey               NVARCHAR(10)   = ''      
   ,@c_WaveKey               NVARCHAR(10)   = ''      
   ,@c_ReasonKey             NVARCHAR(10)   = ''       
   ,@c_Message01             NVARCHAR(20)   = ''       
   ,@c_Message02             NVARCHAR(20)   = ''       
   ,@c_Message03             NVARCHAR(20)   = ''       
   ,@n_SystemQty             INT            = 0      -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
   ,@c_RefTaskKey            NVARCHAR(10)   = ''       
   ,@c_LoadKey               NVARCHAR(10)   = ''       
   ,@c_AreaKey               NVARCHAR(10)   = ''     -- ?F=Get from location areakey ?T=Get to location areakey       
   ,@c_DropID                NVARCHAR(20)   = ''       
   ,@n_TransitCount          INT            = ''       
   ,@c_TransitLOC            NVARCHAR(10)   = ''       
   ,@c_FinalLOC              NVARCHAR(10)   = ''       
   ,@c_FinalID               NVARCHAR(10)   = ''       
   ,@c_Groupkey              NVARCHAR(10)   = ''  
   ,@n_PendingMoveIn         INT            = 0      -- if > 0 trigger will auto update to lotxlocxid.PendingMoveIn when insert/delete or cancel.  (trigger call rdt.rdt_Putaway_PendingMoveIn )
                                                     -- task execute by RDT will not use trigger logic and pendingmovein update by RDT.
                                                     -- if have set @c_RoundUpQty suggest pass in 0 and use @c_ReservePendingMoveIn=Y to copy the final qty to @n_PendingMoveIn
   ,@n_QtyReplen             INT            = 0      -- if > 0 trigger will auto update to lotxlocxid.QtyReplen when insert/delete or cancel. 
                                                     -- task execute by RDT will not use trigger logic and qtyreplen update by RDT.
                                                     -- if have set @c_RoundUpQty or reserve roundup qty only, suggest pass in 0 and use @c_ReserveQtyReplen=TASKQTY / ROUNDUP to copy the final qty to @n_QtyReplen
   ,@c_CallSource            NVARCHAR(20)   = 'WAVE' -- WAVE / LOADPLAN / REPLENISHMENT
   ,@c_LinkTaskToPick        NVARCHAR(5)    = 'N'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip  
   --,@c_LinkTaskToPick_SQL    NVARCHAR(4000) = ''   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY   --INC0769209
   ,@c_LinkTaskToPick_SQL    NVARCHAR(MAX)  = ''     -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY   --INC0769209
   ,@c_WIP_RefNo             NVARCHAR(30)   = ''     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
   ,@c_RoundUpQty            NVARCHAR(5)    = ''     -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
   ,@c_ReserveQtyReplen      NVARCHAR(10)   = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
   ,@c_LinkTaskToReplen      NVARCHAR(5)    = 'N'    -- N=No link to replenisment Y=Update taskdetailkey to Replenishment.ReplenNo and set confirm = 'Y'. Require @c_callsource='REPLENISHMENT' @c_Sourcekey=REPLENISHMENT.Replenishmentkey
   ,@c_ReservePendingMoveIn  NVARCHAR(5)    = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn
   ,@c_CombineTasks          NVARCHAR(5)    = 'N'    -- N=No combine Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                                                     -- Combine qty is depend on whether the first task extra qty (qty-systemqty) is sufficient for subsequence tasks of different load/wave. Will increase task qty if insufficient.
                                                     -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                                                     -- M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
   ,@c_CasecntbyLocUCC       NVARCHAR(5)    = 'N'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
   ,@c_SplitTaskByCase       NVARCHAR(5)    = 'N'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
   ,@c_ZeroSystemQty         NVARCHAR(5)    = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
   ,@c_MergedTaskPriority    NVARCHAR(10)   = '2'    -- Set the priority of merged task based on @c_combineTasks setting.  --NJOW13
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
           @n_ReserveQtyReplen   INT,
           --@c_SQL                NVARCHAR(4000), --INC0769209
           @c_SQL                NVARCHAR(MAX),    --INC0769209
           @c_CurrPickDetailKey  NVARCHAR(10),
           @c_NewPickDetailKey   NVARCHAR(10),
           @n_PickQty            INT,
           @n_TaskQty            INT, 
           @c_PickTableName      NVARCHAR(20),
           @n_SplitQty           INT,
           @n_QtyAvailable       INT,                                                    
           @n_Casecnt            INT,
           @n_Pallet             INT,
           @n_FullPackQty        INT,
           @n_RoundUpQty         INT,
           @c_Username           NVARCHAR(18),
           @n_UCCQty             INT, --NJOW07           
           @c_AllocateGetCasecntFrLottable NVARCHAR(10),  --NJOW08
           @n_LotCaseCnt         INT, --NJOW08
           @c_Facility           NVARCHAR(5), --NJOW08
           @c_CaseQty            NVARCHAR(30), --NJOW08
           @n_QtyRemain          INT, --NJOW09
           @n_SystemQtyRemain    INT, --NJOW09
           @c_IncludeChannel_ID  NCHAR(1)   --WL01
              
   --NJOW04
   DECLARE @n_QtyAllocated       INT, 
           @c_FoundTaskdetailkey NVARCHAR(10),
           @n_FoundSystemQty     INT,
           @n_FoundQty           INT,
           @c_FoundPickMethod    NVARCHAR(10),         
           @n_FoundExtraQty      INT,
           @c_DoCombineTask      NVARCHAR(5),
           @n_IncreaseQty        INT,
           @n_IncreaseSystemQty  INT          
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @c_Username = SUSER_SNAME(), @n_UCCQty = 0, @n_LotCaseCnt = 0, @c_IncludeChannel_ID = 'Y'   --WL01
	 
	 IF @c_LinkTaskToPick = 'WIP'
      IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL  --NJOW10
  	     SET @c_PickTableName = '#PICKDETAIL_WIP'
  	  ELSE   
         SET @c_PickTableName = 'PICKDETAIL_WIP'	    
	 ELSE
	    SET @c_PickTableName = 'PICKDETAIL'
	 
	 IF @d_StartTime IS NULL
	    SELECT @d_StartTime = GETDATE()                
	 IF @d_EndTime IS NULL           	    
	    SELECT @d_EndTime = GETDATE()

    --WL01 S
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
    ELSE IF @c_PickTableName = 'PICKDETAIL_WIP'
    BEGIN
       IF NOT EXISTS (SELECT 1
                      FROM syscolumns
                      JOIN sysobjects ON (sysobjects.id = syscolumns.id)
                      AND sysobjects.type = 'U'
                      AND sysobjects.name = 'PICKDETAIL_WIP' 
                      AND syscolumns.name = 'Channel_ID')    
          SET @c_IncludeChannel_ID = 'N'       	     	
    END
    --WL01 E
   
	 --Initialization
	 IF @n_continue IN(1,2)
	 BEGIN
	 	  CREATE TABLE #TMP_PICK (Pickdetailkey NVARCHAR(10) primary key,
	 	                          Qty           INT NULL,
	 	                          rowid         INT IDENTITY(1,1))	 	  
	 END
	    
   --Auto set field value
   IF @n_continue IN(1,2)
   BEGIN      
      IF @n_SystemQty = 0
         SET @n_SystemQty = @n_Qty
         
      IF @n_SystemQty < 0 OR @c_ZeroSystemQty = 'Y' --NJOW09
         SET @n_SystemQty = 0   
      
      --Get Logical location
      IF @c_LogicalFromLoc = '?'
      BEGIN
         SELECT @c_LogicalFromLoc = ISNULL(LogicalLocation,'')
         FROM LOC (NOLOCK)
         WHERE Loc = @c_FromLoc

         IF ISNULL(@c_LogicalFromLoc,'') = ''
            SET @c_LogicalFromLoc = @c_FromLoc
      END 

      IF @c_LogicalToLoc = '?'
      BEGIN
         SELECT @c_LogicalToLoc = ISNULL(LogicalLocation,'')
         FROM LOC (NOLOCK)
         WHERE Loc = @c_ToLoc

         IF ISNULL(@c_LogicalToLoc,'') = ''
            SET @c_LogicalToLoc = @c_ToLoc
      END       
            
      --Recalculate qty to avoid over take if already have replenishment
      /*
      IF @n_continue IN(1,2)
      BEGIN
         SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked) 
               ,@n_LLIQtyReplen = QtyReplen
         FROM LOTXLOCXID (NOLOCK)           
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
         AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
         AND Loc = @c_FromLoc
         AND ID = @c_FromID      		
         
         IF @n_LLIQtyReplen > 0
         BEGIN
         	  SET @n_BalQtyAfterShareReplen = @n_QtyAvailable - @n_LLIQtyReplen + @n_Qty 
         	  
         	  IF @n_Qty > @n_BalQtyAfterShareReplen 
         	     SET @n_Qty = @n_BalQtyAfterShareReplen
         END
      END
      */
      
      --Get casecnt from ucc qty by location --NJOW07
      IF @c_CasecntbyLocUCC = 'Y' AND ISNULL(@c_Lot,'') <> '' 
      BEGIN
         SELECT @n_UCCQty = MAX(UCC.Qty)
         FROM UCC (NOLOCK)
         WHERE UCC.Storerkey = @c_Storerkey
         AND UCC.Sku = @c_Sku
         AND UCC.Lot = @c_Lot
         AND UCC.Loc = @c_FromLoc
         AND UCC.ID = @c_FromID
         AND UCC.Status <= '3'
      END
      
      --Get casecnt from lottable --NJOW08
      IF (@c_RoundUpQty = 'FC'  OR (@n_UOMQty = 0 AND @c_UOM IN('1','2','6')))  AND ISNULL(@c_Lot,'') <> ''
      BEGIN
      	 SELECT @c_Facility = Facility
      	 FROM LOC (NOLOCK)
      	 WHERE Loc = @c_FromLoc
      	 
         SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable') 
         
         IF ISNULL(@c_AllocateGetCasecntFrLottable,'')  IN ('01','02','03','06','07','08','09','10','11','12') 
         BEGIN
            SET @c_CaseQty = ''
            SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +       	 
                ' FROM LOTATTRIBUTE(NOLOCK) ' +
                ' WHERE LOT = @c_Lot '
            
   	        EXEC sp_executesql @c_SQL,
   	        N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_Lot NVARCHAR(10)', 
   	        @c_CaseQty OUTPUT,
   	        @c_lot    
   	        
   	        IF ISNUMERIC(@c_CaseQty) = 1
   	        	  SELECT @n_LotCaseCnt = CAST(@c_CaseQty AS INT)
         END
      END      
      
      --Round up qty to full case/pallet             
      IF @c_RoundUpQty IN('FC','FP','FL')
      BEGIN
      	SELECT @n_Casecnt = PACK.Casecnt,
      	       @n_Pallet = PACK.Pallet
      	FROM SKU (NOLOCK)
      	JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      	WHERE SKU.Storerkey = @c_Storerkey
      	AND SKU.Sku = @c_Sku
      	
      	--NJOW07
      	IF @n_UCCQty > 0
      	   SET @n_CaseCnt = @n_UCCQty
      	
      	--NJOW08   
      	IF @n_LotCaseCnt > 0
      	   SET @n_CaseCnt = @n_LotCaseCnt
      	         	
      	IF @c_RoundUpQty = 'FC' AND @n_Casecnt > 0
      	BEGIN
           SET @n_FullPackQty = CEILING(@n_Qty / (@n_Casecnt * 1.00)) * @n_Casecnt
        END   

      	IF @c_RoundUpQty = 'FP' AND @n_Pallet > 0
      	BEGIN
           SET @n_FullPackQty = CEILING(@n_Qty / (@n_Pallet * 1.00)) * @n_Pallet
        END   

      	IF @c_RoundUpQty = 'FL' --NJOW05
      	BEGIN
           SELECT @n_Qty = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
           FROM LOTXLOCXID (NOLOCK)           
           WHERE Storerkey = @c_Storerkey
           AND (Sku = @c_Sku OR ISNULL(@c_Sku,'') = '')
           AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
           AND Loc = @c_FromLoc
           AND ID = @c_FromID      		
      	END
      	ELSE
      	BEGIN        
           SET @n_RoundUpQty = @n_FullPackQty - @n_SystemQty
           
           IF @n_RoundUpQty > 0
           BEGIN         
              SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
              FROM LOTXLOCXID (NOLOCK)           
              WHERE Storerkey = @c_Storerkey
              AND Sku = @c_Sku
              AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
              AND Loc = @c_FromLoc
              AND ID = @c_FromID      		
              
              IF @n_QtyAvailable >= @n_RoundUpQty
              BEGIN
                 SET @n_Qty = @n_FullPackQty              
              END
           END       
        END
     	END        	
            
      --pickmethod full pallet(FP) or partial pallet(PP)   
      IF CHARINDEX('?', @c_PickMethod) > 0
      BEGIN
         SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked),
                @n_QtyAllocated = SUM(QtyAllocated + QtyPicked) 
         FROM LOTXLOCXID (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Loc = @c_FromLoc
         AND ID = @c_FromID
         
         IF CHARINDEX('?ROUNDUP', @c_PickMethod) > 0 AND @n_Qty <> @n_SystemQty
            SET @n_QtyAvailable = @n_QtyAvailable - (@n_Qty - @n_SystemQty) --qty available exclude round up full carton/pallet qty

         IF CHARINDEX('?TASKQTY', @c_PickMethod) > 0 
            SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty --qty available exclude all task qty
         
         IF @n_QtyAvailable <= 0 
            IF @c_LinkTaskToPick = 'Y' AND @n_QtyAllocated > @n_SystemQty --Some Qty allocated by other load/wave --NJOW04
         	    SET @c_PickMethod = 'PP'         	  
            ELSE    
         	    SET @c_PickMethod = 'FP'         	  
         ELSE
            SET @c_PickMethod = 'PP'                       
      END    
            
      --Get areakey
      IF  @c_Areakey = '?F'
      BEGIN
      	 SET @c_Areakey = ''
      	 
      	 SELECT TOP 1 @c_Areakey = AREADETAIL.Areakey
      	 FROM LOC (NOLOCK)
      	 JOIN AREADETAIL (NOLOCK) ON LOC.Putawayzone = AREADETAIL.Putawayzone
      	 WHERE LOC.Loc = @c_FromLoc
      END

      IF  @c_Areakey = '?T'
      BEGIN
      	 SET @c_Areakey = ''
      	 
      	 SELECT TOP 1 @c_Areakey = AREADETAIL.Areakey
      	 FROM LOC (NOLOCK)
      	 JOIN AREADETAIL (NOLOCK) ON LOC.Putawayzone = AREADETAIL.Putawayzone
      	 WHERE LOC.Loc = @c_ToLoc
      END          
      
      --Calculate UOMQty
      IF (@c_RoundUpQty IN('FC','FP') OR (@n_UOMQty = 0 AND @c_UOM IN('1','2','6')) OR @c_SplitTaskByCase = 'Y') AND ISNULL(@c_Storerkey,'') <> '' AND ISNULL(@c_Sku,'') <> ''  --NJOW09
      BEGIN
      	 SELECT @n_Casecnt = PACK.Casecnt, 
      	        @n_Pallet = PACK.Pallet
      	 FROM SKU (NOLOCK)
      	 JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      	 WHERE SKU.Storerkey = @c_Storerkey
      	 AND SKU.Sku = @c_Sku
      	 
       	--NJOW07
      	IF @n_UCCQty > 0
      	   SET @n_CaseCnt = @n_UCCQty

      	--NJOW08   
      	IF @n_LotCaseCnt > 0
      	   SET @n_CaseCnt = @n_LotCaseCnt
         
      	 IF @c_UOM = 1 AND @n_Pallet > 0 AND (@n_UOMQty = 0 OR @c_RoundUpQty = 'FP')
      	 BEGIN
      	    SET @n_UOMQty = FLOOR(@n_Qty / @n_Pallet) 
         END
         
      	 IF @c_UOM = 2 AND @n_Casecnt > 0 AND (@n_UOMQty = 0 OR @c_RoundUpQty = 'FC')
      	 BEGIN
      	    SET @n_UOMQty = FLOOR(@n_Qty / @n_Casecnt) --NJOW02
         END
      	 
      	 IF @c_UOM = 6  AND @n_UOMQty = 0 
      	 BEGIN
      	    SET @n_UOMQty = @n_Qty
         END              	       
      END
   END
   
   --NJOW09
   IF @c_SplitTaskByCase = 'Y' AND @n_casecnt > 0
   BEGIN
      SET @n_cnt = CEILING(@n_Qty / (@n_CaseCnt * 1.00))
      --SET @c_UOM = '2'
      SET @n_UOMQty = 1
      SET @c_PickMethod = 'PP'
   END
   ELSE
   BEGIN
      SET @n_cnt = 1
      SET @c_SplitTaskByCase = 'N'  --turn off if not qualify
   END
   SET @n_QtyRemain = @n_Qty
   SET @n_SystemQtyRemain = @n_SystemQty
      
  --WHILE @n_cnt > 0 AND @n_QtyRemain > 0 AND @n_continue IN(1,2) --loop by carton or task
   WHILE @n_cnt > 0 AND (@n_QtyRemain > 0 OR (@n_Qty = 0 AND @c_SplitTaskByCase = 'N')) AND @n_continue IN(1,2) --loop by carton or task   --NJOW14
   BEGIN      
      --NJOW09 Start
      IF @c_SplitTaskByCase = 'Y'
      BEGIN
         SET @c_Taskdetailkey = ''
	  	   IF @n_QtyRemain >= @n_CaseCnt
	  	 	    SET @n_Qty = @n_CaseCnt
 	  	 	 ELSE   
 	  	 	    SET @n_Qty = @n_QtyRemain    

         IF @n_SystemQtyRemain > 0
         BEGIN
	  	      IF @n_SystemQtyRemain >= @n_CaseCnt
	  	 	       SET @n_SystemQty = @n_CaseCnt
 	  	 	    ELSE   
 	  	 	       SET @n_SystemQty = @n_SystemQtyRemain    
         END         
      END
         
      SET @n_QtyRemain = @n_QtyRemain - @n_Qty
      SET @n_SystemQtyRemain = @n_SystemQtyRemain - @n_SystemQty
      SET @n_cnt = @n_cnt - 1 
      --NJOW09 End
      
      --Update Qty Task Qty to LOTXLOCXID.QtyReplen
      IF @c_ReserveQtyReplen IN('TASKQTY','ROUNDUP') AND ISNULL(@c_Lot,'') <> ''
      BEGIN
         IF @c_ReserveQtyReplen = 'TASKQTY'
            SET @n_ReserveQtyReplen = @n_Qty
         ELSE   
            SET @n_ReserveQtyReplen = @n_Qty - @n_SystemQty
            
         SET @n_QtyReplen = @n_ReserveQtyReplen
            
         /*
         IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK) 
                   WHERE Lot = @c_Lot
                   AND Loc = @c_FromLoc
                   AND ID = @c_FromID)
         BEGIN
         	  UPDATE LOTXLOCXID WITH (ROWLOCK)
         	  SET QtyReplen = QtyReplen + @n_ReserveQtyReplen
            WHERE Lot = @c_Lot
            AND Loc = @c_FromLoc
            AND ID = @c_FromID

            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN 
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81000  
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update LOTXLOCXID Failed' + ' ( '+  
                                  ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
            END     
         END
         */         
      END
      
      --Update task qty as pending move in qty at TOLOC  @n_PendingMoveIn = @n_Qty  
      IF @c_ReservePendingMoveIn = 'Y' AND ISNULL(@c_ToLoc,'') <> ''
      BEGIN   	
   	     SET @n_PendingMoveIn = @n_Qty
      END      
   
      --Check Combine tasks
      SET @c_DoCombineTask = 'N' --NJOW09
      IF @n_continue IN(1,2) AND @c_CombineTasks IN ('Y','M','C') --NJOW04 NJOW06
      BEGIN
         SELECT @c_FoundTaskdetailkey = '', @n_FoundSystemQty = 0, @n_FoundQty = 0, @c_FoundPickMethod = '' --NJOW09
         SELECT @n_IncreaseSystemQty = 0, @n_IncreaseQty = 0 --NJOW09
         
         SELECT TOP 1 @c_FoundTaskdetailkey = TD.Taskdetailkey,
                      @n_FoundSystemQty = TD.SystemQty,
                      @n_FoundQty = TD.Qty,
                      @c_FoundPickMethod = TD.PickMethod
         FROM TASKDETAIL TD (NOLOCK)
         WHERE TD.Lot = CASE WHEN ISNULL(@c_Lot,'') <> '' THEN @c_Lot ELSE TD.Lot END
         AND TD.Storerkey = @c_Storerkey  
         AND TD.Sku = CASE WHEN ISNULL(@c_Sku,'') <> '' THEN @c_Sku ELSE TD.Sku END                                            
         AND TD.FromLoc = @c_FromLoc
         AND TD.FromID = @c_FromID
         AND TD.ToLoc = @c_Toloc
         AND TD.ToID = @c_ToID
         AND TD.Status IN('0','H')
         AND TD.Qty > 0
         ORDER BY (TD.Qty - TD.SystemQty) DESC
               
         SET @n_FoundExtraQty = @n_FoundQty - @n_FoundSystemQty
         
         IF @c_CombineTasks = 'C' AND (@n_FoundExtraQty < @n_SystemQty OR @n_FoundSystemQty = 0)   --if extra qty not sufficient not combine.  --NJOW06
         BEGIN
             --if extra qty not sufficien but still allow combine if after combine is full pallet/carton/full location  --NJOW11
            IF NOT (@n_Casecnt > 0  AND @n_FoundSystemQty > 0  AND @n_SystemQty > 0
                    AND (@n_FoundSystemQty + @n_SystemQty) % IIF(@n_Casecnt > 0, @n_Casecnt, 1) = 0  --after combine is full case
                    AND (@n_FoundSystemQty) % IIF(@n_Casecnt > 0, @n_Casecnt, 1) <> 0  --The task is not full case
                    )
               AND
               NOT (@n_Pallet > 0  AND @n_FoundSystemQty > 0  AND @n_SystemQty > 0
                    AND (@n_FoundSystemQty + @n_SystemQty) % IIF(@n_Pallet > 0, @n_Pallet, 1) = 0  --after combine is full pallet
                    AND (@n_FoundSystemQty) % IIF(@n_Pallet > 0, @n_Pallet, 1) <> 0  --The task is not full pallet
                    )        
               AND
               NOT (@c_RoundUpQty = 'FL' AND @n_FoundSystemQty > 0  AND @n_SystemQty > 0)  --if full location pick just combine      
               AND
               NOT (@n_Casecnt > 0  AND @n_FoundSystemQty > 0  AND @n_SystemQty > 0   --NJOW12
                    AND (@n_FoundSystemQty + @n_SystemQty) <= @n_Casecnt  --after combine is a case
                    AND @n_FoundExtraQty = 0  --Not extara qty but the task is a case after combine. this happen when last carton of the loc partially allocated by more than a wave/load
                    )  
               SET @c_FoundTaskdetailkey = ''
         END   
         
         IF ISNULL(@c_FoundTaskdetailkey,'') <> ''
         BEGIN
            SET @c_DoCombineTask = 'Y'
            SET @n_IncreaseQty = 0
            SET @n_IncreaseSystemQty = 0
            
            --Combine task based on extra qty of existing task
            IF @c_CombineTasks IN('Y','C') --NJOW06
            BEGIN
               IF @n_FoundExtraQty < @n_SystemQty AND @c_FoundPIckMethod = 'FP' --insufficient qty with full pallet. create new task
               BEGIN
                  SET @c_DoCombineTask = 'N'
                  
                  /*
                  IF @n_FoundExtraQty > 0
                  BEGIN
                     SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
                     FROM LOTXLOCXID (NOLOCK)           
                     WHERE Storerkey = @c_Storerkey
                     AND Sku = @c_Sku
                     AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
                     AND Loc = @c_FromLoc
                     AND ID = @c_FromID  
                     
                     IF @n_Qty > @n_QtyAvailable 
                     BEGIN
                        SET @n_Qty = @n_Qty - @n_FoundExtraQty
                     END                  
      
                     --round up to full carton        
                     IF @c_RoundUpQty = 'FC' AND @n_Casecnt > 0
                     BEGIN
                        SET @n_FullPackQty = CEILING(@n_Qty/ (@n_Casecnt * 1.00)) * @n_Casecnt
                     
                        SET @n_RoundUpQty = @n_FullPackQty - @n_Qty
                     
                        IF @n_RoundUpQty > 0
                        BEGIN         
                           SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
                           FROM LOTXLOCXID (NOLOCK)           
                           WHERE Storerkey = @c_Storerkey
                           AND Sku = @c_Sku
                           AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
                           AND Loc = @c_FromLoc
                           AND ID = @c_FromID      		
                           
                           IF (@n_QtyAvailable + @n_FoundExtraQty) >= @n_RoundUpQty
                           BEGIN
                              SET @n_Qty = @n_FullPackQty              
                           END
                        END         
                     END                            
                  END
                  */               
               END    
               ELSE IF @n_FoundExtraQty < @n_SystemQty AND @c_FoundPIckMethod = 'PP' --insufficient qty with partial pallet. increase task qty.
               BEGIN
                  SET @n_IncreaseSystemQty = @n_SystemQty
                  
                  IF @c_CombineTasks = 'C' AND @n_FoundExtraQty = 0 AND @c_RoundUpQty = 'FC' AND @n_Casecnt > 0 --NJOW12           
                  BEGIN      
                     SET @n_IncreaseQty = @n_SystemQty           
                     SET @n_RoundUpQty =  @n_Casecnt - ((@n_FoundQty + @n_IncreaseQty) % @n_Casecnt)
                     
                     IF @n_RoundUpQty = @n_Casecnt
                     	  SET @n_RoundUpQty = 0
                     
                     --round up to full case
                     SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
                     FROM LOTXLOCXID (NOLOCK)           
                     WHERE Storerkey = @c_Storerkey
                     AND Sku = @c_Sku
                     AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
                     AND Loc = @c_FromLoc
                     AND ID = @c_FromID      		
                     
                     IF @n_QtyAvailable >= @n_RoundUpQty
                     BEGIN
                        SET @n_IncreaseQty = @n_IncreaseQty + @n_RoundUpQty              
                     END                                                         
                  END         
                  ELSE  
                     SET @n_IncreaseQty = @n_SystemQty - @n_FoundExtraQty 
                  
                  SET @n_QtyReplen = 0
               
                  --round up to full carton        
                  IF @c_RoundUpQty = 'FC' AND @n_Casecnt > 0
                     AND @c_CombineTasks <> 'C'  --NJOW12  'C' usually combine to the task per carton. no need round up again.
                  BEGIN
                     SET @n_FullPackQty = CEILING(@n_IncreaseQty / (@n_Casecnt * 1.00)) * @n_Casecnt
                     
                     SET @n_RoundUpQty = @n_FullPackQty - @n_IncreaseQty
                     
                     IF @n_RoundUpQty > 0
                     BEGIN         
                        SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
                        FROM LOTXLOCXID (NOLOCK)           
                        WHERE Storerkey = @c_Storerkey
                        AND Sku = @c_Sku
                        AND (Lot = @c_Lot OR ISNULL(@c_Lot,'') = '')
                        AND Loc = @c_FromLoc
                        AND ID = @c_FromID      		
                        
                        IF @n_QtyAvailable >= @n_RoundUpQty
                        BEGIN
                           SET @n_IncreaseQty = @n_FullPackQty              
                        END
                     END  
                  END
                  
                  --Idendify pickmethod full pallet(FP) or partial pallet(PP)  
                  IF CHARINDEX('?', @c_PickMethod) > 0
                  BEGIN
                     SET @n_QtyAvailable = 0 --NJOW09
                     SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked) 
                     FROM LOTXLOCXID (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     AND Loc = @c_FromLoc
                     AND ID = @c_FromID
                     
                     IF CHARINDEX('?ROUNDUP', @c_PickMethod) > 0 AND (@n_FoundQty + @n_IncreaseQty) <> (@n_FoundSystemQty + @n_IncreaseSystemQty)
                        SET @n_QtyAvailable = @n_QtyAvailable - ((@n_FoundQty + @n_IncreaseQty) - (@n_FoundSystemQty + @n_IncreaseSystemQty)) --qty available exclude round up full carton/pallet qty
                  
                     IF CHARINDEX('?TASKQTY', @c_PickMethod) > 0 
                        SET @n_QtyAvailable = @n_QtyAvailable - (@n_FoundQty + @n_IncreaseQty)  --qty available exclude all task qty
                     
                     IF @n_QtyAvailable <= 0 
                   	    SET @c_PickMethod = 'FP'         	  
                     ELSE
                        SET @c_PickMethod = 'PP'                             
                  END             
                              
                  IF @c_ReserveQtyReplen IN('TASKQTY','ROUNDUP') AND ISNULL(@c_Lot,'') <> ''
                  BEGIN
                     IF @c_ReserveQtyReplen = 'TASKQTY'
                        SET @n_ReserveQtyReplen = @n_IncreaseQty
                     ELSE   
                        IF @c_CombineTasks = 'C' AND @n_FoundExtraQty = 0 AND @c_RoundUpQty = 'FC' AND @n_Casecnt > 0 --NJOW12
                           SET @n_ReserveQtyReplen = (@n_FoundQty + @n_IncreaseQty) - (@n_FoundSystemQty + @n_IncreaseSystemQty)
                        ELSE
                           SET @n_ReserveQtyReplen = @n_IncreaseQty - @n_IncreaseSystemQty
                        
                     SET @n_QtyReplen = @n_ReserveQtyReplen
                  END
                     
                  IF @c_CallSource = 'WAVE'   
                     SET @c_Message03  = 'WV:' + @c_Wavekey 
                  
                  IF @c_CallSource = 'LOADPLAN' 
                     SET @c_Message03  = 'LP:' + @c_Loadkey
                              
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty + @n_IncreaseQty,
                      SystemQty = SystemQty + @n_IncreaseSystemQty,
                      PendingMoveIn = PendingMoveIn + CASE WHEN @c_ReservePendingMoveIn = 'Y' AND ISNULL(@c_ToLoc,'') <> '' THEN
                                                            @n_IncreaseQty ELSE 0 END,
                      QtyReplen = QtyReplen + @n_QtyReplen,
                      PickMethod = CASE WHEN CHARINDEX('?', @c_PickMethod) > 0 THEN @c_PickMethod ELSE PickMethod END,
                      Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN @c_Message03 ELSE Message03 END,
                      Priority = @c_MergedTaskPriority --NJOW13
                  WHERE Taskdetailkey = @c_FoundTaskdetailkey
                  
                  SELECT @n_err = @@ERROR
               
                  IF @n_err <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81015   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END             
               END
               ELSE
               BEGIN
                  --NJOW06 Start
                  SET @n_IncreaseSystemQty = @n_SystemQty
                  SET @n_QtyReplen = 0
                  SET @n_ReserveQtyReplen = 0
      
                  IF @c_ReserveQtyReplen = 'ROUNDUP' AND ISNULL(@c_Lot,'') <> ''
                  BEGIN
                     SET @n_ReserveQtyReplen = @n_SystemQty                     
                  END
                  --NJOW06 End
                                   
                  IF @c_CallSource = 'WAVE'   
                     SET @c_Message03  = 'WV:' + @c_Wavekey
                  
                  IF @c_CallSource = 'LOADPLAN' 
                     SET @c_Message03  = 'LP:' + @c_Loadkey
                              
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN @c_Message03 ELSE Message03 END,
                      SystemQty = SystemQty + @n_IncreaseSystemQty,
                      QtyReplen = CASE WHEN QtyReplen - @n_ReserveQtyReplen < 0 THEN 0 ELSE QtyReplen - @n_ReserveQtyReplen END,
                      Priority = @c_MergedTaskPriority --NJOW13                      
                  WHERE Taskdetailkey = @c_FoundTaskdetailkey
                  
                  SELECT @n_err = @@ERROR
               
                  IF @n_err <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81016   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END                           
               END
            END
      
            --Merge to existing task without based on extra qty
            IF @c_CombineTasks = 'M'
            BEGIN
               SET @n_IncreaseSystemQty = @n_SystemQty
               SET @n_IncreaseQty = @n_Qty 
      
               --Idendify pickmethod full pallet(FP) or partial pallet(PP)  
               IF CHARINDEX('?', @c_PickMethod) > 0
               BEGIN
                  SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked) 
                  FROM LOTXLOCXID (NOLOCK)
                  WHERE Storerkey = @c_Storerkey
                  AND Loc = @c_FromLoc
                  AND ID = @c_FromID
                  
                  IF CHARINDEX('?ROUNDUP', @c_PickMethod) > 0 AND (@n_FoundQty + @n_IncreaseQty) <> (@n_FoundSystemQty + @n_IncreaseSystemQty)  
                     SET @n_QtyAvailable = @n_QtyAvailable - ((@n_FoundQty + @n_IncreaseQty) - (@n_FoundSystemQty + @n_IncreaseSystemQty)) --qty available exclude round up full carton/pallet qty
               
                  IF CHARINDEX('?TASKQTY', @c_PickMethod) > 0 
                     SET @n_QtyAvailable = @n_QtyAvailable - (@n_FoundQty + @n_IncreaseQty)  --qty available exclude all task qty
                  
                  IF @n_QtyAvailable <= 0 
                	    SET @c_PickMethod = 'FP'         	  
                  ELSE
                     SET @c_PickMethod = 'PP'                             
      
                  IF @c_ReserveQtyReplen IN('TASKQTY','ROUNDUP') AND ISNULL(@c_Lot,'') <> ''
                  BEGIN
                     IF @c_ReserveQtyReplen = 'TASKQTY'
                        SET @n_ReserveQtyReplen = @n_IncreaseQty
                     ELSE   
                        SET @n_ReserveQtyReplen = @n_IncreaseQty - @n_IncreaseSystemQty
                        
                     SET @n_QtyReplen = @n_ReserveQtyReplen
                  END
                     
                  IF @c_CallSource = 'WAVE'   
                     SET @c_Message03  = 'WV:' + @c_Wavekey 
                  
                  IF @c_CallSource = 'LOADPLAN' 
                     SET @c_Message03  = 'LP:' + @c_Loadkey
                              
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty + @n_IncreaseQty,
                      SystemQty = SystemQty + @n_IncreaseSystemQty,
                      PendingMoveIn = PendingMoveIn + CASE WHEN @c_ReservePendingMoveIn = 'Y' AND ISNULL(@c_ToLoc,'') <> '' THEN
                                                            @n_IncreaseQty ELSE 0 END,
                      QtyReplen = QtyReplen + @n_QtyReplen,
                      PickMethod = CASE WHEN CHARINDEX('?', @c_PickMethod) > 0 THEN @c_PickMethod ELSE PickMethod END,
                      Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN @c_Message03 ELSE Message03 END,
                      Priority = @c_MergedTaskPriority --NJOW13                      
                  WHERE Taskdetailkey = @c_FoundTaskdetailkey
                  
                  SELECT @n_err = @@ERROR
               
                  IF @n_err <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81016   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END             
               END             
            END
            
            IF @c_DoCombineTask = 'Y'
               SET @c_Taskdetailkey = @c_FoundTaskdetailkey
         END   
      END
      
 	    --Generate taskdetailkey   
      IF @n_continue IN(1,2) 
         AND @c_DoCombineTask <> 'Y' --NJOW04
      BEGIN   	
      	  IF ISNULL(@c_TaskDetailKey,'') = ''
      	  BEGIN
            SELECT @b_success = 1  
            EXECUTE nspg_getkey  
               "TaskDetailKey"  
               , 10  
               , @c_taskdetailkey OUTPUT  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
               
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END
         END  
      END
      
      --Insert taskdetail
      IF @n_continue IN(1,2) 
         AND @c_DoCombineTask <> 'Y' --NJOW04
      BEGIN
         INSERT TASKDETAIL  
          (  
            TaskDetailKey  
           ,TaskType       
           ,Storerkey      
           ,Sku            
           ,Lot            
           ,UOM            
           ,UOMQty         
           ,Qty            
           ,FromLoc        
           ,LogicalFromLoc 
           ,FromID         
           ,ToLoc          
           ,LogicalToLoc   
           ,ToID           
           ,Caseid         
           ,PickMethod     
           ,Status         
           ,StatusMsg      
           ,Priority       
           ,SourcePriority 
           ,Holdkey        
           ,UserKey        
           ,UserPosition   
           ,UserKeyOverRide
           ,StartTime      
           ,EndTime        
           ,SourceType     
           ,SourceKey      
           ,PickDetailKey  
           ,OrderKey       
           ,OrderLineNumber
           ,ListKey        
           ,WaveKey        
           ,ReasonKey      
           ,Message01      
           ,Message02      
           ,Message03      
           ,SystemQty      
           ,RefTaskKey     
           ,LoadKey        
           ,AreaKey        
           ,DropID         
           ,TransitCount   
           ,TransitLOC     
           ,FinalLOC       
           ,FinalID        
           ,Groupkey     
           ,QtyReplen  
           ,PendingMoveIn        
          )  
          VALUES  
          (  
            @c_TaskDetailKey  
           ,@c_TaskType       
           ,@c_Storerkey      
           ,@c_Sku            
           ,@c_Lot            
           ,@c_UOM            
           ,@n_UOMQty         
           ,@n_Qty            
           ,@c_FromLoc        
           ,@c_LogicalFromLoc 
           ,@c_FromID         
           ,@c_ToLoc          
           ,@c_LogicalToLoc   
           ,@c_ToID           
           ,@c_Caseid         
           ,@c_PickMethod     
           ,@c_Status         
           ,@c_StatusMsg      
           ,@c_Priority       
           ,@c_SourcePriority 
           ,@c_Holdkey        
           ,@c_UserKey        
           ,@c_UserPosition   
           ,@c_UserKeyOverRide
           ,@d_StartTime      
           ,@d_EndTime        
           ,@c_SourceType     
           ,@c_SourceKey      
           ,@c_PickDetailKey  
           ,@c_OrderKey       
           ,@c_OrderLineNumber
           ,@c_ListKey        
           ,@c_WaveKey        
           ,@c_ReasonKey      
           ,@c_Message01      
           ,@c_Message02      
           ,@c_Message03      
           ,@n_SystemQty      
           ,@c_RefTaskKey     
           ,@c_LoadKey        
           ,@c_AreaKey        
           ,@c_DropID         
           ,@n_TransitCount   
           ,@c_TransitLOC     
           ,@c_FinalLOC       
           ,@c_FinalID        
           ,@c_Groupkey              
           ,@n_QtyReplen
           ,@n_PendingMoveIn
          )   	
          
          SET @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN 
             SELECT @n_continue = 3  
             SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81010  
             SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Taskdetail Failed' + ' ( '+  
                                ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
          END     
      END   
      
      --Update taskdetailkey to replenishment and change to confirm status
      IF @n_continue IN(1,2) AND @c_LinkTaskToReplen = 'Y' AND @c_CallSource = 'REPLENISHMENT' 
      BEGIN
         IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) WHERE Replenishmentkey = @c_Sourcekey AND Storerkey = @c_Storerkey)
         BEGIN
            UPDATE REPLENISHMENT WITH (ROWLOCK)
            SET ReplenNo = @c_Taskdetailkey,
                Confirmed = 'Y',
                ArchiveCop = NULL
            WHERE Replenishmentkey = @c_Sourcekey
            AND Storerkey = @c_Storerkey
            
            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END 
         END   	   	
      END
               
      --Update taskdetailkey to pickdetail(Y) or pickdetail_wip(WIP) 
      IF @n_continue IN(1,2) AND @c_LinkTaskToPick IN('Y','WIP') AND @c_CallSource IN ('WAVE','LOADPLAN')  
      BEGIN
          SELECT  @n_TaskQty = @n_SystemQty   --NJOW01      
          
          IF ISNULL(@c_LinkTaskToPick_SQL,'') <> ''
          BEGIN
              IF LEFT(LTRIM(@c_LinkTaskToPick_SQL), 4) <> 'AND ' AND (CHARINDEX('ORDER BY', LTRIM(@c_LinkTaskToPick_SQL)) = 0 OR CHARINDEX('ORDER BY', LTRIM(@c_LinkTaskToPick_SQL)) > 1)
                 SET @c_LinkTaskToPick_SQL  = 'AND ' + RTRIM(LTRIM(@c_LinkTaskToPick_SQL)) --NJOW08

          	  IF CHARINDEX('ORDER BY', @c_LinkTaskToPick_SQL) = 0
          	     SET @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL + CHAR(13) + ' ORDER BY ORDERS.Loadkey, ORDERS.Orderkey, PICKDETAIL.Pickdetailkey ' 
          END
          ELSE
          BEGIN
         	     SET @c_LinkTaskToPick_SQL = ' ORDER BY ORDERS.Loadkey, ORDERS.Orderkey, PICKDETAIL.Pickdetailkey ' 
          END
          
          IF @c_CallSource = 'WAVE'
             SET @c_LinkTaskToPick_SQL  = ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' + CHAR(13) +  @c_LinkTaskToPick_SQL 
      
          IF @c_CallSource = 'LOADPLAN'
             SET @c_LinkTaskToPick_SQL  = ' AND ORDERS.Loadkey = @c_Loadkey ' + CHAR(13) + @c_LinkTaskToPick_SQL 
      
          --NJOW03     
          IF @c_LinkTaskToPick IN('WIP') AND  ISNULL(@c_WIP_RefNo, '') <> ''  
             SET @c_LinkTaskToPick_SQL  = ' AND PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + CHAR(13) +  @c_LinkTaskToPick_SQL             
          TRUNCATE TABLE #TMP_PICK
          
          SET @c_SQL = ' INSERT INTO #TMP_PICK (Pickdetailkey, Qty)
                         SELECT PICKDETAIL.Pickdetailkey, 
                                PICKDETAIL.Qty 
                         FROM ' + RTRIM(@c_PickTableName) + ' PICKDETAIL (NOLOCK) 
                         JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey
                         JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc                
                         JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc '  +
                         CASE WHEN @c_CallSource = 'WAVE' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +
                       ' WHERE ISNULL(PICKDETAIL.Taskdetailkey,'''') = ''''
                         AND PICKDETAIL.Storerkey = @c_Storerkey
                         AND (PICKDETAIL.Sku = @c_Sku OR ISNULL(@c_Sku,'''') = '''')
                         AND (PICKDETAIL.Lot = @c_Lot OR ISNULL(@c_Lot,'''') = '''')
                         AND PICKDETAIL.Loc = @c_FromLoc
                         AND PICKDETAIL.ID = @c_FromID ' + CHAR(13) + @c_LinkTaskToPick_SQL                         
                         --AND PICKDETAIL.UOM = @c_UOM '     
						 
						 print('@c_SQL:::::'+@c_SQL)

						 print('@c_Storerkey')
						 print(@c_Storerkey)
						  print('@c_Sku')
						  print(@c_Sku)
						  print( '@c_Lot')
						  print( @c_Lot)
					      print( '@c_FromLoc')
						  print( @c_FromLoc)
						   print( '@c_FromID')
						  print( @c_FromID)
					     print( '@c_UOM')
						 print( @c_UOM)
		  
          EXEC sp_executesql @c_SQL,
               N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Lot NVARCHAR(10), @c_FromLoc NVARCHAR(10), 
                 @c_FromID NVARCHAR(18), @c_UOM NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Loadkey NVARCHAR(10), @c_DropID NVARCHAR(20), @c_Orderkey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
               @c_Storerkey,
               @c_Sku,
               @c_Lot,
               @c_FromLoc,
               @c_FromID,
               @c_UOM,
               @c_Wavekey,
               @c_Loadkey,
               @c_DropID, --NJOW01
               @c_Orderkey, --NJOW02
               @c_WIP_RefNo --NJOW03
               
          DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT Pickdetailkey, Qty
             FROM #TMP_PICK
             ORDER BY rowid
      
          OPEN CUR_Pick  
      
          FETCH NEXT FROM CUR_Pick INTO @c_CurrPickdetailkey, @n_PickQty

		  print('@@FETCH_STATUS')
          print(@@FETCH_STATUS)
		  print('@n_TaskQty')
		  print(@n_TaskQty)
          WHILE @@FETCH_STATUS = 0 AND @n_TaskQty > 0 AND @n_continue IN(1,2) 
          BEGIN   
		     print('@n_PickQty')
			 print(@n_PickQty)
			  print('@n_TaskQty')
			  print(@n_TaskQty)
             IF @n_PickQty <= @n_TaskQty
             BEGIN
                IF @c_LinkTaskToPick IN('WIP') AND  ISNULL(@c_WIP_RefNo, '') <> ''  --NJOW03  
             	    SET @c_SQL = 'UPDATE ' + RTRIM(@c_PickTableName) + ' WITH (ROWLOCK) ' +
                                ' SET Taskdetailkey =  @c_TaskdetailKey,' +
                                ' editdate =  getdate(), ' +
                                ' TrafficCop = NULL ' +
                                ' WHERE Pickdetailkey = @c_CurrPickdetailKey ' +
                                ' AND WIP_Refno = @c_WIP_RefNo ' 
                ELSE
             	    SET @c_SQL = 'UPDATE ' + RTRIM(@c_PickTableName) + ' WITH (ROWLOCK) ' +
                                ' SET Taskdetailkey =  @c_TaskdetailKey,' +
                                ' editdate =  getdate(), ' +
                                ' TrafficCop = NULL ' +
                                ' WHERE Pickdetailkey = @c_CurrPickdetailKey ' 
                                                                         
                EXEC sp_executesql @c_SQL,
               N'@c_CurrPickdetailKey NVARCHAR(10), @c_TaskdetailKey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)', 
               @c_CurrPickdetailKey,
               @c_TaskdetailKey,
               @c_WIP_RefNo  --NJOW03               
                
                SELECT @n_err = @@ERROR
                IF @n_err <> 0 
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   BREAK
               END 
               SELECT @n_TaskQty = @n_TaskQty - @n_PickQty
             END
             ELSE
             BEGIN  -- pickqty > taskqty   
                SELECT @n_SplitQty = @n_PickQty - @n_TaskQty
                
                EXECUTE nspg_GetKey      
                   'PICKDETAILKEY',      
                   10,      
                   @c_NewPickdetailKey OUTPUT,         
                   @b_success OUTPUT,      
                   @n_err OUTPUT,      
                   @c_errmsg OUTPUT      
             
                IF NOT @b_success = 1      
                BEGIN
                   SELECT @n_continue = 3      
                END                  
                
                IF @c_LinkTaskToPick IN('WIP') 
                BEGIN       
                   --NJOW03
                   SET @c_SQL = 'INSERT INTO ' + RTRIM(@c_PickTableName)  + 
                                           ' (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                              Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                              DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                              WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                              TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo ' +     --WL01  
                                              CASE WHEN @c_IncludeChannel_ID = 'Y' THEN  ',Channel_ID ' ELSE ' ' END +  --WL01      
                                 ') 
                                 SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                        Storerkey, Sku, AltSku, UOM, CASE UOM WHEN ''6'' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                                        '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                                        WaveKey, EffectiveDate, ''9'', ShipFlag, PickSlipNo,                                                               
                                        TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo ' +     --WL01
                                        CASE WHEN @c_IncludeChannel_ID = 'Y' THEN  ',Channel_ID ' ELSE ' ' END +  --WL01
                                 '                                                     
                                 FROM ' + RTRIM(@c_PickTableName) + ' (NOLOCK)                                                                                             
                                 WHERE PickdetailKey = @c_CurrPickdetailKey '             
                END
                ELSE
                BEGIN
                   SET @c_SQL = 'INSERT INTO ' + RTRIM(@c_PickTableName)  + 
                                           ' (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                              Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                              DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                              WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                              TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey ' +                --WL01
                                              CASE WHEN @c_IncludeChannel_ID = 'Y' THEN  ',Channel_ID ' ELSE ' ' END +  --WL01   
                                 ')               
                                 SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                        Storerkey, Sku, AltSku, UOM, CASE UOM WHEN ''6'' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                                        '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                                        WaveKey, EffectiveDate, ''9'', ShipFlag, PickSlipNo,                                                               
                                        TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey ' +                --WL01       
                                        CASE WHEN @c_IncludeChannel_ID = 'Y' THEN  ',Channel_ID ' ELSE ' ' END +  --WL01    
                                 '                               
                                 FROM ' + RTRIM(@c_PickTableName) + ' (NOLOCK)                                                                                             
                                 WHERE PickdetailKey = @c_CurrPickdetailKey '             
                END                     
                             
                EXEC sp_executesql @c_SQL,
                     N'@c_CurrPickdetailkey NVARCHAR(10), @c_NewpickDetailKey NVARCHAR(10), @n_SplitQty INT', 
                     @c_CurrPickdetailkey,
                     @c_NewpickDetailKey,
                     @n_SplitQty
                                   
                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0     
                BEGIN     
                   SELECT @n_continue = 3      
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82120   
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   BREAK    
                END
             
                IF @c_LinkTaskToPick IN ('WIP') AND ISNULL(@c_WIP_RefNo, '') <> ''  --NJOW03
             	    SET @c_SQL = 'UPDATE ' + RTRIM(@c_PickTableName) + ' WITH (ROWLOCK) ' +
                                ' SET Taskdetailkey = @c_TaskdetailKey, ' +
                                ' TrafficCop = NULL, ' +
                                ' Editdate = getdate(), ' +
                                ' UOMQTY = CASE UOM WHEN ''6'' THEN @n_TaskQty ELSE UOMQty END, ' +
                                ' Qty = @n_TaskQty ' + 
                                ' WHERE Pickdetailkey = @c_CurrPickdetailKey ' +
                                ' AND WIP_Refno = @c_WIP_RefNo ' 
                ELSE
             	    SET @c_SQL = 'UPDATE ' + RTRIM(@c_PickTableName) + ' WITH (ROWLOCK) ' +
                                ' SET Taskdetailkey = @c_TaskdetailKey, ' +
                                ' TrafficCop = NULL, ' +
                                ' Editdate = getdate(), ' +
                                ' UOMQTY = CASE UOM WHEN ''6'' THEN @n_TaskQty ELSE UOMQty END, ' +
                                ' Qty = @n_TaskQty ' + 
                                ' WHERE Pickdetailkey = @c_CurrPickdetailKey '
                                                      
                EXEC sp_executesql @c_SQL,
                     N'@c_CurrPickdetailKey NVARCHAR(10), @c_TaskdetailKey NVARCHAR(10), @n_TaskQty INT, @c_WIP_RefNo NVARCHAR(30)', 
                     @c_CurrPickdetailKey, 
                     @c_TaskdetailKey,
                     @n_TaskQty,
                     @c_WIP_RefNo --NJOW03
                                                    
                SELECT @n_err = @@ERROR
                IF @n_err <> 0 
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (isp_InsertTaskDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   BREAK
                END
                
                SELECT @n_taskQty = 0
             END     
      
             FETCH NEXT FROM CUR_Pick INTO @c_CurrPickdetailkey, @n_PickQty
          END -- While TaskQty > 0
          CLOSE CUR_Pick
          DEALLOCATE CUR_Pick      
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_InsertTaskDetail'		
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