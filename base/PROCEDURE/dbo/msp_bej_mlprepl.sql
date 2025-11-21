SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_BEJ_MLPRepl                                         */
/* Creation Date: 2024-10-14                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-24391 [FCR-837] Unilever Replenishment for Flowrack     */
/*        : locations                                                   */
/*        :                                                             */
/* Called By: Call by SQL Scheduler Job                                 */
/*          :                                                           */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-10-08  Wan      1.0   Created.                                  */
/************************************************************************/
CREATE   PROC msp_BEJ_MLPRepl
   @c_Storerkey   NVARCHAR(15)   = ''
,  @c_Facility    NVARCHAR(5)    = ''
,  @c_OtherConfig NVARCHAR(4000) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1
         , @b_Success         INT            = 1
         , @n_Err             INT            = 0
         , @c_ErrMsg          NVARCHAR(255)  = ''
 
         , @c_Sku             NVARCHAR(20)   = ''
         , @c_Loc             NVARCHAR(10)   = ''

         , @CUR_JOB           CURSOR
         , @CUR_REPL          CURSOR
   
   IF @c_Facility <> ''
   BEGIN
      SET @CUR_REPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT l.Facility
            ,sl.Sku
            ,sl.Loc
      FROM   SKUxLOC sl WITH (NOLOCK)
      JOIN   Loc l WITH (NOLOCK) ON  sl.Loc = l.Loc
      WHERE  sl.Storerkey = @c_Storerkey
      AND    sl.LocationType IN ('CASE', 'PICK')
      AND    l.Facility = @c_Facility
      ORDER BY sl.Sku
            ,  sl.Loc
   END
   ELSE
   BEGIN
      SET @CUR_REPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT l.Facility
            ,sl.Sku
            ,sl.Loc
      FROM   SKUxLOC sl WITH (NOLOCK)
      JOIN   Loc l WITH (NOLOCK) ON  sl.Loc = l.Loc
      WHERE  sl.Storerkey = @c_Storerkey
      AND    sl.LocationType IN ('CASE', 'PICK')
      GROUP BY l.Facility
            ,  sl.Sku
            ,  sl.Loc
      ORDER BY l.Facility
            ,  sl.Sku
            ,  sl.Loc
   END

   OPEN @CUR_REPL
   
   FETCH NEXT FROM @CUR_REPL INTO @c_Facility, @c_Sku, @c_Loc

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
   BEGIN
      EXEC isp_ODMRPL01
         @c_Facility   = @c_Facility 
      ,  @c_Storerkey  = @c_Storerkey
      ,  @c_SKU        = @c_SKU      
      ,  @c_LOC        = @c_LOC      
      ,  @c_ReplenType = 'T'   -- T=TaskManager/R-Replenishment
      ,  @c_ReplenishmentGroup = '' 
      ,  @b_Success    = @b_Success OUTPUT
      ,  @n_Err        = @n_Err     OUTPUT
      ,  @c_ErrMsg     = @c_ErrMsg  OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
      END

      FETCH NEXT FROM @CUR_REPL INTO @c_Facility, @c_Sku, @c_Loc
   END
   CLOSE @CUR_REPL
   DEALLOCATE @CUR_REPL
  
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
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
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