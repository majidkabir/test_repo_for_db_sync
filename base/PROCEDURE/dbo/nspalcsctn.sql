SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/***************************************************************************/      
/* Stored Procedure: nspALCSCTN                                            */      
/* Creation Date: 10-07-2013                                               */      
/* Copyright: IDS                                                          */      
/* Written by: Shong                                                       */      
/*                                                                         */      
/* Purpose: Project AEO (Project ID : 20713) SOS283637                     */      
/*          SKU with multiple order lines. System need to consolidate by   */    
/*          SKU so that User will pick full case from bulk location and    */    
/*          pick piece from picking face.                                  */    
/*                                                                         */      
/* Called By: Exceed Allocate Orders                                       */      
/*                                                                         */      
/* PVCS Version: 1.1                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date        Author   Ver  Purposes                                      */  
/* 13-Feb-2020 Wan01    1.1  Dynamic SQL review, impact SQL cache log      */       
/***************************************************************************/      
CREATE PROC [dbo].[nspALCSCTN]      
     @c_LOT              NVARCHAR(10)      
   , @c_UOM              NVARCHAR(10)      
   , @c_HostWHCode       NVARCHAR(10)      
   , @c_Facility         NVARCHAR(5)      
   , @n_UOMBase          Int      
   , @n_QtyLeftToFulfill Int      
   , @c_OtherParms       NVARCHAR(200)      
AS      
BEGIN      
   SET NOCOUNT ON      
      
   DECLARE @b_debug          Int      
      
   SELECT @b_debug = 0     
      
   -- Get OrderKey and line Number      
   DECLARE @c_OrderKey        NVARCHAR(10)      
         , @c_OrderLineNumber NVARCHAR(5)    
         , @n_QtyInBulk       INT    
         , @n_QtyInPick       INT    
         , @c_StorerKey       NVARCHAR(15)    
         , @c_SKU             NVARCHAR(20)     
         , @n_CaseCnt         INT     
         , @n_OpenQty         INT       
         , @n_CasePickQty     INT     
         , @n_QtyToTake       INT    
         , @c_LOC             NVARCHAR(10)  
         , @c_ID              NVARCHAR(18)   
         , @n_QtyAvailable    INT   
         , @c_SQL             NVARCHAR(MAX)  

         , @n_QtyToInsert     INT = 0     --(Wan01) 
         
   EXEC isp_Init_Allocate_Candidates      --(Wan01)        
      
   SET @c_SQL= ''  
   IF ISNULL(RTRIM(@c_OtherParms),'') <> ''      
   BEGIN      
      SELECT @c_StorerKey = StorerKey,    
             @c_SKU = SKU    
      FROM LOT WITH (NOLOCK)     
      WHERE LOT = @c_LOT    
          
      SET @n_CaseCnt=0    
      SELECT @n_CaseCnt = p.CaseCnt     
      FROM SKU s WITH (NOLOCK)     
      JOIN PACK p WITH (NOLOCK) ON p.PACKKey = s.PACKKey     
      WHERE s.StorerKey = @c_StorerKey     
      AND s.Sku = @c_SKU     
          
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)      
      SELECT @c_OrderLineNumber = SUBSTRING(LTRIM(@c_OtherParms), 11, 5)      
      
      SET @n_QtyInBulk = 0    
      SET @n_QtyInPick = 0     
          
      SELECT @n_QtyInBulk = ISNULL(SUM(CASE WHEN SL.LocationType NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW') THEN P.Qty ELSE 0 END),0),     
             @n_QtyInPick = ISNULL(SUM(CASE WHEN SL.LocationType IN ('PICK', 'CASE', 'IDZ', 'FLOW') THEN P.Qty ELSE 0 END),0)     
      FROM PickDetail P (NOLOCK)      
      JOIN SKUxLOC sl (NOLOCK) ON sl.Storerkey = P.Storerkey AND sl.Sku = P.Sku AND sl.Loc = P.Loc     
      WHERE P.OrderKey = @c_OrderKey      
      AND P.StorerKey = @c_StorerKey    
      AND P.Sku = @c_SKU    
          
      SET @n_OpenQty = 0    
      SELECT @n_OpenQty = SUM(OpenQty)    
      FROM OrderDetail (NOLOCK)      
      WHERE OrderKey = @c_OrderKey      
      AND StorerKey = @c_StorerKey    
      AND Sku = @c_SKU    
            
        --@n_QtyLeftToFulfill > (@n_CasePickQty - @n_QtyInBulk)    
      SET @n_CasePickQty = 0                          --(Wan01) Fixed divide by zero issue
      IF @n_CaseCnt > 0 
      BEGIN
         SET @n_CasePickQty = FLOOR( @n_OpenQty / @n_CaseCnt ) * @n_CaseCnt 
      END            
          
      IF @b_debug = 1    
      BEGIN    
         SELECT @n_CasePickQty '@n_CasePickQty', @n_OpenQty '@n_OpenQty', @n_CaseCnt '@n_CaseCnt',    
                @n_QtyInBulk '@n_QtyInBulk'    
      END    
                
      IF @n_QtyInBulk < @n_CasePickQty  --AND @n_CasePickQty > @n_QtyInBulk  
      BEGIN    
         SET @n_QtyToTake = @n_CasePickQty - @n_QtyInBulk     
    
         IF (SELECT ISNULL(SUM(Qty),0) FROM PreAllocatePickDetail papd WITH (NOLOCK)  
             WHERE papd.OrderKey = @c_OrderKey AND papd.Sku=@c_SKU) < @n_QtyToTake  
         BEGIN  
            GOTO DECLARE_EMPTY_CUR  
         END  
           
         IF @b_debug = 1    
         BEGIN    
            SELECT @n_QtyToTake '@n_QtyToTake'     
         END    
  
         CREATE TABLE #CursorResult ( LOC NVARCHAR(10), ID NVARCHAR(18), Qty INT)  
           
         DECLARE  CUR_QtyAvailable CURSOR LOCAL FAST_FORWARD READ_ONLY    
         FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, 
               QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)     
            --QTYAVAILABLE = FLOOR((LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) / @n_CaseCnt ) * @n_CaseCnt    
         FROM LOTxLOCxID (NOLOCK)    
         JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)    
         JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID)    
         JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey AND    
                                          LOTxLOCxID.Sku = SKUxLOC.Sku AND    
                                          LOTxLOCxID.Loc = SKUxLOC.Loc)    
         WHERE LOTxLOCxID.Lot = @c_lot    
         AND ID.Status <> 'HOLD'    
         AND LOC.Locationflag NOT IN  ('HOLD','DAMAGE')    
         AND LOC.LocationType NOT IN  ('IDZ','FLOW')    
         AND LOC.Facility = @c_Facility    
         AND LOC.Status <> 'HOLD'    
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) > 0    
         AND SKUxLOC.LocationType NOT IN ('PICK', 'CASE', 'IDZ', 'FLOW')    
         ORDER BY QTYAVAILABLE, LOC.LogicalLocation, LOTxLOCxID.LOC               
            
         OPEN CUR_QtyAvailable  
         FETCH NEXT FROM CUR_QtyAvailable INTO @c_LOC, @c_ID, @n_QtyAvailable        
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @n_QtyToInsert = 0 
            IF @n_QtyAvailable > @n_QtyToTake   
            BEGIN  
               --IF LEN(RTRIM(@c_SQL)) = 0  
               --BEGIN  
               --   SET @c_SQL = RTRIM(@c_SQL) + 'DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' +  
               --            ' FOR SELECT ''' + RTRIM(@c_LOC) + ''',''' + @c_ID + ''',''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''',1 '   
               --END  
               --ELSE  
               --BEGIN  
               --   SET @c_SQL = RTRIM(@c_SQL) + ' UNION ALL ' +  
               --            ' SELECT ''' + RTRIM(@c_LOC) + ''',''' + @c_ID + ''',''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''',1 '                   
                     
               --END
               SET @n_QtyToInsert = @n_QtyToTake                   
               SET @n_QtyToTake = 0   
            END  
            ELSE  
            BEGIN  
                --IF LEN(RTRIM(@c_SQL)) = 0  
                --BEGIN  
                --   SET @c_SQL = RTRIM(@c_SQL) +'DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY ' +  
                --              ' FOR SELECT ''' + RTRIM(@c_LOC) + ''',''' + @c_ID + ''',''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''',1 '   
                --END  
                --ELSE  
                --BEGIN  
                --   SET @c_SQL = RTRIM(@c_SQL) + ' UNION ALL ' +  
                --              ' SELECT ''' + RTRIM(@c_LOC) + ''',''' + @c_ID + ''',''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''',1 '                   
                     
                --END  
               SET @n_QtyToInsert = @n_QtyAvailable                   
               SET @n_QtyToTake = @n_QtyToTake - @n_QtyAvailable                   
            END  
               
            SET @c_Loc       = RTRIM(@c_Loc)
            SET @c_ID        = RTRIM(@c_ID)

            EXEC isp_Insert_Allocate_Candidates
                  @c_Lot = ''
               ,  @c_Loc = @c_Loc
               ,  @c_ID  = @c_ID
               ,  @n_QtyAvailable = @n_QtyToInsert
               ,  @c_OtherValue = '1'

            IF @n_QtyToTake = 0   
               BREAK   
                  
            FETCH NEXT FROM CUR_QtyAvailable INTO @c_LOC, @c_ID, @n_QtyAvailable   
         END  
         CLOSE CUR_QtyAvailable  
         DEALLOCATE CUR_QtyAvailable  
            
         --IF LEN(RTRIM(@c_SQL)) > 0   
         --BEGIN  
         --   EXEC (@c_SQL)  
  
         --   IF @b_debug = 1    
         --   BEGIN                 
         --      PRINT @c_SQL  
         --   END   
         --END  
         --ELSE  
         --   GOTO DECLARE_EMPTY_CUR  
      END    
      --ELSE    
      --BEGIN    
      --   GOTO DECLARE_EMPTY_CUR    
      --END 
      
      --DECLARE CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY     
      --FOR    
      --   SELECT Loc 
      --         ,ID   
      --         ,QtyAvailable
      --         ,OtherValue
      --   FROM  #ALLOCATE_CANDIDATES   
      --   ORDER BY RowID        
      --(Wan01) - END 
   END   
   --(Wan01) - START 
   --ELSE    
   --BEGIN    
   --   GOTO DECLARE_EMPTY_CUR    
   --END
         
   --RETURN     
   DECLARE_EMPTY_CUR:    
   --DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY    
   --FOR     
   --   SELECT LOC='', ID='',    
   --      QTYAVAILABLE = 0,     
   --          '1'    
   --   WHERE 1=2  
   EXEC isp_Cursor_Allocate_Candidates   
          @n_SkipPreAllocationFlag = 0    --Do not return Lot column
   --(Wan01) - END 
END 

GO