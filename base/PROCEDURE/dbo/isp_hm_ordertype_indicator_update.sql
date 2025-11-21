SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc : isp_HM_OrderType_Indicator_Update                      */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: ONG GB                                                   */  
/*                                                                      */  
/* Purpose: Back Order Report By SKU (SOS51041)                         */  
/*                                                                      */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author         Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_HM_OrderType_Indicator_Update] ( 
	@c_StorerKey  NVARCHAR(15), 
	@c_Facility   NVARCHAR(5), 
	@c_Platform   VARCHAR(10) = '',
	@n_NoOfOrders INT = 0,
	@b_Debug      INT = 0, 
   @b_Success    INT = 1 OUTPUT,	
	@n_Err        INT = 0 OUTPUT, 
   @c_ErrMsg     NVARCHAR(215) = '' OUTPUT 
 	)
AS 
BEGIN 
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
		   
	DECLARE @n_OrderCount INT = 0 
	        
   DECLARE @c_OrderKey            NVARCHAR(10)
          ,@n_Continue            INT = 1
          ,@c_OrderLineNumber     NVARCHAR(5)  = ''
          ,@c_Sku                 NVARCHAR(20) = ''
          ,@n_OpenQty             INT = 0 
          ,@c_Lot                 NVARCHAR(10) = ''
          ,@c_Loc                 NVARCHAR(10) = ''
          ,@c_Id                  NVARCHAR(18) = ''
          ,@n_Qty                 INT = 0 
          ,@c_Zone                NVARCHAR(5) = ''
          ,@c_ReplenType          NVARCHAR(5) = ''
          ,@c_PickZone            VARCHAR(1) = ''
          ,@c_PrevPickZone        VARCHAR(1) = ''
          ,@c_ReplenishmentKey    NVARCHAR(10) = ''
          ,@c_ReplenishmentGroup  NVARCHAR(10) = '' 
          ,@c_UOM                 NVARCHAR(10) = ''
          ,@c_PackKey             NVARCHAR(10) = '' 
         
	IF ISNULL(RTRIM(@c_Platform), '') NOT IN ('TMALL','NORMAL','ALL')
   BEGIN  
      SELECT @n_Continue = 3  
      SELECT @n_Err = 68001  
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid Order Type'    
      GOTO EXIT_SP
   END  


   BEGIN TRAN           
   EXECUTE nspg_GetKey
           @keyname       = 'REPLENISHGROUP',
           @fieldlength   = 10,
           @keystring     = @c_ReplenishmentGroup OUTPUT,
           @b_success     = @b_success   OUTPUT,
           @n_err         = @n_err       OUTPUT, 
           @c_errmsg      = @c_errmsg    OUTPUT
   IF NOT @b_success = 1
   BEGIN
      SELECT @n_continue = 3
      GOTO EXIT_SP 
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   IF @b_Debug = 1
   BEGIN
      PRINT 'Replenishment Group: ' + @c_ReplenishmentGroup 
   END
      
   IF OBJECT_ID('tempdb..#ReplenInv') IS NOT NULL
   BEGIN
      DROP TABLE #ReplenInv 		
   END

	CREATE TABLE #ReplenInv (
		StorerKey      NVARCHAR(15), 
		SKU            NVARCHAR(20), 
		LOT            NVARCHAR(10),
		LOC            NVARCHAR(10),
		ID             NVARCHAR(18), 
		AllocatedQty   INT )

   IF OBJECT_ID('tempdb..#ReplenZone') IS NOT NULL
   BEGIN
      DROP TABLE #ReplenZone 		
   END
   
   CREATE TABLE #ReplenZone ( ReplenZone VARCHAR(3) )


   IF OBJECT_ID('tempdb..#PickDetail') IS NOT NULL
   BEGIN
      DROP TABLE #PickDetail 		
   END

	CREATE TABLE #PickDetail (
		OrderKey        NVARCHAR(10),
		OrderLineNumber NVARCHAR(5),
		StorerKey      NVARCHAR(15), 
		SKU            NVARCHAR(20), 
		LOT            NVARCHAR(10),
		LOC            NVARCHAR(10),
		ID             NVARCHAR(18), 
		Qty            INT )
		   		         
   IF @c_Platform = 'TMALL' 
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM ORDERS AS O WITH (NOLOCK)
      WHERE O.StorerKey = @c_StorerKey
      AND   O.Facility = @c_Facility
      AND   O.DocType='E' 
      AND   O.[Status] = '0'   
      AND   O.[Type] = 'TMALLCN'
   END
   ELSE IF @c_Platform = 'NORMAL' 
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM ORDERS AS O WITH (NOLOCK)
      WHERE O.StorerKey = @c_StorerKey
      AND   O.Facility = @c_Facility
      AND   O.DocType='E' 
      AND   O.[Status] = '0'   
      AND   O.[Type] <> 'TMALLCN'
   END
   ELSE IF @c_Platform = 'ALL' 
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM ORDERS AS O WITH (NOLOCK)
      WHERE O.StorerKey = @c_StorerKey
      AND   O.Facility = @c_Facility
      AND   O.DocType='E' 
      AND   O.[Status] = '0'   
   END   

   OPEN CUR_ORDERKEY
   
   FETCH FROM CUR_ORDERKEY INTO @c_OrderKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	IF @b_Debug = 1
   	BEGIN
   		PRINT ''
   		PRINT '---------------------------' 
   		PRINT 'OrderKey: ' + @c_OrderKey
   	END
   	   
   	   
   	SET @c_PickZone = 'B'
   	SET @c_PrevPickZone = ''
   	SET @c_ReplenType = ''
   	
   	TRUNCATE TABLE #ReplenZone
   	TRUNCATE TABLE #PickDetail 
   	
   	DECLARE CUR_ORDERDETAIL_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	SELECT OrderLineNumber, Sku, (OpenQty - QtyAllocated - QtyPicked) AS OpenQty  
   	FROM ORDERDETAIL WITH (NOLOCK)
   	WHERE OrderKey = @c_OrderKey 
   	AND (OpenQty - QtyAllocated - QtyPicked) > 0 
   	
   	
   	OPEN CUR_ORDERDETAIL_LINES
   	
   	FETCH FROM CUR_ORDERDETAIL_LINES INTO @c_OrderLineNumber, @c_Sku, @n_OpenQty
   	
   	WHILE @@FETCH_STATUS = 0
   	BEGIN
   		IF @b_Debug = 1
   		BEGIN
   		   PRINT '>>> Order Line:' + @c_OrderLineNumber
   		   PRINT '    SKU: ' + @c_Sku
   		END
   		      		
   		-- Check Qty Availalbe in B Zone
   		SET @n_Qty = 0 
   		SET @c_LOC = ''
   		SET @c_LOT = ''
   		SET @c_ID = ''
   		SET @c_Zone = ''
   		SET @c_ReplenType = ''
   		
   		WHILE @n_OpenQty > 0 
   		BEGIN
   		   --  Pick Location
   		   SELECT TOP 1  
   		          @c_Zone = @c_PickZone + '1', 
   		          @c_LOT = LLI.LOT, 
   		          @c_LOC = LLI.Loc, 
   		          @c_ID = LLI.Id, 
   		          @n_Qty = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(RI.AllocatedQty, 0) 
            FROM LOTxLOCxID LLI (NOLOCK)  
            JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC)  
            JOIN ID (NOLOCK) ON (LLI.Id = ID.ID AND ID.STATUS <> 'HOLD')  
            JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')         
            LEFT OUTER JOIN #ReplenInv AS ri WITH(NOLOCK) ON ri.StorerKey = LLI.StorerKey AND ri.SKU = LLI.SKU 
                     AND ri.LOT = LLI.Lot AND ri.LOC = LLI.Loc AND ri.ID = LLI.Id   
            WHERE LOC.Facility = @c_Facility 
            AND   LLI.StorerKey = @c_StorerKey
            AND   LLI.SKU = @c_Sku
            AND   LOC.LocationType = 'PICK'
            AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(RI.AllocatedQty, 0)	> 0 
            AND 	LOC.PickZone = @c_PickZone 
            AND PutawayZone <> 'BUF27'
   		   ORDER BY LOC.LogicalLocation 
   		   
   		   IF @n_Qty = 0 
   		   BEGIN
   		      SELECT TOP 1  
   		             @c_Zone = @c_PickZone + '2',  
   		             @c_LOT = LLI.LOT, 
   		             @c_LOC = LLI.Loc, 
   		             @c_ID = LLI.Id, 
   		             @n_Qty = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(RI.AllocatedQty, 0) 
               FROM LOTxLOCxID LLI (NOLOCK)  
               JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC)  
               JOIN ID (NOLOCK) ON (LLI.Id = ID.ID AND ID.STATUS <> 'HOLD')  
               JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')         
               LEFT OUTER JOIN #ReplenInv AS ri WITH(NOLOCK) ON ri.StorerKey = LLI.StorerKey AND ri.SKU = LLI.SKU 
                        AND ri.LOT = LLI.Lot AND ri.LOC = LLI.Loc AND ri.ID = LLI.Id   
               WHERE LOC.Facility = @c_Facility 
               AND   LLI.StorerKey = @c_StorerKey
               AND   LLI.SKU = @c_Sku
               AND   LOC.LocationType = 'BUFFER'
               AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - ISNULL(RI.AllocatedQty, 0)	> 0 
               AND 	LOC.PickZone = @c_PickZone 
               AND PutawayZone <> 'BUF27'
   		      ORDER BY LOC.LogicalLocation    			
   		   END
   		   
   		   IF @b_Debug = 1
   		   BEGIN
   		   	PRINT '>>>>> PrevPickZone:' + @c_PrevPickZone
   		   	PRINT '      PickZone: ' + @c_PickZone
   		   	PRINT '      Zone: ' + @c_Zone
   		   	PRINT '      Qty: ' + CAST(@n_Qty AS VARCHAR) + ' OpenQty: ' + CAST(@n_OpenQty AS VARCHAR)
   		   END
   		   IF @n_Qty = 0 
   		   BEGIN
   		   	IF @c_PrevPickZone <> @c_PickZone AND @c_PrevPickZone <> ''
   		   	BEGIN
   		   		
   		   	  IF NOT EXISTS (SELECT 1 FROM #ReplenZone WHERE ReplenZone = @c_PickZone + '3' )
                     INSERT INTO #ReplenZone(ReplenZone) VALUES (@c_PickZone + '3') 
                 
                  -- Unallocate 
                  UPDATE RI 
                     SET AllocatedQty = AllocatedQty - pd.Qty
                  FROM #ReplenInv RI 
                  JOIN #PickDetail AS pd WITH(NOLOCK) ON pd.StorerKey = RI.StorerKey AND pd.SKU = RI.SKU 
                  AND pd.LOT = RI.LOT AND pd.LOC = RI.LOC AND pd.ID = RI.ID            
                  
                  SET @n_OpenQty = 0 
                         
                  GOTO NEXT_ORDERS
                   
   		   	END
   		   	   
   		   	IF @c_PrevPickZone = 'A'
   		   	BEGIN
   		   		SET @c_PickZone = 'B'
   		   	END   		   	   
   		   	ELSE 
   		   	BEGIN
   		   		SET @c_PickZone = 'A'
   		   		SET @c_PrevPickZone = 'B'
   		   	END
   		   		
   		   END
    			
    			IF @n_Qty > @n_OpenQty
    			BEGIN
    				SET @n_Qty = @n_OpenQty
    			END

            IF @n_Qty > 0 
            BEGIN
            	INSERT INTO #PickDetail
            	( OrderKey, OrderLineNumber, StorerKey, SKU, LOT, LOC, ID, Qty )
            	VALUES
            	( @c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_Qty )
            	               	
            	IF NOT EXISTS(SELECT 1 FROM #ReplenInv AS ri WITH(NOLOCK)
            	              WHERE LOT = @c_Lot 
            	              AND   LOC = @c_Loc
            	              AND   ID = @c_ID )
            	BEGIN
             	   INSERT INTO #ReplenInv
            	   ( StorerKey, SKU, LOT, LOC, ID, AllocatedQty )
            	   VALUES
            	   ( @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_Qty )       
            	               	   
            	END
               ELSE 
               BEGIN
               	UPDATE #ReplenInv
               	   SET AllocatedQty = AllocatedQty + @n_Qty 
               	WHERE LOT = @c_Lot 
            	   AND   LOC = @c_Loc
            	   AND   ID = @c_ID 
               END

            	SET @n_OpenQty = @n_OpenQty - @n_Qty        
            	                  
               IF NOT EXISTS (SELECT 1 FROM #ReplenZone WHERE ReplenZone = @c_zone )
                  INSERT INTO #ReplenZone(ReplenZone) VALUES (@c_zone) 
               
               SET @n_OpenQty = @n_OpenQty - @n_Qty 
               
               IF @c_PrevPickZone = ''
                  SET @c_PrevPickZone = @c_PickZone 
                          
            END
            
            IF @n_OpenQty = 0 
               BREAK 
   		END -- WHILE @n_OpenQty > 0    	
   	
   		FETCH FROM CUR_ORDERDETAIL_LINES INTO @c_OrderLineNumber, @c_Sku, @n_OpenQty
   	END

NEXT_ORDERS:
   	
   	CLOSE CUR_ORDERDETAIL_LINES
   	DEALLOCATE CUR_ORDERDETAIL_LINES
      --IF @b_Debug = 1
      --   SELECT * FROM #ReplenZone AS rz WITH(NOLOCK)

      IF (SELECT COUNT(DISTINCT LEFT(ReplenZone, 1 )) FROM #ReplenZone) = 1
      BEGIN
   	   SELECT @c_ReplenType = LEFT(ReplenZone, 1) + MAX(RIGHT(ReplenZone, 1))
   	   FROM #ReplenZone 
         GROUP BY LEFT(ReplenZone, 1 )  	
      END
      ELSE 
      BEGIN
   	   SELECT @c_ReplenType = 'AB' + MAX(RIGHT(ReplenZone, 1))
   	   FROM #ReplenZone 
      END
      
   	IF @b_Debug = 1
   	BEGIN
   		PRINT '      ReplenType: ' + @c_ReplenType
   	END            
      
      UPDATE ORDERS 
         SET M_Address2 = @c_ReplenType, 
             M_Address3 =  @c_ReplenishmentGroup, 
             TrafficCop = NULL, 
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
      WHERE OrderKey = @c_OrderKey 
         	                     
      SET @n_OrderCount = @n_OrderCount + 1
      IF @n_OrderCount >= @n_NoOfOrders 
   	   BREAK 
   	   
   	FETCH FROM CUR_ORDERKEY INTO @c_OrderKey
   END
   
   CLOSE CUR_ORDERKEY
   DEALLOCATE CUR_ORDERKEY

   --IF @b_Debug = 1
   
   DECLARE CUR_REPLEN_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT StorerKey, SKU, LOT, LOC, ID, AllocatedQty
   FROM #ReplenInv
   WHERE AllocatedQty > 0 
   
   OPEN CUR_REPLEN_REC
   
   FETCH FROM CUR_REPLEN_REC INTO @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID,
                             @n_Qty
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      EXECUTE nspg_GetKey
         'REPLENISHKEY'
      ,  10
      ,  @c_ReplenishmentKey  OUTPUT
      ,  @b_Success           OUTPUT 
      ,  @n_Err               OUTPUT 
      ,  @c_ErrMsg            OUTPUT
                  
      IF @b_Success <> 1 
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 78325
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed!'
         GOTO EXIT_SP         
      END
      
      SELECT @c_PackKey = s.PACKKey, 
             @c_UOM = p.PackUOM3
      FROM SKU AS s WITH(NOLOCK)
      JOIN PACK AS p WITH(NOLOCK) ON p.PACKKey = s.PACKKey
      WHERE s.StorerKey=@c_StorerKey 
      AND s.Sku = @c_Sku 
                  
      INSERT INTO REPLENISHMENT(
            Replenishmentgroup, ReplenishmentKey, StorerKey,
            Sku,                FromLoc,          ToLoc,
            Lot,                Id,               Qty,
            UOM,                PackKey,          Confirmed, 
            MoveRefKey,         ToID,             PendingMoveIn, 
            QtyReplen,          QtyInPickLoc,     RefNo )
      VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
              @c_SKU,                @c_LOC,              @c_LOC, 
              @c_LOT,                @c_ID,               @n_Qty, 
              @c_UOM,                @c_PackKey,          'Y', 
              '',                    @c_ID,               0, 
              0,                     0,                   '' )  
                           
                              
   	FETCH FROM CUR_REPLEN_REC INTO @c_StorerKey, @c_SKU, @c_LOT, @c_LOC, @c_ID, @n_Qty
   END
   
   CLOSE CUR_REPLEN_REC
   DEALLOCATE CUR_REPLEN_REC
   
      
EXIT_SP:
      
END -- Procedure

 

GO