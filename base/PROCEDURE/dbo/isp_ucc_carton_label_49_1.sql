SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_49_1                               */
/* Creation Date: 29-MAY-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  convert from sql to SP                                     */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_49_1                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_49_1]
           @c_PickSlipNo      NVARCHAR(10)
         , @n_CartonNo        INT

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT
         
         , @n_PrintOrderAddresses   INT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

      SELECT dbo.PackDetail.CartonNo as Cartonno
        , dbo.SKU.Style as style
        , dbo.SKU.Color as color
        , CASE WHEN ISNULL(C.short,'')='Y' THEN 
          CASE WHEN sku.measurement IN ('','U') THEN dbo.SKU.Size ELSE ISNULL(sku.measurement,'') END
          ELSE dbo.SKU.Size END [Size]
        , dbo.PackDetail.Qty as qty
     FROM dbo.PackDetail WITH (NOLOCK) 
     JOIN dbo.SKU WITH (NOLOCK)  
       ON (dbo.Sku.Storerkey = dbo.PackDetail.Storerkey)  
      AND (dbo.Sku.Sku = dbo.PackDetail.Sku)
    LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= PackDetail.Storerkey
          AND listname = 'REPORTCFG' and code ='GetSkuMeasurement'
      AND long='r_dw_ucc_carton_label_49'
    WHERE (dbo.PackDetail.PickSlipNo= @c_PickSlipNo)
      AND (dbo.PackDetail.CartonNo =@n_CartonNo)

QUIT_SP:
END -- procedure

GO