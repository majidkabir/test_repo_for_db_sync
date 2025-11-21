SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: mspGetOverPickLoc02                                */  
/* Creation Date: 2024-10-16                                            */  
/* Copyright: Maersk Logistics                                          */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: UWP-24391 [FCR-837] Unilever Replenishment for              */ 
/*          Flowrack locations                                          */
/*                                                                      */  
/* Called By: Over Allocation                                           */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */ 
/* 2024-10-16  Wan      1.0   Created.                                  */
/************************************************************************/  
CREATE   PROC mspGetOverPickLoc02  
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
,  @c_OverPickLoc                NVARCHAR(10) = '' OUTPUT                            
,  @n_OverQtyLeftToFulfill       INT = 0           OUTPUT                            
AS     
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @n_Continue     INT         = 1 
         , @n_StartTCnt    INT         = @@TRANCOUNT
                                                     
         , @d_Lottable04   DATETIME    = NULL
         , @d_Lottable04_2 DATETIME    = NULL

   SET @b_Success = 1    
   SET @n_Err = 0
   SET @c_ErrMsg = ''  
  
   CREATE TABLE #PICKLOCTYPE ( RowID         INT          IDENTITY(1,1) PRIMARY Key      
                             , loc           NVARCHAR(10) NOT NULL DEFAULT ('')
                             )  
  
   IF @n_continue IN (1,2)  
   BEGIN             
      SELECT @d_Lottable04 = la.Lottable04
      FROM LOTATTRIBUTE la (NOLOCK) 
      WHERE la.Lot = @c_Lot
 
      SET @d_Lottable04_2 = CASE WHEN CONVERT(NVARCHAR(8), @d_Lottable04, 121) = '19000101'  
                                 THEN NULL 
                                 ELSE ISNULL(@d_Lottable04,'1900-01-01')
                                 END

      INSERT INTO #PICKLOCTYPE (Loc)
      SELECT sl.LOC    
      FROM SKUxLOC sl (NOLOCK)   
      JOIN LOC l(NOLOCK) ON sl.loc = l.loc
      WHERE sl.STORERKEY = @c_StorerKey    
      AND sl.SKU = @c_Sku    
      AND sl.LocationType = @c_LocationTypeOverride      
      AND l.facility = @c_Facility  
      AND l.[Status] = 'OK'
      AND l.LocationFlag NOT IN ('HOLD','DAMAGE')
      ORDER BY l.LogicalLocation, l.Loc  
                                  
      SELECT TOP 1 @c_OverPickLoc= pl.Loc 
      FROM #PICKLOCTYPE pl 
      JOIN LOTxLOCxID  lli (NOLOCK) ON lli.Loc = pl.Loc
      JOIN LotAttribute la (NOLOCK) ON la.Lot = lli.Lot
      WHERE lli.STORERKEY = @c_StorerKey    
      AND lli.SKU = @c_Sku   
      ORDER BY CASE WHEN la.Lottable04 IN (@d_lottable04, @d_lottable04_2) AND
                         lli.Qty - lli.QtyAllocated - lli.QtyPicked > 0 
                    THEN 1
                    WHEN la.Lottable04 IN (@d_lottable04, @d_lottable04_2) AND
                         lli.Qty - lli.QtyAllocated - lli.QtyPicked < 0 
                    THEN 3
                    WHEN lli.Qty - lli.QtyAllocated - lli.QtyPicked > 0 
                    THEN 5
                    ELSE 7
                    END 
               , ABS(lli.Qty - lli.QtyAllocated - lli.QtyPicked)
                                                                             
      IF @c_OverPickLoc = ''
      BEGIN
         SELECT TOP 1 @c_OverPickLoc= Loc                                                   
         FROM #PICKLOCTYPE                                                                 
         ORDER BY RowID                                                                 
      END
   END  

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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'mspGetOverPickLoc02'    
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