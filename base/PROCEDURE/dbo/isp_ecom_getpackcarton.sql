SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Ecom_GetPackCarton                                  */
/* Creation Date: 11-JUN-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Performance Tune                                            */
/*        :                                                             */
/* Called By: ECOM PackHeader - ue_saveend                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_GetPackCarton]
           @c_PickSlipNo   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SELECT DISTINCT PACKDETAIL.PickSlipNo
      ,PACKDETAIL.CartonNo
      ,PACKDETAIL.Storerkey
      ,PACKHEADER.Status 
      ,'                     '    Sku
      ,'                               '    SerialNo
      ,'N'    SerialNoRequired
      ,'N'    SKUVASRequired
         ,'          '    CartonGroup
        ,'N' AutoCloseCarton
        ,'    ' rowfocusindicatorcol
   FROM PACKDETAIL WITH (NOLOCK)
   JOIN   PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 

QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO