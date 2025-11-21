SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Stored Procedure: ispPSTALC2                                         */    
/* Creation Date: 18-07-2019                                            */    
/* Copyright: LFL                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */    
/* 18-07-2019   Shong   1.0   Initial Version                           */    
/*                            WMS-9275 ANF ALlocation                   */
/* 27-09-2019   NJOW01  1.1   WMS-10776 Change find DPP loc logic       */
/* 08-02-2021   WLChooi 1.2   WMS-16327 - Use Codelkup to control       */
/*                            sorting (WL01)                            */
/************************************************************************/    
CREATE PROC [dbo].[ispPSTALC2]      
     @c_OrderKey    NVARCHAR(10)    
   , @c_LoadKey     NVARCHAR(10)  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0    
AS      
BEGIN      
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
      

   DECLARE  @n_Continue             INT,      
            @n_StartTCnt            INT, -- Holds the current transaction count  
            @c_Ecom_Single_Flag     NVARCHAR(80),   
            @c_StorerKey            NVARCHAR(15), 
            @c_PickDetailKey        NVARCHAR(10), 
            @c_SKU                  NVARCHAR(20), 
            @c_OrderType            NVARCHAR(10),
            @c_DPP_Loc              NVARCHAR(10) = '',
            @c_AllowOverallocations NVARCHAR(1) = '0', 
            @c_LOT                  NVARCHAR(10) = '',
            @c_LOC                  NVARCHAR(10) = '',
            @c_ID                   NVARCHAR(18) = '',
            @c_SKUZone              NVARCHAR(10) = '',
            @c_SortingSQL           NVARCHAR(4000),    --WL01
            @c_SortingSQL1          NVARCHAR(4000),    --WL01
            @c_SortingSQL2          NVARCHAR(4000),    --WL01
            @c_SQL                  NVARCHAR(4000),    --WL01
            @c_SQLParm              NVARCHAR(4000),    --WL01
            @c_GroupBySQL           NVARCHAR(4000)     --WL01
            
   DECLARE @c_Facility     NVARCHAR(5)  
          ,@c_Shipperkey   NVARCHAR(15)  
  
   DECLARE @c_CLK_UDF02           NVARCHAR(30)  
         , @c_UpdateEComDstntCode CHAR(1)  
  
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0    
   SELECT @c_ErrMsg=''    
   
   SET @c_SortingSQL  = ''   --WL01
   SET @c_SortingSQL1 = 'ORDER BY LOC.LogicalLocation, LOC.LOC '           --WL01
   SET @c_SortingSQL2 = 'ORDER BY SL.Qty, LOC.LogicalLocation, LOC.Loc '   --WL01
   SET @c_GroupBySQL  = 'GROUP BY LOC.LogicalLocation, LOC.LOC '           --WL01
   
   --WL01 START
   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)  
              WHERE CL.Storerkey = @c_Storerkey  
              AND CL.Code = 'SORTBY'  
              AND CL.Listname = 'PKCODECFG'  
              AND CL.Long = 'ispPSTALC2'
              AND ISNULL(CL.Short,'') <> 'N')
   BEGIN
      SELECT @c_SortingSQL = LTRIM(RTRIM(ISNULL(CL.Notes,'')))
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Storerkey = @c_Storerkey
      AND CL.Code = 'SORTBY'
      AND CL.Listname = 'PKCODECFG'
      AND CL.Long = 'ispPSTALC2'
      AND ISNULL(CL.Short,'') <> 'N'
      
      SET @c_SortingSQL1 = @c_SortingSQL     
      SET @c_SortingSQL2 = REPLACE(@c_SortingSQL1, 'ORDER BY', 'ORDER BY SL.Qty, ')
      SET @c_GroupBySQL  = REPLACE(@c_SortingSQL1, 'ORDER BY', 'GROUP BY')
   END
   --WL01 END
          
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
   BEGIN  
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey   
      FROM ORDERS WITH (NOLOCK)  
      WHERE OrderKey = @c_OrderKey  
      AND   ShipperKey IS NOT NULL 
      AND   ShipperKey <> ''  
   END  
   ELSE  
   BEGIN  
   	IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   	BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT lpd.OrderKey   
         FROM LoadplanDetail AS lpd WITH (NOLOCK) 
         JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey       
         WHERE lpd.LoadKey = @c_LoadKey        
         AND   o.ShipperKey IS NOT NULL 
         AND   o.ShipperKey <> ''   		
   	END 
   	ELSE 
   	BEGIN
   		GOTO EXIT_SP
   	END	
   	
   END  
     
   OPEN CUR_ORDERKEY      
  
   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
    
   WHILE @@FETCH_STATUS <> -1          
   BEGIN            
      SET @c_Ecom_Single_Flag = ''  
      SET @c_StorerKey = ''  
      SET @c_ShipperKey = ''  
      SET @c_Facility = ''  
      SET @c_PickDetailKey = ''  
      SET @c_SKU = ''     
      SET @c_OrderType = ''   
        
      SELECT @c_Ecom_Single_Flag = ISNULL(o.Ecom_Single_Flag ,''),   
             @c_StorerKey  = o.StorerKey,   
             @c_Facility   = o.Facility,  
             @c_OrderType  = ISNULL(o.[Type], '') 
      FROM ORDERS o WITH (NOLOCK)  
      WHERE o.OrderKey = @c_OrderKey  
      
      SET @b_Success = 1
      SET @c_AllowOverallocations = '0'
      
      EXEC nspGetRight
      	@c_Facility = @c_Facility,
      	@c_StorerKey = @c_StorerKey,
      	@c_sku = '',
      	@c_ConfigKey = 'ALLOWOVERALLOCATIONS',
      	@b_Success = @b_Success OUTPUT,
      	@c_authority = @c_AllowOverallocations OUTPUT,
      	@n_err = @n_Err OUTPUT,
      	@c_errmsg = @c_ErrMsg OUTPUT 
       
      IF ISNULL(RTRIM(@c_Ecom_Single_Flag),'') = 'M' AND @c_AllowOverallocations = '1' 
      BEGIN 
      	DECLARE CUR_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT p.PickDetailKey, p.Sku, p.LOT ,p.LOC, p.ID  
         FROM PICKDETAIL AS p WITH(NOLOCK)
         JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
         WHERE p.OrderKey = @c_OrderKey 
         AND p.UOM = '7'
         AND L.LocationFlag = 'NONE'
         AND L.LocationCategory IN ('MEZZANINE', 'SELECTIVE')
         
         OPEN CUR_PickDetail
         FETCH NEXT FROM CUR_PickDetail INTO @c_PickDetailKey, @c_SKU, @c_LOT, @c_LOC, @c_ID
         WHILE @@FETCH_STATUS = 0 
         BEGIN
         	SET @c_SKUZone = ''
         	
         	SELECT @c_SKUZone = ISNULL(PutawayZone,'')  
         	FROM SKU WITH (NOLOCK)
         	WHERE StorerKey = @c_StorerKey
         	AND Sku = @c_SKU
         	
         	-- Get DPP Location for same SKU
            SET @c_DPP_Loc = ''
            IF ISNULL(@c_SKUZone,'') <> ''
            BEGIN
         	   --WL01 S - Change to Dynamic SQL, no logic change
               --SELECT TOP 1 @c_DPP_Loc = LOC.Loc
               --FROM SKUXLOC SL (NOLOCK)
               --JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
               --CROSS APPLY dbo.fnc_skuxloc_extended(SL.StorerKey,SL.Sku, SL.Loc) AS SL2        
               --WHERE SL.Storerkey = @c_Storerkey
               --AND SL.Sku = @c_Sku
               --AND LOC.LocationType IN('DYNPICKP', 'DYNPICKR','DYNPPICK', 'PICK')
               --AND LOC.LocationFlag = 'NONE'
               --AND (SL.Qty + SL2.PendingMoveIn > 0 OR ((SL.QtyAllocated + SL.QtyPicked) > SL.Qty)) -- Choose Location with Qty or Over-Allocated
               --AND LOC.Putawayzone = @c_SKUZone 
               --ORDER BY SL.Qty, LOC.LogicalLocation, LOC.Loc
               
               SET @c_SQL = N'SELECT TOP 1 @c_DPP_Loc = LOC.Loc
                              FROM SKUXLOC SL (NOLOCK)
                              JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
                              CROSS APPLY dbo.fnc_skuxloc_extended(SL.StorerKey,SL.Sku, SL.Loc) AS SL2        
                              WHERE SL.Storerkey = @c_Storerkey
                              AND SL.Sku = @c_Sku
                              AND LOC.LocationType IN(''DYNPICKP'', ''DYNPICKR'',''DYNPPICK'', ''PICK'')
                              AND LOC.LocationFlag = ''NONE''
                              AND (SL.Qty + SL2.PendingMoveIn > 0 OR ((SL.QtyAllocated + SL.QtyPicked) > SL.Qty)) -- Choose Location with Qty or Over-Allocated
                              AND LOC.Putawayzone = @c_SKUZone ' + 
                              --ORDER BY SL.Qty, LOC.LogicalLocation, LOC.Loc'
                              @c_SortingSQL2
               
               
               SET @c_SQLParm =  N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_SKUZone NVARCHAR(10), @c_DPP_Loc NVARCHAR(10) OUTPUT ' 

               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Storerkey, @c_Sku, @c_SKUZone, @c_DPP_Loc OUTPUT         
               --WL01 E - Change to Dynamic SQL, no logic change
        
             /*
         	   SELECT TOP 1 @c_DPP_Loc = SL.LOC 
         	   FROM SKUxLOC AS sl WITH(NOLOCK) 
         	   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = sl.Loc 
         	   WHERE l.LocationType = 'DYNPPICK' 
         	   AND ( sl.Qty > 0 OR ( (sl.QtyAllocated + sl.QtyPicked) > sl.Qty)) -- Choose Location with Qty or Over-Allocated
         	   AND sl.StorerKey = @c_StorerKey 
         	   AND sl.Sku = @c_SKU 
         	   AND l.PutawayZone = @c_SKUZone 
         	   ORDER BY (sl.Qty - sl.QtyAllocated - sl.QtyPicked) DESC
         	   */         		
         	END
         	ELSE 
         	BEGIN
         		IF @b_debug = 1
         		BEGIN
         			PRINT '-- 1. Found DYNPPICK Location: ' + @c_DPP_LOC
         		END         		
         		GOTO UPDATE_DPP_LOC
         	END         	
         	
          IF ISNULL(@c_DPP_LOC,'') = ''
         	BEGIN

            --WL01 S - Change to Dynamic SQL, no logic change
            --SELECT TOP 1 @c_DPP_Loc = LOC.Loc
            --FROM LOC (NOLOCK)
            --LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc
            --WHERE LOC.LocationType IN('DYNPICKP', 'DYNPICKR','DYNPPICK', 'PICK')
            --AND LOC.LocationFlag = 'NONE'
            --AND LOC.Putawayzone = @c_SKUZone
            --GROUP BY LOC.LogicalLocation, LOC.Loc
            --HAVING ISNULL(SUM((LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) + LLI.PendingMoveIn),0) = 0
            --ORDER BY LOC.LogicalLocation, LOC.Loc
            
            SET @c_SQL = N'SELECT TOP 1 @c_DPP_Loc = LOC.Loc
                           FROM LOC (NOLOCK)
                           LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc
                           WHERE LOC.LocationType IN(''DYNPICKP'', ''DYNPICKR'',''DYNPPICK'', ''PICK'')
                           AND LOC.LocationFlag = ''NONE''
                           AND LOC.Putawayzone = @c_SKUZone ' + 
                           --GROUP BY LOC.LogicalLocation, LOC.Loc
                           @c_GroupBySQL + '
                           HAVING ISNULL(SUM((LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) + LLI.PendingMoveIn),0) = 0 ' +
                           --ORDER BY LOC.LogicalLocation, LOC.Loc '
                           @c_SortingSQL1
               
            SET @c_SQLParm =  N'@c_SKUZone NVARCHAR(10), @c_DPP_Loc NVARCHAR(10) OUTPUT ' 

            EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_SKUZone, @c_DPP_Loc OUTPUT
            --WL01 E - Change to Dynamic SQL, no logic change

            /*
         	   SELECT TOP 1 @c_DPP_Loc = L.LOC 
         	   FROM LOC AS l WITH(NOLOCK)
         	   LEFT OUTER JOIN SKUxLOC AS sl WITH(NOLOCK) ON l.Loc = sl.Loc 
         	   WHERE l.LocationType = 'DYNPPICK' 
         	   AND L.PutawayZone = @c_SKUZone  
         	   GROUP BY l.Loc
         	   HAVING ISNULL( SUM(sl.Qty + sl.QtyAllocated + sl.QtyPicked), 0) = 0     
         	   */
         	END
         	ELSE 
         	BEGIN
         		IF @b_debug = 1
         		BEGIN
         			PRINT '-- 2. Found DYNPPICK Location: ' + @c_DPP_LOC
         		END         		
         		
         		GOTO UPDATE_DPP_LOC
         	END
         	        	         	
         	IF ISNULL(@c_DPP_LOC,'') = ''
         	BEGIN         		
             --Find loc with same sku from PA ANFFAKE
             
             --WL01 S - Change to Dynamic SQL, no logic change
             --SELECT TOP 1 @c_DPP_Loc = LOC.Loc
             --FROM SKUXLOC SL (NOLOCK)
             --JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
             --CROSS APPLY dbo.fnc_skuxloc_extended(SL.StorerKey,SL.Sku, SL.Loc) AS SL2        
             --WHERE SL.Storerkey = @c_Storerkey
             --AND SL.Sku = @c_Sku
             --AND LOC.LocationType IN('DYNPICKP', 'DYNPICKR','DYNPPICK', 'PICK')
             --AND LOC.LocationFlag = 'NONE'
             --AND (SL.Qty + SL2.PendingMoveIn > 0 OR ((SL.QtyAllocated + SL.QtyPicked) > SL.Qty)) 
             --AND LOC.Putawayzone = 'ANFFAKE' 
             --ORDER BY SL.Qty, LOC.LogicalLocation, LOC.Loc
             
             SET @c_SQL = N'SELECT TOP 1 @c_DPP_Loc = LOC.Loc
                            FROM SKUXLOC SL (NOLOCK)
                            JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
                            CROSS APPLY dbo.fnc_skuxloc_extended(SL.StorerKey,SL.Sku, SL.Loc) AS SL2        
                            WHERE SL.Storerkey = @c_Storerkey
                            AND SL.Sku = @c_SKU
                            AND LOC.LocationType IN(''DYNPICKP'', ''DYNPICKR'',''DYNPPICK'', ''PICK'')
                            AND LOC.LocationFlag = ''NONE''
                            AND (SL.Qty + SL2.PendingMoveIn > 0 OR ((SL.QtyAllocated + SL.QtyPicked) > SL.Qty)) 
                            AND LOC.Putawayzone = ''ANFFAKE'' ' + 
                            --ORDER BY SL.Qty, LOC.LogicalLocation, LOC.Loc '
                            @c_SortingSQL2
             
             SET @c_SQLParm =  N'@c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @c_DPP_Loc NVARCHAR(10) OUTPUT ' 
             
             EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_StorerKey, @c_SKU, @c_DPP_Loc OUTPUT
             --WL01 E - Change to Dynamic SQL, no logic change

             --find empty loc from PA ANFFAKE
             IF ISNULL(@c_DPP_LOC,'') = ''
             BEGIN
             	 --WL01 S - Change to Dynamic SQL, no logic change
                --SELECT TOP 1 @c_DPP_Loc = LOC.Loc
                --FROM LOC (NOLOCK)
                --LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc
                --WHERE LOC.LocationType IN('DYNPICKP', 'DYNPICKR','DYNPPICK', 'PICK')
                --AND LOC.LocationFlag = 'NONE'
                --AND LOC.Putawayzone = 'ANFFAKE'
                --GROUP BY LOC.LogicalLocation, LOC.Loc
                --HAVING ISNULL(SUM((LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) + LLI.PendingMoveIn),0) = 0
                --ORDER BY LOC.LogicalLocation, LOC.Loc
                
                SET @c_SQL = N'SELECT TOP 1 @c_DPP_Loc = LOC.Loc
                               FROM LOC (NOLOCK)
                               LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc
                               WHERE LOC.LocationType IN(''DYNPICKP'', ''DYNPICKR'',''DYNPPICK'', ''PICK'')
                               AND LOC.LocationFlag = ''NONE''
                               AND LOC.Putawayzone = ''ANFFAKE'' ' + 
                               --GROUP BY LOC.LogicalLocation, LOC.Loc
                               @c_GroupBySQL + '
                               HAVING ISNULL(SUM((LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) + LLI.PendingMoveIn),0) = 0 ' +
                               --ORDER BY LOC.LogicalLocation, LOC.Loc '
                               @c_SortingSQL1
               
               
                SET @c_SQLParm =  N'@c_DPP_Loc NVARCHAR(10) OUTPUT ' 

                EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_DPP_Loc OUTPUT         
                --WL01 E - Change to Dynamic SQL, no logic change
             END

         		 /*
         	   SELECT TOP 1 @c_DPP_Loc = L.LOC 
         	   FROM LOC AS l WITH(NOLOCK)
         	   LEFT OUTER JOIN SKUxLOC AS sl WITH(NOLOCK) ON l.Loc = sl.Loc 
         	   WHERE l.LocationType = 'DYNPPICK' 
         	   AND L.PutawayZone = 'ANFFAKE'  
         	   GROUP BY l.Loc
         	   HAVING ISNULL( SUM(sl.Qty + sl.QtyAllocated + sl.QtyPicked), 0) = 0     
         	   */
         	END
         	ELSE 
         	BEGIN
         		IF @b_debug = 1
         		BEGIN
         			PRINT '-- 3. Found DYNPPICK Location: ' + @c_DPP_LOC
         		END         		
         	END
         	
         	UPDATE_DPP_LOC:
         	IF ISNULL(@c_DPP_LOC,'') <> '' 
         	BEGIN
         	   IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) 
         	                  WHERE LOT = @c_LOT 
         	                  AND LOC = @c_DPP_Loc
         	                  AND ID  = '' )
         	   BEGIN
         		   INSERT INTO LOTxLOCxID (StorerKey, Sku, Loc, Id, Lot, Qty) 
         		   VALUES ( @c_StorerKey, @c_SKU, @c_DPP_LOC, '', @c_LOT, 0 )
         	   END
         	
         	   IF NOT EXISTS (SELECT 1 FROM SKUxLOC WITH (NOLOCK)  
         	                  WHERE StorerKey = @c_StorerKey
         	                  AND Sku = @c_SKU 
         	                  AND LOC = @c_DPP_LOC) 
         	   BEGIN
         		   INSERT INTO SKUxLOC (StorerKey, Sku, Loc, Qty)
         		   VALUES (@c_StorerKey, @c_SKU, @c_DPP_LOC, 0) 
         	   END
         	            		
               UPDATE PICKDETAIL WITH (ROWLOCK) 
                  SET Loc = @c_DPP_LOC,
                      ID = '', 
                      EditDate = GETDATE(), 
                      EditWho = SUSER_SNAME() 
               WHERE PickDetailKey = @c_PickDetailKey         		
         	END
         	ELSE
         	BEGIN
         		IF @b_debug = 1
         		BEGIN
         			PRINT '-- No DYNPPICK Location Found' 
         		END
         	END
         	
         	FETCH NEXT FROM CUR_PickDetail INTO @c_PickDetailKey, @c_SKU, @c_LOT, @c_LOC, @c_ID
         END
      END                
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey         
   END -- WHILE @@FETCH_STATUS <> -1      
     
   CLOSE CUR_ORDERKEY          
   DEALLOCATE CUR_ORDERKEY    
     
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPSTALC2'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
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