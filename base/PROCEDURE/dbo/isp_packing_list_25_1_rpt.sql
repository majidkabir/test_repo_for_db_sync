SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_25_1_rpt                               */
/* Creation Date: 22-JAN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3828 - [TW] PMA add New View Report --Packlist New      */
/*        :                                                             */
/* Called By:r_dw_print_packlist_09                                     */
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
CREATE PROC [dbo].[isp_packing_list_25_1_rpt]
         @c_PickSlipNo  NVARCHAR(10)
      ,  @n_CartonNo    INT
      ,  @c_Style       NVARCHAR(20)
      ,  @c_Color       NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT SKU.Size
         ,PD.Qty
   FROM PACKHEADER     PH  WITH (NOLOCK) 
   JOIN PACKDETAIL     PD  WITH (NOLOCK) ON (PH.PickSlipNo= PD.PickSlipNo)
   JOIN SKU            SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku       = SKU.Sku)
   WHERE PD.PickSlipNo = @c_PickSlipNo
   AND   PD.CartonNo   = @n_CartonNo
   AND   SKU.Style     = @c_Style
   AND   SKU.Color     = @c_Color
   ORDER BY RIGHT(RTRIM(SKU.SKU),3)
      ,     SKU.Size
END -- procedure

GO