SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: nspPRCSCTN                                         */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by: ACM                                                      */      
/*                                                                      */      
/* Purpose:                                                             */      
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
/* Date        Author   Ver. Purposes                                   */
/* 13-Feb-2020 Wan01    1.1  Dynamic SQL review, impact SQL cache log   */       
/************************************************************************/      
CREATE PROC  [dbo].[nspPRCSCTN]        
 @c_StorerKey NVARCHAR(15) ,        
 @c_SKU NVARCHAR(20) ,        
 @c_Lot NVARCHAR(10) ,        
 @c_Lottable01 NVARCHAR(18) ,        
 @c_Lottable02 NVARCHAR(18) ,        
 @c_Lottable03 NVARCHAR(18) ,        
 @d_Lottable04 DATETIME ,        
 @d_Lottable05 DATETIME ,        
 @c_UOM NVARCHAR(10) ,         
 @c_Facility NVARCHAR(10)  ,        
 @n_UOMBase INT ,        
 @n_QtyLeftToFulfill INT,        
 @c_OtherParms    NVARCHAR(200) =NULL      
AS        
BEGIN    
   SET NOCOUNT ON  
        
   DECLARE @b_debug INT        
   SELECT @b_debug = 0       
        
   -- Get OrderKey and line Number        
   DECLARE @c_OrderKey        NVARCHAR(10)        
         , @c_OrderLineNumber NVARCHAR(5)      
         , @n_QtyInBulk       INT      
         , @n_QtyInPick       INT      
         , @n_CaseCnt         INT       
         , @n_OpenQty         INT         
         , @n_CasePickQty     INT       
         , @n_QtyToTake       INT      
         , @c_LOC             NVARCHAR(10)    
         , @c_ID              NVARCHAR(18)     
         , @n_QtyAvailable    INT     
         , @c_SQL             NVARCHAR(MAX)    
         , @n_NoOfLOT         INT    
         , @c_PreAllocLOT     NVARCHAR(10) 
         
         , @n_QtyToInsert     INT = 0     --(Wan01)   
       
   EXEC isp_Init_Preallocate_Candidates   --(Wan01) 

   SET @c_SQL= ''    
   SET @n_CaseCnt=0      
   SELECT @n_CaseCnt = p.CaseCnt       
   FROM SKU s WITH (NOLOCK)       
   JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey       
   WHERE s.StorerKey = @c_StorerKey       
   AND s.Sku = @c_SKU       

   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''        
   BEGIN      
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)        
      SELECT @c_OrderLineNumber = SUBSTRING(LTRIM(@c_OtherParms), 11, 5)        

      SET @n_QtyInBulk = 0      
      SET @n_QtyInPick = 0       
      SET @n_NoOfLOT = 0     
      SELECT @n_QtyInBulk = ISNULL(SUM(CASE WHEN P.PreAllocatePickCode = 'nspPRCSCTN' THEN P.Qty ELSE 0 END),0),       
             @n_QtyInPick = ISNULL(SUM(CASE WHEN P.PreAllocatePickCode <> 'nspPRCSCTN' THEN P.Qty ELSE 0 END),0),     
             @n_NoOfLOT = COUNT(DISTINCT LOT),    
             @c_PreAllocLOT  = MAX(LOT)    
      FROM PreAllocatePickDetail P (NOLOCK)        
      WHERE P.OrderKey = @c_OrderKey        
      AND P.StorerKey = @c_StorerKey      
      AND P.Sku = @c_SKU      
            
      SET @n_OpenQty = 0      
      SELECT @n_OpenQty = SUM(OpenQty)      
      FROM OrderDetail (NOLOCK)        
      WHERE OrderKey = @c_OrderKey        
      AND StorerKey = @c_StorerKey      
      AND Sku = @c_SKU      
               
      SET @n_CasePickQty = 0                          --(Wan01) - Fix Divide by Zero issue

      IF @n_CaseCnt > 1 
      BEGIN
         SET @n_CasePickQty = FLOOR( @n_OpenQty / @n_CaseCnt ) * @n_CaseCnt 
      END              
            
      IF @b_debug = 1      
      BEGIN      
         SELECT @n_CasePickQty '@n_CasePickQty', @n_OpenQty '@n_OpenQty', @n_CaseCnt '@n_CaseCnt',      
                @n_QtyInBulk '@n_QtyInBulk', @n_QtyInPick '@n_QtyInPick'
      END      
       
      IF @n_QtyInBulk < @n_CasePickQty --AND @n_CasePickQty > @n_QtyInBulk    
      BEGIN      
         SET @n_QtyToTake = @n_CasePickQty - @n_QtyInBulk    
              
         IF @n_NoOfLOT = 1    
         BEGIN    
            DECLARE CUR_LOT_AVAILBLE CURSOR FAST_FORWARD READ_ONLY     
            FOR    
            SELECT LOT.LOT                 
               ,QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold)    
            FROM LOT (NOLOCK)    
            WHERE LOT = @c_PreAllocLOT     
            AND   ((LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold))  > 0    
                 
         END    
         ELSE    
         BEGIN    
            DECLARE CUR_LOT_AVAILBLE CURSOR FAST_FORWARD READ_ONLY     
            FOR    
            SELECT LOT.LOT    
                  ,QTYAVAILABLE = (FLOOR((LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold)     
                                 / @n_CaseCnt) * @n_CaseCnt)    
            FROM   LOT (NOLOCK)     
            WHERE  FLOOR((LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED - LOT.QtyOnHold) / @n_CaseCnt)  > 0    
            AND    LOT.StorerKey = @c_StorerKey     
            AND    LOT.Sku = @c_SKU      
            Order BY Lot.Lot    
                 
         END 

         OPEN CUR_LOT_AVAILBLE    
         FETCH NEXT FROM CUR_LOT_AVAILBLE INTO @c_Lot, @n_QtyAvailable    

         --(Wan01) - START              
         WHILE @@FETCH_STATUS <> -1    
         BEGIN
            SET @n_QtyToInsert = 0                                   
            IF @n_QtyAvailable > @n_QtyToTake     
            BEGIN    
               --IF LEN(RTRIM(@c_SQL)) = 0    
               --BEGIN    
               --   SET @c_SQL = RTRIM(@c_SQL) + 'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' +    
               --              ' FOR SELECT ''' + RTRIM(@c_StorerKey) + ''',''' + @c_SKU + ''','''    
               --                + @c_LOT + ''','      
               --                + CAST(@n_QtyToTake AS NVARCHAR(10))      
               --END    
               --ELSE    
               --BEGIN    
               --   SET @c_SQL = RTRIM(@c_SQL) + ' UNION ALL ' +    
               --              ' SELECT ''' + RTRIM(@c_StorerKey) + ''',''' + @c_SKU + ''','''    
               --                + @c_LOT + ''',' + CAST(@n_QtyToTake AS NVARCHAR(10))              
                       
               --END 
               SET @n_QtyToInsert = @n_QtyToTake                      
               SET @n_QtyToTake = 0     
            END    
            ELSE    
            BEGIN    
               --IF LEN(RTRIM(@c_SQL)) = 0    
               --BEGIN    
               --   SET @c_SQL = RTRIM(@c_SQL) +'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' +    
               --              ' FOR SELECT ''' + RTRIM(@c_StorerKey) + ''',''' + @c_SKU + ''','''    
               --                + @c_LOT + ''',' + CAST(@n_QtyAvailable AS NVARCHAR(10))      
               --END    
               --ELSE    
               --BEGIN    
               --   SET @c_SQL = RTRIM(@c_SQL) + ' UNION ALL ' +    
               --              ' SELECT ''' + RTRIM(@c_StorerKey) + ''',''' + @c_SKU + ''','''    
               --                + @c_LOT + ''',' + CAST(@n_QtyAvailable AS NVARCHAR(10))               
                       
               --END   
               SET @n_QtyToInsert = @n_QtyAvailable              
               SET @n_QtyToTake = @n_QtyToTake - @n_QtyAvailable                     
            END
             
            SET @c_Storerkey = RTRIM(@c_Storerkey)
            SET @c_Sku       = RTRIM(@c_Sku)
            SET @c_Lot       = RTRIM(@c_Lot)

            EXEC isp_Insert_Preallocate_Candidates
                  @c_Storerkey = @c_Storerkey
               ,  @c_Sku = @c_Sku
               ,  @c_Lot = @c_Lot
               ,  @n_QtyAvailable = @n_QtyToInsert
      
            IF @n_QtyToTake = 0     
               BREAK     
                                 
            FETCH NEXT FROM CUR_LOT_AVAILBLE INTO @c_Lot, @n_QtyAvailable    
         END          
         CLOSE CUR_LOT_AVAILBLE    
         DEALLOCATE CUR_LOT_AVAILBLE     
              
         --IF LEN(RTRIM(@c_SQL)) > 0     
         --BEGIN    
         --   EXEC (@c_SQL)    
    
         --   IF @b_debug = 1      
         --BEGIN                   
         --      PRINT @c_SQL    
         --   END     
         --END    
         --ELSE    
         --   GOTO SKIPREALLOC    
      END -- IF @n_QtyInBulk < @n_CasePickQty  
      --ELSE  
      --   GOTO SKIPREALLOC 
      --(Wan01) - END
   END-- ISNULL(RTRIM(@c_OtherParms),'') <> ''  
   --(Wan01) - START   
   --ELSE    
   --BEGIN    
   --     SKIPREALLOC:    
   --     -- Dummy Cursor      
   --     DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY     
   --     FOR    
   --         SELECT LOT.StorerKey    
   --               ,LOT.SKU    
   --               ,LOT.LOT    
   --               ,QTYAVAILABLE                = (    
   --                    LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED    
   --                )    
   --         FROM   LOT(NOLOCK)    
   --         WHERE  1=2    
   --         Order BY Lot.Lot    
   --END 
   EXEC isp_Cursor_PreAllocate_Candidates 
   --(Wan01) - END
END 

GO