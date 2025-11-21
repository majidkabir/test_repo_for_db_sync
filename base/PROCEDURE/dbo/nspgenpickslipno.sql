SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspGenPickSlipNo                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspGenPickSlipNo    Script Date: 3/11/99 6:24:26 PM ******/
CREATE PROCEDURE [dbo].[nspGenPickSlipNo](
@c_OrderKey	   NVARCHAR(10),
@c_LoadKey      NVARCHAR(10),
@c_PickSlipType NVARCHAR(1),
@c_PickSlipNo   NVARCHAR(10) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_PickHeaderKey NVARCHAR(10),
   @b_success       int,
   @n_err           int,
   @c_errmsg        NVARCHAR(60)
   EXECUTE nspg_GetKey
   "PICKSLIP",
   9,
   @c_pickheaderkey   OUTPUT,
   @b_success   	    OUTPUT,
   @n_err       	    OUTPUT,
   @c_errmsg    	    OUTPUT
   SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
   BEGIN TRAN
      INSERT INTO PICKHEADER
      (PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop)
      VALUES
      (@c_pickheaderkey, @c_OrderKey, @c_LoadKey, "0", @c_PickSlipType,  "")
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
         END
      END
   ELSE
      BEGIN
         IF @@TRANCOUNT > 0
         BEGIN
            SELECT @c_PickSlipNo = @c_PickHeaderKey
            COMMIT TRAN
         END
      ELSE
         ROLLBACK TRAN
      END
   END


GO