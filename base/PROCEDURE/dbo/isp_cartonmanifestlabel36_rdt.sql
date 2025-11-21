SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel36_RDT                      */
/* Creation Date: 04-MAY-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-16910 WMS-16910_PH_YLEO_Shipment_Label_Report          */
/*                                                                      */
/* Input Parameters: @c_Orderkey                                        */                                     
/*                                                                      */
/* Called By:  dw = r_dw_carton_manifest_label_36_Rdt                   */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 15-Jun-2021  CSCHONG       WMS-16910 revised field logic (CS01)      */
/* 24-Jul-2021  CSCHONG       WMS-16910 revised field logic (CS02)      */
/* 28-JUL-2021  CSCHONG       WMS-17587 fix dupliacte qty issue (CS03)  */
/* 24-JAN-2022  MINGLE        WMS-18724 add new field(ML01)             */
/* 24-JAN-2022  MINGLE        DevOps Combine Script                     */
/* 28-OCT-2022  MINGLE        WMS-21093 add new mappings (ML02)         */
/* 09-DEC-2022  MINGLE        WMS-21328 modify logic (ML03)             */
/* 26-MAY-2023  CSCHONG       WMS-22605 add new field (CS04)            */
/************************************************************************/
CREATE   PROC [dbo].[isp_CartonManifestLabel36_RDT] (
      @c_Orderkey      NVARCHAR(10) 
 
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT        INT
         , @n_StartTCnt    INT
         , @c_sku          NVARCHAR(20)
         , @c_ODUDF02      NVARCHAR(18)
         , @c_DeliveryMode NVARCHAR(30)
         , @n_CAMT         FLOAT
         , @c_editdate     NVARCHAR(50)
         , @c_SPCNotes1    NVARCHAR(35)   --CS01 
         , @c_SPCNotes2    NVARCHAR(35)   --CS01 

   SET @n_IsRDT     = 0
   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END


  SET @c_sku = ''
  SET @c_ODUDF02 = ''
  SET @c_DeliveryMode = ''
  SET @n_CAMT = 0
  SET @c_editdate = ''


   SELECT @c_sku = MAX(OD.SKU)
         ,@c_ODUDF02 = MAX(ISNULL(OD.Userdefine02,''))
   FROM ORDERDETAIL OD WITH (NOLOCK)
   WHERE OD.Orderkey = @c_Orderkey

  IF EXISTS (SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
             WHERE orderkey = @c_Orderkey AND SKU LIKE '%COD%')
  BEGIN
     SET @c_sku = 'COD'
  END

   SELECT @n_CAMT = ISNULL(SUM(OD.unitprice),0)
   FROM ORDERDETAIL OD WITH (NOLOCK)
   WHERE OD.Orderkey = @c_Orderkey
   AND OD.sku LIKE '%COD%'
   AND OD.Userdefine02 = 'PN' 

  SELECT @c_DeliveryMode = OIF.DeliveryMode
  FROM dbo.OrderInfo OIF WITH (NOLOCK) 
  WHERE OIF.Orderkey = @c_Orderkey

----CS04 S
--   SELECT TOP 1 @c_SPCNotes1 = SUBSTRING(c.long,0,35)
--               ,@c_SPCNotes2 = SUBSTRING(c.Notes,0,35)
--   FROM dbo.CODELKUP C WITH (NOLOCK)
--   WHERE C.LISTNAME ='SHIPMETHOD'
--   AND  ISNULL(C.notes,'') <> ''   AND ISNULL(C.long,'') <> '' 
----CS04 E

 SELECT     Orderkey = ORDERS.Orderkey
         ,  ConsigneeKey = ISNULL(RTRIM(ORDERS.ConsigneeKey),'') 
         --,  C_Company  = ISNULL(RTRIM(ORDERS.C_Company),'') 
         ,  C_Company  = CASE WHEN STORER.SUSR5 = 'FOM' THEN ISNULL(RTRIM(ORDERS.C_Contact1),'') ELSE ISNULL(RTRIM(ORDERS.C_Company),'') END --ML03 
         ,  F_Address1 = ISNULL(RTRIM(FA.notes),'')  
         ,  C_Address1 = ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')      
         ,  C_Address2 = ISNULL(RTRIM(ORDERS.C_ADDRESS2),'') 
         ,  C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')   
         ,  C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4),'')  
         ,  C_City     = ISNULL(RTRIM(ORDERS.C_City),'')  
         ,  C_Zip      = ISNULL(RTRIM(ORDERS.C_Zip),'')   
         ,  c_phone1      = ISNULL(RTRIM(ORDERS.c_phone1),'')   
         ,  Trackingno    = ISNULL(RTRIM(ORDERS.trackingno),'')  
         --,  ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'') 
         ,  ExternOrderkey  = CASE WHEN STORER.SUSR5 = 'FOM' THEN ISNULL(RTRIM(ORDERS.M_Company),'') ELSE ISNULL(RTRIM(ORDERS.ExternOrderkey),'') END --ML03 
         ,  ZCUDF02    = ISNULL(RTRIM(SHPC.UDF03),'')                      --CS01
         ,  ZCUDF03    = ISNULL(RTRIM(ZC.UDF03),'')  
         ,  ZCUDF04    = ISNULL(RTRIM(ZC.UDF04),'')  
         ,  PVALUE     = ISNULL(ABS(CAST(@n_CAMT AS DECIMAL(10,2))),0) --CASE WHEN @c_sku='COD' AND @c_ODUDF02 = 'PN' THEN ISNULL(OIF.OrderInfo03,'') ELSE '' END  
         ,  PickSlipNo = PACKHEADER.PickSlipNo 
      --   ,  EditWho  = CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'') = '' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'') END 
         ,  CartonNo = PACKDETAIL.CartonNo  
      --   ,  SKU = PACKDETAIL.SKU  
         ,  CODVALUE = CASE WHEN @c_sku LIKE '%COD%' THEN 'COD'  ELSE CASE WHEN @c_DeliveryMode LIKE '%PICK-UP%' THEN 'PICK-UP' ELSE 'REG' END  END 
         ,  QTY = SUM(PACKDETAIL.QTY)
       --  ,  UOM = PACK.PackUOM3
         ,  Labelno = ISNULL(RTRIM(PACKDETAIL.Labelno),'')
         ,  TotalOrderQty = (SELECT SUM(PD.Qty)   FROM PACKDETAIL PD WITH (NOLOCK) WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo)
         ,  TotalCarton   = (SELECT MAX(CartonNo) FROM PACKDETAIL PD WITH (NOLOCK) WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo)                   
      --   ,  CartonLBL = CASE WHEN CL.Code IS NOT NULL THEN RIGHT(ISNULL(RTRIM(ORDERS.ExternOrderkey),''),4) ELSE '' END  
      --   ,  showskudesc = CL1.Short
      --   ,  DESCR = SKU.DESCR
        -- ,  SumNetWgt =  (SKU.NetWgt * PACKDETAIL.QTY)
         ,  CBM = PACKHEADER.TOTCTNCUBE
         ,  Carton_Wgt = PACKHEADER.TotCtnWeight
         ,  C_State     = ISNULL(RTRIM(ORDERS.C_State),'')  
         ,  VOLWGT = CAST((PACKHEADER.TOTCTNCUBE/3500) AS DECIMAL(10,7))
         ,  editdate = CONVERT(VARCHAR(50),Packheader.editdate,101) + ' ' + FORMAT(Packheader.editdate,'hh:mm:ss tt')   --ML01
         ,  LBC = CASE WHEN SHPC.Code = 'PHSDLBC' THEN 'No automatic RTS' ELSE '' END   --ML01
         ,  Packheader.editdate   --ML01 
         ,  FA.Notes2   --ML02
         ,  SUBSTRING(SHPC.long,0,35) AS Text01    --CS04
         ,  SUBSTRING(SHPC.Notes,0,35) AS Text02    --CS04 
   FROM  PACKDETAIL  WITH (NOLOCK) 
   JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
   JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   CROSS APPLY(SELECT DISTINCT OD.storerkey,OD.SKU,PD.CartonNo,pd.qty AS PQTY FROM  ORDERDETAIL OD WITH (NOLOCK) 
               JOIN Packdetail PD WITH (NOLOCK) ON PD.StorerKey=OD.StorerKey AND PD.SKU = OD.Sku
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OD.OrderKey AND PH.PickSlipNo=PD.PickSlipNo where ORDERS.Orderkey = OD.OrderKey 
               AND OD.StorerKey = orders.Storerkey AND OD.userdefine02 <> 'K' AND OD.sku = PACKDETAIL.sku AND PD.Cartonno = PACKDETAIL.Cartonno) AS OD --CS03
   JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                   AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
   JOIN  STORER      WITH (NOLOCK)  ON (STORER.StorerKey = ORDERS.StorerKey)  --ML03
   LEFT JOIN  ORDERINFO OIF WITH (NOLOCK)  ON (OIF.OrderKey = ORDERS.Orderkey)
   LEFT JOIN  CODELKUP FA WITH (NOLOCK)  ON (FA.ListName = 'BRANCHCODE') 
                                         AND(FA.short = ORDERS.Facility)
                                         AND(FA.Storerkey = ORDERS.Storerkey)
   LEFT JOIN  CODELKUP ZC WITH (NOLOCK)  ON (ZC.ListName = 'ZipCode') 
                                         AND(ZC.Code = ORDERS.c_zip)
                                         AND(ZC.Storerkey = ORDERS.Storerkey)
   --CS01 START
    LEFT JOIN  CODELKUP SHPC WITH (NOLOCK)  ON (SHPC.ListName = 'SHIPMETHOD') 
                                         AND(SHPC.Code = ORDERS.shipperkey)
                                         AND(SHPC.Storerkey = ORDERS.Storerkey)
   --CS01 END
   WHERE PACKHEADER.Orderkey = @c_orderkey  
  -- AND   PACKDETAIL.DropID   = CASE WHEN @c_dropid = '' THEN PACKDETAIL.DropID ELSE @c_dropid END 
  -- AND   PACKHEADER.Status = '9'
   AND ISNULL(ORDERS.shipperkey,'') <> '' AND ISNULL(ORDERS.trackingno,'') <> ''
   --AND OD.userdefine02 <> 'K'             --CS03
   GROUP BY ORDERS.Orderkey
         ,  ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         --,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  CASE WHEN STORER.SUSR5 = 'FOM' THEN ISNULL(RTRIM(ORDERS.C_Contact1),'') ELSE ISNULL(RTRIM(ORDERS.C_Company),'') END  --ML03 
         ,  ISNULL(RTRIM(FA.notes),'') 
         ,  ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')     
         ,  ISNULL(RTRIM(ORDERS.C_ADDRESS2),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'') 
         ,  ISNULL(RTRIM(ORDERS.C_City),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')        
         ,  ISNULL(RTRIM(ORDERS.c_phone1),'') 
         ,  ISNULL(RTRIM(ORDERS.trackingno),'')   
         --,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         ,  CASE WHEN STORER.SUSR5 = 'FOM' THEN ISNULL(RTRIM(ORDERS.M_Company),'') ELSE ISNULL(RTRIM(ORDERS.ExternOrderkey),'') END --ML03
        -- ,  ISNULL(RTRIM(ZC.UDF02),'')      --CS01
         ,  ISNULL(RTRIM(SHPC.UDF03),'')       --CS01 
         ,  ISNULL(RTRIM(ZC.UDF03),'')   
         ,  ISNULL(RTRIM(ZC.UDF04),'')   
      --   ,  CONVERT(NVARCHAR(60), ORDERS.Notes) 
         ,  PACKHEADER.PickSlipNo 
         ,  CASE WHEN @c_sku='COD' AND @c_ODUDF02 = 'PN' THEN ISNULL(OIF.OrderInfo03,'') ELSE '' END
         ,  PACKDETAIL.CartonNo  
       --  ,  PACKDETAIL.SKU  
       --  ,  SUBSTRING(SKU.SkuGroup, 1, 2)   
     --    ,  SKU.Packkey  
        -- ,  PACKDETAIL.QTY
    --     ,  PACK.PackUOM3
         ,  ISNULL(RTRIM(PACKDETAIL.Labelno),'')
         --,  CL.Code
         --,  CL1.short
         --,  SKU.DESCR
         --,  SKU.NetWgt
         ,  PACKHEADER.TOTCTNCUBE
         ,PACKHEADER.TotCtnWeight
         , ISNULL(RTRIM(ORDERS.C_State),'') 
         , CASE WHEN SHPC.Code = 'PHSDLBC' THEN 'No automatic RTS' ELSE '' END   --ML01
         , Packheader.editdate   --ML01
         ,  FA.Notes2   --ML02
         , SUBSTRING(SHPC.Notes,0,35)   --CS04
         , SUBSTRING(SHPC.long,0,35)    --CS04

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO