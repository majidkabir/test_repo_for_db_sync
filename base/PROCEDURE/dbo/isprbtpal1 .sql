SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispRBTPAL1                                         */    
/* Creation Date: 13-Nov-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose: Post Allocation Process, Do thing that the original         */    
/*          Allocation Strategy not able to do                          */
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */    
/* 14-Aug-2018  NJOW01  1.0   Swap pickdetail lot when move from Robot  */
/*                            to Pick or Robot stag to Robot            */
/* 18-Aug-2018  SWT01   1.1   Update ID to BLANK when Change from Bulk  */
/* 26-Feb-2019  NJOW02  1.2   WMS-7506 B2B skip move loc                */
/************************************************************************/    
CREATE PROC [dbo].[ispRBTPAL1 ]      
     @c_OrderKey    NVARCHAR(10)    
   , @c_LoadKey     NVARCHAR(10)  
   , @b_Success     INT =0 OUTPUT      
   , @n_Err         INT =0 OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) ='' OUTPUT      
   , @b_debug       INT = 0          
AS      
BEGIN      
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF     
   
   DECLARE  @n_Continue          INT      
           ,@n_StartTCnt         INT  -- Holds the current transaction count  
           ,@c_Facility          NVARCHAR(5) = ''
           ,@c_SuperOrderFlag    NVARCHAR(1) = 'N'
           ,@n_RobotLoc_Qty      INT = 0    
           ,@n_RobotStage_Qty    INT = 0 
           ,@n_NormBulkLoc_Qty   INT = 0 
           ,@n_NormPickLoc_Qty   INT = 0 
           ,@c_RobotLoc          NVARCHAR(10) = ''
           ,@c_PickLoc           NVARCHAR(10) = ''
           ,@c_PickDetailKey     NVARCHAR(18) = ''
           ,@c_StorerKey         NVARCHAR(15) = ''
           ,@c_SKU               NVARCHAR(20) = ''
           ,@c_PDet_SKU          NVARCHAR(20) = ''
           ,@n_QtyAllocated      INT = 0 
           ,@n_QtyAvailable      INT = 0
           ,@c_AllocateType      VARCHAR(10) = ''
           ,@c_DocKey            NVARCHAR(10) = '' 
           ,@c_LOT               NVARCHAR(10) = ''
           ,@c_ID                NVARCHAR(18) = '' 
           ,@c_B2B_Order         CHAR(1) = 'N'   

   --NJOW01
   DECLARE @n_PickQty          INT,  
           @c_fLot             NVARCHAR(10),
           @c_fId              NVARCHAR(18),
           @n_fQtyAvailable    INT, 
           @n_fLotQtyAvailable INT,
           @c_CreateNewPick    NCHAR(1),
           @c_NewPickdetailKey NVARCHAR(10),
           @n_QtyTake          INT             
   			              
   DECLARE @b_Allocate_From_Pick_Loc BIT = 0 
              
   SET @n_StartTCnt = @@TRANCOUNT 
   SET @n_Continue = 1   
         
   -- Check whether it's consolidate orders or single order
   IF ISNULL(RTRIM(@c_LoadKey), '') <> '' AND ISNULL(RTRIM(@c_OrderKey), '') = ''
   BEGIN
   	SELECT @c_SuperOrderFlag = ISNULL(lp.SuperOrderFlag,'N'), 
   	       @c_Facility = lp.facility
   	FROM LoadPlan AS lp WITH(NOLOCK) 
   	WHERE lp.LoadKey = @c_LoadKey 
   
      IF @c_SuperOrderFlag <> 'Y'
         SET @c_SuperOrderFlag = 'N'
   END
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') = '' AND ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
   	SET @c_AllocateType = 'ORDER'
   	SET @c_SuperOrderFlag = 'N' 
   END  
   ELSE 
   BEGIN
   	SET @c_SuperOrderFlag = 'N' 
   END
   
   SET @c_B2B_Order = 'N'
   
   --NJOW02
   IF EXISTS(SELECT 1 
                FROM LoadPlanDetail LPD WITH(NOLOCK) 
   	            JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = LPD.OrderKey
                WHERE LPD.LoadKey = CASE WHEN ISNULL(@c_LoadKey,'') <> '' THEN @c_Loadkey ELSE LPD.Loadkey END 
                AND O.Orderkey = CASE WHEN ISNULL(@c_OrderKey,'') <> '' THEN @c_Orderkey ELSE O.Orderkey END 
                AND o.DocType='N')
   BEGIN
     	SET @c_B2B_Order = 'Y'
     	GOTO EXIT_SP
   END 
      
   IF @c_SuperOrderFlag = 'Y'  
   BEGIN
   	SET @c_AllocateType = 'LOAD'

      IF EXISTS(SELECT 1 
                FROM LoadPlanDetail LPD WITH(NOLOCK) 
   	          JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = LPD.OrderKey
                WHERE LPD.LoadKey = @c_LoadKey 
                AND o.DocType='N')
      BEGIN
      	SET @c_B2B_Order = 'Y'
      END 
                
   	DECLARE CUR_LOAD_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	SELECT DISTINCT LPD.LoadKey, O.StorerKey, O.Facility, OD.SKU   
   	FROM LoadPlanDetail LPD WITH(NOLOCK) 
   	JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = LPD.OrderKey 
   	JOIN ORDERDETAIL AS OD WITH(NOLOCK) ON OD.OrderKey = o.OrderKey 
   	WHERE LPD.LoadKey = @c_LoadKey    		
   	AND OD.QtyAllocated > 0 
   	
   	
   END
   ELSE
   BEGIN
   	SET @c_AllocateType = 'ORDER'

      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
      BEGIN
   	   DECLARE CUR_LOAD_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	   SELECT OrderKey, StorerKey, Facility, ''
   	   FROM ORDERS WITH(NOLOCK)
   	   WHERE OrderKey = @c_OrderKey    		
      END
      ELSE
      BEGIN
   	   DECLARE CUR_LOAD_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	   SELECT lpd.OrderKey, o.StorerKey, o.Facility, ''
   	   FROM LoadPlanDetail AS lpd WITH(NOLOCK)
   	   JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = LPD.OrderKey 
   	   WHERE lpd.LoadKey = @c_LoadKey    			
      END   	
   END   
   
   OPEN CUR_LOAD_ORDER
   	
   FETCH FROM CUR_LOAD_ORDER INTO @c_DocKey, @c_StorerKey, @c_Facility, @c_SKU
   	
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	SET @n_RobotLoc_Qty     = 0
      SET @n_RobotStage_Qty   = 0
      SET @n_NormBulkLoc_Qty  = 0
      SET @n_NormPickLoc_Qty  = 0 

   	IF @b_debug = 1
   	BEGIN
   		PRINT '   @c_AllocateType: ' + @c_AllocateType + ' B2B: ' + @c_B2B_Order
   	END

      
      IF @c_AllocateType = 'ORDER'
      BEGIN
   	   -- If all qty in ROBOT location? 
   	   SELECT @n_RobotLoc_Qty   = SUM(CASE WHEN l.LocationCategory = 'ROBOT' AND l.LocationType='DYNPPICK' THEN p.Qty ELSE 0 END), 
   		       @n_RobotStage_Qty = SUM(CASE WHEN l.LocationCategory = 'ROBOT' AND l.LocationType='ROBOTSTG' THEN p.Qty ELSE 0 END),
   		       @n_NormBulkLoc_Qty  = SUM(CASE WHEN l.LocationCategory <> 'ROBOT' AND SL.LocationType NOT IN ('PICK','CASE') THEN p.Qty ELSE 0 END), 
   		       @n_NormPickLoc_Qty  = SUM(CASE WHEN l.LocationCategory <> 'ROBOT' AND SL.LocationType IN ('PICK','CASE') THEN p.Qty ELSE 0 END)
   	   FROM PICKDETAIL AS p WITH(NOLOCK)
   	   JOIN SKUxLOC AS sl WITH(NOLOCK) ON sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku AND sl.Loc = p.Loc  
   	   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc    	   
   	   WHERE p.OrderKey = @c_DocKey 
   	   AND   p.UOM IN ('6','7')       	
      END
      ELSE
      BEGIN
   	   SELECT @n_RobotLoc_Qty   = SUM(CASE WHEN l.LocationCategory = 'ROBOT' AND l.LocationType='DYNPPICK' THEN p.Qty ELSE 0 END), 
   		       @n_RobotStage_Qty = SUM(CASE WHEN l.LocationCategory = 'ROBOT' AND l.LocationType='ROBOTSTG' THEN p.Qty ELSE 0 END),
   		       @n_NormBulkLoc_Qty  = SUM(CASE WHEN l.LocationCategory <> 'ROBOT' AND SL.LocationType NOT IN ('PICK','CASE') THEN p.Qty ELSE 0 END), 
   		       @n_NormPickLoc_Qty  = SUM(CASE WHEN l.LocationCategory <> 'ROBOT' AND SL.LocationType IN ('PICK','CASE') THEN p.Qty ELSE 0 END)
   	   FROM PICKDETAIL AS p WITH(NOLOCK) 
   	   JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey  
   	   JOIN SKUxLOC AS sl WITH(NOLOCK) ON sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku AND sl.Loc = p.Loc  
   	   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc  
   	   WHERE lpd.LoadKey = @c_DocKey  
   	   AND   p.Storerkey = @c_StorerKey 
   	   AND   p.Sku = @c_SKU 
   	   AND   p.UOM IN ('6','7')       	      	
      END
   		
   	-- If All allocated in ROBOT, and some allocated from ROBOT Stage location 
   	-- Required to do Over Allocation for ROBOT Location 
   	IF (@n_NormBulkLoc_Qty + @n_NormPickLoc_Qty) = 0 AND @n_RobotStage_Qty > 0 
   	BEGIN
   		IF @b_debug = 1
   		BEGIN
   			PRINT ' - NormalLoc_Qty = 0 AND RobotStage_Qty > 0 '
   		END
   		IF @c_AllocateType = 'ORDER'
   		BEGIN
   			DECLARE CUR_PICKDETAIL_STAGE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			SELECT p.PickDetailKey, p.LOT, p.ID, p.SKU   
   			FROM PICKDETAIL AS p WITH(NOLOCK)
   			JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			WHERE p.OrderKey = @c_DocKey 
   		   AND   p.UOM IN ('6','7')
   		   AND   l.LocationCategory = 'ROBOT' 
   		   AND   l.LocationType='ROBOTSTG'    				
   		END
   		ELSE 
   		BEGIN
   			DECLARE CUR_PICKDETAIL_STAGE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			SELECT p.PickDetailKey, p.LOT, p.ID, p.SKU   
   			FROM PICKDETAIL AS p WITH(NOLOCK) 
   			JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey 
   			JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			WHERE lpd.LoadKey = @c_DocKey 
   			AND p.Storerkey = @c_StorerKey 
   			AND p.Sku = @c_SKU  
   		   AND   p.UOM IN ('6','7')
   		   AND   l.LocationCategory = 'ROBOT' 
   		   AND   l.LocationType='ROBOTSTG'    				   				
   		END
   			
   		OPEN CUR_PICKDETAIL_STAGE
   			
   		FETCH FROM CUR_PICKDETAIL_STAGE INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU
   			
   		WHILE @@FETCH_STATUS = 0
   		BEGIN
   			-- Get ROBOT Location
   			SET @c_RobotLoc = ''
   			
   			SELECT TOP 1 
   				@c_RobotLoc = LOC 
   			FROM LOC AS l WITH(NOLOCK) 
   			WHERE l.Facility = @c_Facility 
   			AND l.LocationCategory = 'ROBOT' 
   			AND l.LocationType = 'DYNPPICK'
   			
   			IF @b_debug = 1
   			BEGIN
   				PRINT ' - UPDATE to ROBOT PickDetailKey: ' + @c_PickDetailKey 
   			END
   			
   			-- Change by SHONG 18th Aug 2018 SWT01
   			-- Overallocate with Blank ID
   			IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
   			               WHERE LOT = @c_LOT AND LOC = @c_RobotLoc AND ID = '' )
            BEGIN
            	INSERT INTO LOTxLOCxID (LOT, LOC, ID, StorerKey, SKU, Qty) VALUES (@c_LOT, @c_RobotLoc, '', @c_StorerKey, @c_PDet_SKU, 0)
            END   
            
            IF NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                          WHERE StorerKey = @c_StorerKey 
                          AND SKU = @c_PDet_SKU 
                          AND LOC = @c_RobotLoc)
            BEGIN
            	INSERT INTO SKUxLOC (StorerKey, Sku, Loc, Qty) VALUES (@c_StorerKey, @c_PDet_SKU, @c_RobotLoc, 0)
            END
            
            -- SWT01            			               
   			UPDATE PickDetail WITH (ROWLOCK)
   			   SET LOC = @c_RobotLoc, ID = '', UOM='7', EditDate = GETDATE(), EditWho = SUSER_SNAME(), ToLoc = LOC
   			WHERE PickDetailKey = @c_PickDetailKey 
   			    
			FETCH FROM CUR_PICKDETAIL_STAGE INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU 
   		END   			
   		CLOSE CUR_PICKDETAIL_STAGE
   		DEALLOCATE CUR_PICKDETAIL_STAGE

   	END
   	ELSE IF (@n_NormBulkLoc_Qty + @n_NormPickLoc_Qty) > 0 -- AND (@n_RobotStage_Qty + @n_RobotLoc_Qty) > 0  
   	BEGIN
   		-- If both robot and normal location have allocated qty 
   		-- need to decide whether all allocate from robot location or normal location
   		IF @b_debug = 1
   		BEGIN
   			PRINT ' - (@n_NormBulkLoc_Qty + @n_NormPickLoc_Qty) > 0  '
   		END
   		
   		-- If all qty available from build, pick from bulk   		
   		IF @c_AllocateType = 'ORDER' OR ( @c_B2B_Order = 'Y' AND @c_AllocateType = 'LOAD' ) 
   		BEGIN
   			SET @b_Allocate_From_Pick_Loc = 1
   			
   			IF @c_AllocateType = 'ORDER'
   			BEGIN
   			   DECLARE CUR_CHECK_AVAILABILITY  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.Storerkey, p.Sku, SUM(qty)  
   			   FROM PICKDETAIL AS p WITH(NOLOCK)
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE p.OrderKey = @c_DocKey 
   		      AND   p.UOM IN ('6','7')
   		      AND   l.LocationCategory = 'ROBOT'  
   			   GROUP BY p.Storerkey, p.Sku    				   				
   			END
   			ELSE 
   			BEGIN
   			   DECLARE CUR_CHECK_AVAILABILITY  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.Storerkey, p.Sku, SUM(qty)  
   			   FROM PICKDETAIL AS p WITH(NOLOCK) 
   			   JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey 
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE lpd.LoadKey = @c_DocKey 
   		      AND   p.UOM IN ('6','7')
   		      AND   l.LocationCategory = 'ROBOT'  
   			   GROUP BY p.Storerkey, p.Sku     				
   			END
  			
   			OPEN CUR_CHECK_AVAILABILITY 
   			
   			FETCH FROM CUR_CHECK_AVAILABILITY  INTO @c_StorerKey, @c_SKU, @n_QtyAllocated
   			
   			WHILE @@FETCH_STATUS = 0
   			BEGIN
   				SET @n_QtyAvailable = 0 
   				
   			   SELECT @n_QtyAvailable = ISNULL(SUM(SL.Qty - SL.QtyAllocated - SL.QtyPicked),0) 
   			   FROM SKUxLOC AS SL WITH(NOLOCK)
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc 
   			   WHERE SL.StorerKey = @c_StorerKey 
   			   AND   SL.Sku = @c_SKU  
   			   AND   SL.LocationType IN ('PICK','CASE') 
   			   AND   L.Facility = @c_Facility   			     
   			   AND   L.STATUS = 'OK'
   			   AND   L.LocationFlag = 'NONE' --NJOW01 

   			   IF @b_debug = 1
   			   BEGIN
   			   	PRINT ' - Allocate_From_Pick_Loc: ' + CAST(@b_Allocate_From_Pick_Loc AS VARCHAR)	
   			   	PRINT ' - QtyAvailable: ' + CAST(@n_QtyAvailable AS VARCHAR) + ' QtyAllocated: ' + CAST(@n_QtyAllocated AS VARCHAR)
   			   END
   			   	   			      			   
   			   IF ISNULL(@n_QtyAvailable,0) < @n_QtyAllocated
   			   BEGIN
   			   	SET @b_Allocate_From_Pick_Loc = 0   
   			   	BREAK   			   	
   			   END
   			   
   				FETCH FROM CUR_CHECK_AVAILABILITY  INTO @c_StorerKey, @c_SKU, @n_QtyAllocated
   			END   			
   			CLOSE CUR_CHECK_AVAILABILITY 
   			DEALLOCATE CUR_CHECK_AVAILABILITY    	      		   				
   		END -- IF @c_AllocateType = 'ORDER' OR ( @c_B2B_Order = 'Y' AND @c_AllocateType = 'LOAD' ) 
   		ELSE
   		BEGIN
   			SET @b_Allocate_From_Pick_Loc = 0
   		END   		
   		
   		IF @c_AllocateType = 'ORDER'
   		BEGIN
   			IF EXISTS(SELECT 1   
   			          FROM PICKDETAIL AS p WITH(NOLOCK)
   			          JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			          JOIN SKUxLOC AS sl WITH(NOLOCK) ON p.Storerkey = sl.StorerKey AND p.Sku = sl.Sku AND p.Loc = sl.Loc 
   			          WHERE p.OrderKey = @c_DocKey 
   		             AND   p.UOM ='7'
   		             AND   l.LocationCategory <> 'ROBOT'   
   		             AND   sl.LocationType NOT IN ('PICK','CASE'))
   		   BEGIN
   		   	SET @b_Allocate_From_Pick_Loc = 0
   		   END
   		END
   		ELSE 
   		BEGIN
   			IF EXISTS(SELECT 1   
   			          FROM PICKDETAIL AS p WITH(NOLOCK)
   			          JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey 
   			          JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			          JOIN SKUxLOC AS sl WITH(NOLOCK) ON p.Storerkey = sl.StorerKey AND p.Sku = sl.Sku AND p.Loc = sl.Loc 
   			          WHERE lpd.LoadKey = @c_DocKey 
   		             AND   p.UOM ='7'
   		             AND   l.LocationCategory <> 'ROBOT'   
   		             AND   sl.LocationType NOT IN ('PICK','CASE'))
   		   BEGIN
   		   	SET @b_Allocate_From_Pick_Loc = 0
   		   END
   		END   			
   			   	   	 
   		IF @b_debug = 1
   		BEGIN
   			PRINT ' - @b_Allocate_From_Pick_Loc: ' + CAST(@b_Allocate_From_Pick_Loc AS VARCHAR)
   		END
   		
   		-- If All qty Available in Normal Location, Change PickDetail to allocate from Normal Pick Location
   	   IF @b_Allocate_From_Pick_Loc = 1 AND 
   	      (@c_AllocateType = 'ORDER' OR ( @c_B2B_Order = 'Y' AND @c_AllocateType = 'LOAD' )) 
   	   BEGIN
   			IF @c_AllocateType = 'ORDER'
   			BEGIN   	   	
               DECLARE CUR_PICKDETAIL_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.PickDetailKey, p.Lot, p.ID, p.SKU,
   			          p.Qty --NJOW01
   			   FROM PICKDETAIL AS p WITH(NOLOCK)
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE p.OrderKey = @c_DocKey 
   		      AND   p.UOM IN ('6','7')
   		      AND   l.LocationCategory = 'ROBOT'   	   		  	   		
   			END
   			ELSE 
   			BEGIN
               DECLARE CUR_PICKDETAIL_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.PickDetailKey, p.Lot, p.ID, p.SKU,
   			          P.Qty  --NJOW01
   			   FROM PICKDETAIL AS p WITH(NOLOCK) 
   			   JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey 
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE lpd.LoadKey = @c_DocKey 
   		      AND   p.UOM IN ('6','7')
   		      AND   l.LocationCategory = 'ROBOT'   	   	   				
   			END    			
   			OPEN CUR_PICKDETAIL_PICK
   			
   			FETCH FROM CUR_PICKDETAIL_PICK INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU,
   			                                    @n_PickQty --NJOW01 
   			
   			WHILE @@FETCH_STATUS = 0
   			BEGIN
   				-- Get Pick Location
   				SET @c_PickLoc = ''
   				
   				SELECT TOP 1 
   				   @c_PickLoc = L.LOC
   				FROM LOC AS L WITH (NOLOCK) 
   				JOIN SKUxLOC AS sl WITH(NOLOCK) ON sl.Loc = l.Loc  
   				WHERE l.Facility = @c_Facility
   				AND SL.StorerKey = @c_StorerKey 
   				AND SL.Sku = @c_PDet_SKU 
   				AND SL.LocationType = 'PICK'
   			
   			   IF @c_PickLoc <> ''  
   			   BEGIN
   			      IF @b_debug = 1
   			      BEGIN
   				      PRINT ' - UPDATE to Pick Face, PickDetailKey: ' + @c_PickDetailKey 
   			      END                                     
   			         			      
   			      --NJOW01 Start
            	   DECLARE cur_pickloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            	   SELECT LLI.Lot, LLI.ID, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable,
            	          ISNULL(LOT.LotQtyAVailable,0) - ISNULL(ROBOTLOT.RobotQtyAvailable,0) AS LotQtyAvailable
            	   FROM LOTXLOCXID LLI (NOLOCK)           
            	   LEFT JOIN (SELECT LLI.Lot, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS LotQtyAvailable
                            FROM LOTXLOCXID LLI (NOLOCK)          
                            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
                            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                            JOIN ID (NOLOCK) ON LLI.Id = ID.Id
                            WHERE LOT.STATUS = 'OK' 
                            AND LOC.STATUS = 'OK' 
                            AND ID.STATUS = 'OK'  
                            AND LOC.LocationFlag = 'NONE' 
                            AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) <> 0
                            AND LLI.Storerkey = @c_Storerkey
                            AND LLI.Sku = @c_PDet_SKU
                            AND LOC.Facility = @c_Facility
                            GROUP BY LLI.Lot) AS LOT ON LOT.Lot = LLI.Lot 
                 LEFT JOIN (SELECT LLI.Lot, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS RobotQtyAvailable      
                            FROM LOTXLOCXID LLI (NOLOCK)
                            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                            WHERE LOC.LocationCategory = 'ROBOT'
                            AND LLI.Storerkey = @c_Storerkey
                            AND LLI.Sku = @c_PDet_SKU 
                            AND LOC.Facility = @c_Facility
                            AND LOC.STATUS = 'OK' 
                            AND LOC.LocationFlag = 'NONE' 
                            GROUP BY LLI.Lot
                            HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0) AS ROBOTLOT ON LLI.Lot = ROBOTLOT.Lot                          			         
                 WHERE LLI.Storerkey = @c_Storerkey
   			         AND LLI.Sku = @c_PDet_SKU
   			         AND LLI.Loc = @c_PickLoc
   			         AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked <> 0
   			         ORDER BY QtyAvailable DESC

              OPEN cur_pickloc  
          
              FETCH NEXT FROM cur_pickloc INTO @c_fLot, @c_fId, @n_fQtyAvailable, @n_fLotQtyAvailable
              
              SET @c_CreateNewPick = 'N'
              WHILE @@FETCH_STATUS = 0 AND @n_PickQty > 0
              BEGIN              	
              	 IF @n_PickQty <= @n_fQtyAvailable
              	 BEGIN
              	 	   SET @n_QtyTake = @n_PickQty
              	 END
              	 ELSE IF @n_fQtyAvailable > 0
              	 BEGIN              	 	   
              	 	   SET @n_QtyTake = @n_fQtyAvailable
              	 END
              	 ELSE IF @n_fQtyAvailable < 0 AND @n_fLotQtyAvailable > 0
              	 BEGIN
              	 	   IF @n_PickQty <= @n_fLotQtyAvailable
              	 	      SET @n_QtyTake = @n_PickQty
              	 	   ELSE
              	 	   	  SET @n_QtyTake = @n_fLotQtyAvailable              	 	   
              	 END
              	 
              	 IF @c_CreateNewPick = 'Y'
              	 BEGIN 
              	    EXECUTE nspg_GetKey      
                       'PICKDETAILKEY',      
                       10,      
                       @c_NewPickdetailKey OUTPUT,         
                       @b_success OUTPUT,      
                       @n_err OUTPUT,      
                       @c_errmsg OUTPUT      
                       
   	                INSERT INTO PICKDETAIL
                                (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                 Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                 DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                 WaveKey, EffectiveDate, ShipFlag, PickSlipNo,            
                                 TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
                    SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_fLot,                                      
                           Storerkey, Sku, AltSku, UOM, @n_QtyTake, @n_QtyTake, QtyMoved, Status,       
                           '', @c_PickLoc, @c_fID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                           WaveKey, EffectiveDate, ShipFlag, PickSlipNo,                                                               
                           TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey                                                           
                    FROM PICKDETAIL (NOLOCK)                                                                                             
                    WHERE PickdetailKey = @c_Pickdetailkey
                 END
                 ELSE  
                 BEGIN                 	
         	          UPDATE PICKDETAIL WITH (ROWLOCK)
         	          SET Qty = 0
         	          WHERE Pickdetailkey = @c_PickDetailKey
              	    
         	          UPDATE PICKDETAIL WITH (ROWLOCK)
         	          SET Lot = @c_fLot,
         	              Loc = @c_PickLoc,
         	              Id = @c_fID,
         	              Qty = @n_QtyTake,
         	              Toloc = Loc,
         	              UOM = '6',         	               
         	              Notes = 'Swap from robot',
         	              EditDate = GETDATE(), 
         	              EditWho = SUSER_SNAME()         	               
         	          WHERE Pickdetailkey = @c_PickDetailKey         	       
         	          
         	          SET @c_CreateNewPick = 'Y'       
         	       END
              	 
              	 SET @n_PickQty = @n_PickQty - @n_QtyTake
              	 
                 FETCH NEXT FROM cur_pickloc INTO @c_fLot, @c_fId, @n_fQtyAvailable, @n_fLotQtyAvailable
              END
              CLOSE cur_pickloc
              DEALLOCATE cur_pickloc
              
              IF @n_PickQty > 0
              BEGIN
   			      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
   			                     WHERE LOT = @c_LOT AND LOC = @c_PickLoc AND ID = '' )
                  BEGIN            	     
  	                  INSERT INTO LOTxLOCxID (LOT, LOC, ID, StorerKey, SKU, Qty) VALUES (@c_LOT, @c_PickLoc, '', @c_StorerKey, @c_PDet_SKU, 0)
                  END    			  
                  
                  IF @c_CreateNewPick = 'Y'
                  BEGIN
              	     EXECUTE nspg_GetKey      
                        'PICKDETAILKEY',      
                        10,      
                        @c_NewPickdetailKey OUTPUT,         
                        @b_success OUTPUT,      
                        @n_err OUTPUT,      
                        @c_errmsg OUTPUT      
                        
   	                 INSERT INTO PICKDETAIL
                                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                  WaveKey, EffectiveDate, ShipFlag, PickSlipNo,            
                                  TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
                     SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_Lot,                                      
                            Storerkey, Sku, AltSku, UOM, @n_PickQty, @n_PickQty, QtyMoved, Status,       
                            '', @c_PickLoc, 
                            -- @c_ID, (SWT01)
                            '', 
                            PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                            WaveKey, EffectiveDate, ShipFlag, PickSlipNo,                                                               
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey                                                           
                     FROM PICKDETAIL (NOLOCK)                                                                                             
                     WHERE PickdetailKey = @c_Pickdetailkey                  	
                  END
                  ELSE
                  BEGIN
         	           UPDATE PICKDETAIL WITH (ROWLOCK)
         	           SET Loc = @c_PickLoc,
         	               ID = '', -- (SWT01)
         	               Qty = @n_PickQty,
         	               Toloc = Loc,
         	               UOM = '6',         	               
         	               Notes = 'Swap from robot',
         	               EditDate = GETDATE(), 
         	               EditWho = SUSER_SNAME()         	               
         	           WHERE Pickdetailkey = @c_PickDetailKey         	                         	
                  END                                                         	
              END   			       
              --NJOW01 End     			         
   			   			   	
   			      /*
   			      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
   			                     WHERE LOT = @c_LOT AND LOC = @c_PickLoc AND ID = @c_ID )
                  BEGIN            	     
  	                  INSERT INTO LOTxLOCxID (LOT, LOC, ID, StorerKey, SKU, Qty) VALUES (@c_LOT, @c_PickLoc, @c_ID, @c_StorerKey, @c_PDet_SKU, 0)
                  END    			   
                              	
   			      UPDATE PickDetail WITH (ROWLOCK)
   			         SET LOC = @c_PickLoc, UOM = '6', EditDate = GETDATE(), EditWho = SUSER_SNAME(), ToLoc = LOC
   			      WHERE PickDetailKey = @c_PickDetailKey
   			      */   			        	
   			   END
   			    
   				FETCH FROM CUR_PICKDETAIL_PICK INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU,
   				   			                            @n_PickQty --NJOW01  
   			END   			
   			CLOSE CUR_PICKDETAIL_PICK
   			DEALLOCATE CUR_PICKDETAIL_PICK
   		END -- IF @b_Allocate_From_Pick_Loc = 1   			      	   	
   	   ELSE -- OverAllocate to Robot Location
   	   BEGIN
   	   	IF (@c_AllocateType = 'ORDER') 
   	   	BEGIN
   			   DECLARE CUR_PICKDETAIL_STAGE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.PickDetailKey, P.LOT, P.ID, P.Sku
   			   FROM PICKDETAIL AS p WITH(NOLOCK)
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE p.OrderKey = @c_DocKey 
   		      AND   p.UOM IN ('6','7')
   		      AND  ( ( l.LocationCategory = 'ROBOT' AND l.LocationType='ROBOTSTG' ) -- Robot Stage Location 
   		               OR 
   		               ( l.LocationCategory <> 'ROBOT' ) ) -- Normal Location   	   		
   	   	END -- IF @c_AllocateType = 'ORDER'
   	   	ELSE 
   	   	BEGIN
   			   DECLARE CUR_PICKDETAIL_STAGE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   			   SELECT p.PickDetailKey, P.LOT, P.ID, P.SKU
   			   FROM PICKDETAIL AS p WITH(NOLOCK) 
   			   JOIN SKUxLOC AS sl WITH(NOLOCK) ON sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku AND sl.Loc = p.Loc  
   			   JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = p.OrderKey 
   			   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
   			   WHERE lpd.LoadKey = @c_DocKey  
   		      AND   p.UOM IN ('6','7')
   		      AND  ( ( l.LocationCategory = 'ROBOT' AND l.LocationType='ROBOTSTG' ) -- Robot Stage Location 
   		               OR 
   		             ( l.LocationCategory <> 'ROBOT' AND @c_B2B_Order = 'N' AND sl.LocationType NOT IN ('PICK','CASE') ) 
   		               OR 
   		             ( l.LocationCategory <> 'ROBOT' AND @c_B2B_Order = 'Y' )
   		           ) -- Normal Location   	   		
   	   	END
   			
   			OPEN CUR_PICKDETAIL_STAGE
   			
   			FETCH FROM CUR_PICKDETAIL_STAGE INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU
   			
   			WHILE @@FETCH_STATUS = 0
   			BEGIN
   				 -- Get ROBOT Location
   				 SELECT TOP 1 
   				    @c_RobotLoc = LOC
   				 FROM LOC AS l WITH(NOLOCK) 
   				 WHERE l.Facility = @c_Facility 
   				 AND l.LocationCategory = 'ROBOT' 
   				 AND l.LocationType = 'DYNPPICK'
   			
   			   -- SWT02 
   			   IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
   			                  WHERE LOT = @c_LOT AND LOC = @c_RobotLoc AND ID = '' )
               BEGIN            	   
            	   INSERT INTO LOTxLOCxID (LOT, LOC, ID, StorerKey, SKU, Qty) VALUES (@c_LOT, @c_RobotLoc, '', @c_StorerKey, @c_PDet_SKU, 0)
               END  

               IF NOT EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                              WHERE StorerKey = @c_StorerKey 
                              AND SKU = @c_PDet_SKU 
                              AND LOC = @c_RobotLoc)
               BEGIN
            	   INSERT INTO SKUxLOC (StorerKey, Sku, Loc, Qty) VALUES (@c_StorerKey, @c_PDet_SKU, @c_RobotLoc, 0)
               END               

   			   IF @b_debug = 1
   			   BEGIN
   				   PRINT ' - UPDATE to ROBOT, PickDetailKey: ' + @c_PickDetailKey 
   			   END
               
               -- SWT02    			                     
   			   UPDATE PickDetail WITH (ROWLOCK)
   			      SET LOC = @c_RobotLoc, ID = '', UOM='7', EditDate = GETDATE(), EditWho = SUSER_SNAME(), ToLoc = LOC
   			   WHERE PickDetailKey = @c_PickDetailKey 
   			    
   				FETCH FROM CUR_PICKDETAIL_STAGE INTO @c_PickDetailKey, @c_LOT, @c_ID, @c_PDet_SKU
   			END   			
   			CLOSE CUR_PICKDETAIL_STAGE
   			DEALLOCATE CUR_PICKDETAIL_STAGE   	   	
   	   END
   	END -- IF @n_NormBulkLoc_Qty > 0 AND (@n_RobotStage_Qty + @n_RobotLoc_Qty)
   	   	   
   	FETCH FROM CUR_LOAD_ORDER INTO @c_DocKey, @c_StorerKey, @c_Facility, @c_SKU
   END -- While CUR_LOAD_ORDER Loop
   	
   CLOSE CUR_LOAD_ORDER
   DEALLOCATE CUR_LOAD_ORDER
   
EXIT_SP:  
      
   IF @n_Continue=3  -- Error Occured - Process And Return      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispRBTPAL1 '      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
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
END -- Procedure 

GO