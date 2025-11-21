SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                
/* Store Procedure:  isp_UCC_Carton_Label_74                            */                
/* Creation Date:19-SEP-2018                                            */                
/* Copyright: IDS                                                       */                
/* Written by: CSCHONG                                                  */                
/*                                                                      */                
/* Purpose:  WMS-5895 -[CN] Levi's B2B - Carton Label                   */                
/*                                                                      */                
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */                
/*                                                                      */                
/* Output Parameters:                                                   */                
/*                                                                      */                
/* Usage:                                                               */                
/*                                                                      */                
/* Called By:  r_dw_ucc_carton_label_74                                 */                
/*                                                                      */                
/* PVCS Version: 1.1                                                    */                
/*                                                                      */                
/* Version: 5.4                                                         */                
/*                                                                      */                
/* Data Modifications:                                                  */                
/*                                                                      */                
/* Updates:                                                             */                
/* Date         Author   Ver  Purposes                                  */                
/* 2018-12-15   TLTING   1.1  missing nolock                            */                
/* 2019-04-01   WLCHOOI  1.2  WMS-8452 New Barcode (WL01)               */                
/* 2019-04-29   WLCHOOI  1.3  WMS-8452 - Add new condition (WL02)       */                
/* 2019-12-13   KuanYee  1.4  INC0967625 - Add Border (KY01)            */   
/* 2021-02-05   CSCHONG  1.5  WMS-16224 revised field mapping (CS01)    */      
/* 2023-01-05   MINGLE   1.6  WMS-21448 add new fields(ML01)            */ 
/* 2023-07-04   CSCHONG  1.7  Devops Scripts Combine & WMS-22888 (CS02) */
/************************************************************************/                
                
CREATE   PROC [dbo].[isp_UCC_Carton_Label_74] (                
           @c_StorerKey      NVARCHAR(20),                 
           @c_PickSlipNo     NVARCHAR(20),                
           @c_StartCartonNo  NVARCHAR(20),                
           @c_EndCartonNo    NVARCHAR(20)                
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
         , @c_getExternOrdkey NVARCHAR(500)                
                   
                
                
   SET @c_ExternOrderkey  = ''                
   SET @c_GetExtOrdkey    = ''                
   SET @c_OrdBuyerPO      = ''                
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
   SET @n_MaxLineno       = 6                            
                
                
CREATE TABLE #TMP_LCartonLABEL74 (                
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,                
          PickSlipNo      NVARCHAR(10)   NOT NULL,                 
          ST_Company      NVARCHAR(45) NULL,                
          loadkey         NVARCHAR(20) NULL,                
          OrdExtOrdKey    NVARCHAR(1000) NULL,                
          Consigneekey    NVARCHAR(45) NULL,                
          cartonno        INT NULL,                
          Con_Company     NVARCHAR(45) NULL,                
          Con_Add1        NVARCHAR(45) NULL,                
          SKUStyle        NVARCHAR(20) NULL,                
          SKUSize         NVARCHAR(10) NULL,                
          PDQty           INT,                
          Con_Add2        NVARCHAR(45) NULL,                
          Con_Add3        NVARCHAR(45)  NULL,                
          PageNo          INT,                
          Con_Add4        NVARCHAR(45),                
          Con_City        NVARCHAR(45) NULL,                
          pdLabelno       NVARCHAR(20) NULL,
          PDDropID        NVARCHAR(20) NULL,	--ML01   
          ShowDropID	     NVARCHAR(5)  NULL,	--ML01
          BuyerPO         NVARCHAR(20) NULL  --CS02

			 )
                          
CREATE TABLE #TMP_LCartonLABEL74_1                 
         (rowid           int NOT NULL identity(1,1) PRIMARY KEY,                
          PickSlipNo      NVARCHAR(10)   NOT NULL,                  
          ST_Company      NVARCHAR(45) NULL,                
          loadkey         NVARCHAR(20) NULL,                
          OrdExtOrdKey    NVARCHAR(1000) NULL,                
          Consigneekey    NVARCHAR(45) NULL,                
          cartonno        INT NULL,                
          Con_Company     NVARCHAR(45) NULL,                
          Con_Add1        NVARCHAR(45) NULL,                
          SKUStyle        NVARCHAR(20) NULL,                
          SKUSize         NVARCHAR(10) NULL,                
          PDQty           INT,                
          Con_Add2        NVARCHAR(45) NULL,                
          Con_Add3        NVARCHAR(45)  NULL,                
          PageNo          INT,                
          Con_Add4        NVARCHAR(45),                
          Con_City        NVARCHAR(45) NULL,                
          pdLabelno       NVARCHAR(20) NULL,                 
          recgroup        INT NULL,                 
          ShowNo          NVARCHAR(1),
          PDDropID	     NVARCHAR(20) NULL,	--ML01
          ShowDropID	     NVARCHAR(5)  NULL,	--ML01
          BuyerPO         NVARCHAR(20) NULL  --CS02
          )                   
                
                          
                          
   INSERT INTO #TMP_LCartonLABEL74(ST_Company, PickSlipNo, LoadKey,OrdExtOrdKey,Consigneekey,cartonno,            
                                   Con_Company,Con_Add1,SKUStyle,SKUSize,PDQty,Con_Add2,Con_Add3,PageNo,                
                                   Con_Add4,Con_city,pdLabelno,PDDropID,ShowDropID,BuyerPO )	--ML01     --CS02              
   SELECT DISTINCT ST.company                
         ,  PAH.Pickslipno                
         ,  PAH.loadkey                
         ,  ''                
         ,  ORDERS.consigneekey                                           
         ,  PADET.CartonNo                
         ,  ISNULL(RTRIM(CONST.company),'')                
         ,  ISNULL(RTRIM(CONST.Address1),'')                
         ,  ISNULL(RTRIM(S.Style),'')                
         ,  ISNULL(RTRIM(S.Size),'')                
         ,  PADET.qty                
         ,  ISNULL(CONST.Address2,'')                
         ,  ISNULL(RTRIM(CONST.Address3),'')                
         ,  @n_Page                
         ,  ISNULL(RTRIM(CONST.Address4),'')                            
         ,  ISNULL(RTRIM(CONST.City),'')                   
  --     ,  PADET.labelno                
         ,  CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 AND ORDERS.type<>'IC' THEN    --WL01 --WL02        --CS01           
            CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PADET.labelno,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)   --WL01                
                 ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))            --WL01                
            WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0  AND ORDERS.type<>'IC'  THEN --WL02     --CS01           
            CL.UDF01 + PADET.LABELNO                                          --WL02                
            ELSE PADET.labelno END                                            --WL01 
         ,  PADET.DropID	--ML01
         ,  ISNULL(CL1.SHORT,'') AS ShowDropID	--ML01
         , CASE WHEN ORDERS.type='IC' THEN ORDERS.buyerpo ELSE '' END     --CS02
   FROM PACKHEADER PAH WITH (NOLOCK)                
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno                
   JOIN ORDERS     WITH (NOLOCK) ON ORDERS.loadkey=PAH.loadkey                
   JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.storerkey                
   JOIN STORER CONST WITH (NOLOCK) ON CONST.Storerkey = ORDERS.consigneekey                 
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PADET.Storerkey and S.sku = PADET.SKU                
   --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB') --WL01                
   OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM             --WL02                
                CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND                
                (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL 
   LEFT JOIN CODELKUP CL1(NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Storerkey = PAH.StorerKey AND CL1.LONG = 'r_dw_ucc_carton_label_74'	--ML01
   WHERE PAH.Pickslipno = @c_PickSlipNo                
   AND   PAH.Storerkey = @c_StorerKey                
   AND PADET.cartonno >= CAST(@c_StartCartonNo as INT) AND PADET.CartonNo <=  CAST(@c_EndCartonNo as INT)                
 --GROUP BY ST.company                
 --        ,  PAH.loadkey                
 --        ,  ORDERS.Externorderkey                
 --        ,  ORDERS.consigneekey                                           
 --        ,  PADET.CartonNo                
 --        ,  ISNULL(RTRIM(CONST.company),'')                
 --        ,  ISNULL(RTRIM(CONST.Address1),'')                
 --        ,  ISNULL(RTRIM(S.Style),'')                
 --        ,  ISNULL(RTRIM(S.Size),'')                
 --        ,  ISNULL(CONST.Address2,'')                
 --        ,  ISNULL(RTRIM(CONST.Address3),'')                
 --  ,ISNULL(RTRIM(CONST.Address4),'')    
 --  ,ISNULL(RTRIM(CONST.City),'')                  
 --  , PADET.qty                
   ORDER BY  PAH.loadkey, PADET.CartonNo                
                
     SET @c_getExternOrdkey = (SELECT distinct top 10 RTRIM(OH.Externorderkey)+', 'FROM ORDERS OH (NOLOCK)                 
            join #TMP_LCartonLABEL74 p74a on OH.LoadKey=p74a.LoadKey FOR XML PATH(''))                 
           
--SELECT * FROM #TMP_LCartonLABEL74                
                
--KY01 (START)                 
  DECLARE CUR_psno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
  SELECT DISTINCT PickSlipNo, CartonNo                
  FROM #TMP_LCartonLABEL74                
                
  OPEN CUR_PSNO                 
                
  FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo, @n_cartonno                
  WHILE @@FETCH_STATUS <> -1                
  BEGIN                
        INSERT INTO #TMP_LCartonLABEL74_1                 
        (ST_Company,PickSlipNo, loadkey,OrdExtOrdKey,Consigneekey,cartonno,                
                                   Con_Company,Con_Add1,SKUStyle,SKUSize,PDQty,Con_Add2,Con_Add3,PageNo,                
                                   Con_Add4,Con_city,pdLabelno,       
                                   recgroup, ShowNo,PDDropID,ShowDropID,BuyerPO)	--ML01  --CS02              
        SELECT ST_Company,PickSlipNo            
               ,loadkey                
               ,@c_getExternOrdkey                
               ,Consigneekey                
               ,cartonno                
               ,Con_Company,Con_Add1,SKUStyle,SKUSize,PDQty,Con_Add2,Con_Add3,PageNo,                
               Con_Add4,Con_city,pdlabelno,       
               (Row_Number() OVER (PARTITION BY PickSlipNo, CartonNo ORDER BY PickSlipNo,CartonNo Asc)-1)/@n_MaxLineno+1 AS recgroup                
                ,'Y',PDDropID,ShowDropID,BuyerPO	--ML01         --CS02     
        FROM  #TMP_LCartonLABEL74                
        WHERE PickSlipNo = @c_PickSlipNo                
        AND cartonno = @n_cartonno                
        ORDER BY loadkey,cartonno,SKUStyle,SKUSize                
                
  SELECT @n_MaxRec = COUNT(ROWID)                 
  FROM #TMP_LCartonLABEL74                 
        WHERE PickSlipNo = @c_PickSlipNo                
        AND cartonno = @n_cartonno                
                
  SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                
                
  WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
  BEGIN                 
                
      INSERT INTO #TMP_LCartonLABEL74_1                 
      (ST_Company, PickSlipNo, loadkey,OrdExtOrdKey,Consigneekey,cartonno,                
                                   Con_Company,Con_Add1,SKUStyle,SKUSize,PDQty,Con_Add2,Con_Add3,PageNo,                
                                   Con_Add4,Con_city,pdLabelno, ShowNo,PDDropID,ShowDropID,BuyerPO)	--ML01   --CS02               
      SELECT TOP 1 ST_Company,PickSlipNo, loadkey,@c_getExternOrdkey,Consigneekey,cartonno,                
                                   Con_Company,Con_Add1,'','',0,Con_Add2,Con_Add3,PageNo,                
                                   Con_Add4,Con_city,pdLabelno, 'N',PDDropID,ShowDropID,BuyerPO	--ML01   --CS02              
      FROM #TMP_LCartonLABEL74_1                 
        WHERE PickSlipNo = @c_PickSlipNo                
        AND cartonno = @n_cartonno                
      ORDER BY ROWID DESC                
                
      SET @n_CurrentRec = @n_CurrentRec + 1                
                
END                 
                
  SET @n_MaxRec = 0                
  SET @n_CurrentRec = 0                
                
  FETCH NEXT FROM CUR_psno INTO @c_PickSlipNo, @n_cartonno                
  END                
                
  SELECT ST_Company,loadkey,OrdExtOrdKey,Consigneekey,cartonno,                
                                   Con_Company,Con_Add1,SKUStyle,SKUSize,PDQty,Con_Add2,Con_Add3,PageNo,                
                                   Con_Add4,Con_city,pdLabelno, ShowNo,PDDropID,ShowDropID,BuyerPO	--ML01   --CS02             
  FROM #TMP_LCartonLABEL74_1                 
  ORDER BY LoadKey, CARTONNO, CASE WHEN ISNULL(SKUStyle,'') = '' THEN 1 ELSE 0 END, SKUStyle,SKUSize                 
--KY01 (END)                 
                
QUIT_RESULT:                
                
END 

GO