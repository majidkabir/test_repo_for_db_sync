SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CartonManifestLabel34    								*/
/* Creation Date: 2020-06-17                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-13785                                                   */
/*        : Copy from isp_CartonManifestLabel08                         */
/*                                                                      */
/* Called By: r_dw_carton_manifest_Label_34                             */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_CartonManifestLabel34] (
      @c_Storerkey      NVARCHAR(15)
   ,  @c_Pickslipno     NVARCHAR(10)
   ,  @c_StartcartonNo  NVARCHAR(5)
   ,  @c_EndcartonNo    NVARCHAR(5))
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*
   DECLARE @c_Loadkey      NVARCHAR(10)
         , @c_Consigneekey NVARCHAR(15)
         , @c_C_Company    NVARCHAR(45)
         , @c_Division     NVARCHAR(30)
         , @c_Divisions    NVARCHAR(100)
         , @n_CartonNo     INT
         , @n_PCartonNo    INT
         , @n_TotalPcs     INT
         , @n_PTotalPcs    INT

   SET @c_Loadkey       = ''
   SET @c_Consigneekey  = ''
   SET @c_C_Company     = '' 
   SET @c_Division      = ''
   SET @c_Divisions     = ''
   SET @n_CartonNo      = 0
   SET @n_PCartonNo     = 0
   SET @n_TotalPcs      = 0
   SET @n_PTotalPcs     = 0

   CREATE Table #TempLBL (
            PickSlipNo   NVARCHAR(10)  NULL
         ,  Loadkey      NVARCHAR(10)  NULL
         ,  Consigneekey NVARCHAR(15)  NULL
         ,  C_Company    NVARCHAR(45)  NULL
         ,  Divisions    NVARCHAR(100) NULL
         ,  CartonNo     INT           NULL
         ,  TotalPCs     INT           NULL)  
 
 
 
   DECLARE CTNLBL_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT  DISTINCT PACKHEADER.LoadKey
         ,ISNULL(RTRIM(ORDERS.Consigneekey),'')
         ,ISNULL(RTRIM(ORDERS.C_Company),'')  
         ,ISNULL(RTRIM(SKU.BUSR3),'')
         ,ISNULL(PACKDETAIL.CartonNo,0)
         ,(SELECT SUM(PKD.Qty) From PACKDETAIL PKD WITH (NOLOCK) 
                        WHERE PKD.PickslipNo = PACKHEADER.Pickslipno 
                        AND PKD.CartonNo = PACKDETAIL.CartonNo) 
    FROM PACKHEADER WITH (NOLOCK) 
    JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)		
                                  AND(PACKDETAIL.Sku = SKU.Sku)	
   WHERE ORDERS.Storerkey = @c_Storerkey
     AND PACKHEADER.PickSlipNo = @c_pickslipno 
     AND	PACKDETAIL.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
   ORDER BY ISNULL(PACKDETAIL.CartonNo,0)
         ,  ISNULL(RTRIM(SKU.BUSR3),'')

   OPEN CTNLBL_CUR  
  
   FETCH NEXT FROM CTNLBL_CUR INTO @c_Loadkey
                                 , @c_Consigneekey
                                 , @c_C_Company  
                                 --, @c_Division
                                 , @n_CartonNo
                                 , @n_TotalPCs
 
   WHILE @@FETCH_STATUS = 0  
   BEGIN
      SET @n_PCartonNo = @n_CartonNo
      SET @n_PTotalPcs = @n_TotalPCs
      SET @c_Divisions = @c_Divisions + @c_Division + ', '

      FETCH NEXT FROM CTNLBL_CUR INTO @c_Loadkey
                                    , @c_Consigneekey
                                    , @c_C_Company  
                                   -- , @c_Division
                                    , @n_CartonNo
                                    , @n_TotalPCs

      IF @n_CartonNo <> @n_PCartonNo  OR @@FETCH_STATUS <> 0 
      BEGIN
         SET @c_Divisions = SUBSTRING(@c_Divisions, 1, LEN(@c_Divisions) - 1)

         --INSERT INTO #TempLBL ( PickSlipNo, Loadkey, Consigneekey, C_Company, Divisions, CartonNo, TotalPCs )
         --VALUES (@c_PickSlipNo, @c_Loadkey, @c_Consigneekey, @c_C_Company, @c_Divisions, @n_PCartonNo, @n_PTotalPcs)
         INSERT INTO #TempLBL ( PickSlipNo, Loadkey, Consigneekey, C_Company, CartonNo, TotalPCs )
         VALUES (@c_PickSlipNo, @c_Loadkey, @c_Consigneekey, @c_C_Company, @n_PCartonNo, @n_PTotalPcs)

         --SET @c_Divisions = ''
      END

   END
   CLOSE CTNLBL_CUR
   DEALLOCATE CTNLBL_CUR

   SELECT PickSlipNo
         ,Loadkey
         ,Consigneekey
         ,C_Company
         ,Divisions
         ,CartonNo
         ,TotalPCs
   FROM #TempLBL
   
   DROP TABLE #TempLBL
   */
   
    SELECT PACKHEADER.Pickslipno, PACKHEADER.LoadKey
         ,MAX(ISNULL(RTRIM(ORDERS.Consigneekey),'')) AS Consigneekey
         ,MAX(ISNULL(RTRIM(ORDERS.C_Company),'')) AS C_Company
         ,ISNULL(PACKDETAIL.CartonNo,0) AS CartonNo 
         ,(SELECT SUM(PKD.Qty) From PACKDETAIL PKD WITH (NOLOCK) 
                        WHERE PKD.PickslipNo = PACKHEADER.Pickslipno 
                        AND PKD.CartonNo = PACKDETAIL.CartonNo) AS Qty
    INTO #TEMP_PACK
    FROM PACKHEADER WITH (NOLOCK) 
    JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)		
                                  AND(PACKDETAIL.Sku = SKU.Sku)	
   WHERE ORDERS.Storerkey = @c_Storerkey
     AND PACKHEADER.PickSlipNo = @c_pickslipno 
     AND	PACKDETAIL.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
   GROUP BY PACKHEADER.Pickslipno, PACKHEADER.LoadKey, PACKDETAIL.CartonNo
   ORDER BY ISNULL(PACKDETAIL.CartonNo,0)   
   
   SELECT P.PickslipNo, 
          P.LoadKey,
          P.Consigneekey,
          P.C_Company,
          P.CartonNo,
          P.Qty,
          /*CS02 Start*/
          --SUM(CASE WHEN SKU.Class = 'LCLK' THEN PD.Qty ELSE 0 END) AS ClassQty1,
          --SUM(CASE WHEN SKU.Class = 'LYES' THEN PD.Qty ELSE 0 END) AS ClassQty2,
          --SUM(CASE WHEN SKU.Class = 'MCLK' THEN PD.Qty ELSE 0 END) AS ClassQty3,
          --SUM(CASE WHEN SKU.Class = 'MLIT' THEN PD.Qty ELSE 0 END) AS ClassQty4,
          --SUM(CASE WHEN SKU.Class = 'D3' THEN PD.Qty ELSE 0 END) AS ClassQty5,
          --SUM(CASE WHEN SKU.Class = 'D4' THEN PD.Qty ELSE 0 END) AS ClassQty6,
          --SUM(CASE WHEN SKU.Class = 'D5' THEN PD.Qty ELSE 0 END) AS ClassQty7,
          --SUM(CASE WHEN SKU.Class = 'MJNS' THEN PD.Qty ELSE 0 END) AS ClassQty8,           --(CS01)
          --SUM(CASE WHEN SKU.Class = 'LBND' THEN PD.Qty ELSE 0 END) AS ClassQty9            --(CS01)
          SUM(CASE WHEN SKU.BUSR3  = 'JDV' THEN PD.Qty ELSE 0 END) AS ClassQty1,             --(CS03)
          SUM(CASE WHEN SKU.BUSR3  = 'LAC' THEN PD.Qty ELSE 0 END) AS ClassQty2,             --(CS03)
          SUM(CASE WHEN SKU.BUSR3  = 'LDV' THEN PD.Qty ELSE 0 END) AS ClassQty3,             --(CS03)
          SUM(CASE WHEN SKU.BUSR3  = 'MAC' THEN PD.Qty ELSE 0 END) AS ClassQty4,             --(CS03)
          SUM(CASE WHEN SKU.BUSR3  = 'MDV' THEN PD.Qty ELSE 0 END) AS ClassQty5,             --(CS03)
          '' AS ClassQty6,
          '' AS ClassQty7,
          '' AS ClassQty8,
          '' AS ClassQty9  
        /*CS02 End*/  
   FROM #TEMP_PACK P   
   JOIN PACKDETAIL PD(NOLOCK) ON P.Pickslipno = PD.Pickslipno AND P.Cartonno = PD.Cartonno
   JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   GROUP BY P.PickslipNo, 
            P.LoadKey,
            P.Consigneekey,
            P.C_Company,
            P.CartonNo,
            P.Qty
   ORDER BY P.CartonNo
      
END

GO