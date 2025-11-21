SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_CartonManifestLabel34_rdt                           */
/* Creation Date: 2020-03-30                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-12721 - SG - PMI - Packing List [CR]                    */
/*        :                                                             */
/* Called By: Normal Packing CTNMNFLBL                                  */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-09-25  WLChooi  1.1   WMS-15214 - Get Descr using ALTSKU (WL01) */
/************************************************************************/
CREATE PROC [dbo].[isp_CartonManifestLabel34_rdt]
           @c_PickslipNo         NVARCHAR(10)
         , @c_CartonNoStart      NVARCHAR(10)            
         , @c_CartonNoEnd        NVARCHAR(10) 
         , @c_RecGrp             NVARCHAR(5) = 'H'             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt    INT = @@TRANCOUNT

         , @c_Orderkey     NVARCHAR(10)   = ''
         , @c_DropID       NVARCHAR(20)   = ''
         , @n_LastCaseID   INT            = 0

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @c_Orderkey = PH.Orderkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickslipNo
   
   IF @c_RecGrp = 'H'
   BEGIN
      GOTO HEADER_REC
   END

   IF @c_RecGrp = 'D'
   BEGIN
      GOTO DETAIL_REC
   END

   HEADER_REC:

   DECLARE @n_TotalCarton INT          = 0

   SELECT @n_TotalCarton = COUNT(DISTINCT PD.CartonNo)
   FROM PACKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_PickslipNo

   SELECT O.Orderkey     
   ,   ExternOrderKey = ISNULL(RTRIM(O.ExternOrderKey), '')     
   ,   O.Storerkey      
   ,   Consigneekey = ISNULL(RTRIM(O.ConsigneeKey), '')     
   ,   PH.PickSlipNo     
   ,   c_Company    = ISNULL(RTRIM(O.c_Company), '')     
   ,   c_Address1   = ISNULL(RTRIM(O.c_Address1), '')                              
   ,   c_Address2   = ISNULL(RTRIM(O.c_Address2), '')       
   ,   c_Address3   = ISNULL(RTRIM(O.c_Address3), '')                            
   ,   c_Address4   = ISNULL(RTRIM(O.c_Address4), '')                          
   ,   c_C_Zip      = ISNULL(RTRIM(o.c_zip), '')                       
   ,   OHRoute      = ISNULL(RTRIM(O.[Route]), '')                               
   ,   Country      = ISNULL(RTRIM(O.c_Country), '')                               
   ,   DelDate      = O.DeliveryDate                      
   ,   Altsku       = S.ALTSKU                            
   ,   SDescr       = ISNULL(RTRIM(S.DESCR), '')     
   ,   CartonNo     = PD.CartonNo
   ,   labelno      = PD.labelno    
   ,   TotalCarton  = @n_TotalCarton    
   ,   PD.Sku    
   ,   QtyCtn       = CASE WHEN P.OtherUnit1 = 0 THEN 0 ELSE FLOOR(SUM(PD.Qty) / P.OtherUnit1) END  
   ,   QtyPack      = CASE WHEN P.OtherUnit1 = 0 THEN SUM(PD.Qty) ELSE SUM(PD.Qty) % CONVERT(INT, P.OtherUnit1) END   
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON  PD.PickSlipNo= PH.PickSlipNo  
   JOIN ORDERS     O  WITH (NOLOCK) ON  O.Orderkey   = PH.Orderkey
   JOIN STORER     ST WITH (NOLOCK) ON  ST.StorerKey = O.Storerkey    
   JOIN SKU        S  WITH (NOLOCK) ON  S.Storerkey  = PD.Storerkey   
                                    AND S.Sku = PD.Sku    
   LEFT JOIN PACK P WITH (NOLOCK) ON  P.PackKey = S.PACKKey  
   WHERE  PH.PickSlipNo =  @c_PickSlipNo  
   AND    PD.CartonNo   >= @c_CartonNoStart
   AND    PD.CartonNo   <= @c_CartonNoEnd   
   GROUP BY O.Orderkey     
         ,  ISNULL(RTRIM(O.ExternOrderKey), '')    
         ,  O.Storerkey     
         ,  PH.PickSlipNo    
         ,  ISNULL(RTRIM(O.ConsigneeKey), '')     
         ,  ISNULL(RTRIM(O.C_Company), '')   
         ,  ISNULL(RTRIM(O.C_Address1), '')    
         ,  ISNULL(RTRIM(O.C_Address2), '')    
         ,  ISNULL(RTRIM(O.C_Address3), '')    
         ,  ISNULL(RTRIM(O.C_Address4), '')    
         ,  ISNULL(RTRIM(O.[Route]), '')   
         ,  ISNULL(RTRIM(O.C_Zip), '')    
         ,  ISNULL(RTRIM(O.C_Country), '')    
         ,  O.DeliveryDate   
         ,  S.ALTSKU  
         ,  PD.CartonNo   
         ,  PD.labelno   
         ,  PD.Sku    
         ,  ISNULL(RTRIM(S.DESCR), '')   
         ,  P.OtherUnit1

   GOTO QUIT  

   DETAIL_REC:

   SELECT TOP 1 @c_Orderkey = PH.OrderKey
         ,  @c_DropID = PD.DropID
   FROM  PACKHEADER PH WITH (NOLOCK) 
   JOIN  PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   WHERE PD.PickSlipNo = @c_PickSlipNo 
   AND   PD.CartonNo   >= CONVERT(INT, @c_CartonNoStart)
   AND   PD.CartonNo   <= CONVERT(INT, @c_CartonNoEnd)

   DECLARE @t_OutOfStock  TABLE
      (  RowID             INT            DEFAULT(0)
      ,  OrderLineNumber   NVARCHAR(5)    DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   DEFAULT('')
      ,  Sku               NVARCHAR(20)   DEFAULT('')
      ,  AltSku            NVARCHAR(20)   DEFAULT('')
      ,  OriginalQty       INT            DEFAULT(0)
      ,  OutOfStock        INT            DEFAULT(0)
      )

   DECLARE @t_DropID  TABLE
      (  RowID             INT            DEFAULT(0)
      ,  OrderLineNumber   NVARCHAR(5)    DEFAULT('')
      ,  DropID            NVARCHAR(20)   DEFAULT('')
      ,  CaseID            NVARCHAR(20)   DEFAULT('')
      ,  NoOfSku           INT            DEFAULT(0)
      ,  Qty               INT            DEFAULT(0)
      )

   DECLARE @t_OutOfStockSKU TABLE
      (  Orderkey          NVARCHAR(20)   DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   DEFAULT('')
      ,  Sku               NVARCHAR(20)   DEFAULT('')
      ,  AltSku            NVARCHAR(20)   DEFAULT('')
      ,  OriginalQty       INT            DEFAULT(0)
      ,  OutOfStock        INT            DEFAULT(0)
      )

   INSERT INTO @t_OutOfStock (RowID, OrderLineNumber, Storerkey, Sku, AltSku, OriginalQty, OutOfStock)
   SELECT 1, OD.OrderLineNumber, OD.Storerkey, OD.Sku, OD.AltSku, OD.OriginalQty, OutOfStock = OD.OriginalQty - (OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty)
   FROM ORDERDETAIL OD WITH (NOLOCK)
   WHERE OD.Orderkey = @c_Orderkey
   AND OD.OriginalQty - (OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) > 0

   INSERT INTO @t_DropID (RowID, OrderLineNumber, DropID, CaseID, NoOfSku, Qty)
   SELECT  RowID = ROW_NUMBER() OVER (PARTITION BY PD.OrderLineNumber ORDER BY SUM(PD.Qty), COUNT(DISTINCT PD.Sku) DESC)
         , PD.OrderLineNumber, PD.DropID, PD.CaseID
         , NoOfSku = COUNT(DISTINCT PD.Sku)
         , Qty = SUM(PD.Qty)
   FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.Orderkey = @c_Orderkey
   GROUP BY PD.OrderLineNumber, PD.DropID, PD.CaseID
      
   SELECT TOP 1 @n_LastCaseID = CONVERT(INT, CaseID)
   FROM @t_DropID
   ORDER BY CaseID DESC

   IF @n_LastCaseID = CONVERT(INT, @c_CartonNoStart) AND CONVERT(INT, @c_CartonNoStart) = CONVERT(INT, @c_CartonNoEnd)
   BEGIN
      --Order Sku Not Found In Any DropID
      INSERT INTO @t_OutOfStockSKU
         (     OrderKey   
            ,  Storerkey  
            ,  Sku        
            ,  AltSku     
            ,  OriginalQty
            ,  OutOfStock
         )
      SELECT   @c_OrderKey      
            ,  OOS.Storerkey         
            ,  OOS.Sku               
            ,  OOS.AltSku            
            ,  OriginalQty = ISNULL(SUM(OOS.OriginalQty),0)
            ,  OutOfStock  = ISNULL(SUM(OOS.OutOfStock),0)
      FROM @t_OutOfStock OOS
      WHERE OOS.OriginalQty = OOS.OutOfStock
      GROUP BY OOS.Storerkey, OOS.Sku, OOS.AltSku
   END

   INSERT INTO @t_OutOfStockSKU
      (     OrderKey   
         ,  Storerkey  
         ,  Sku        
         ,  AltSku     
         ,  OriginalQty
         ,  OutOfStock
      )
   SELECT   @c_OrderKey      
         ,  OOS.Storerkey         
         ,  OOS.Sku               
         ,  OOS.AltSku            
         ,  OriginalQty = ISNULL(SUM(OOS.OriginalQty),0)
         ,  OutOfStock  = ISNULL(SUM(OOS.OutOfStock),0)
   FROM @t_OutOfStock OOS
   JOIN @t_DropID DID ON OOS.OrderLineNumber = DID.OrderLineNumber --AND OOS.RowID = DID.RowID
   WHERE OOS.OriginalQty > OOS.OutOfStock
   AND  DID.DropID = @c_DropID
   GROUP BY OOS.Storerkey, OOS.Sku, OOS.AltSku
   
   SELECT OD.Storerkey
         ,OD.Orderkey
         ,AltSku   = ISNULL(RTRIM(OD.AltSku),'')
         ,Sku      = OD.Sku
         ,SkuDesc  = (SELECT TOP 1 ISNULL(SKU.Descr,'') FROM SKU (NOLOCK) WHERE SKU.StorerKey = OD.Storerkey AND SKU.ALTSKU = ISNULL(RTRIM(OD.AltSku),'')) --ISNULL(S.Descr,'')   --WL01
         ,ODCSQty  = FLOOR(SUM(OD.OriginalQty) / ISNULL(P.OtherUnit1,0))
         ,ODEAQty  = SUM(OD.OriginalQty) % CONVERT(INT, ISNULL(P.OtherUnit1,0))
         ,OOSCSQty = FLOOR(SUM(OD.OutOfStock) / ISNULL(P.OtherUnit1,0))
         ,OOSEAQty = SUM(OD.OutOfStock) % CONVERT(INT, ISNULL(P.OtherUnit1,0))
         ,PickSlipNo = @c_PickslipNo 
   FROM @t_OutOfStockSKU  OD
   JOIN SKU       S  WITH (NOLOCK) ON  S.Storerkey = OD.Storerkey   
                                   AND S.Sku = OD.Sku 
   JOIN PACK      P  WITH (NOLOCK) ON  S.Packkey = P.Packkey 
   GROUP BY OD.Storerkey
         ,  OD.Orderkey
         ,  ISNULL(RTRIM(OD.AltSku),'')
         ,  OD.Sku
         --,  ISNULL(S.Descr,'')   --WL01
         ,  ISNULL(P.OtherUnit1,0)
  
   QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END
END -- procedure

GO