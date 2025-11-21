SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                        
/* Store Procedure:  isp_UCC_Carton_Label_63_rdt                        */                        
/* Creation Date:01-Aug-2017                                            */                        
/* Copyright: IDS                                                       */                        
/* Written by: CSCHONG                                                  */                        
/*                                                                      */                        
/* Purpose:  WMS-2481 -CNWMS -511 TACTICAL - RDT - Shipping Label       */                        
/*                                                                      */                        
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */                        
/*                                                                      */                        
/* Output Parameters:                                                   */                        
/*                                                                      */                        
/* Usage:                                                               */                        
/*                                                                      */                        
/* Called By:  r_dw_ucc_carton_label_63_rdt                             */                        
/*                                                                      */                        
/* PVCS Version: 1.1                                                    */                        
/*                                                                      */                        
/* Version: 5.4                                                         */                        
/*                                                                      */                        
/* Data Modifications:                                                  */                        
/*                                                                      */                        
/* Updates:                                                             */                        
/* Date         Author   Ver  Purposes                                  */                        
/* 16/04/2019   WLCHOOI  1.0  WMS-8727 - Add ExternOrderKey (WL01)      */                        
/* 25/03/2021   CSCHONG  1.1  WMS-16583 - add loc field (CS01)          */                        
/************************************************************************/                        
     
CREATE PROC [dbo].[isp_UCC_Carton_Label_63_rdt] (                        
      -- @c_StorerKey      NVARCHAR(20)                         
           @c_PickSlipNo     NVARCHAR(20)                        
      --,  @c_StartCartonNo  NVARCHAR(20)                        
      --,  @c_EndCartonNo    NVARCHAR(20)                        
          ,@c_labelno         NVARCHAR(20)                        
)                        
AS                        
BEGIN                        
                        
   SET NOCOUNT ON                        
   SET ANSI_NULLS OFF                        
   SET QUOTED_IDENTIFIER OFF                        
   SET CONCAT_NULL_YIELDS_NULL OFF                        
                        
                        
   DECLARE @c_ExternOrderkey  NVARCHAR(150)                        
         , @c_GetExtOrdkey    NVARCHAR(150)                        
         , @c_GrpExtOrderkey  NVARCHAR(150)                        
         , @c_OrdBuyerPO      NVARCHAR(20)                        
         , @n_cartonno        INT                        
         , @c_PDLabelNo       NVARCHAR(20)                        
         , @c_PIDLOC          NVARCHAR(10)                        
         , @c_SKU             NVARCHAR(20)                        
         , @c_PICtnType       NVARCHAR(10)                        
         , @n_PDqty           INT                        
         , @n_qty             INT                        
         , @c_Orderkey        NVARCHAR(20)                        
         , @c_Delimiter       NVARCHAR(1)        
         , @n_lineNo          INT                        
         , @c_Prefix          NVARCHAR(3)                           
		 , @n_CntOrderkey     INT                        				 
         , @c_SKUStyle        NVARCHAR(20)                        
 , @n_CntSize         INT                        
   , @n_Page            INT                        
   , @c_ordkey          NVARCHAR(20)                     
   , @n_PrnQty          INT                        
   , @n_MaxId           INT                        
   , @n_MaxRec          INT                
   , @n_getPageno       INT                        
   , @n_MaxLineno       INT                        
   , @n_CurrentRec      INT                        
   , @c_StorerKey    NVARCHAR(20)                         
                        
                        
   SET @c_ExternOrderkey  = ''                        
   SET @c_GetExtOrdkey    = ''                        
   SET @c_OrdBuyerPO     = ''                        
   SET @n_cartonno        = 1                        
   SET @c_PDLabelNo       = ''                        
   SET @c_PIDLOC          = ''                        
   SET @c_SKU             = ''                        
   SET @c_PICtnType       = ''                        
   SET @n_PDqty           = 0                        
   SET @n_qty             = 0                        
   SET @c_Orderkey        = ''                        
   SET @c_Delimiter       = ','                        
   SET @n_lineNo          =1                        
   SET @n_CntOrderkey     = 1                        
   SET @c_SKUStyle        = ''                        
   SET @n_CntSize         = 1                        
   SET @c_GrpExtOrderkey = ''                        
 SET @n_Page            = 1                        
 SET @n_PrnQty          = 1                        
 SET @n_PrnQty          = 1                        
 SET @n_MaxLineno       = 17                                    
                        
                        
  CREATE TABLE #TMP_LCartonLABEL63 (                        
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,                        
          Pickslipno      NVARCHAR(20) NULL,                        
          BContact1       NVARCHAR(45) NULL,                        
          OrdExtOrdKey    NVARCHAR(150) NULL,                        
          OrdBuyerPO      NVARCHAR(20) NULL,                        
          cartonno        INT NULL,                        
          PDLabelNo       NVARCHAR(20) NULL,                        
          SKUColor        NVARCHAR(10) NULL,                        
          SKUStyle        NVARCHAR(20) NULL,                        
          SKUSize         NVARCHAR(10) NULL,                        
          PDQty           INT,                        
          PICtnType       NVARCHAR(10) NULL,                        
          BUSR1           NVARCHAR(30)  NULL,                        
    PageNo          INT,                        
    sku             NVARCHAR(20),                        
          BAdd1           NVARCHAR(45) NULL,                        
          BAdd2           NVARCHAR(45) NULL,                                    
          BCity           NVARCHAR(45) NULL ,                        
          Bcountry        NVARCHAR(45) NULL,                        
          ExternOrderKey  NVARCHAR(50) NULL,        --WL01                        
          PLOC            NVARCHAR(10) NULL,        --CS01                   
    PLOT            NVARCHAR(10) NULL)        --CS01                        
                        
          --IF ISNULL(@c_StorerKey,'') = ''                        
          --BEGIN                        
     SELECT TOP 1 @c_StorerKey = PAH.storerkey                        
     FROM PACKHEADER PAH WITH (NOLOCK)                       
     JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno                        
     WHERE PAH.Pickslipno = @c_PickSlipNo                        
      AND PADET.LabelNo = @c_labelno                        
-- AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)                        
          --END                        
                                  
                                  
   INSERT INTO #TMP_LCartonLABEL63(Pickslipno,BContact1,OrdExtOrdKey,OrdBuyerPO,cartonno,                        
                                   PDLabelNo,SKUColor,SKUStyle,SKUSize,PDQty,PICtnType,BUSR1,PageNo,                        
                                   sku,BAdd1,BAdd2,BCity,Bcountry,ExternOrderKey,PLOC,PLOT )   --WL01  --CS01                        
   SELECT    PAH.Pickslipno--,ISNULL(RTRIM(ORDERS.Stop),'')                        
         ,  ISNULL(RTRIM(ORDERS.B_Contact1),'')                        
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')                     
         ,  ISNULL(RTRIM(ORDERS.BuyerPO),'')                                                   
         ,  PADET.CartonNo                        
         ,  ISNULL(RTRIM(PADET.Labelno),'')                        
         ,  ISNULL(RTRIM(S.color),'')                        
         ,  ISNULL(RTRIM(S.Style),'')                        
         ,  ISNULL(RTRIM(S.Size),'')                        
         ,  PIDET.qty                      
         ,  ISNULL(PAIF.CartonType,'')                        
         ,  ISNULL(RTRIM(S.BUSR1),'')                        
   ,  @n_Page                        
   ,  PIDET.SKU                      
   ,  ISNULL(RTRIM(ORDERS.B_Address1),'')                        
   ,  ISNULL(RTRIM(ORDERS.B_Address2),'')                                     
   ,  ISNULL(RTRIM(ORDERS.B_City),'')                          
   ,  ISNULL(RTRIM(ORDERS.B_Country),'')                         
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')      --WL01                           
         ,  PIDET.LOC                                    --CS01                        
   ,  PIDET.LOT                                    --CS01                                          
   FROM PACKHEADER PAH WITH (NOLOCK)                        
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno                        
   JOIN PICKHEADER PIHD WITH (NOLOCK) ON PIHD.PICKHEADERKEY=PAH.PICKSLIPNO                        
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno       --CS01                        
                                        AND PIDET.SKU = PADET.SKU                        
   -- JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = PIDET.Orderkey                        
   --                                       AND ORDDET.Orderlinenumber=PIDET.Orderlinenumber                        
   JOIN ORDERS     WITH (NOLOCK) ON ORDERS.ORDERKEY=PIHD.ORDERKEY--(ORDDET.Orderkey = ORDERS.Orderkey)                        
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU                        
   LEFT JOIN PACKINFO   PAIF WITH (NOLOCK) ON PAIF.Pickslipno =PADET.Pickslipno AND PAIF.CartonNo = PADET.CartonNo                        
   --LEFT JOIN codelkup CL ON CL.description=ORDERS.facility AND CL.listname ='carterfac' AND CL.storerkey='cartersz'                        
   WHERE PAH.Pickslipno = @c_PickSlipNo                        
   AND   PAH.Storerkey = @c_StorerKey                        
   --AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)                        
   AND PADET.LabelNo = @c_labelno                   
   GROUP BY                
    PAH.Pickslipno--,ISNULL(RTRIM(ORDERS.Stop),'')                        
         ,  ISNULL(RTRIM(ORDERS.B_Contact1),'')                        
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')                        
         ,  ISNULL(RTRIM(ORDERS.BuyerPO),'')                                                   
         ,  PADET.CartonNo                        
         ,  ISNULL(RTRIM(PADET.Labelno),'')                        
         ,  ISNULL(RTRIM(S.color),'')                        
         ,  ISNULL(RTRIM(S.Style),'')                        
         ,  ISNULL(RTRIM(S.Size),'')                      
         ,  ISNULL(PAIF.CartonType,'')                        
         ,  ISNULL(RTRIM(S.BUSR1),'')                           
   ,  PIDET.SKU                 
   ,  PIDET.QTY                    
   ,  ISNULL(RTRIM(ORDERS.B_Address1),'')                        
   ,  ISNULL(RTRIM(ORDERS.B_Address2),'')                                     
   ,  ISNULL(RTRIM(ORDERS.B_City),'')                          
   ,  ISNULL(RTRIM(ORDERS.B_Country),'')                         
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')      --WL01                           
         ,  PIDET.LOC                                    --CS01                        
   ,  PIDET.LOT                                    --CS01       
   ,  PIDET.Pickdetailkey                        --CS01    
   ORDER BY ISNULL(RTRIM(PADET.Labelno),''),PADET.CartonNo                  
                        
                        
                        
        SELECT Pickslipno,BContact1,OrdExtOrdKey,OrdBuyerPO,cartonno,                        
               PDLabelNo,SKUColor,SKUStyle,SKUSize,SUM(PDQty),PICtnType,BUSR1,PageNo,                        
               sku,BAdd1,BAdd2,BCity,Bcountry,ExternOrderKey,PLOC --WL01   --CS01                        
        FROM  #TMP_LCartonLABEL63                
  group by Pickslipno,BContact1,OrdExtOrdKey,OrdBuyerPO,cartonno,                        
               PDLabelNo,SKUColor,SKUStyle,SKUSize,PICtnType,BUSR1,PageNo,                        
               sku,BAdd1,BAdd2,BCity,Bcountry,ExternOrderKey,PLOC ,PLOT                   
        ORDER BY Pickslipno,cartonno,PLOC,SKUStyle,SKUColor,SKUSize                       
            
                        
END                        
SET QUOTED_IDENTIFIER OFF 


GO