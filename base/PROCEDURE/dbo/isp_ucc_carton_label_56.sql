SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_UCC_Carton_Label_56                            */  
/* Creation Date: 14-Mar-2017                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  To print Ucc Carton Label 56 (Carton Content)              */  
/*                                                                      */  
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  r_dw_ucc_carton_label_56                                 */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 30-MAY-2017  CSCHONG  1.0  WMS-2021 - Add new field (CS01)           */  
/* 08-SEP-2017  CSCHONG  1.1  WMS-2802 - Revise Field mapping (CS02)    */  
/* 18-OCT-2018  CSCHONG  1.2  WMS-5450 revised report logic (CS03)      */  
/* 13-DEC-2018  LZG      1.3  D12 - Fix empty VAS value (ZG01)          */  
/* 26-SEP-2019  WLChooi  1.4  WMS-10691 - Fix 1 sku in multiple         */  
/*                            Orderlinenumber cannot show VAS (WL01)    */  
/* 12-Dec-2020  WLChooi  1.5  WMS-15833 - Add new column for CN (WL02)  */  
/* 12-Jan-2021  WLChooi  1.6  WMS-15973 Add C_Company and controlled by */  
/*                            ReportCFG (WL03)                          */  
/* 06-SEP-2021  CSCHONG  1.7  WMS-17830 revised field logic (CS04)      */  
/* 19-JUL-2022  MINGLE   1.8  WMS-20216 add new mappings (ML01)         */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_56] (  
         @c_StorerKey      NVARCHAR(20)  
      ,  @c_PickSlipNo     NVARCHAR(20)  
      ,  @c_StartCartonNo  NVARCHAR(20)  
      ,  @c_EndCartonNo    NVARCHAR(20)  
      ,  @c_PrintType      NVARCHAR(10) = ''   --WL03  
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_ExternOrderkey  NVARCHAR(150)  
         , @c_GetOrdkey       NVARCHAR(150)  
         , @c_GrpExtOrderkey  NVARCHAR(150)  
         , @c_OrdUserDef09    NVARCHAR(20)  
         , @c_OrdUserDef02    NVARCHAR(20)  
         , @c_OrdBuyerPO      NVARCHAR(20)  
         , @n_cartonno        INT  
         , @c_PDLabelNo       NVARCHAR(20)  
         , @c_PIDLOC          NVARCHAR(10)  
         , @c_SKU             NVARCHAR(20)  
         , @c_putawayzone     NVARCHAR(10)  
         , @c_PICtnType       NVARCHAR(10)  
         , @n_PDqty           INT  
         , @c_MixSku          NVARCHAR(1)  
         , @c_Orderkey        NVARCHAR(20)  
         , @c_Delimiter       NVARCHAR(1)  
         , @n_lineNo          INT  
         , @c_Prefix          NVARCHAR(3)  
         , @n_CntOrderkey     INT  
         , @c_SKUStyle        NVARCHAR(100)  
         , @n_CntSize         INT  
         , @n_Page            INT  
         , @c_ordkey NVARCHAR(20)  
         , @n_PrnQty          INT  
         , @c_picloc          NVARCHAR(10)  
         , @c_getpicloc       NVARCHAR(10)  
         , @n_MaxId           INT  
         , @n_MaxRec          INT  
         , @n_getPageno       INT  
         , @n_MaxLineno       INT  
         , @n_CurrentRec      INT  
         , @n_qty             INT  
         , @c_GetPDLabelNo    NVARCHAR(20)  
         , @c_GetPIDLOC       NVARCHAR(10)  
         , @c_getsku          NVARCHAR(20)  
         , @c_CARTERPO        NVARCHAR(10)  
         , @c_sortLane        NVARCHAR(20)  
         , @c_dispatchLane    NVARCHAR(20)  
         , @n_MaxCartonNo     INT  
         , @n_seqno           INT  
         , @c_ORDRoute        NVARCHAR(20)  
         , @c_busr7           NVARCHAR(30)  
         , @c_VNotes2         NVARCHAR(250)  
         , @c_vas             NVARCHAR(250)  
         , @c_Category        NVARCHAR(20)            --CS01  
         , @c_ODLineNumber    NVARCHAR(5)             --CS02  
         , @c_VNote           NVARCHAR(250)           --CS02  
         , @n_CntVas          INT                     --CS02  
         , @c_TempVAS         NVARCHAR(255) = ''      --WL01  
         , @c_ODUDF10         NVARCHAR(50)  = ''      --CS04  
         , @c_Color           NVARCHAR(20)  = ''      --CS04  
		 , @c_odnotes         NVARCHAR(100)			  --ML01          
          
   SET @c_ExternOrderkey  = ''  
   SET @c_GetOrdkey       = ''  
   SET @c_OrdUserDef09    = ''  
   SET @c_OrdUserDef02    = ''  
   SET @c_OrdBuyerPO      = ''  
   SET @n_cartonno        = 1  
   SET @c_PDLabelNo       = ''  
   SET @c_PIDLOC          = ''  
   SET @c_SKU             = ''  
   SET @c_putawayzone     = ''  
   SET @c_PICtnType       = ''  
   SET @c_MixSku          = 'N'  
   SET @n_PDqty           = 0  
   SET @c_Orderkey        = ''  
   SET @c_Delimiter       = ','  
   SET @n_lineNo          =1  
   SET @n_CntOrderkey     = 1  
   SET @c_SKUStyle        = ''  
   SET @n_CntSize         = 1  
   SET @c_GrpExtOrderkey = ''  
   SET @n_Page            = 1  
   SET @n_PrnQty          = 1  
   SET @c_picloc          = ''  
   SET @c_getpicloc       = ''  
   SET @n_MaxLineno       = 17  
   SET @n_qty             = 0  
   SET @c_CARTERPO        = ''  
   SET @n_CntVas          = 1             --CS02  
   SET @c_TempVAS         = '' --WL01  
  
   CREATE TABLE #TMP_SDCCartonLBL (  
          rowid           int identity(1,1),  
          Pickslipno      NVARCHAR(20) NULL,  
          orderkey        NVARCHAR(20) NULL,  
          sortLane        NVARCHAR(10) NULL,  
          DispatchLane    NVARCHAR(10) NULL,  
          caseid          NVARCHAR(20) NULL,  
          PIDLOC          NVARCHAR(10) NULL,  
          SKU             NVARCHAR(20) NULL,  
          SKUSIze         NVARCHAR(10) NULL,  
          SKUStyle        NVARCHAR(20) NULL,  
          PDQty           INT,  
          PICtnType       NVARCHAR(10) NULL,  
          CurrCnt         NVARCHAR(5) NULL ,  
          MaxCarton       NVARCHAR(10) NULL,  
          PageNo          NVARCHAR(20) NULL,              --WL03  
          VAS             NVARCHAR(250) NULL,  
          SUSR3           NVARCHAR(50)  NULL,  
          Category        NVARCHAR(20)  NULL,             --CS01  
          ShowRing        NVARCHAR(50)  NULL,             --WL02  
          Ring            NVARCHAR(50)  NULL,             --WL02  
          ShowPickzone    NVARCHAR(10)  NULL,             --WL03  
          C_Company       NVARCHAR(45)  NULL,             --WL03  
		  ODNote		  NVARCHAR(100) NULL,             --ML01  
		  ODUDF05		  NVARCHAR(18) NULL               --ML01  
   )  
  
   /*CS02 Start*/  
   CREATE TABLE #TEMPVASDETAIL (  
      Pickslipno      NVARCHAR(20) NULL,  
      orderkey        NVARCHAR(20) NULL,  
      OrdLineNo       NVARCHAR(5)  NULL,  
      caseid          NVARCHAR(20) NULL,  
      PIDLOC          NVARCHAR(10) NULL,  
      Notes           NVARCHAR(100) NULL	--ML01 
   )  
  
   /*CS02 End*/  
     
   CREATE TABLE #TempVAS(  
      Notes  NVARCHAR(255)  
   )  
  
  
      SELECT TOP 1 @c_ODUDF10 = OD.userdefine10,@c_odnotes = OD.Notes	--ML01  
      FROM Pickdetail PD WITH (NOLOCK)  
      --JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey  
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.Sku  
      LEFT JOIN CartonListDetail AS cld WITH (NOLOCK) ON cld.PickDetailKey = PD.PickDetailKey  
      LEFT JOIN CartonList AS CL WITH (NOLOCK) ON CL.CartonKey = cld.CartonKey  
      WHERE Pd.Pickslipno = @c_PickSlipNo  
      AND   Pd.Storerkey = @c_StorerKey  
      AND CL.seqno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)  
  
    SET @c_Color = ''  
  
     SELECT @c_Color = ISNULL(C.short,'')  
     FROM dbo.CODELKUP C WITH (NOLOCK)  
     WHERE C.LISTNAME = 'NKSDCDISCT'  
     AND C.Storerkey = @c_StorerKey  
     AND C.Code = @c_ODUDF10  
  
   INSERT INTO #TMP_SDCCartonLBL(Pickslipno,caseid,orderkey,SKU,SKUStyle,SKUSIze,  
                                 PDQty,sortLane,DispatchLane,PICtnType,CurrCnt,MaxCarton,  
                                 PIDLOC,Pageno,VAS,susr3 ,Category, ShowRing, Ring, ShowPickzone, C_Company,ODNote,ODUDF05)   --CS01   --WL02   --WL03	--ML01  
   SELECT DISTINCT PD.PickSlipNo,PD.CaseID,ORD.OrderKey,pd.sku,(S.Style + '-' + S.Color),S.[Size],SUM(PD.Qty) AS PDQTY,  
          ISNULL(min(LPLD.LOC),'') AS SORTLANE,ISNULL(min(LPLD1.LOC),'') AS DESPTLANE,CL.CartonType,CL.seqno,'1',  
         --CASE WHEN PD.loc = '' THEN TD.LogicalToLoc ELSE PD.loc END,  
          CASE WHEN ISNULL(PD.TaskDetailKey,'') <> '' THEN TD.LogicalToLoc ELSE PD.loc END ,@n_Page , '',  
    CASE WHEN OD.UserDefine07 = 'N' THEN '' ELSE @c_Color END,'',--ISNULL(STO.SUSR3,''),'',   --CS01   --CS03   --CS04  
          ISNULL(CL3.Short,'N') AS ShowRing,  
          --CASE WHEN ISNULL(CL1.Code,'') = OD.Channel AND S.SKUGROUP = 'APPAREL' THEN ISNULL(CL2.Long,'') ELSE '' END AS Ring,   --WL02  
    CASE WHEN OD.UserDefine06 = 'N' THEN '' ELSE ISNULL(CL2.Long,'') END AS Ring,   --ML01  
          ISNULL(CL4.Short,'N'),   --WL03  
          CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN MAX(ORD.C_Company) ELSE '' END,        --WL03  
    '', --ML01  
    ISNULL(OD.UserDefine05,'')	--ML01  
   FROM PickDetail PD WITH (NOLOCK)  
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=PD.OrderKey  
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PD.Storerkey AND S.SKU=PD.Sku  
   LEFT JOIN loadplanLaneDetail lpld WITH (NOLOCK) ON LPLD.LoadKey=ORD.LoadKey AND LPLD.LocationCategory='PROC'  
   LEFT JOIN loadplanLaneDetail lpld1 WITH (NOLOCK) ON LPLD1.LoadKey=ORD.LoadKey AND LPLD1.LocationCategory='STAGING'  
   LEFT JOIN CartonListDetail AS cld WITH (NOLOCK) ON cld.PickDetailKey = PD.PickDetailKey  
   LEFT JOIN CartonList AS CL WITH (NOLOCK) ON CL.CartonKey = cld.CartonKey  
   LEFT JOIN TaskDetail AS td WITH (NOLOCK) ON td.TaskType='RPF' AND td.TaskDetailKey=PD.TaskDetailKey  
   LEFT JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = 'NKS' + RTRIM(LTRIM(ORD.ConsigneeKey))  
  -- JOIN PackDetail AS pad WITH (NOLOCK) ON pad.LabelNo = pd.CaseID  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.SKU   --WL02  
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'Channel' AND CL1.Storerkey = ORD.StorerKey AND CL1.UDF01 = '1' AND OD.Channel = CL1.Code   --WL02  
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'SDCVAS' AND CL2.Storerkey = ORD.StorerKey AND S.[Size] = CL2.Code   --WL02  
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME = 'REPORTCFG' AND CL3.Storerkey = ORD.StorerKey      --WL02  
                                       AND CL3.Code = 'ShowRing' AND CL3.Long = 'r_dw_ucc_carton_label_56'   --WL02  
   LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.LISTNAME = 'REPORTCFG' AND CL4.Storerkey = ORD.StorerKey          --WL03  
                                       AND CL4.Code = 'ShowPickZone' AND CL4.Long = 'r_dw_ucc_carton_label_56'   --WL03  
   WHERE Pd.Pickslipno = @c_PickSlipNo  
   AND   Pd.Storerkey = @c_StorerKey  
   AND CL.seqno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)  
   --AND ISNULL(PD.CaseID,'') <> ''  
   GROUP BY PD.PickSlipNo,PD.CaseID,ORD.OrderKey,pd.sku,(S.Style + '-' + S.Color),S.[Size],CL.CartonType,CL.seqno,  
            --CASE WHEN PD.loc = '' THEN TD.LogicalToLoc ELSE PD.loc END  
            CASE WHEN ISNULL(PD.TaskDetailKey,'') <> '' THEN TD.LogicalToLoc ELSE PD.loc END  
        --    ,STO.SUSR3--,PD.Qty                           --CS03    --CS04  
            ,ISNULL(CL3.Short,'N')   --WL02  
            --,CASE WHEN ISNULL(CL1.Code,'') = OD.Channel AND S.SKUGROUP = 'APPAREL' THEN ISNULL(CL2.Long,'') ELSE '' END   --WL02  
   ,CASE WHEN OD.UserDefine06 = 'N' THEN '' ELSE ISNULL(CL2.Long,'') END   --ML01  
            ,ISNULL(CL4.Short,'N')   --WL03  
   ,OD.UserDefine07  
   ,ISNULL(OD.UserDefine05,'')	--ML01  
   ORDER BY PD.CaseID,ORD.OrderKey,pd.sku  
  
  
 --select * from #TMP_SDCCartonLBL  
  
  DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Pickslipno,  
                   caseid,  
                   orderkey,  
                   sku,  
                   PIDLOC  
   FROM #TMP_SDCCartonLBL WITH (NOLOCK)  
   WHERE Pickslipno = @c_PickSlipNo  
  
   OPEN CUR_Labelno  
  
   FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo  
                                    ,@c_PDLabelNo  
                                    ,@c_GetOrdkey  
                                    ,@c_SKU  
                                    ,@c_PIDLOC  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SET @n_prnqty = 1  
      SET @c_ORDRoute = ''  
      SET @c_busr7 = ''  
      SET @c_VNotes2 = ''  
      SET @n_seqno = 1  
      SET @c_vas = ''  
      SET @c_Category = ''  
      SET @c_ODLineNumber = ''  
      SET @c_getpicloc = ''  
      SET @c_ODUDF10 = ''  
  
      IF ISNULL(@c_PIDLOC,'') = ''  
      BEGIN  
         /*CS02 start*/  
         SELECT TOP 1 @c_getpicloc=pd.loc  
         FROM  PICKDETAIL AS pd WITH (NOLOCK)  
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=PD.OrderKey  
         JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PD.Storerkey AND S.SKU=PD.Sku  
         LEFT JOIN loadplanLaneDetail lpld WITH (NOLOCK) ON LPLD.LoadKey=ORD.LoadKey AND LPLD.LocationCategory='PROC'  
         LEFT JOIN loadplanLaneDetail lpld1 WITH (NOLOCK) ON LPLD1.LoadKey=ORD.LoadKey AND LPLD1.LocationCategory='STAGING'  
         LEFT JOIN CartonListDetail AS cld WITH (NOLOCK) ON cld.PickDetailKey = PD.PickDetailKey  
         LEFT JOIN CartonList AS CL WITH (NOLOCK) ON CL.CartonKey = cld.CartonKey  
         LEFT JOIN TaskDetail AS td WITH (NOLOCK) ON td.TaskType='RPF' AND td.TaskDetailKey=PD.TaskDetailKey  
         where pd.sku=@c_sku AND pd.CaseID = @c_PDLabelNo  
         AND ISNULL(td.LogicalToLoc,'') = ''  
  
         /*CS02 END*/  
  
      END  
      ELSE  
      BEGIN  
         SET @c_getpicloc = @c_PIDLOC  
      END  
        
      --WL01 Start  
  
      --SELECT TOP 1 @c_ODLineNumber = OD.OrderLineNumber  
      --FROM ORDERDETAIL OD WITH (NOLOCK)  
      --WHERE orderkey=@c_GetOrdkey  
      --AND OD.Sku=@c_SKU  
  
      DECLARE CUR_ODLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT OD.OrderLineNumber   
      FROM ORDERDETAIL OD WITH (NOLOCK)  
      WHERE orderkey=@c_GetOrdkey  
      AND OD.Sku=@c_SKU  
  
      OPEN CUR_ODLine  
  
      FETCH NEXT FROM CUR_ODLine INTO @c_ODLineNumber  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         INSERT INTO #TEMPVASDETAIL (pickslipno,orderkey, OrdLineNo,caseid,pidloc, Notes)  
         SELECT DISTINCT @c_PickSlipNo,@c_GetOrdkey,@c_ODLineNumber,@c_PDLabelNo,  
         CASE WHEN ISNULL(PD.TaskDetailKey,'') <> '' THEN TD.LogicalToLoc ELSE PD.loc END, --pd.loc,               -- ZG01  
         odr.Note1                        --CS03  
         FROM pickdetail pd (NOLOCK)  
         JOIN orderdetail od (NOLOCK) ON od.OrderKey=pd.OrderKey AND od.OrderLineNumber=pd.OrderLineNumber  
                  and od.sku = pd.sku and od.storerkey = pd.storerkey  
         join OrderDetailRef AS odr WITH (NOLOCK) ON odr.OrderLineNumber=pd.OrderLineNumber AND odr.Orderkey=od.OrderKey  
         LEFT JOIN TaskDetail AS td WITH (NOLOCK) ON td.TaskType='RPF' AND td.TaskDetailKey=PD.TaskDetailKey      -- ZG01  
         WHERE od.OrderKey=@c_GetOrdkey  
         --AND odr.StorerKey='NIKESDC'  
         AND ISNULL(odr.Note1,'') <> ''  
         AND odr.OrderLineNumber=@c_ODLineNumber  
         AND pd.PickSlipNo=@c_PickSlipNo  
         --AND pd.Loc=@c_getpicloc                 --(CS02a)  
  
          DECLARE CUR_vas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT notes  
          FROM #TEMPVASDETAIL  
          WHERE Pickslipno = @c_PickSlipNo  
          AND orderkey = @c_GetOrdkey  
          AND OrdLineNo = @c_ODLineNumber  
          AND caseid = @c_PDLabelNo  
          --AND PIDLOC = @c_getpicloc  --WL01  
  
          OPEN CUR_vas  
  
          FETCH NEXT FROM CUR_vas INTO @c_VNote  
          WHILE @@FETCH_STATUS <> -1  
          BEGIN  
             SET @c_TempVAS = @c_vas  
  
             --Remove numbers in string --WL01  
             WHILE PATINDEX('%[0-9]%', @c_TempVAS) > 0  
             BEGIN  
                SET @c_TempVAS = STUFF(@c_TempVAS, PATINDEX('%[0-9]%', @c_TempVAS), 1, '')  
             END  
  
             INSERT INTO #TempVAS  
             SELECT CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(ColValue,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS NVARCHAR(255))  
             FROM fnc_DelimSplit('.',@c_TempVAS)  
             WHERE ColValue <> ''  
  
             --WL01 Check if notes already exists in the VAS string, do not add in  
             IF NOT EXISTS (SELECT 1 FROM #TempVAS WHERE Notes = @c_VNote )  
             BEGIN  
                IF @c_vas = ''  
                BEGIN  
                   SET @c_vas = CONVERT(NVARCHAR(10),@n_seqno) +'. ' +@c_VNote + CHAR(13)  
                END  
                ELSE  
                BEGIN  
                   SET @c_vas = @c_vas + CONVERT(NVARCHAR(10),@n_seqno)+'. ' + @c_VNote + CHAR(13)  
                END  
             END  
               
             SET @n_seqno = @n_seqno + 1  
             SET @c_TempVAS = '' --WL01  
             TRUNCATE TABLE #TempVAS              --WL01  
               
             FETCH NEXT FROM CUR_vas INTO @c_VNote  
          END  
          CLOSE CUR_vas  
          DEALLOCATE CUR_vas  
  
          FETCH NEXT FROM CUR_ODLine INTO @c_ODLineNumber  
      END   
      CLOSE CUR_ODLine  
      DEALLOCATE CUR_ODLine  
      --WL01 End  
  
      --CS01 Start  
      SELECT @c_Category = ISNULL(c.UDF02,'')  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      JOIN SKU S WITH (NOLOCK) ON s.StorerKey = pd.Storerkey AND s.sku = pd.Sku  
      JOIN CODELKUP C WITH (NOLOCK) ON c.listname = 'NKSCate' AND c.Code=s.SUSR4  
      WHERE pd.caseid =  @c_PDLabelNo  
      AND pd.Sku= @c_SKU  
  
  
 --SELECT  @n_MaxCartonNo= MAX(CartonNo) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo  
  
      SELECT @n_MaxCartonNo = MAX(CL.Seqno)  
      FROM PickDetail  PD WITH (NOLOCK)  
      LEFT JOIN CartonListDetail CLD WITH (NOLOCK) ON CLD.PickDetailKey=PD.PickDetailKey  
      LEFT JOIN CartonList AS CL WITH (NOLOCK) ON CL.CartonKey = CLD.CartonKey  
      WHERE PD.PickSlipNo = @c_PickSlipNo  
        
        
      UPDATE #TMP_SDCCartonLBL  
      SET  
           PIDLOC = CASE WHEN ISNULL(PIDLOC,'') = '' THEN @c_getpicloc ELSE PIDLOC END  
           ,MaxCarton = @n_MaxCartonNo--convert(nvarchar(10),@n_MaxCartonNo)  
           ,VAS = RTRIM(@c_vas)  
           ,Category = @c_Category                    --CS01  
		   ,ODNote = @c_odnotes						  --ML01  
      WHERE caseid = @c_PDLabelNo  
      AND SKU = @c_SKU  
      --AND PIDLOC = @c_getpicloc  
  
      SET @c_GetOrdkey = ''  
      SET @n_lineNo = 1  
        
      DELETE FROM #TEMPVASDETAIL           --CS02  
      SET @n_seqno = 1                     --CS02  
      SET @c_TempVAS = ''                  --WL01  
        
      FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo  
                               ,@c_PDLabelNo  
         ,@c_GetOrdkey  
                               ,@c_SKU  
                               ,@c_PIDLOC  
   END  
   CLOSE CUR_Labelno  
   DEALLOCATE CUR_Labelno  
  
   SELECT Pickslipno,caseid,'' as orderkey,SKU,PIDLOC,SKUStyle,SKUSIze,                 --CS03  
        sum(PDQty) AS PDQty,PICtnType,sortLane,DispatchLane,CurrCnt,MaxCarton,  
        Pageno,VAS,SUSR3,Category,ShowRing,Ring,ShowPickzone,C_Company,ODNote,ODUDF05   --WL02   --WL03	--ML01  
   FROM #TMP_SDCCartonLBL  
   GROUP BY Pickslipno,caseid,SKU,SKUStyle,SKUSIze,  
         PIDLOC,PICtnType,sortLane,DispatchLane,CurrCnt,MaxCarton,  
         Pageno,VAS,SUSR3,Category,ShowRing,Ring,ShowPickzone,C_Company,ODNote,ODUDF05   --WL02   --WL03	--ML01
   ORDER BY CASE WHEN ISNULL(PIDLOC,'') = '' THEN 1 ELSE 0 END             --(CS05)  
   --END  
END  

GO