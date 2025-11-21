SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_ReplBack2Front                                      */
/* Creation Date: 2024-10-08                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-24391 [FCR-837] Unilever Replenishment for Flowrack     */
/*        : locations                                                   */
/*                                                                      */
/* Called By:                                                           */
/*          :                                                           */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-10-08  Wan      1.0   Created.                                  */
/* 2024-11-06  Wan01    1.1   UWP-24391 Fixed. New pick face without    */
/*                            lotxlocxid                                */
/* 2024-11-23  Wan02    1.2   FCR-1430 - Gap on Swap lot when move      */
/************************************************************************/
CREATE   PROC msp_ReplBack2Front
   @c_Facility   NVARCHAR(5)     = '' 
,  @c_Storerkey  NVARCHAR(15)    = '' 
,  @c_SKU        NVARCHAR(20)    = '' 
,  @c_LOC_Back   NVARCHAR(10)    = ''    
,  @c_LOC_Front  NVARCHAR(10)    = ''   
,  @b_Success    INT             = 1   OUTPUT
,  @n_Err        INT             = 0   OUTPUT
,  @c_ErrMsg     NVARCHAR(255)   = ''  OUTPUT 
,  @b_Debug      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1

         , @c_Packkey         NVARCHAR(10)   = ''
         , @c_UOM             NVARCHAR(10)   = ''
         , @c_Lot_front       NVARCHAR(10)   = ''
         , @c_ID_front        NVARCHAR(18)   = ''
         , @c_Sku_back        NVARCHAR(20)   = ''
         , @c_Lot_back        NVARCHAR(10)   = ''
         , @c_ID_back         NVARCHAR(18)   = ''
         , @n_QtyToMove       INT            = 0

         , @CUR_LI            CURSOR
         , @CUR_MV            CURSOR
   
   SET @b_Success = 1

   IF EXISTS ( SELECT 1                                                             --(Wan01)
               FROM   LOTxLOCxID lli WITH (NOLOCK)
               WHERE  lli.Storerkey = @c_Storerkey
               AND    lli.Sku       = @c_Sku
               AND    lli.Loc       = @c_Loc_front
               GROUP BY lli.Storerkey, lli.Loc
               HAVING   SUM(lli.Qty - lli.QtyPicked) > 0                            --(Wan01)       
               )
   BEGIN
      SET @n_Continue = 4
   END

   IF @n_Continue = 1
   BEGIN
      SET @CUR_LI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT lli.Loc
            ,lli.ID 
      FROM  LOTxLOCxID lli WITH (NOLOCK) 
      JOIN  Loc l WITH (NOLOCK) ON l.loc = lli.loc
      WHERE lli.Storerkey = @c_Storerkey
      AND lli.Sku = @c_Sku
      AND l.Loc   = @c_LOC_Back
      AND l.facility = @c_Facility
      GROUP BY lli.Loc
            ,  lli.ID
      HAVING SUM(lli.Qty - lli.QtyPicked) > 0
   
      OPEN @CUR_LI

      FETCH NEXT FROM @CUR_LI INTO @c_Loc_back
                                 , @c_ID_back

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @CUR_MV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT llib.Lot
               ,llib.Sku
               ,llib.Qty
               ,s.Packkey
               ,p.Packuom3
         FROM   LOTxLOCxID llib  WITH (NOLOCK)
         JOIN   SKU s WITH (NOLOCK) ON  s.Storerkey = llib.Storerkey
                                    AND s.Sku = llib.Sku
         JOIN   PACK p WITH (NOLOCK) ON p.Packkey = s.Packkey
         WHERE  llib.Storerkey = @c_Storerkey
         AND    llib.Loc   = @c_Loc_back 
         AND    llib.ID    = @c_ID_back
         AND    llib.Qty - llib.QtyAllocated - llib.QtyPicked > 0                   --(Wan02)
         ORDER BY llib.Lot
   
         OPEN @CUR_MV
   
         FETCH NEXT FROM @CUR_MV INTO @c_Lot_back
                                    , @c_Sku_back
                                    , @n_QtyToMove
                                    , @c_Packkey
                                    , @c_UOM

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Need to turn on Storerconfig - AutoReplenSwapLot
            EXECUTE nspItrnAddMove  
               @n_ItrnSysId  = null   
            ,  @c_StorerKey  = @c_StorerKey    
            ,  @c_SKU        = @c_Sku_back  
            ,  @c_LOT        = @c_LOT_back  
            ,  @c_FromLoc    = @c_LOC_back  
            ,  @c_FromID     = @c_ID_back 
            ,  @c_ToLoc      = @c_LOC_Front  
            ,  @c_ToID       = @c_ID_back 
            ,  @c_Status     = '' 
            ,  @c_LOTtable01 = ''
            ,  @c_LOTtable02 = ''  
            ,  @c_LOTtable03 = ''  
            ,  @d_lottable04 = null  
            ,  @d_lottable05 = null  
            ,  @c_LOTtable06 = ''
            ,  @c_LOTtable07 = ''
            ,  @c_LOTtable08 = ''
            ,  @c_LOTtable09 = ''
            ,  @c_LOTtable10 = ''
            ,  @c_LOTtable11 = ''
            ,  @c_LOTtable12 = ''  
            ,  @d_lottable13 = null 
            ,  @d_lottable14 = null 
            ,  @d_lottable15 = null 
            ,  @n_casecnt    = 0  
            ,  @n_innerpack  = 0  
            ,  @n_Qty        = @n_QtyToMove  
            ,  @n_pallet     = 0  
            ,  @f_cube       = 0  
            ,  @f_grosswgt   = 0  
            ,  @f_netwgt     = 0  
            ,  @f_otherunit1 = 0  
            ,  @f_otherunit2 = 0  
            ,  @c_SourceKey  = ''   
            ,  @c_SourceType = 'msp_ReplBack2Front'   
            ,  @c_PackKey    = @c_PackKey   
            ,  @c_UOM        = @c_UOM   
            ,  @b_UOMCalc    = 1   
            ,  @d_EffectiveDate = NULL   
            ,  @c_itrnkey    = ''  
            ,  @b_Success    = @b_Success    OUTPUT   
            ,  @n_Err        = @n_Err        OUTPUT   
            ,  @c_ErrMsg     = @c_ErrMsg     OUTPUT   
  
            IF @b_Success = 0  
            BEGIN 
               SET @n_Continue = 3
            END
            
            IF @n_Continue = 1                                                      --(Wan02) - START
            BEGIN
               EXEC [dbo].[msp_Back2FrontSwapLot]
                  @c_LOT            = @c_LOT_back 
               ,  @c_LOC            = @c_LOC_Front
               ,  @c_ID             = @c_ID_back    
               ,  @b_Success        = @b_Success    OUTPUT 
               ,  @n_ErrNo          = @n_Err        OUTPUT    
               ,  @c_ErrMsg         = @c_ErrMsg     OUTPUT  
               
               IF @b_Success = 0 OR @n_Err <> 0
               BEGIN 
                  SET @n_Continue = 3
               END
            END                                                                     -- (Wan02) - END

            FETCH NEXT FROM @CUR_MV INTO @c_Lot_back
                                       , @c_Sku_back
                                       , @n_QtyToMove
                                       , @c_Packkey
                                       , @c_UOM
         END
         CLOSE @CUR_MV
         DEALLOCATE @CUR_MV  
         FETCH NEXT FROM @CUR_LI INTO @c_Loc_back
                                    , @c_ID_back
      END
      CLOSE @CUR_LI
      DEALLOCATE @CUR_LI
   END
QUIT_SP:
   IF @n_continue=3    
   BEGIN  
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt    
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
   END    
   ELSE    
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
  
 END        
END

GO