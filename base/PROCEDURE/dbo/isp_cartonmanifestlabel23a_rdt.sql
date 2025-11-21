SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_CartonManifestLabel23a_rdt                     */  
/* Creation Date:01-FEB-2021                                            */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  WMS-15981-CN PVHQHW CONTENT LABEL CR                       */  
/*                                                                      */  
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  r_dw_carton_manifest_label_23a_rdt                       */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-04-14   WLChooi  1.1  WMS-16817 - Add new column and modify     */  
/*                            logic (WL01)                              */   
/* 2023-03-17   CHONGCS  1.2  Devops Scripts Combine & WMS-21924(CS01)  */  
/* 2023-06-12   KuanYee  1.3  JSM-155706 AddOn CodeLkup filter(KY01)    */
/* 2023-07-26   CHONGCS  1.4  WMS-23045 revised field logic (CS02)      */
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_CartonManifestLabel23a_rdt] (  
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
         , @n_CntCarton       INT  
         , @n_MaxCarton       INT  
         , @c_STSUSR4         NVARCHAR(20)  
         , @c_PHStatus        NVARCHAR(10)  
         , @c_DropID          NVARCHAR(20)  
         , @c_ShowDropID      NVARCHAR(1)  
         , @c_ShowCategory    NVARCHAR(1)  
         , @c_SBUSR2          NVARCHAR(5)  
         , @c_category        NVARCHAR(60)  
         , @c_sku             NVARCHAR(20)  
         , @c_consigneekey    NVARCHAR(45)  
  
  DECLARE @c_getpickslipno    NVARCHAR(20)  
         ,@n_GetCartonNo      INT  
         ,@n_MaxPQty          INT  
         ,@c_MINLOC           NVARCHAR(10)  
         ,@c_GetSKU           NVARCHAR(20)  
         ,@c_GetStorerkey     NVARCHAR(20)  
         ,@n_cttloc           INT  
         ,@c_VASTYPE          NVARCHAR(30)    --CS01  
  
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
   SET @n_CntCarton       = 0  
   SET @c_STSUSR4         = ''  
   SET @n_MaxCarton       = 0  
   SET @c_DropID          = ''  
   SET @c_ShowDropID      = 'N'  
   SET @c_ShowCategory    = 'N'  
   SET @c_SBUSR2          = ''  
   SET @c_category        = ''  
   SET @c_Sku             = ''  
   SET @c_consigneekey    = ''  
  
  
   CREATE TABLE #TMP_LCTNMANIFEST23a(  
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
          MaxCtn          INT,  
          DropID          NVARCHAR(20) NULL,  
          loc             NVARCHAR(20) NULL,  
          CartonType      NVARCHAR(50) NULL,   --WL01  
          VASTYPE         NVARCHAR(30) NULL)   --CS01  
  
  
   CREATE TABLE #TMP_PICKDET23a(  
          Pickslipno      NVARCHAR(20) NULL,  
          cartonno        INT NULL,  
          sku             NVARCHAR(20) NULL,  
          loc             NVARCHAR(20) NULL,  
          QTY             INT)  
  
   CREATE TABLE #TMP_PLOC  
   (  Storerkey  NVARCHAR(20),  
      Pickslipno NVARCHAR(20),  
      CartonNo   INT,  
      SKU        NVARCHAR(20),  
      PQTY       INT,  
      PLOC       NVARCHAR(20))  
  
   CREATE TABLE #TMP_PMINLOC  
   (  Storerkey  NVARCHAR(20),  
      Pickslipno NVARCHAR(20),  
      CartonNo   INT,  
      SKU        NVARCHAR(20),  
      PQTY       INT,  
      MINLOC     NVARCHAR(20))  
  
  
   SET @c_StorerKey = ''  
   SET @c_ordgrp = ''  
  
   SELECT @c_Ordkey     = PH.OrderKey  
         ,@c_loadkey    = PH.LoadKey  
         ,@c_labelno    = PD.LabelNo  
         ,@n_qty        = SUM(PD.Qty)  
         ,@n_CartonNo   = PD.CartonNo  
         ,@c_OHDELNotes = MIN(S.BUSR6)  
         ,@c_STSUSR4    = ST.SUSR4  
         ,@c_PHStatus   = PH.status  
         ,@c_DropID     = ISNULL(MAX(PD.DropID),'')  
   FROM  PACKHEADER  PH WITH (NOLOCK)  
   JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno  
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey and S.SKU = PD.SKU  
   JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = PH.Storerkey  
   WHERE PH.Pickslipno = @c_PickSlipNo  
   AND   PD.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)  
   GROUP BY PH.OrderKey,PH.LoadKey,pd.LabelNo,PD.CartonNo,ST.SUSR4,PH.[Status]  
  
  
   --CS01 Start  
   SET @n_CntCarton = 0  
   SET @n_MaxCarton = 0  
  
   SELECT @n_CntCarton =  COUNT(DISTINCT PD.CartonNo)  
   FROM  PACKHEADER  PH WITH (NOLOCK)  
   JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno  
   WHERE PH.Pickslipno = @c_PickSlipNo  
  
   SET @n_MaxCarton = @n_CntCarton  
  
   IF @c_STSUSR4 = 'Y'  
   BEGIN  
      IF @c_PHStatus <> '9'  
      BEGIN  
         SET @n_MaxCarton = 0  
      END  
   END  
  
  
   IF @c_Ordkey = ''  
   BEGIN  
      SELECT TOP 1 @c_Ordkey = ORD.Orderkey  
      FROM ORDERS ORD WITH (NOLOCK)  
      WHERE ORD.LoadKey = @c_loadkey  
      ORDER BY ORD.Orderkey  
   END  
  
   SET @c_Ordtype = ''  
  
   SELECT @c_CustPO         = ISNULL(RTRIM(ORD.Userdefine03),'') --CASE WHEN C.udf01 = 'W' THEN ISNULL(RTRIM(ORD.Userdefine03),'')     --CS02 S
                              --ELSE ISNULL(RTRIM(ORD.Userdefine01),'') END                                                             --CS02 E
         --WL01 S  
         --,@c_ExternOrderkey = CASE WHEN C.udf01 = 'W' THEN ISNULL(RTRIM(ORD.ExternOrderkey),'')  
         --                     ELSE ISNULL(RTRIM(ORD.loadkey),'') END  
         ,@c_ExternOrderkey = ISNULL(RTRIM(ORD.LoadKey),'')  
         --WL01 E  
         ,@c_Ordtype        = C.udf01  
         ,@c_StorerKey      = ORD.StorerKey  
         ,@c_consigneekey   = ORD.ConsigneeKey  
         ,@c_VASTYPE        = ISNULL(C1.short,'')                    --CS01  
   FROM ORDERS ORD (NOLOCK)  
   JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility    
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.Code = ORD.OrderGroup AND C.Storerkey=ORD.storerkey AND C.LISTNAME = 'ORDERGROUP'   --KY01
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname ='PVHVAS' AND C1.long = ORD.deliveryplace        --CS01  
                                       AND C1.Storerkey=ORD.storerkey  
   WHERE ORD.Orderkey = @c_Ordkey  
  
  
   SELECT @c_ShowDropID = ISNULL(MAX(CASE WHEN Code = 'ShowDropID' THEN 'Y' ELSE 'N' END),'N')  
         ,@c_showcategory = ISNULL(MAX(CASE WHEN Code = 'Showcategory' THEN 'Y' ELSE 'N' END),'N')  
   FROM  CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'REPORTCFG'  
   AND   Storerkey= @c_Storerkey  
   AND   Long = 'r_dw_carton_manifest_label_23a_rdt'  
   AND   ISNULL(Short,'') <> 'N'  
  
   SELECT @c_sku = MIN(PD.sku)  
   FROM  PACKHEADER  PH WITH (NOLOCK)  
   JOIN  PACKDETAIL  PD WITH (NOLOCK) on PD.pickslipno = PH.pickslipno  
   WHERE PH.Pickslipno = @c_PickSlipNo  
  
   SELECT @c_SBUSR2 = Substring(S.busr2,1,2)  
   FROM SKU S WITH (NOLOCK)  
   WHERE S.storerkey = @c_storerkey  
   AND S.sku = @c_sku  
  
   SELECT @c_category = CASE WHEN @c_Ordtype = 'W' THEN ISNULL(RTRIM(C.UDF01),'')  
                              ELSE ISNULL(RTRIM(C.UDF02),'') END  
   FROM CODELKUP C WITH (NOLOCK)  
   WHERE C.listname = 'QHWCLB'  
   AND C.short = @c_SBUSR2  
   AND C.long = @c_consigneekey  
  
  
   INSERT INTO #TMP_LCTNMANIFEST23a(Pickslipno,CUStPO,OrdExtOrdKey,DELNotes,cartonno,  
                                   PDLabelNo,SKUColor,SKUStyle,SKUSize,PDQty,SMeasument,BUSR1,PageNo,  
                                   sku,MaxCtn,DropID,CartonType,VASTYPE)   --WL01     --CS01  
   SELECT DISTINCT PAH.Pickslipno  
          , @c_CustPO  
          , @c_ExternOrderkey  
          , ''  
          , PADET.CartonNo  
          , ISNULL(RTRIM(PADET.Labelno),'')  
          , ISNULL(RTRIM(S.color),'')  
          , ISNULL(RTRIM(S.Style),'')  
          , ISNULL(RTRIM(S.Size),'')  
          , PADET.qty  
          , ISNULL(s.Measurement,'')  
          , ISNULL(RTRIM(S.BUSR1),'')  
          , (Row_Number() OVER (PARTITION BY PAH.PickslipNo,PADET.SKU  ORDER BY PADET.SKU  Asc) - 1)/@n_MaxLineno  
          , PADET.SKU  
          , @n_MaxCarton  
          , CASE WHEN ISNULL(@c_ShowDropID,'N') = 'Y' THEN @c_DropID ELSE '' END  
          , ISNULL(PIF.CartonType,'')   --WL01  
          , ISNULL(@c_VASTYPE,'')       --CS01  
   FROM PACKHEADER PAH WITH (NOLOCK)  
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno  
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU  
   LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PADET.PickSlipNo AND PIF.CartonNo = PADET.CartonNo   --WL01  
   WHERE PAH.Pickslipno = @c_PickSlipNo  
   AND   PAH.Storerkey = @c_StorerKey  
   AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)  
   ORDER BY ISNULL(RTRIM(PADET.Labelno),''),PADET.CartonNo  
  
  
   INSERT INTO #TMP_PLOC (storerkey,Pickslipno,CartonNo,SKU,PLOC,PQTY)  
   SELECT pad.storerkey as storerkey,pad.pickslipno as pickslipno,pad.cartonno as cartonno,pad.sku as sku,(pid.loc) as loc,(pid.qty) as qty  
   FROM packdetail pad (nolock)  
   JOIN pickdetail pid (nolock) on pid.caseid=pad.labelno and pid.sku=pad.sku  
   WHERE pad.pickslipno=@c_PickSlipNo  
   AND pad.cartonno  BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)  
   GROUP BY pad.pickslipno,pad.cartonno,pad.sku,pid.loc,pid.qty,pad.storerkey  
   ORDER BY pad.pickslipno,pad.cartonno,pid.qty desc  
  
  
   DECLARE CUR_ChkPLOCLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  
   SELECT storerkey,Pickslipno,CartonNo,sku,max(pqty)  
   FROM #TMP_PLOC  
   WHERE pickslipno = @c_PickSlipNo  
   AND cartonno BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)  
   GROUP BY storerkey,Pickslipno,CartonNo,sku  
   ORDER BY storerkey,Pickslipno,CartonNo,sku  
  
   OPEN CUR_ChkPLOCLoop  
  
   FETCH NEXT FROM CUR_ChkPLOCLoop INTO  @c_GetStorerkey  
                                       , @c_GetPickslipno  
                                       , @n_Getcartonno  
                                       , @c_GetSKU  
                                       , @n_MaxPQty  
  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SET @c_MINLOC = ''  
      SET @n_cttloc = 1  
  
      SELECT @n_cttloc = COUNT(1)  
      FROM #TMP_PLOC  
      WHERE pickslipno=@c_getpickslipno  
      AND cartonno = @n_Getcartonno  
      AND sku = @c_GetSKU  
      AND pqty = @n_MaxPQty  
  
      IF @n_cttloc = 1  
      BEGIN  
         SELECT @c_MINLOC = ploc  
         FROM #TMP_PLOC  
         WHERE pickslipno=@c_getpickslipno  
         AND cartonno = @n_Getcartonno  
         AND sku = @c_GetSKU  
         AND pqty = @n_MaxPQty  
      END  
      ELSE  
      BEGIN  
         SELECT @c_MINLOC = MIN(ploc)  
         FROM #TMP_PLOC  
         WHERE pickslipno=@c_getpickslipno  
         AND cartonno = @n_Getcartonno  
         AND sku = @c_GetSKU  
         AND pqty = @n_MaxPQty  
      END  
  
      INSERT INTO #TMP_PMINLOC (storerkey,Pickslipno,CartonNo,SKU,PQTY,MINLOC)  
      VALUES(@c_GetStorerkey,@c_getpickslipno,@n_CartonNo,@c_GetSKU,@n_MaxPQty,@c_MINLOC)  
  
   FETCH NEXT FROM CUR_ChkPLOCLoop INTO    @c_GetStorerkey  
                                         , @c_GetPickslipno  
                                         , @n_Getcartonno  
                                         , @c_GetSKU  
                                         , @n_MaxPQty  
  
  
   END  
   CLOSE CUR_ChkPLOCLoop  
   DEALLOCATE CUR_ChkPLOCLoop  
  
   SELECT A.Pickslipno,A.CUStPO,A.OrdExtOrdKey,A.DELNotes,A.cartonno,  
          A.PDLabelNo,A.SKUColor,A.SKUStyle,A.SKUSize,A.PDQty,A.SMeasument,A.BUSR1,A.PageNo,  
          A.sku,A.MaxCtn,A.DropID,@c_ShowDropID,B.MINLOC,  
          A.CartonType,A.VASTYPE   --WL01      --CS01  
   FROM  #TMP_LCTNMANIFEST23a A  
   JOIN #TMP_PMINLOC B ON B.Pickslipno = A.pickslipno AND B.CartonNo = A.cartonno AND B.SKU=A.sku  
   ORDER BY Pickslipno,cartonno,SKUStyle,SKUColor,SKUSize  
  
  
   DROP TABLE #TMP_LCTNMANIFEST23a  
   DROP TABLE #TMP_PLOC  
   DROP TABLE #TMP_PMINLOC  
  
END  


GO