SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_UCC_Carton_Label_97                             */
/* Creation Date: 18-SEP-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15236 - WMS-15236_PH_Novateur_Carton_Label_CR           */ 
/*                                                                      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes                                        */
/* 05-NOV-2020 CSCHONG  WMS-15236 fix total carton (CS01)               */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_97] (
            @c_StorerKey NVARCHAR(15), 
            @c_PickSlipNo NVARCHAR(40),
            @c_cartonNoStart NVARCHAR(5),  
            @c_cartonNoEnd NVARCHAR(5)   
)
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_startNumber          NVARCHAR(20),
   @c_selectedNumber       NVARCHAR(20),
   @c_endNumber            NVARCHAR(20),
   @c_externorderkey_start NVARCHAR(50),  
   @c_externorderkey_end   NVARCHAR(50),  
   @c_orderkey_start       NVARCHAR(10),
   @c_orderkey_end         NVARCHAR(10),
   @nPosStart              int, 
   @nPosEnd                int,
   @nDashPos               int ,
   @c_ExecStatements       nvarchar(4000),  
   @c_ExecStatements1      nvarchar(4000), 
   @c_ExecStatements2      nvarchar(4000), 
   @c_ExecStatements3      nvarchar(4000),  
   @c_ExecStatementsMain   nvarchar(4000),
   @c_ExecArguments        nvarchar(4000),
   @c_ShowCartonGID        NVARCHAR(20),
   @n_ttlcarton            INT                 --CS01


SET  @n_ttlcarton = 1                          --CS01


CREATE TABLE #UCCCNTLBL97 
      (  PickSlipNo          NVARCHAR(20)      
      ,  LabelNo             NVARCHAR(20)     
      ,  buyerpo             NVARCHAR(20)   
      ,  ExternOrderKey      NVARCHAR(50)   
      ,  CartonNo            INT 
      ,  Userdefine09        NVARCHAR(50)     
      ,  C_Company           NVARCHAR(45)  
      ,  C_Address1          NVARCHAR(45)
      ,  C_Address2          NVARCHAR(45)      
      ,  C_Address3          NVARCHAR(45)   
      ,  C_Address4          NVARCHAR(45)   
      ,  ConsigneeKey        NVARCHAR(45)   
      ,  loadkey             NVARCHAR(20)   
      ,  C_city              NVARCHAR(45)    
      ,  ohtype              NVARCHAR(20)     
      ,  deliverydate        DATETIME NULL 
      ,  rptdate             DATETIME NULL  
      ,  ttlctn              INT  
      ,  orderkey            NVARCHAR(10)   
      ,  qty                 INT
      ,  ttlqty              INT 
      ,  innerpack           FLOAT
      )  


   --CS01 START
    SELECT @n_ttlcarton = MAX(PD.cartonno)
    FROM PACKDETAIL PD WITH (NOLOCK)
    WHERE PD.Storerkey = @c_StorerKey  
    AND   PD.PickSlipNo = @c_pickslipno
   --CS01 END

  INSERT INTO #UCCCNTLBL97 (PickSlipNo,LabelNo,buyerpo,ExternOrderKey,CartonNo,Userdefine09,
                            C_Company,C_Address1,C_Address2,C_Address3,C_Address4,ConsigneeKey,
                            loadkey,C_city,ohtype,deliverydate,rptdate,ttlctn,orderkey,qty,ttlqty,innerpack)
   SELECT PACKHEADER.PickSlipNo, 
          MIN(PACKDETAIL.LabelNo),  
          ISNULL(ORDERS.buyerpo,'') AS buyerpo,  
          ORDERS.ExternOrderKey,  
          PACKDETAIL.CartonNo,  
          ORDERS.Userdefine09,  
          ORDERS.C_Company,  
          ISNULL(ORDERS.C_Address1,''),  
          ISNULL(ORDERS.C_Address2,''),  
          ISNULL(ORDERS.C_Address3,''),  
          ISNULL(ORDERS.C_Address4,''),  
          ORDERS.ConsigneeKey,   
          ORDERS.loadkey,  
          ORDERS.C_city,  
          Orders.type as OHType,   
          Orders.DeliveryDate,
          MAX(PACKDETAIL.editdate) as rptdate,
          --max(PACKDETAIL.cartonno) as TTLCTN,        --CS01
          @n_ttlcarton as TTLCTN,                      --CS01  
          ORDERS.OrderKey, 
          SUM(PACKDETAIL.qty),
           CASE WHEN ISNULL(pack.innerpack,'0') = 0 THEN SUM(PACKDETAIL.qty) else SUM(PACKDETAIL.qty)/ISNULL(pack.innerpack,'0') end  as ttlqty ,
          (PACK.innerpack)     
 FROM ORDERS ORDERS (NOLOCK)  
     JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey) 
     JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   
     JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey) 
     JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)  
WHERE ORDERS.StorerKey = @c_StorerKey  
      AND PACKHEADER.PickSlipNo = @c_pickslipno
      AND PACKDETAIL.CartonNo BETWEEN CAST(@c_cartonNoStart as int) AND CAST(@c_cartonNoEnd as Int) 
GROUP BY PACKHEADER.PickSlipNo,  
         PACKDETAIL.LabelNo,  
         ISNULL(ORDERS.buyerpo,''),  
         ORDERS.ExternOrderKey,  
         PACKDETAIL.CartonNo,  
         ORDERS.Userdefine09,  
         ORDERS.C_Company,  
         ISNULL(ORDERS.C_Address1,''),  
         ISNULL(ORDERS.C_Address2,''),  
         ISNULL(ORDERS.C_Address3,''),  
         ISNULL(ORDERS.C_Address4,''),  
         ORDERS.ConsigneeKey,  
         ORDERS.loadkey,  
         ORDERS.C_city,  
         ORDERS.OrderKey, 
         ORDERS.Type, 
         ORDERS.OrderKey,
         Orders.DeliveryDate
         ,PACK.innerpack
  ORDER BY PACKHEADER.PickSlipNo,ORDERS.OrderKey,PACKDETAIL.CartonNo


SELECT PickSlipNo,LabelNo,buyerpo,ExternOrderKey,CartonNo,Userdefine09,
       C_Company,C_Address1,C_Address2,C_Address3,C_Address4,ConsigneeKey,
       loadkey,C_city,ohtype,deliverydate,max(rptdate) as rptdate,ttlctn,orderkey,sum(qty) as qty,
       --CASE WHEN ISNULL(innerpack,'0') = 0 THEN qty else qty/innerpack end as ttlqty,
      sum(ttlqty) as ttlqty,
       0 as innerpack
FROM #UCCCNTLBL97
group by PickSlipNo,LabelNo,buyerpo,ExternOrderKey,CartonNo,Userdefine09,
       C_Company,C_Address1,C_Address2,C_Address3,C_Address4,ConsigneeKey,
       loadkey,C_city,ohtype,deliverydate,ttlctn,orderkey
ORDER BY PickSlipNo,orderkey,CartonNo
        

END


GO