SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_UpdatePutaway                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nsp_UpdatePutaway]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@c_pickdetailkey NVARCHAR(10),
   @n_err		 int

   DECLARE putaway_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey
   FROM PICKDETAIL (NOLOCK), SKUxLOC (NOLOCK)
   WHERE SKUxLOC.StorerKey = PICKDETAIL.StorerKey
   AND SKUxLOC.Sku = PICKDETAIL.Sku
   AND SKUxLOC.Loc = PICKDETAIL.Loc
   AND SKUxLOC.LocationType <> 'CASE'
   AND Shipflag = '5'
   AND Status < '5'

   OPEN putaway_cur
   FETCH NEXT FROM putaway_cur INTO @c_pickdetailkey


   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      BEGIN TRAN

         UPDATE PICKDETAIL
         SET Status = '5'
         WHERE PickDetailKey = @c_pickdetailkey
         AND ShipFlag = '5'
         AND Status < '5'

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 ROLLBACK TRAN
      ELSE COMMIT TRAN


         FETCH NEXT FROM putaway_cur INTO @c_pickdetailkey
      END

      CLOSE putaway_cur
      DEALLOCATE putaway_cur


   END

GO