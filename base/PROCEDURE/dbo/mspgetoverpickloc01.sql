SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: mspGetOverPickLoc01                                */  
/* Creation Date: 2024-05-09                                            */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: UWP-19537-Mattel Overallocation                             */    
/*                                                                      */  
/* Called By: Over Allocation                                           */  
/*                                                                      */  
/* Version: 1.6                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */ 
/* 2024-05-20  Wan      1.0   Created.                                  */
/* 2024-05-20  Wan01    1.1   UWP-19537-Fixed to add SKUxLOC for DPP    */   
/* 2024-05-20  Wan02    1.2   UWP-19537-Fixed to find friend for same   */   
/*                            lot & empty DPP to include qtyexpected    */ 
/* 2024-06-28  Wan03    1.3   UWP-21429-Mattel Overallocation Enhancement*/
/*                            -Match LOC.HostWHCode at Preallocate & BULK*/ 
/*                             Allocate                                 */
/*                            -Finding Empty location logic             */
/*                            -Allocate QtyAvailable Stock then only find*/
/*                             Overallocate friend                      */  
/* 2024-07-05  Wan04    1.4   UWP-21429-Mattel Overallocation Enhancement*/
/*                            -Remove qtyallocated + qtylefttofullfil <=*/
/*                            PendingMoveIn                             */
/*                            -Use @n_Rowcount instead                  */
/* 2024-07-08  Wan05    1.5   UWP-21429-Mattel Overallocation Enhancement*/
/*                            -If overallocate + lefttofulfill>1 pallet */
/*                             ,find empty DPP                          */
/* 2024-07-18  Wan06    1.6   UWP-22202-Mattel Overallocation           */
/*                            Do Not Overallocate to partial fulfill DPP*/
/************************************************************************/  
CREATE   PROC mspGetOverPickLoc01  
   @c_Storerkey                  NVARCHAR(15)   
,  @c_Sku                        NVARCHAR(20)   
,  @c_AllocateStrategykey        NVARCHAR(10)  
,  @c_AllocateStrategyLineNumber NVARCHAR(5)  
,  @c_LocationTypeOverride       NVARCHAR(10)   
,  @c_LocationTypeOverridestripe NVARCHAR(10)  
,  @c_Facility                   NVARCHAR(5)   
,  @c_HostWHCode                 NVARCHAR(10)   
,  @c_Orderkey                   NVARCHAR(10)   
,  @c_Loadkey                    NVARCHAR(10)   
,  @c_Wavekey                    NVARCHAR(10)   
,  @c_Lot                        NVARCHAR(10)   
,  @c_Loc                        NVARCHAR(10)   
,  @c_ID                         NVARCHAR(18)   
,  @c_UOM                        NVARCHAR(10) --allocation strategy UOM  
,  @n_QtyToTake                  INT   
,  @n_QtyLeftToFulfill           INT   
,  @c_CallSource                 NVARCHAR(20) ----ORDER LOADORDER LOADCONSO WAVEORDER WAVECONSO  
,  @b_success                    INT OUTPUT   
,  @n_err                        INT OUTPUT   
,  @c_ErrMsg                     NVARCHAR(250)     OUTPUT 
,  @c_OverPickLoc                NVARCHAR(10) = '' OUTPUT                           --(Wan05)
,  @n_OverQtyLeftToFulfill       INT = 0           OUTPUT                           --(Wan06)
AS     
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @n_Continue     INT = 1 
         , @n_StartTCnt    INT = @@TRANCOUNT
         
         , @n_PalletQty    FLOAT = 0.00                                             --(Wan02)              
         , @c_Lottable02   NVARCHAR(18) = ''  

         , @c_DPPLoc       NVARCHAR(10) = ''                                        --(Wan01)
         , @n_RowCount     INT          = 0                                         --(Wan04)
        
         , @n_PackQty      FLOAT = 0.00                                             --(Wan05)
         , @n_MaxPallet    INT          = 0                                         --(Wan05) 
         , @n_Qty          INT          = 0                                         --(Wan05) 
         , @n_QtyAllocated INT          = 0                                         --(Wan05)
         , @n_QtyPicked    INT          = 0                                         --(Wan05)
         , @c_PickLoc      NVARCHAR(10) = ''                                        --(Wan05)
         , @n_MaxPalletQty INT          = 0                                         --(Wan06)
         , @n_QtyExpected  INT          = 0                                         --(Wan06)   

         , @CUR_FindLOC    CURSOR                                                   --(Wan05)

   SET @b_Success = 1    
   SET @n_Err = 0
   SET @c_ErrMsg = ''  
  
   CREATE TABLE #PICKLOCTYPE ( RowID         INT          IDENTITY(1,1) PRIMARY Key --(Wan05)      
                             , loc           NVARCHAR(10) NOT NULL DEFAULT ('')
                             )  
  
   IF @n_continue IN (1,2)  
   BEGIN             
      SELECT @c_Lottable02 = la.Lottable02
      FROM LOTATTRIBUTE la (NOLOCK) 
      WHERE la.Lot = @c_Lot
   
      INSERT INTO #PICKLOCTYPE
      SELECT sl.LOC    
      FROM SKUxLOC sl (NOLOCK)   
      JOIN LOC l(NOLOCK) ON sl.loc = l.loc
      WHERE sl.STORERKEY = @c_StorerKey    
      AND sl.SKU = @c_Sku    
      AND sl.LocationType = @c_LocationTypeOverride      
      AND l.facility = @c_Facility  
      AND l.HostWHCode = @c_Lottable02
      AND l.[Status] = 'OK'
      AND l.LocationFlag NOT IN ('HOLD','DAMAGE')
      ORDER BY l.LogicalLocation, l.Loc  
      
      SET @n_RowCount = @@ROWCOUNT                                                  --(Wan04)
 
      IF @n_RowCount = 0                                                            --(Wan04)
      BEGIN
         SELECT @n_PalletQty = p.Pallet                                             --(Wan02)
               ,@n_PackQty   = CASE WHEN @c_UOM = '2' THEN p.CaseCnt                --(Wan05)
                                    WHEN @c_UOM = '6' THEN p.Qty                    --(Wan05)
                                    END                                             --(Wan05)   
         FROM dbo.SKU s(NOLOCK) 
         JOIN dbo.PACK p (NOLOCK) ON s.Packkey = p.Packkey
         WHERE s.Storerkey = @c_Storerkey
         AND s.Sku = @c_Sku

         -- 1) find Loc with available inventory => SUM(lli.Qty-lli.QtyAllocated-lli.Qtypicked) > 0
         -- 2) Find same friend that which has stock and able to fit for 1 pallet 
         --    => SUM(lli.QtyAllocated) > 0
      
         --INSERT INTO #PICKLOCTYPE                                                 --(Wan05)-START
         SET @CUR_FindLOC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                 
         SELECT l.LOC 
               ,l.MaxPallet                                                              
               ,QtyAvailable = SUM(lli.Qty)                                         
               ,QtyAllocated = SUM(lli.QtyAllocated)                                
               ,QtyAllocated = SUM(lli.QtyPicked)                  
         FROM LOC l (NOLOCK)   
         JOIN LOTxLOCxID lli (NOLOCK) ON  lli.Storerkey = @c_StorerKey 
                                      AND lli.SKU = @c_Sku 
                                      AND lli.loc = l.loc
                                      AND lli.Lot = @c_Lot                          --(Wan02)
         WHERE l.LocationType = 'DYNPPICK'     
         AND l.Facility   = @c_Facility  
         AND l.HostWHCode = @c_Lottable02
         AND l.LocLevel = 0
         AND l.[Status] = 'OK'
         AND l.LocationFlag NOT IN ('HOLD','DAMAGE')
         GROUP BY l.loc
               ,  l.ABC        
               ,  l.LogicalLocation
               ,  l.MaxPallet
         --HAVING ( SUM(lli.Qty) > 0 OR SUM(lli.QtyExpected) > 0)                   --(Wan03) START --(Wan02)
         --   AND ((SUM(lli.PendingMoveIn) = 0 AND 
         --         CEILING(SUM(lli.QtyExpected + @n_QtyLeftToFulfill)/@n_PalletQty) <= l.MaxPallet) OR --(Wan02)  
         --         SUM(lli.QtyExpected) + @n_QtyLeftToFulfill <= SUM(lli.PendingMoveIn))
         HAVING SUM(lli.Qty-lli.QtyAllocated-lli.Qtypicked) <> 0                    --(Wan06) 
                 --((SUM(lli.Qty) = 0 AND SUM(lli.QtyAllocated) > 0) AND                      
                 -- (--(SUM(lli.PendingMoveIn) = 0 AND                                         --(Wan04)      
                 --   CEILING(SUM(lli.QtyAllocated + @n_QtyLeftToFulfill)/@n_PalletQty) <= l.MaxPallet
                 --  --) OR                                                                    --(Wan04)
                 --  -- SUM(lli.QtyAllocated) + @n_QtyLeftToFulfill <= SUM(lli.PendingMoveIn)  --(Wan04)
                 -- )
         ORDER BY CASE WHEN SUM(lli.Qty-lli.QtyAllocated-lli.Qtypicked-@n_QtyLeftToFulfill) > 0 
                       THEN 1 
                       WHEN SUM(lli.Qty-lli.QtyAllocated-lli.Qtypicked) > 0 
                       THEN 3
                       WHEN SUM(lli.Qty-lli.Qtypicked) = 0                          --(Wan06)-START
                       THEN 5
                       WHEN SUM(lli.Qty-lli.Qtypicked) > 0 
                       THEN 6
                       ELSE 7 END                                                   --(Wan06)-END--(Wan03) END
               ,  l.ABC
               ,  l.LogicalLocation                                                 --(Wan04)
         OPEN @CUR_FindLOC
         FETCH NEXT FROM @CUR_FindLOC INTO @c_PickLoc
                                          ,@n_MaxPallet
                                          ,@n_Qty
                                          ,@n_QtyAllocated
                                          ,@n_QtyPicked

         WHILE @@FETCH_STATUS = 0 AND @n_QtyLeftToFulfill > 0
         BEGIN
            IF (@n_Qty - @n_QtyPicked) - @n_QtyAllocated < 0       --Overallocated  --(Wan05) 
            BEGIN
               IF @n_Qty - @n_QtyPicked = 0 OR @n_Qty = 0                           --(Wan06)-START
               BEGIN
                  SET @n_MaxPalletQty = @n_MaxPallet * @n_PalletQty
               END
               ELSE
               BEGIN
                  SET @n_MaxPalletQty = (@n_MaxPallet - CEILING((@n_Qty)/@n_PalletQty))*@n_PalletQty
               END

               SET @n_QtyExpected = @n_QtyAllocated + (@n_QtyPicked - @n_Qty)

               IF @n_MaxPalletQty < @n_QtyExpected + @n_QtyLeftToFulfill
               BEGIN
                  BREAK
               END                                                                  --(Wan06) - END
            END

            IF @n_Qty - @n_QtyAllocated - @n_QtyPicked > 0           --QtyAvailable inv
            BEGIN
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - 
                   (FLOOR((@n_Qty-@n_QtyAllocated-@n_QtyPicked)/@n_PackQty)*@n_PackQty)
            END
            ELSE 
            BEGIN
               SET @n_QtyLeftToFulfill = 0
            END
   
            INSERT INTO #PICKLOCTYPE
            VALUES ( @c_PickLoc )

            FETCH NEXT FROM @CUR_FindLOC INTO @c_PickLoc
                                             ,@n_MaxPallet            
                                             ,@n_Qty 
                                             ,@n_QtyAllocated
                                             ,@n_QtyPicked
         END
         SET @n_RowCount = 1 
 
         IF @n_QtyLeftToFulfill > 0
         BEGIN
            SET @n_RowCount = 0  
         END                                                                        --(Wan05) - END
      END
 
      IF @n_RowCount = 0                                                            --(Wan04)
      BEGIN    
         INSERT INTO #PICKLOCTYPE
         SELECT TOP 1 l.LOC     
         FROM LOC l (NOLOCK)   
         LEFT OUTER JOIN LOTxLOCxID lli (NOLOCK) ON  lli.loc = l.loc
         WHERE l.LocationType = 'DYNPPICK'     
         AND l.facility = @c_Facility  
         AND l.HostWHCode = @c_Lottable02
         AND l.LocLevel = 0
         AND l.[Status] = 'OK'
         AND l.LocationFlag NOT IN ('HOLD','DAMAGE')
         AND l.MaxPallet > 0                                                        --(Wan02)
         GROUP BY l.loc
               ,  l.ABC          
               ,  l.LogicalLocation
         HAVING SUM(ISNULL(lli.PendingMoveIn,0) + ISNULL(lli.QtyAllocated,0)) = 0   --(Wan06)  
            AND SUM(ISNULL(lli.Qty,0) - ISNULL(lli.QtyPicked,0)) = 0                --(Wan06)--(Wan03)--(Wan02)
         ORDER BY l.ABC
               ,  l.LogicalLocation
               ,  l.Loc

         SET @n_RowCount = @@ROWCOUNT                                               --(Wan05)
         IF @n_RowCount = 0                                                         --(Wan06) - START
         BEGIN
            SET @n_OverQtyLeftToFulfill = @n_OverQtyLeftToFulfill - @n_QtyLeftToFulfill
         END                                                                        --(Wan06) - END          
         
         IF @n_RowCount > 0                                                         --(Wan05)(Wan01) - START
         BEGIN
            SELECT @c_DPPLoc = LOC
            FROM #PICKLOCTYPE pl

            IF NOT EXISTS (SELECT 1 FROM SKUxLOC sl (NOLOCK)
                           WHERE sl.Storerkey = @c_Storerkey
                           AND   sl.Sku = @c_Sku
                           AND   sl.Loc = @c_DPPLoc
                           )
            BEGIN
               INSERT INTO SKUxLOC (Storerkey, Sku, Loc, LocationType)
               VALUES (@c_Storerkey, @c_sku, @c_DPPLoc, '')
            END
         END                                                                        --(Wan01) - END
      END                                                                           
  END                                                                               
                                                                          
  SELECT TOP 1 @c_OverPickLoc= Loc                                                  --(Wan05) - START
  FROM #PICKLOCTYPE                                                                 
  ORDER BY RowID DESC                                                               --(Wan05) - END
 
  SELECT Loc FROM #PICKLOCTYPE
     
QUIT_SP:  
    
   IF @n_Continue=3  -- Error Occured - Process AND Return  
   BEGIN  
      SET @b_Success = 0  
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'mspGetOverPickLoc01'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END    
END    

GO