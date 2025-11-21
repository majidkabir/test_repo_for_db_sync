SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel35_RDT                      */
/* Creation Date: 08-Apr-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-16706: RC-Data window Carton Manifest report           */
/*                                                                      */
/* Input Parameters: @c_Orderkey, @c_dropid                             */
/*                                                                      */
/* Called By:  dw = r_dw_carton_manifest_label_35_Rdt                   */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2022-09-10   mingle        Add new logic(ML01)                       */
/* 2022-09-12   mingle01      Add new mappings(ML02)                    */
/* 2023-09-26   CSCHONG       WMS-23649 revised filter logic (CS01)     */
/* 2023-10-26   CSCHONG       Devops Scripts Combine                    */
/* 2023-10-16   CSCHONG       WMS-23649 add storerkey as filter (CS02)  */
/************************************************************************/
CREATE   PROC [dbo].[isp_CartonManifestLabel35_RDT] (
      @c_Orderkey      NVARCHAR(10)
   ,  @c_Dropid        NVARCHAR(20)  = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT     INT
         , @n_StartTCnt INT
         , @n_weight   decimal(7,2)
         , @c_BypassPackSTS   NVARCHAR(1) ='N'     --CS01
         , @c_storerkey       NVARCHAR(10) = ''    --CS02

   SET @n_IsRDT     = 0
   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   

   --select @n_weight = s.STDGROSSWGT * sum(p.Qty)    
   --FROM pickdetail(nolock) as p
   --INNER join SKU as s ON p.Sku = s.Sku AND p.storerkey = s.storerkey
   --where Dropid = CASE WHEN @c_dropid = '' THEN p.DropID ELSE @c_dropid END
   --GROUP by p.DropID,p.Qty,s.STDGROSSWGT

   --SELECT @n_weight

--CS02 S
   SELECT @c_storerkey = OH.storerkey
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.OrderKey = @c_Orderkey

--CS02 E

   --CS01 S
   IF EXISTS (SELECT 1 FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME='REPORTCFG' AND Code='BypassPackSTS' AND Short='Y' AND storerkey = @c_storerkey)    --CS02
   BEGIN
      SET @c_BypassPackSTS ='Y'
   END

--CS01 E
 SELECT     Orderkey = ORDERS.Orderkey
         ,  ConsigneeKey = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         ,  C_Company  = ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  B_Address1 = ISNULL(RTRIM(ORDERS.B_ADDRESS1),'')
         ,  C_Address1 = ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')
         ,  C_Address2 = ISNULL(RTRIM(ORDERS.C_ADDRESS2),'')
         ,  C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,  C_City     = ISNULL(RTRIM(ORDERS.C_City),'')
         ,  C_Zip      = ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,  Route      = ISNULL(RTRIM(ORDERS.Route),'')
         ,  Carrier    = ISNULL(RTRIM(ROUTEMASTER.CarrierKey),'')
         ,  ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ExternPOKey    = ISNULL(RTRIM(ORDERS.ExternPOKey),'')
         ,  Invoice        = ISNULL(RTRIM(ORDERS.InvoiceNo),'')
         ,  DELIVERYDATE = ORDERS.DeliveryDate
         ,  Notes = CONVERT(NVARCHAR(60), ORDERS.Notes)
         ,  PickSlipNo = PACKHEADER.PickSlipNo
         ,  EditWho  = CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'') = '' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'') END
         ,  CartonNo = PACKDETAIL.CartonNo
         ,  SKU = PACKDETAIL.SKU
         ,  DIV = SUBSTRING(SKU.SkuGroup, 1, 2)
         --,  QTY = PACKDETAIL.QTY
         ,  QTY = CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.BUSR7 IN ('2','WET') AND PACK.INNERPACK = 0 THEN PACKDETAIL.QTY
                       WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.BUSR7 IN ('2','WET') AND PACK.INNERPACK > 0 THEN PACKDETAIL.QTY/PACK.INNERPACK   
                       ELSE PACKDETAIL.QTY END  --ML02
         --,  UOM = PACK.PackUOM3
         ,  UOM = CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.BUSR7 IN ('2','WET') AND PACK.INNERPACK = 0 THEN PACK.PackUOM3
                       WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.BUSR7 IN ('2','WET') AND PACK.INNERPACK > 0 THEN PACK.PackUOM2
                       ELSE PACK.PackUOM3 END   --ML02
         ,  DropID = ISNULL(RTRIM(PACKDETAIL.DropID),'')
         ,  TotalOrderQty = (SELECT SUM(PD.Qty)   FROM PACKDETAIL PD WITH (NOLOCK) WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo)
         ,  TotalCarton   = (SELECT MAX(CartonNo) FROM PACKDETAIL PD WITH (NOLOCK) WHERE PD.PickSlipNo = PACKHEADER.PickSlipNo)
         ,  CartonLBL = CASE WHEN CL.Code IS NOT NULL THEN RIGHT(ISNULL(RTRIM(ORDERS.ExternOrderkey),''),4) ELSE '' END
         ,  showskudesc = CL1.Short
         ,  DESCR = SKU.DESCR
         --,  SumNetWgt =  (SKU.NetWgt * PACKDETAIL.QTY)
         ,    SumNetWgt =  CASE WHEN ISNULL(SC2.Svalue,'') = '1'
                                THEN SUM(SKU.STDGROSSWGT *PACKDETAIL.QTY)
                                ELSE SUM(SKU.NetWgt * PACKDETAIL.QTY) END  --ML02
         ,  CartonType = LEFT(PACKDETAIL.DROPID,1)
         ,  Carton_Wgt = CONVERT(INT,ISNULL(CL2.Short,'0'))
         ,  C_State     = ISNULL(RTRIM(ORDERS.C_State),'')        
         ,  SKU.STYLE   --ML02
         ,  ISNULL(CL3.SHORT,'N')   --ML02
   FROM  PACKDETAIL  WITH (NOLOCK)
   JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
   JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                   AND (PACKDETAIL.Sku = SKU.Sku)
   JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
   LEFT JOIN  RDT.RDTUSER WITH (NOLOCK)  ON (PACKHEADER.EditWho = RDT.RDTUSER.UserName)
   LEFT JOIN  ROUTEMASTER WITH (NOLOCK)  ON (ORDERS.Route  = ROUTEMASTER.Route)
   LEFT JOIN  CODELKUP CL WITH (NOLOCK)  ON (CL.ListName = 'REPORTCFG')
                                         AND(CL.Code = 'ShowLast4ExtSONo')
                                         AND(CL.Storerkey = PACKHEADER.Storerkey)
                                         AND(CL.Long = 'r_dw_carton_manifest_label_35_rdt')
                                         AND(CL.Short IS NULL OR CL.Short = 'N')
   LEFT JOIN  CODELKUP CL1 WITH (NOLOCK)  ON (CL1.ListName = 'REPORTCFG')
                                         AND(CL1.Code = 'SHOWSKUDESC')
                                         AND(CL1.Storerkey = PACKHEADER.Storerkey)
                                         AND(CL1.Long = 'r_dw_carton_manifest_label_35_rdt')
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.LISTNAME='MPICRTWG') AND(CL2.Code = LEFT(PACKDETAIL.DropID,1))
                                         AND(CL2.Storerkey = PACKHEADER.Storerkey)
   LEFT JOIN rdt.STORERCONFIG SC WITH (NOLOCK) ON ( PACKHEADER.Storerkey = SC.Storerkey      
                                               AND  SC.Configkey='ShowUOMQty' AND SC.Svalue='1' )  --ML02
   LEFT JOIN rdt.STORERCONFIG SC2 WITH (NOLOCK) ON ( PACKHEADER.Storerkey = SC2.Storerkey      
                                               AND  SC2.Configkey='CalWgtFromPickdetail' AND SC2.Svalue='1' )  --ML02
   LEFT JOIN  CODELKUP CL3 WITH (NOLOCK)  ON (CL3.ListName = 'REPORTCFG')
                                         AND(CL3.Code = 'SHOWSKUSTYLE')
                                         AND(CL3.Storerkey = PACKHEADER.Storerkey)
                                         AND(CL3.Long = 'r_dw_carton_manifest_label_35_rdt') --ML02
   WHERE PACKHEADER.Orderkey = @c_orderkey
   AND   PACKDETAIL.DropID   = CASE WHEN @c_dropid = '' THEN PACKDETAIL.DropID ELSE @c_dropid END
   AND   PACKHEADER.Status = CASE WHEN @c_BypassPackSTS ='N' THEN '9' ELSE PACKHEADER.Status END     --CS01
   GROUP BY ORDERS.Orderkey
         ,  ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.B_ADDRESS1),'')
         ,  ISNULL(RTRIM(ORDERS.C_ADDRESS1),'')
         ,  ISNULL(RTRIM(ORDERS.C_ADDRESS2),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,  ISNULL(RTRIM(ORDERS.C_City),'')
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,  ISNULL(RTRIM(ORDERS.Route),'')
         ,  ISNULL(RTRIM(ROUTEMASTER.Carrierkey),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.ExternPOKey),'')
         ,  ISNULL(RTRIM(ORDERS.InvoiceNo),'')
         ,  ORDERS.DeliveryDate
         ,  CONVERT(NVARCHAR(60), ORDERS.Notes)
         ,  PACKHEADER.PickSlipNo
         ,  CASE WHEN  ISNULL(RDT.RDTUSER.FullName,'') = '' THEN PACKHEADER.EditWho ELSE ISNULL(RDT.RDTUSER.FullName,'') END
         ,  PACKDETAIL.CartonNo
         ,  PACKDETAIL.SKU
         ,  SUBSTRING(SKU.SkuGroup, 1, 2)
         ,  SKU.Packkey
         ,  PACKDETAIL.QTY
         ,  PACK.PackUOM3
         ,  ISNULL(RTRIM(PACKDETAIL.DropID),'')
         ,  CL.Code
         ,  CL1.short
         ,  SKU.DESCR
         ,  SKU.NetWgt
         ,  LEFT(PACKDETAIL.DROPID,1)
         ,  CONVERT(INT,ISNULL(CL2.Short,'0'))
         ,  ISNULL(RTRIM(ORDERS.C_State),'')
         ,  PACK.INNERPACK --ML02
         ,  PACK.PackUOM2  --ML02
         ,  SC.SValue   --ML02
         ,  SC2.SValue  --ML02
         ,  SKU.BUSR7   --ML02
         ,  SKU.STYLE   --ML02
         ,  ISNULL(CL3.SHORT,'N')   --ML02

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO