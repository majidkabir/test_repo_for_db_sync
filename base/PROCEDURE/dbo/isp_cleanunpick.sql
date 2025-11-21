SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_CleanUnPick                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - To update pickdetail status after pickslip scanned out.   */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/* 13-JUN-2014  Leong     1.1   SOS# 313369 - Exclude cancelled orders. */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_CleanUnPick]
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey NVARCHAR(10), @n_err INT

   WHILE (1 = 1)
   BEGIN
      SELECT @c_PickDetailKey = ''
      SELECT @c_PickDetailKey  = MIN(PickDetailKey)
      FROM Orders O WITH (NOLOCK)
      JOIN PickDetail P WITH (NOLOCK) ON (O.OrderKey = P.OrderKey AND O.StorerKey = P.StorerKey)
      JOIN PickingInfo F WITH (NOLOCK) ON (P.PickSlipNo = F.PickSlipNo AND ISNULL(RTRIM(F.ScanOutDate),'') <> '')
      WHERE P.Status < '5'
      AND ISNULL(RTRIM(P.PickSlipNo),'') <> ''
      AND (O.Status <> 'CANC' OR O.SOStatus <> 'CANC') -- SOS# 313369

      IF ISNULL(RTRIM(@c_PickDetailKey),'') = ''
         BREAK

      BEGIN TRAN
      UPDATE PICKDETAIL
      SET STATUS = '5'
      WHERE PickDetailKey = @c_PickDetailKey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         ROLLBACK
         BREAK
      END
      ELSE
      BEGIN
         COMMIT
      END
   END
END

GO