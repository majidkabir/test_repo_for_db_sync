SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel12                          */
/* Creation Date: 19-Jul-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#284151: VFTBL - Carton & Manifest Label                */
/*                                                                      */
/* Input Parameters: @c_PickslipNo, @c_CartonNoStart, @c_CartonNoEnd    */
/*                    - 1) Exceed - PickslipNo, Start Carton# &         */
/*                                  End Carton#                         */
/*                    - 2) RDT    - PickslipNo, Start Label# &          */
/*                                  End Label#                          */                                         
/*                                                                      */
/* Called By:  dw = r_dw_carton_manifest_label_12                       */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_CartonManifestLabel12] (
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

   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  

   IF @n_IsRDT = 1
   BEGIN
      SELECT PACKHEADER.PickSlipNo      
            ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
            ,DischargePlace = ISNULL(RTRIM(ORDERS.DischargePlace),'')
            ,PACKDETAIL.CartonNo 
            ,PACKDETAIL.LabelNo 
            ,Style = ISNULL(RTRIM(SKU.Style),'')
            ,Color = ISNULL(RTRIM(SKU.Color),'')
            ,Q     = SUBSTRING(SKU.Sku,12,1) 
            ,Size  = ISNULL(RTRIM(SKU.Size),'')
            ,Measurement  = ISNULL(RTRIM(SKU.Measurement),'') 
            ,MaxCartonNo =  ISNULL((SELECT CONVERT(VARCHAR(5), MAX(PD.CartonNo))
                                   FROM PACKDETAIL PD WITH (NOLOCK) 
                                   JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
                                   WHERE PH.PickSlipNo = PACKHEADER.PickSlipNo
                                   GROUP BY PH.Orderkey
                                   HAVING SUM(PD.Qty) = (SELECT SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) 
                                                         FROM ORDERDETAIL OD WITH (NOLOCK)  
                                                         WHERE OD.Orderkey = PH.Orderkey)),'')
            ,Qty = SUM(PACKDETAIL.Qty)
            ,PrintDate = GETDATE()
        FROM ORDERS     WITH (NOLOCK) 
        JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
        JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
        JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey) AND (PACKDETAIL.Sku = SKU.Sku)
       WHERE PACKHEADER.PickSlipNo = @c_PickslipNo
         AND PACKDETAIL.LabelNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd
       GROUP BY PACKHEADER.PickSlipNo
               ,ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
               ,ISNULL(RTRIM(ORDERS.DischargePlace),'')
               ,PACKDETAIL.CartonNo
               ,PACKDETAIL.LabelNo 
               ,ISNULL(RTRIM(SKU.Style),'')
               ,ISNULL(RTRIM(SKU.Color),'')
               ,SUBSTRING(SKU.Sku,12,1) 
               ,ISNULL(RTRIM(SKU.Size),'')
               ,ISNULL(RTRIM(SKU.Measurement),'') 
       ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
               ,PACKDETAIL.CartonNo 
               ,ISNULL(RTRIM(SKU.Style),'')
               ,ISNULL(RTRIM(SKU.Color),'')
   END  
   ELSE
   BEGIN
      SELECT PACKHEADER.PickSlipNo      
            ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
            ,DischargePlace = ISNULL(RTRIM(ORDERS.DischargePlace),'')
            ,PACKDETAIL.CartonNo 
            ,PACKDETAIL.LabelNo 
            ,Style = ISNULL(RTRIM(SKU.Style),'')
            ,Color = ISNULL(RTRIM(SKU.Color),'')
            ,Q     = SUBSTRING(SKU.Sku,12,1) 
            ,Size  = ISNULL(RTRIM(SKU.Size),'')
            ,Measurement  = ISNULL(RTRIM(SKU.Measurement),'') 
            ,MaxCartonNo =  ISNULL((SELECT CONVERT(VARCHAR(5), MAX(PD.CartonNo))
                                   FROM PACKDETAIL PD WITH (NOLOCK) 
                                   JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
                                   WHERE PH.PickSlipNo = PACKHEADER.PickSlipNo
                                   GROUP BY PH.Orderkey
                                   HAVING SUM(PD.Qty) = (SELECT SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) 
                                                         FROM ORDERDETAIL OD WITH (NOLOCK)  
                                                         WHERE OD.Orderkey = PH.Orderkey)),'')
            ,Qty = SUM(PACKDETAIL.Qty)
            ,PrintDate = GETDATE()
        FROM ORDERS     WITH (NOLOCK) 
        JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
        JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
        JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey) AND (PACKDETAIL.Sku = SKU.Sku)
       WHERE PACKHEADER.PickSlipNo = @c_PickslipNo
         AND PACKDETAIL.CartonNo   BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
       GROUP BY PACKHEADER.PickSlipNo
               ,ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
               ,ISNULL(RTRIM(ORDERS.DischargePlace),'')
               ,PACKDETAIL.CartonNo
               ,PACKDETAIL.LabelNo 
               ,ISNULL(RTRIM(SKU.Style),'')
               ,ISNULL(RTRIM(SKU.Color),'')
               ,SUBSTRING(SKU.Sku,12,1) 
               ,ISNULL(RTRIM(SKU.Size),'')
               ,ISNULL(RTRIM(SKU.Measurement),'') 
       ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
               ,PACKDETAIL.CartonNo 
               ,ISNULL(RTRIM(SKU.Style),'')
               ,ISNULL(RTRIM(SKU.Color),'')
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO