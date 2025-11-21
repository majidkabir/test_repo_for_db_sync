SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGetOverPickLoc01                                */
/* Creation Date: 30-Mar-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-12491 CN Dyson find pick loc by locationgroup           */
/*                                                                      */
/* Called By: Over Allocation                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 06-Jul-2023  WLChooi  1.1  Bug Fix - DEALLOC CUR if no result (WL01) */
/* 06-Jul-2023  WLChooi  1.1  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispGetOverPickLoc01]
   @c_Storerkey                  NVARCHAR(15)
 , @c_Sku                        NVARCHAR(20)
 , @c_AllocateStrategykey        NVARCHAR(10)
 , @c_AllocateStrategyLineNumber NVARCHAR(5)
 , @c_LocationTypeOverride       NVARCHAR(10)
 , @c_LocationTypeOverridestripe NVARCHAR(10)
 , @c_Facility                   NVARCHAR(5)
 , @c_HostWHCode                 NVARCHAR(10)
 , @c_Orderkey                   NVARCHAR(10)
 , @c_Loadkey                    NVARCHAR(10)
 , @c_Wavekey                    NVARCHAR(10)
 , @c_Lot                        NVARCHAR(10)
 , @c_Loc                        NVARCHAR(10)
 , @c_ID                         NVARCHAR(18)
 , @c_UOM                        NVARCHAR(10) --allocation strategy UOM  
 , @n_QtyToTake                  INT
 , @n_QtyLeftToFulfill           INT
 , @c_CallSource                 NVARCHAR(20) ----ORDER, LOADORDER, LOADCONSO, WAVEORDER, WAVECONSO  
 , @b_success                    INT           OUTPUT
 , @n_err                        INT           OUTPUT
 , @c_ErrMsg                     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT
         , @n_StartTCnt INT
         , @c_Doctype   NVARCHAR(1)

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_err = 0
        , @c_ErrMsg = ''
        , @b_success = 1

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      IF ISNULL(@c_Orderkey, '') <> ''
      BEGIN
         SELECT @c_Doctype = DocType
         FROM ORDERS (NOLOCK)
         WHERE OrderKey = @c_Orderkey
      END
      ELSE IF ISNULL(@c_Loadkey, '') <> ''
      BEGIN
         SELECT TOP 1 @c_Doctype = O.DocType
         FROM LoadPlanDetail LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey
         WHERE LPD.LoadKey = @c_Loadkey
      END
      ELSE IF ISNULL(@c_Wavekey, '') <> ''
      BEGIN
         SELECT TOP 1 @c_Doctype = O.DocType
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.WaveKey = @c_Wavekey
      END

      IF ISNULL(@c_Doctype, '') <> ''
      BEGIN
         SELECT SKUxLOC.Loc
         FROM SKUxLOC (NOLOCK)
         JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
         WHERE SKUxLOC.StorerKey = @c_Storerkey
         AND   SKUxLOC.Sku = @c_Sku
         AND   SKUxLOC.LocationType = @c_LocationTypeOverride
         AND   LOC.Facility = @c_Facility
         AND   LOC.LocationGroup = @c_Doctype
      END
      ELSE
         SELECT SKUxLOC.Loc
         FROM SKUxLOC (NOLOCK)
         JOIN LOC (NOLOCK) ON SKUxLOC.Loc = LOC.Loc
         WHERE SKUxLOC.StorerKey = @c_Storerkey
         AND   SKUxLOC.Sku = @c_Sku
         AND   SKUxLOC.LocationType = @c_LocationTypeOverride
         AND   LOC.Facility = @c_Facility
   END

   --WL01 S
   IF @@ROWCOUNT = 0
   BEGIN
      IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN ( 0, 1 )
      BEGIN
         CLOSE CURSOR_CANDIDATES
         DEALLOCATE CURSOR_CANDIDATES
      END
   END
   --WL01 E

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process AND Return  
   BEGIN
      SELECT @b_success = 0
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
      EXECUTE dbo.nsp_logerror @n_err, @c_ErrMsg, 'ispGetOverPickLoc01'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO