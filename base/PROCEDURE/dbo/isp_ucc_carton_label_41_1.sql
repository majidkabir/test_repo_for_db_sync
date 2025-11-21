SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  isp_UCC_Carton_Label_41_1                          */    
/* Creation Date: 7-Mar-2016                                            */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:  To print Ucc Carton Label 40 (Launch Carton )              */    
/*                                                                      */    
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */    
/*                                                                      */    
/* Output Parameters:                                                   */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By:  r_dw_ucc_carton_label_40                                 */    
/*                                                                      */    
/* PVCS Version: 2.4                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/* 20-May-2016  CSCHONG  1.1. fix loc blank issue (CS01)                */    
/* 29-May-2016  CSCHONG  1.2  Change mapping AND add new field (CS02)   */    
/* 25-JUL-2016  CSCHONG  1.3  Change loc mapping (CS03)                 */    
/* 18-Jul-2016  MTTey    1.1  IN00090573 Revised _MaxLineno to 17 (MT01)*/    
/* 11-Aug-2016  CSCHONG  1.4  SOS#373800-Add new field AND sorting(CS04)*/    
/* 29-Aug-2016  TLTING   1.5  Perfromance tune - Storerkey filter       */    
/* 04-Oct-2016  SPChin   1.6  IN00152476 - Add Filter By LabelNo        */    
/* 27-SEP-2017  CSCHONG  1.7  WMS-3054- Revised field mapping (CS05)    */    
/* 15-JAN-2018  CSCHONG  1.8  WMS-3742 - add new field (CS06)           */    
/* 21-DEC-2018  WLCHOOI  1.9  WMS-7319 - add new field (WL01)           */    
/* 20-Mar-2019  TLTING01 1.10 missing nolock                            */    
/* 20-Mar-2019  TLTING01 1.10 performance tune                          */    
/* 20-MAR-2019  CSCHONG  2.0  WMS-8273 - revised field logic (CS07)     */    
/* 12-May-2019  TLTING02 2.2  performance tune  TLTING03                */   
/* 04-Jun-2020  WLChooi  2.3  WMS-13502 Revise @n_MaxLineno to 13 (WL01)*/
/* 28-Dec-2021  WLChooi  2.4  DevOps Combine Script                     */
/* 28-Dec-2021  WLChooi  2.4  WMS-18633 Use MAX(OrderGroup) (WL02)      */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_UCC_Carton_Label_41_1] (    
         @c_StorerKey      NVARCHAR(20)    
      ,  @c_PickSlipNo     NVARCHAR(20)    
      ,  @c_StartCartonNo  NVARCHAR(20)    
      ,  @c_EndCartonNo    NVARCHAR(20)    
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
         , @c_OrdStop         NVARCHAR(10)    
         , @c_OrdUserDef02    NVARCHAR(20)    
         , @c_OrdBuyerPO      NVARCHAR(20)    
         , @n_cartonno        INT    
         , @c_PDLabelNo       NVARCHAR(20)    
         , @c_PIDLOC          NVARCHAR(10)    
         , @c_SKU             NVARCHAR(20)    
         , @c_putawayzone     NVARCHAR(10)    
         , @c_PICtnType       NVARCHAR(10)    
         , @n_PDqty           INT   
         , @n_qty             INT    
         , @c_MixSku          NVARCHAR(1)    
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
         , @c_picloc          NVARCHAR(10)    
         , @c_getpicloc       NVARCHAR(10)    
         , @n_MaxId           INT    
         , @n_MaxRec          INT    
         , @n_getPageno       INT    
         , @n_MaxLineno       INT    
         , @n_CurrentRec      INT    
         , @c_GetPDLabelNo    NVARCHAR(20)  --(CS01)    
         , @c_GetPIDLOC       NVARCHAR(10)  --(CS01)    
         , @c_getsku          NVARCHAR(20)   --(CS01)    
         , @c_CARTERPO        NVARCHAR(10)   --(CS04)    
         , @c_splitskustyle   NVARCHAR(20)   --(CS05)    
         , @c_getseqno        NVARCHAR(10)   --(CS06)    
         , @c_showvas         NVARCHAR(1)   --(WL01)    
         , @c_OHUDF09         NVARCHAR(50)  --(CS07)  
    
   SET @c_ExternOrderkey  = ''    
   SET @c_GetExtOrdkey    = ''    
   SET @c_OrdStop         = ''    
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
   SET @n_qty             = 0    
   SET @c_Orderkey        = ''    
   SET @c_Delimiter       = ','    
   SET @n_lineNo          =1    
   SET @c_Prefix          ='Ext'    
   SET @n_CntOrderkey     = 1    
   SET @c_SKUStyle        = ''    
   SET @n_CntSize         = 1    
   SET @c_GrpExtOrderkey = ''    
   SET @n_Page            = 1    
   SET @n_PrnQty          = 1    
   SET @c_picloc          = ''    
   SET @c_getpicloc       = ''    
   SET @n_Page            = 1    
   SET @n_PrnQty          = 1    
   SET @c_picloc          = ''    
   SET @c_getpicloc       = ''    
   SET @n_MaxLineno       = 13              --(MT01)   --WL01    
   SET @c_CARTERPO        = ''    
   SET @c_getseqno        = ''              --(CS06)    
   SET @c_showvas         = ''              --(WL01)    

   CREATE TABLE #TMP_LCartonLABEL (    
          rowid           INT NOT NULL identity(1,1) PRIMARY KEY,    
          Pickslipno      NVARCHAR(20) NULL,    
          OrdStop         NVARCHAR(10) NULL,    
          OrdUserDef02    NVARCHAR(20) NULL,    
          OrdExtOrdKey    NVARCHAR(150) NULL,    
          OrdBuyerPO      NVARCHAR(20) NULL,    
          cartonno        INT NULL,    
          PDLabelNo       NVARCHAR(20) NULL,    
          PIDLOC          NVARCHAR(10) NULL,    
          SKUStyle        NVARCHAR(25) NULL,             --(CS05)    
          susr3           NVARCHAR(18) NULL,    
          PDQty           INT,    
          PICtnType       NVARCHAR(10) NULL,    
          MixSku          NVARCHAR(1) DEFAULT'N',    
          PageNo          INT,    
          sku             NVARCHAR(20),    
          Qty             INT NULL,    
          ORDUpSource     NVARCHAR(10) NULL,    
          ORdCState       NVARCHAR(45) NULL,             --(CS02)    
          CARTERPO        NVARCHAR(10) NULL,             --(CS04)    
          Seqno           NVARCHAR(10) NULL,             --(CS06)    
          showvas         NVARCHAR(1)  NULL,             --(WL01)    
          Brand           NVARCHAR(10) NULL,             --(WL01)    
          Store           NVARCHAR(50) NULL,             --(WL01)    
          OrdUserDef09    NVARCHAR(60) NULL)             --(WL01)    
     
   CREATE TABLE #TMP_LCartonLABEL_1 (    
          rowid           INT NOT NULL identity(1,1) PRIMARY KEY,    
          Pickslipno      NVARCHAR(20) NULL,    
          OrdStop         NVARCHAR(10) NULL,    
          OrdUserDef02    NVARCHAR(20) NULL,    
          OrdExtOrdKey    NVARCHAR(150) NULL,    
          OrdBuyerPO      NVARCHAR(20) NULL,    
          cartonno        INT NULL,    
          PDLabelNo       NVARCHAR(20) NULL,    
          PIDLOC          NVARCHAR(10) NULL,    
          SKUStyle        NVARCHAR(25) NULL,            --(CS05)    
          susr3           NVARCHAR(18) NULL,    
          PDQty           INT NULL,    
          PICtnType       NVARCHAR(10) NULL,    
          MixSku          NVARCHAR(1) DEFAULT'N',    
          PageNo          INT,    
          sku             NVARCHAR(20) NULL,    
          recgroup        INT NULL,    
          Qty             INT NULL,    
          ORDUpSource     NVARCHAR(10) NULL,    
          ORdCState       NVARCHAR(45) NULL,             --(CS02)    
          CARTERPO        NVARCHAR(10) NULL,             --(CS04)    
          Seqno           NVARCHAR(10) NULL,             --(CS06)    
          showvas         NVARCHAR(1)  NULL,             --(WL01)    
          Brand           NVARCHAR(10) NULL,             --(WL01)    
          Store           NVARCHAR(50) NULL,             --(WL01)    
          OrdUserDef09    NVARCHAR(60) NULL)             --(WL01)    

   INSERT INTO #TMP_LCartonLABEL(Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,cartonno,PDLabelNo,    
                                 PIDLOC,SKUStyle,susr3,PDQty,PICtnType,MixSku,PageNo,sku,ORDUpSource,ORdCState,CARTERPO,Seqno, 
                                 ShowVAS,Brand,Store,OrdUserDef09)
   SELECT DISTINCT PAH.Pickslipno--,ISNULL(RTRIM(ORDERS.Stop),'')    
                ,  CL.code    
                ,  ISNULL(RTRIM(ORDERS.Userdefine02),'')    
                ,  ''--ISNULL(RTRIM(ORDERS.ExternOrderkey),'')    
                ,  MAX(ISNULL(RTRIM(ORDERS.BuyerPO),''))   --WL02                               
                ,  PADET.CartonNo    
                ,  ISNULL(RTRIM(PADET.Labelno),'')    
                --,  ISNULL(RTRIM(PIDET.Loc),'')    
                ,  ''--,  ISNULL(TD.FinalLOC,'')          --(CS01)    
                ,  CASE WHEN ISNULL(RTRIM(ORDERS.UpdateSource),'') = '003'     
                   THEN ISNULL(RTRIM(S.Style),'') +'*' +ISNULL(RTRIM(S.Measurement),'') ELSE ISNULL(RTRIM(S.Style),'')  END             --(CS05)    
                ,  CASE WHEN ISNULL(S.BUSR8 ,'') <> '' THEN S.BUSR8 ELSE '99' END            --(CS02)    
                ,  0    
                ,  ISNULL(PAIF.CartonType,'')    
                ,  'N'    
                ,  @n_Page    
                ,  PIDET.SKU    
                ,  ISNULL(RTRIM(ORDERS.UpdateSource),'')    
                ,  ISNULL(RTRIM(ORDERS.C_State),'')             --(CS02)    
                ,  ''                                          --(CS04)    
                ,  ''                                          --(CS06)    
                ,  ''                                          --(WL01)    
                ,  CASE WHEN ORDERS.DOOR = '01' THEN 'CRT' ELSE 'OSH' END   --(WL01)    
                ,  ISNULL(ORDERS.C_CONTACT2,'')   --(WL01)    
                ,  ISNULL(ORDERS.Userdefine09,'') --(WL01)    
   FROM PACKHEADER PAH WITH (NOLOCK)    
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno    
                                      AND PIDET.SKU = PADET.SKU    
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = PIDET.Orderkey    
                                        AND ORDDET.Orderlinenumber=PIDET.Orderlinenumber    
   JOIN ORDERS     WITH (NOLOCK) ON (ORDDET.Orderkey = ORDERS.Orderkey)    
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey AND S.SKU = PADET.SKU    
   LEFT JOIN PACKINFO   PAIF WITH (NOLOCK) ON PAIF.Pickslipno =PADET.Pickslipno AND PAIF.CartonNo = PADET.CartonNo    
   -- JOIN Taskdetail TD WITH (NOLOCK) ON TD.TaskDetailKey=PIDET.TaskDetailKey                                             --CS01    
   --                                  AND TD.TaskType='RPF'                                                               --CS01    
   LEFT JOIN codelkup CL (NOLOCK) ON CL.description=ORDERS.facility AND CL.listname ='carterfac'     
                                 AND CL.storerkey= @c_StorerKey  --'cartersz'    
   --tlting01    
   WHERE PAH.Pickslipno = @c_PickSlipNo    
   AND PAH.Storerkey = @c_StorerKey    
   AND PADET.CartonNo BETWEEN CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)     
   --WL02 S
   GROUP BY PAH.Pickslipno
          , CL.code    
          , ISNULL(RTRIM(ORDERS.Userdefine02),'')    
          --, ISNULL(RTRIM(ORDERS.BuyerPO),'')                               
          , PADET.CartonNo    
          , ISNULL(RTRIM(PADET.Labelno),'')     
          , CASE WHEN ISNULL(RTRIM(ORDERS.UpdateSource),'') = '003'     
            THEN ISNULL(RTRIM(S.Style),'') +'*' +ISNULL(RTRIM(S.Measurement),'') ELSE ISNULL(RTRIM(S.Style),'')  END
          , CASE WHEN ISNULL(S.BUSR8 ,'') <> '' THEN S.BUSR8 ELSE '99' END 
          , ISNULL(PAIF.CartonType,'')     
          , PIDET.SKU    
          , ISNULL(RTRIM(ORDERS.UpdateSource),'')    
          , ISNULL(RTRIM(ORDERS.C_State),'')    
          , CASE WHEN ORDERS.DOOR = '01' THEN 'CRT' ELSE 'OSH' END 
          , ISNULL(ORDERS.C_CONTACT2,'')
          , ISNULL(ORDERS.Userdefine09,'')  
   --WL02 E
   ORDER BY ISNULL(RTRIM(PADET.Labelno),''),PADET.CartonNo  

   /*CS02 Start*/    
    
   --tlting01 - performance tune    
   UPDATE #TMP_LCartonLABEL    
   SET PIDLOC  = ( SELECT TOP 1  CASE WHEN ISNULL(TD.logicaltoloc,'') = '' THEN TD.ToLoc ELSE TD.logicaltoloc END   --(CS04)      
                   FROM PICKDETAIL PD WITH (NOLOCK)      
                   LEFT JOIN TaskDetail AS TD WITH (NOLOCK) ON TD.TaskDetailKey=PD.TaskDetailKey      
                   WHERE  TD.TaskType='RPF'      
                   AND pd.CaseID = A.PDLabelNo    
                   AND pd.StorerKey=@c_StorerKey   --TLTING02    
                   AND pd.sku    = A.SKU   )    
               , Seqno = ISNULL(( SELECT TOP 1 isnull(C.Short,'')      
                                  FROM dbo.CODELKUP C WITH (NOLOCK)      
                                  JOIN dbo.WorkOrderDetail WD WITH (NOLOCK) ON C.Code=WD.WorkOrderKey      
                                  JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ExternOrderKey=WD.Remarks      
                                  JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
                                  WHERE c.LISTNAME='CARTERORD'      
                                  AND C.StorerKey=@c_StorerKey   --TLTING03    
                                  AND PD.CaseID = A.PDLabelNo  ), '')    
               , showvas = ISNULL(( SELECT TOP 1 'Y' FROM PICKDETAIL PD (NOLOCK)    
                                    JOIN OrderDetailRef ODR  (NOLOCK) ON ODR.OrderKey = PD.OrderKey       
                                    AND ODR.Storerkey = PD.Storerkey     
                                    AND PD.OrderLineNumber=ODR.OrderLineNumber      
                                    WHERE PD.CaseID=A.PDLabelNo     
                                    AND EXISTS ( SELECT 1 FROM Codelkup   (NOLOCK)    
                                                 WHERE ListName='CARTERVAS'     
                                                 AND StorerKey=@c_StorerKey     
                                                 AND Short='Y'     
                                                 AND Codelkup.Code = ODR.RetailSKU ) ), 'N')    
   FROM #TMP_LCartonLABEL A    
    
   --  DECLARE CUR_PDLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   --  SELECT DISTINCT    
   --         PDLabelNo,sku    
   --  FROM #TMP_LCartonLABEL WITH (NOLOCK)    
   --  WHERE Pickslipno = @c_PickSlipNo    
      
   --  OPEN CUR_PDLOC    
      
   --  FETCH NEXT FROM CUR_PDLOC INTO @c_GetPDLabelNo,@c_getsku    
      
      
   --  WHILE @@FETCH_STATUS <> -1    
   --  BEGIN    
      
      
   --     SET @c_GetPIDLOC = ''    
   --     SET @c_getseqno = ''   --(CS06)    
      
   -- --SELECT TOP 1 @c_GetPIDLOC = CASE WHEN ISNULL(TD.FinalLOC,'') = '' THEN TD.ToLoc ELSE TD.FinalLOC END   --(CS03)    
   -- SELECT TOP 1 @c_GetPIDLOC = CASE WHEN ISNULL(TD.logicaltoloc,'') = '' THEN TD.ToLoc ELSE TD.logicaltoloc END   --(CS04)    
   -- FROM PICKDETAIL PD WITH (NOLOCK)    
   -- LEFT JOIN TaskDetail AS TD WITH (NOLOCK) ON TD.TaskDetailKey=PD.TaskDetailKey    
   -- WHERE  TD.TaskType='RPF'    
   -- AND pd.CaseID=@c_GetPDLabelNo    
   -- AND pd.sku=@c_getsku    
        
        
        
   --  --CS06 start    
   --  SELECT TOP 1 @c_getseqno  = isnull(C.Short,'')    
   --  FROM dbo.CODELKUP C WITH (NOLOCK)    
   --  JOIN dbo.WorkOrderDetail WD WITH (NOLOCK) ON C.Code=WD.WorkOrderKey    
   -- JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ExternOrderKey=WD.Remarks    
   -- JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey    
   -- WHERE  c.LISTNAME='CARTERORD'    
   --  AND PD.CaseID = @c_GetPDLabelNo     
   --  --CS06 END    
      
   --  --tlting01    
   --  IF EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)     
   --           JOIN OrderDetailRef ODR (NOLOCK)  ON ODR.OrderKey = PD.OrderKey     
   --   AND ODR.Storerkey = PD.Storerkey AND PD.OrderLineNumber=ODR.OrderLineNumber    
   --   WHERE PD.CaseID=@c_GetPDLabelNo AND ODR.RetailSKU IN     
   --   (SELECT Code FROM Codelkup (NOLOCK)      
   --                 WHERE ListName='CARTERVAS' AND StorerKey=@c_StorerKey AND Short='Y'))    
   --BEGIN    
   -- SET @c_showvas = 'Y'    
   --END    
      
   -- UPDATE #TMP_LCartonLABEL    
   -- SET PIDLOC = @c_GetPIDLOC    
   --     ,Seqno = @c_getseqno                       --(CS06)    
   --  ,showvas = @c_showvas                              --(WL01)    
   -- WHERE PDLabelNo = @c_GetPDLabelNo    
   -- AND sku=@c_getsku    
      
   --FETCH NEXT FROM CUR_PDLOC INTO @c_GetPDLabelNo,@c_getsku    
      
   --  END    
   --  CLOSE CUR_PDLOC    
   --  DEALLOCATE CUR_PDLOC    
      
   /*CS02 End*/    
    
   DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT    
          PDLabelNo    
         ,cartonno    
         ,skustyle    
         ,sku    
         ,PIDLOC    
         --,Seqno                           --(CS06)    
   FROM #TMP_LCartonLABEL WITH (NOLOCK)    
   WHERE Pickslipno = @c_PickSlipNo    
    
   OPEN CUR_Labelno    
    
   FETCH NEXT FROM CUR_Labelno INTO @c_PDLabelNo    
                                   ,@n_cartonno    
                                   ,@c_SKUStyle    
                                   ,@c_sku    
                                   ,@c_PIDLOC    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_prnqty = 1    
      SET @c_OrdBuyerPO = ''             --(CS04)    
      SET @c_CARTERPO   = ''              --(CS04)    
    
      --SELECT @n_CntOrderkey = Count(Orderkey)    
      --FROM PACKHEADER PAH WITH (NOLOCK)    
      --JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno    
      --WHERE PADET.Labelno = @c_PDLabelNo    
    
      /*CS05 start*/    
          
      SET @c_splitskustyle = ''    
      IF CHARINDEX('*',@c_SKUStyle) > 0    
      BEGIN    
         SET @c_splitskustyle = SUBSTRING(@c_SKUStyle,1,CHARINDEX('*',@c_SKUStyle)-1)    
      END    
          
      /*CS05 END*/    
    
      SELECT @n_CntOrderkey = Count(DISTINCT Orderkey)    
      FROM PICKDETAIL PIDET WITH (NOLOCK)    
      WHERE PIDET.Caseid = @c_PDLabelNo    
    
      SELECT TOP 1 @n_prnqty = billedContainerQTy    
      FROM PICKDETAIL PIDET WITH (NOLOCK)    
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey    
      WHERE PIDET.Caseid = @c_PDLabelNo    
    
      IF @n_CntOrderkey <> 0    
      BEGIN    
         IF @n_CntOrderkey = 1    
         BEGIN    
            SET @c_Delimiter = ''    
         END    
      END    
            
      /*CS04 start*/    
      SELECT @c_OrdBuyerPO = ORD.BuyerPO    
            ,@c_OHUDF09 = ORD.Userdefine09               --CS07     
      FROM PICKDETAIL PIDET WITH (NOLOCK)    
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey    
      WHERE PIDET.Caseid = @c_PDLabelNo    
          
      IF ISNULL(@c_OrdBuyerPO,'') <> ''    
      BEGIN       
         SELECT @c_CARTERPO = ISNULL(CL.short,'')    
         FROM CODELKUP AS CL WITH (NOLOCK)    
         -- LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.WaveKey=CL.CODE      --CS07    
         WHERE CL.LISTNAME='CARTERPO'     
         AND CL.code2= @c_OrdBuyerPO    
         AND CL.code = @c_OHUDF09          --CS07    
         -- AND PD.Caseid = @c_PDLabelNo --IN00152476                     --CS07    
      END      

      /*CS04 End*/       
    
      SET @c_ExternOrderkey = ''    
      SET @c_GrpExtOrderkey = ''    
      SET @c_GetExtOrdkey = ''    
    
      IF @c_PIDLOC = ''    
      BEGIN    
         SELECT TOP 1 @c_getpicloc=LLD.loc    
         FROM lotxlocxid LLD (NOLOCK)    
         JOIN LOC L (NOLOCK) ON L.Loc = LLd.LOC    
         WHERE LLD.sku=@c_sku     
         AND  LLD.StorerKey = @c_storerkey    
         AND L.LocationCategory='SHELVING'    
         AND L.LocationType='DYNPPICK' AND LLD.qty>0    
      END    
      ELSE    
      BEGIN    
         SET @c_getpicloc = @c_PIDLOC    
      END    
    
      DECLARE CUR_ExtnOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT ExternOrderkey    
      FROM PICKDETAIL PIDET WITH (NOLOCK)    
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey    
      WHERE PIDET.caseid = @c_PDLabelNo    
      ORDER BY 1    
      
      OPEN CUR_ExtnOrdKey    
      
      FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_ExternOrderkey    
      
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
    
         --SET @c_ExternOrderkey = @c_Prefix + RIGHT('000'+CAST(ISNULL(@n_lineNo,'000') as nvarchar(3)),3) + @c_Delimiter    
         
         --SET @c_GetExtOrdkey = @c_GetExtOrdkey + @c_ExternOrderkey    
         
         SET @c_GrpExtOrderkey = @c_ExternOrderkey + @c_Delimiter    
         
         SET @c_GetExtOrdkey = @c_GetExtOrdkey + @c_GrpExtOrderkey    
         
         -- SET @n_lineNo = @n_lineNo + 1    
         -- SET @n_CntOrderkey = @n_CntOrderkey - 1    
         
         FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_ExternOrderkey    
      END    
    
      CLOSE CUR_ExtnOrdKey    
      DEALLOCATE CUR_ExtnOrdKey    
    
      SET @n_CntSize = 1    
      SET @c_MixSku = 'N'    
       
      SELECT @n_CntSize = Count(componentsku)    
      FROM PACKDETAIL PD WITH (NOLOCK)    
      JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.Sku    
      JOIN BillOfMaterial BOM WITH (NOLOCK) ON S.storerkey = BOM.storerkey AND S.Sku = BOM.SKU     
      WHERE PD.labelno = @c_PDLabelNo    
      AND S.storerkey = @c_storerkey    
      AND PD.SKU = @c_sku    
      AND S.Style = @c_splitskustyle              --(CS05)    
    
      SELECT @n_PDqty = SUM(qty)    
            ,@n_qty  = SUM(qty*s.busr1)    
      FROM PACKDETAIL PD WITH (NOLOCK)    
      JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.Sku    
      WHERE PD.labelno = @c_PDLabelNo    
      AND S.sku = @c_sku    
      AND S.storerkey = @c_storerkey    
        
      IF @n_CntSize > 1    
      BEGIN    
         SET @c_MixSku = 'Y'    
      END    
      
      UPDATE #TMP_LCartonLABEL    
      SET OrdExtOrdKey = @c_GetExtOrdkey    
        , PDQty = @n_PDqty    
        , MixSku= @c_MixSku    
        , PIDLOC = @c_getpicloc    
        , Qty = @n_qty    
        , CARTERPO = ISNULL(@c_CARTERPO,'')             --(CS04)    
      WHERE PDLabelNo = @c_PDLabelNo    
      AND cartonno = @n_cartonno    
      AND SKU = @c_sku    
      AND SKUStyle = @c_SKUStyle    
    
      FETCH NEXT FROM CUR_Labelno INTO @c_PDLabelNo    
                                      ,@n_cartonno    
                                      ,@c_SKUStyle    
                                      ,@c_sku    
                                      ,@c_PIDLOC    
   END    
   CLOSE CUR_Labelno    
   DEALLOCATE CUR_Labelno    
    
   WHILE @n_prnqty > 1    
   BEGIN    
      INSERT INTO #TMP_LCartonLABEL    
      ( Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
        cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,PDQty,    
        PICtnType,MixSku,Pageno,sku,qty,ORDUpSource,ORdCState,CARTERPO,Seqno,showvas,Brand,Store,OrdUserDef09)                 --(CS02)   --(CS04)   --(CS06)   --(WL01)    
      SELECT Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
             cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,PDQty,    
             PICtnType,MixSku,(@n_Page+1),sku,qty,ORDUpSource,ORdCState,CARTERPO ,seqno, showvas,brand,store,OrdUserDef02    --(CS02) --(CS04)     --(CS06) --(WL01)    
      FROM #TMP_LCartonLABEL    
      WHERE pageno = @n_Page    
    
      SET @n_prnqty = @n_prnqty - 1    
      SET @n_Page = @n_Page + 1    
   END    
    
   IF @n_prnqty >= 1    
   BEGIN    
      INSERT INTO #TMP_LCartonLABEL_1    
      ( Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
        cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,PDQty,    
        PICtnType,MixSku,Pageno,sku,recgroup,qty,ORDUpSource,ORdCState,CARTERPO,seqno,showvas,brand,store,OrdUserDef09)   --(CS02)   --(CS04)   --(CS06)   --(WL01)    
      SELECT Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
             cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,SUM(PDQty) AS PDQty,    
             PICtnType,MixSku,Pageno,sku,(Row_Number() OVER (PARTITION BY Pickslipno ORDER BY PIDLOC Asc)-1) / @n_MaxLineno+1 AS recgroup   --(CS04)    
            ,SUM(Qty) AS Qty,ORDUpSource,ORdCState ,CARTERPO ,seqno, showvas, brand, store, OrdUserDef09              --(CS02)  --(CS04)  --(CS06)  --(WL01)    
      FROM #TMP_LCartonLABEL WITH (NOLOCK)    
      GROUP BY Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
               cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,    
               PICtnType,MixSku,Pageno,sku,ORDUpSource,ORdCState,CARTERPO ,seqno, showvas, brand, store, OrdUserDef09   --(CS02)  --(CS04)   --(CS06)   --(WL01)    
      ORDER BY CASE WHEN ISNULL(PIDLOC,'') = '' THEN 1 ELSE 0 END      
       
      DECLARE CUR_PageLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT pageno    
      FROM   #TMP_LCartonLABEL_1    
      ORDER BY pageno    
       
      OPEN CUR_PageLoop    
       
      FETCH NEXT FROM CUR_PageLoop INTO @n_GetPageno    
       
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
       
         SELECT @n_MaxRec = MAX(recgroup)    
               ,@n_MaxId  = MAX(rowid)    
         FROM  #TMP_LCartonLABEL_1    
         WHERE PageNo = @n_GetPageno    
       
         SET @n_CurrentRec =  @n_MaxId%@n_MaxLineno    
       
         WHILE @n_MaxId % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno    
         BEGIN    
            INSERT INTO #TMP_LCartonLABEL_1    
            ( Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
              cartonno,PDLabelNo,    
              PICtnType,Pageno,recgroup,ORDUpSource,ORdCState,CARTERPO,seqno,showvas,brand,store,OrdUserDef09)         --(CS02)   --(CS04)  --(CS06)  --(WL01)    
            SELECT TOP 1 Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
                         cartonno,PDLabelNo,PICtnType,Pageno,recgroup,ORDUpSource,ORdCState,CARTERPO,seqno,showvas,brand,store,OrdUserDef09 --(CS02)   --(Cs04)  --(CS06)--(WL01)    
            FROM #TMP_LCartonLABEL_1    
            WHERE PageNo = @n_GetPageno    
            AND recgroup = @n_MaxRec     
       
            SET @n_CurrentRec = @n_CurrentRec + 1    
         END    
       
         FETCH NEXT FROM CUR_PageLoop INTO @n_GetPageno    
      END    
       
      CLOSE CUR_PageLoop    
       
      SELECT Pickslipno,OrdStop,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,    
             cartonno,PDLabelNo,PIDLOC,SKUStyle,susr3,PDQty,    
             PICtnType,MixSku,Pageno,recgroup,qty,ORDUpSource,ORdCState,CARTERPO,seqno        --(CS06)    
            ,showvas, Brand, Store, OrdUserDef09          --(WL01)    
      FROM  #TMP_LCartonLABEL_1    
      ORDER BY CASE WHEN ISNULL(PIDLOC,'') = '' THEN 1 ELSE 0 END,recgroup             --(CS04)    
   END       
END    

GO