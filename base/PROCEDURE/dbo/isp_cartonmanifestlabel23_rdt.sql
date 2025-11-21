SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_CartonManifestLabel23_rdt                      */    
/* Creation Date:11-SEP-2017                                            */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:  WMS-2873-CN_PVH_Report_CartonLabel                         */    
/*                                                                      */    
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */    
/*                                                                      */    
/* Output Parameters:                                                   */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By:  r_dw_carton_manifest_label_23_rdt                        */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/* 16-JAN-2017  CSCHONG  1.0  WMS-3781-revised report logic (CS01)      */    
/* 02-Dec-2019  WLChooi  1.1  WMS-11295 - Add DropID column, control by */    
/*                            ReportCFG (WL01)                          */  
/* 16-Aug-2021  AikLiang 1.2  Sum multiple packdetail line qty          */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_CartonManifestLabel23_rdt] (    
      -- @c_StorerKey      NVARCHAR(20)     
           @c_PickSlipNo     NVARCHAR(20)    
        ,  @c_StartCartonNo  NVARCHAR(20)    
        ,  @c_EndCartonNo    NVARCHAR(20)    
         -- ,@c_labelno         NVARCHAR(20)    
)    
AS    
BEGIN    
    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
    
   DECLARE @c_ExternOrderkey  NVARCHAR(150)    
         , @c_GetExtOrdkey    NVARCHAR(150)    
         , @c_OrdBuyerPO      NVARCHAR(20)    
         , @n_cartonno        INT    
         , @c_PDLabelNo       NVARCHAR(20)    
         , @n_PDqty           INT    
         , @n_qty             INT    
         , @c_Orderkey        NVARCHAR(20)    
         , @c_Delimiter       NVARCHAR(1)    
         , @n_lineNo          INT    
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
         , @c_StorerKey       NVARCHAR(20)     
         , @c_Ordtype         NVARCHAR(20)    
         , @c_ordgrp          NVARCHAR(20)      
         , @c_loadkey         NVARCHAR(20)      
         , @c_labelno         NVARCHAR(20)     
         , @c_CustPO          NVARCHAR(50)     
         , @c_ExtOrdKey       NVARCHAR(20)    
         , @c_OHUDF01         NVARCHAR(30)    
         , @c_OHDELNotes      NVARCHAR(50)    
         , @n_CntCarton       INT                                  --(CS01)    
         , @n_MaxCarton       INT                                  --(CS01)    
         , @c_STSUSR4         NVARCHAR(20)                         --(CS01)    
         , @c_PHStatus        NVARCHAR(10)   --(CS01)    
         , @c_DropID          NVARCHAR(20)                         --(WL01)    
         , @c_ShowDropID      NVARCHAR(1)                          --(WL01)    
    
   SET @c_ExternOrderkey  = ''    
   SET @c_GetExtOrdkey    = ''    
   SET @c_OrdBuyerPO      = ''    
   SET @n_cartonno        = 1    
   SET @c_PDLabelNo       = ''    
   SET @n_PDqty           = 0    
   SET @n_qty             = 0    
   SET @n_Page            = 1    
   SET @n_PrnQty          = 1    
   SET @n_PrnQty          = 1    
   SET @n_MaxLineno       = 20        
   SET @c_Ordkey          = ''    
   SET @c_loadkey         = ''     
   SET @c_labelno         = ''        
   SET @c_CustPO          = ''       
   SET @n_CntCarton       = 0                       --(CS01)    
   SET @c_STSUSR4         = ''                      --(CS01)    
   SET @n_MaxCarton       = 0                       --(CS01)    
   SET @c_DropID          = ''                      --(WL01)    
   SET @c_ShowDropID      = 'N'                     --(WL01)    
    
   CREATE TABLE #TMP_LCTNMANIFEST23(    
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,    
          Pickslipno      NVARCHAR(20) NULL,    
          CUStPO          NVARCHAR(50) NULL,    
          OrdExtOrdKey    NVARCHAR(20) NULL,    
          DELNotes        NVARCHAR(50) NULL,    
          cartonno        INT NULL,    
          PDLabelNo       NVARCHAR(20) NULL,    
          SKUColor        NVARCHAR(10) NULL,    
          SKUStyle        NVARCHAR(20) NULL,    
          SKUSize         NVARCHAR(10) NULL,    
          PDQty           INT,    
          SMeasument      NVARCHAR(20) NULL,    
          BUSR1           NVARCHAR(30)  NULL,    
          PageNo          INT,    
          sku             NVARCHAR(20) NULL,    
          MaxCtn          INT,                                         --(CS01)    
          DropID          NVARCHAR(20) NULL )                          --(WL01)    
    
   SET @c_StorerKey = ''    
   SET @c_ordgrp = ''    
       
   SELECT @c_Ordkey     = PH.OrderKey     
         ,@c_loadkey    = PH.LoadKey     
         ,@c_labelno    = PD.LabelNo    
         ,@n_qty        = SUM(PD.Qty)    
         ,@n_CartonNo   = PD.CartonNo    
         ,@c_OHDELNotes = MIN(S.BUSR6)    
         ,@c_STSUSR4    = ST.SUSR4                      --(CS01)    
         ,@c_PHStatus   = PH.status                     --(CS01)    
         ,@c_DropID     = ISNULL(MAX(PD.DropID),'')     --(WL01)    
   FROM  PACKHEADER  PH WITH (NOLOCK)     
   JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno    
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey and S.SKU = PD.SKU    
   JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = PH.Storerkey                              --(CS01)    
   WHERE PH.Pickslipno = @c_PickSlipNo    
   AND PD.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)    
   GROUP BY PH.OrderKey,PH.LoadKey,pd.LabelNo,PD.CartonNo,ST.SUSR4,PH.[Status]               --(CS01)    
         
   --CS01 Start    
   SET @n_CntCarton = 0    
   SET @n_MaxCarton = 0    
       
   SELECT @n_CntCarton =  COUNT(DISTINCT PD.CartonNo)     
   FROM  PACKHEADER  PH WITH (NOLOCK)     
   JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno    
   WHERE PH.Pickslipno = @c_PickSlipNo    
   --AND PD.CartonNo <= CAST(@c_EndcartonNo AS INT) --BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)    
       
   SET @n_MaxCarton = @n_CntCarton    
               
   IF @c_STSUSR4 = 'Y'    
   BEGIN    
      IF @c_PHStatus <> '9'    
      BEGIN    
         SET @n_MaxCarton = 0    
      END    
   END    
               
   --CS01 End    
         
   IF @c_Ordkey = ''    
   BEGIN    
      SELECT TOP 1 @c_Ordkey = ORD.Orderkey    
      FROM ORDERS ORD WITH (NOLOCK)    
      WHERE ORD.LoadKey = @c_loadkey    
      ORDER BY ORD.Orderkey    
   END    
       
   SET @c_Ordtype = ''    
       
   SELECT @c_CustPO         = CASE WHEN C.udf01 = 'W' THEN ISNULL(RTRIM(ORD.Userdefine03),'')     
                              ELSE ISNULL(RTRIM(ORD.Userdefine01),'') END    
         ,@c_ExternOrderkey = CASE WHEN C.udf01 = 'W' THEN ISNULL(RTRIM(ORD.ExternOrderkey),'')     
    ELSE ISNULL(RTRIM(ORD.loadkey),'') END      
     --  ,@c_OHDELNotes     = CASE WHEN C.udf01 = 'W' THEN '' ELSE ISNULL(RTRIM(ORD.DeliveryNote),'') END                                         
         ,@c_Ordtype        = C.udf01    
         ,@c_StorerKey      = ORD.StorerKey    
   FROM ORDERS ORD (NOLOCK)     
   -- JOIN STORER ST WITH(NOLOCK) ON ST.storerkey = ORD.ConsigneeKey    
   JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility    
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.Code = ORD.OrderGroup AND C.Storerkey=ORD.storerkey    
   -- LEFT JOIN STORER S WITH (NOLOCK) ON S.CustomerGroupCode = C.Storerkey    
   WHERE ORD.Orderkey = @c_Ordkey    
       
   --WL01 Start    
   SELECT @c_ShowDropID = ISNULL(MAX(CASE WHEN Code = 'ShowDropID' THEN 'Y' ELSE 'N' END),'N')    
   FROM  CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_Storerkey    
   AND   Long = 'r_dw_carton_manifest_label_23_rdt'    
   AND   ISNULL(Short,'') <> 'N'    
   --WL01 End           
              
   INSERT INTO #TMP_LCTNMANIFEST23(Pickslipno,CUStPO,OrdExtOrdKey,DELNotes,cartonno,    
                                   PDLabelNo,SKUColor,SKUStyle,SKUSize,PDQty,SMeasument,BUSR1,PageNo,    
                                   sku,MaxCtn,DropID)                                     --(CS01)  --(WL01)    
   SELECT DISTINCT PAH.Pickslipno    
          , @c_CustPO    
          , @c_ExternOrderkey        
          , ''                             
          , PADET.CartonNo    
          , ISNULL(RTRIM(PADET.Labelno),'')    
          , ISNULL(RTRIM(S.color),'')    
          , ISNULL(RTRIM(S.Style),'')    
          , ISNULL(RTRIM(S.Size),'')    
          , SUM(PADET.qty)  --AL01  
          , ISNULL(s.Measurement,'')    
          , ISNULL(RTRIM(S.BUSR1),'')    
          , (Row_Number() OVER (PARTITION BY PAH.PickslipNo,PADET.SKU  ORDER BY PADET.SKU  Asc) - 1)/@n_MaxLineno     
          , PADET.SKU     
          , @n_MaxCarton                                                                --(CS01)       
          , CASE WHEN ISNULL(@c_ShowDropID,'N') = 'Y' THEN @c_DropID ELSE '' END        --(WL01)    
   FROM PACKHEADER PAH WITH (NOLOCK)    
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno    
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU    
   WHERE PAH.Pickslipno = @c_PickSlipNo    
   AND   PAH.Storerkey = @c_StorerKey    
   AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)  
   GROUP BY PAH.Pickslipno,PADET.CartonNo,PADET.Labelno,S.color,S.Style,S.Size, PADET.qty,s.Measurement,S.BUSR1,PADET.SKU  --AL01  
   ORDER BY ISNULL(RTRIM(PADET.Labelno),''),PADET.CartonNo    
  
    
   SELECT Pickslipno,CUStPO,OrdExtOrdKey,DELNotes,cartonno,    
          PDLabelNo,SKUColor,SKUStyle,SKUSize,PDQty,SMeasument,BUSR1,PageNo,    
          sku,MaxCtn,DropID,@c_ShowDropID               --(WL01)    
   FROM  #TMP_LCTNMANIFEST23    
   ORDER BY Pickslipno,cartonno,SKUStyle,SKUColor,SKUSize    
       
       
END    

GO