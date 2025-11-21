SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel31_rdt                      */
/* Creation Date: 11-Feb-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-7938: Lululemon HK - New NSO manifest Label            */
/*                                                                      */
/* Input Parameters: @c_PickslipNo, @c_CartonNoStart, @c_CartonNoEnd    */
/*                    - 1) RDT    - PickslipNo, Start Carton# &         */
/*                                  End Carton#                         */
/*                                                                      */
/* Called By:  dw = r_dw_carton_manifest_label_31_rdt                   */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-OCT-2023  CSCHONG       Devops Scripts Combine & WMS-23796 (CS01) */
/************************************************************************/
CREATE   PROC [dbo].[isp_CartonManifestLabel31_rdt] (
      @c_PickslipNo     NVARCHAR(10)
   ,  @c_CartonNoStart  NVARCHAR(20)
   ,  @c_CartonNoEnd    NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT     INT
         , @n_StartTCnt INT

   SET @n_IsRDT     = 0
   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

      SELECT PACKHEADER.PickSlipNo
            ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
            ,PACKDETAIL.CartonNo
            ,PACKDETAIL.LabelNo
            ,Style = ISNULL(RTRIM(SKU.Style),'')
            ,Color = ISNULL(RTRIM(SKU.BUSR7),'')--ISNULL(RTRIM(SKU.Color),'')    --CS01
            ,SDESCR =MAX(SKU.DESCR)-- substring(Max(SKU.DESCR),1,len(Max(SKU.DESCR))-4) --CS01
            ,Qty = SUM(PACKDETAIL.Qty)
            ,SSize = ISNULL(RTRIM(SKU.Size),'')            --CS01
        FROM ORDERS     WITH (NOLOCK)
        JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
        JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
        JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey) AND (PACKDETAIL.Sku = SKU.Sku)
       WHERE PACKHEADER.PickSlipNo = @c_PickslipNo
         AND PACKDETAIL.CartonNo   BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
       GROUP BY PACKHEADER.PickSlipNo
               ,ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
               ,PACKDETAIL.CartonNo
               ,PACKDETAIL.LabelNo
               ,ISNULL(RTRIM(SKU.Style),'')
               ,ISNULL(RTRIM(SKU.BUSR7),'')           --CS01
               ,ISNULL(RTRIM(SKU.Size),'')            --CS01
              -- ,ISNULL(RTRIM(SKU.Color),'')
       ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
              ,PACKDETAIL.LabelNo
               ,PACKDETAIL.CartonNo
               ,ISNULL(RTRIM(SKU.Style),'')


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO