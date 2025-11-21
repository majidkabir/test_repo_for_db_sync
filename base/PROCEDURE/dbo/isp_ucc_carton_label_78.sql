SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store Procedure:  isp_UCC_Carton_Label_78                            */      
/* Creation Date: 29-Mar-2019                                           */      
/* Copyright: IDS                                                       */      
/* Written by: WLCHOOI                                                  */      
/*                                                                      */      
/* Purpose:  To print Ucc Carton Label 78 (Carton Content)              */      
/*           Copy from isp_UCC_Carton_Label_56                          */      
/*                                                                      */      
/* Input Parameters: (PickSlipNo, CartonNoStart, CartonNoEnd)           */      
/*                   OR ExternOrderKey                                  */      
/*                                                                      */      
/* Output Parameters:                                                   */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Called By:  r_dw_ucc_carton_label_78                                 */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 2019-09-04   WLChooi  1.1  WMS-10453 - Restructure the code, add new */      
/*                            mapping (WL01)                            */      
/* 2019-11-07   WLChooi  1.2  Fixed barcode not showing completely when */      
/*                            labelno with mixed char and number (WL02) */      
/* 2020-03-24   WLChooi  1.3  WMS-12359 - Modify logic (WL03)           */      
/* 2020-09-24   WLChooi  1.4  Max(userkeyoverride) (WL04)               */     
/* 2020-11-10   LZG      1.5  INC1347978- Exclude 0 Qty tasks           */  
/************************************************************************/      
      
CREATE PROC [dbo].[isp_UCC_Carton_Label_78] (      
      --WL03 START      
  --   @c_PickSlipNo     NVARCHAR(20) = ''      
  --,  @c_StartCartonNo  NVARCHAR(20) = ''      
  --,  @c_EndCartonNo    NVARCHAR(20) = ''      
      @c_LabelNo        NVARCHAR(50),      
      @n_StartCartonNo  INT = 0,      
      @n_EndCartonNo    INT = 0,      
      @c_PickType       NVARCHAR(5) = ''      
      --WL03 END      
)      
AS      
BEGIN      
      
 SET NOCOUNT ON      
 SET ANSI_DEFAULTS OFF      
 SET QUOTED_IDENTIFIER OFF      
 SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue      INT = 1      
          , @b_debug         INT = 0      
          , @c_EditWho       NVARCHAR(50) = ''      
          , @d_EditDate      DATETIME      
          , @nSumPackQty     INT = 0      
          , @c_GetPickslipno NVARCHAR(20) = ''      
          , @nCartonNo       INT      
          , @c_pickslipno    NVARCHAR(10) = ''   --WL03      
          , @n_MaxLineno     INT = 5       --WL03               
          , @n_CurrentRec    INT           --WL03      
          , @n_MaxRec        INT           --WL03      
          , @n_cartonno      INT           --WL03      
      
   --WL01 Start      
   --IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL       
   --DROP TABLE #RESULT       
      
   CREATE TABLE #Temp_PACKDETAIL(      
        Pickslipno     NVARCHAR(10) NULL,      
        CartonFrom     NVARCHAR(10) NULL,      
        CartonTo       NVARCHAR(10) NULL )      
      
   CREATE TABLE #Temp_LOC(      
        Loadkey        NVARCHAR(10) NULL,      
        Pickslipno     NVARCHAR(10) NULL,      
        Descr          NVARCHAR(30) NULL,      
        LOC            NVARCHAR(10) NULL )       
      
   --WL03 START      
   DECLARE @c_ExecStatements       NVARCHAR(4000)        
         , @c_ExecArguments        NVARCHAR(4000)        
         , @c_SQLJoin              NVARCHAR(4000)      
         , @c_SQLJoin1             NVARCHAR(4000)        
         , @c_SQL                  NVARCHAR(MAX)       
      
   SELECT @c_pickslipno    = PACKDETAIL.Pickslipno      
        , @n_StartCartonNo = CASE WHEN ISNULL(@n_StartCartonNo,0) = 0 THEN PACKDETAIL.CartonNo ELSE @n_StartCartonNo END      
        , @n_EndCartonNo   = CASE WHEN ISNULL(@n_EndCartonNo,0) = 0   THEN PACKDETAIL.CartonNo ELSE @n_EndCartonNo END      
   FROM PACKDETAIL (NOLOCK)      
   WHERE LabelNo = @c_LabelNo      
      
   IF ISNULL(@c_PickType,'') = ''      
      SET @c_PickType = ''      
   --WL03 END      
      
   --Check Pickslipno or ExternOrderKey      
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_pickslipno)      
   BEGIN      
      --SELECT @c_pickslipno    = PH.PICKSLIPNO      
      --FROM PACKHEADER PH (NOLOCK)      
      --JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
      --WHERE ORD.EXTERNORDERKEY = @c_pickslipno      
      --GROUP BY PH.PICKSLIPNO      
      
      INSERT INTO #Temp_PACKDETAIL      
      SELECT Pickslipno, @n_StartCartonNo, @n_EndCartonNo      
      FROM PACKHEADER PH (NOLOCK)      
    JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
    WHERE ORD.EXTERNORDERKEY = @c_pickslipno      
    GROUP BY PH.PICKSLIPNO      
      
      INSERT INTO #Temp_LOC      
      SELECT OH.Loadkey, PH.Pickslipno,       
      CASE WHEN COUNT(DISTINCT LPLD.LocationCategory) = 2 THEN 'OBStage Loc:'       
           WHEN COUNT(DISTINCT LPLD.LocationCategory) = 1 THEN CASE WHEN MAX(LPLD.LocationCategory) = 'Staging' THEN 'OBStage Loc:'       
                                                                    WHEN MAX(LPLD.LocationCategory) = 'PACK&HOLD' THEN 'P&H Loc:' ELSE '' END      
           ELSE '' END,       
      CASE WHEN COUNT(DISTINCT LPLD.LocationCategory) = 1       
           THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = OH.LOADKEY --AND LPLD.Externorderkey = OH.Externorderkey --WL03      
                 --AND LPLD.Consigneekey = OH.Consigneekey      
                 )      
           WHEN COUNT(DISTINCT LPLD.LocationCategory) = 2       
           THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = OH.LOADKEY --AND LPLD.Externorderkey = OH.Externorderkey --WL03      
                 --AND LPLD.Consigneekey = OH.Consigneekey --WL03       
                 AND LPLD.LocationCategory = 'STAGING')      
           ELSE '' END      
      FROM PACKHEADER PH (NOLOCK)      
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = PH.ORDERKEY      
      JOIN LoadplanLaneDetail LPLD (NOLOCK) ON LPLD.LOADKEY = OH.LOADKEY AND LPLD.Externorderkey = OH.Externorderkey  --WL03      
                                           --AND LPLD.Consigneekey = OH.Consigneekey  --WL03      
    WHERE OH.EXTERNORDERKEY = @c_pickslipno      
      AND LTRIM(RTRIM(LPLD.LocationCategory)) IN ('PACK&HOLD', 'STAGING')      
      GROUP BY OH.Loadkey, PH.Pickslipno, OH.ExternOrderKey, OH.Consigneekey      
            
      --SELECT * FROM #TEMP_LOC      
   END      
   ELSE      
   BEGIN      
      INSERT INTO #Temp_PACKDETAIL      
      SELECT @c_PickSlipNo, @n_StartCartonNo, @n_EndCartonNo      
      
      INSERT INTO #Temp_LOC      
      SELECT OH.Loadkey, PH.Pickslipno,       
      CASE WHEN COUNT(DISTINCT LPLD.LocationCategory) = 2 THEN 'OBStage Loc:'       
           WHEN COUNT(DISTINCT LPLD.LocationCategory) = 1 THEN CASE WHEN MAX(LPLD.LocationCategory) = 'Staging' THEN 'OBStage Loc:'       
                                                                    WHEN MAX(LPLD.LocationCategory) = 'PACK&HOLD' THEN 'P&H Loc:' ELSE '' END      
           ELSE '' END,       
      CASE WHEN COUNT(DISTINCT LPLD.LocationCategory) = 1       
           THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = OH.LOADKEY --AND LPLD.Externorderkey = OH.Externorderkey --WL03      
                 --AND LPLD.Consigneekey = OH.Consigneekey --WL03      
                 )      
           WHEN COUNT(DISTINCT LPLD.LocationCategory) = 2       
           THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = OH.LOADKEY --AND LPLD.Externorderkey = OH.Externorderkey --WL03      
                 --AND LPLD.Consigneekey = OH.Consigneekey --WL03      
                 AND LPLD.LocationCategory = 'STAGING'      
                 )      
           ELSE '' END      
      FROM PACKHEADER PH (NOLOCK)      
    JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = PH.ORDERKEY      
      JOIN LoadplanLaneDetail LPLD (NOLOCK) ON LPLD.LOADKEY = OH.LOADKEY --AND LPLD.Externorderkey = OH.Externorderkey--WL03      
                                           --AND LPLD.Consigneekey = OH.Consigneekey   --WL03      
    WHERE PH.Pickslipno = @c_pickslipno      
      AND LTRIM(RTRIM(LPLD.LocationCategory)) IN ('PACK&HOLD', 'STAGING')      
      GROUP BY OH.Loadkey, PH.Pickslipno, OH.ExternOrderKey, OH.Consigneekey      
      
      --SELECT * FROM #TEMP_LOC      
   END      
   --WL01 End      
      
   CREATE TABLE #RESULT(      
       rowid           int NOT NULL identity(1,1) PRIMARY KEY,    --WL03      
       PickSlipNo      NVARCHAR(10) NULL,      
       LoadKey         NVARCHAR(10) NULL,      
       SKU             NVARCHAR(50) NULL,      
       Qty             INT NULL,      
       BUSR7           NVARCHAR(50) NULL,      
       PACKUOM3        NVARCHAR(50) NULL,      
       LABELNO         NVARCHAR(20) NULL,      
       EDITWHO         NVARCHAR(45) NULL,      
       EditDate        DATETIME NULL,      
       CartonNo        INT NULL,      
       Descr           NVARCHAR(30) NULL, --WL01      
       LOC             NVARCHAR(10) NULL, --WL01      
       CartonType      NVARCHAR(10) NULL, --WL03      
       DeviceID        NVARCHAR(10) NULL, --WL03      
       TaskType        NVARCHAR(10) NULL  --WL03      
   )      
      
   --WL03 START      
   CREATE TABLE #RESULT_1(      
       rowid           int NOT NULL identity(1,1) PRIMARY KEY,       
       PickSlipNo      NVARCHAR(10) NULL,      
       LoadKey         NVARCHAR(10) NULL,      
       SKU             NVARCHAR(50) NULL,      
       Qty             INT NULL,      
       BUSR7           NVARCHAR(50) NULL,      
       PACKUOM3        NVARCHAR(50) NULL,      
       LABELNO         NVARCHAR(20) NULL,      
       EDITWHO         NVARCHAR(45) NULL,      
       EditDate        DATETIME NULL,      
       CartonNo        INT NULL,      
       Descr           NVARCHAR(30) NULL,       
       LOC             NVARCHAR(10) NULL,       
       CartonType      NVARCHAR(10) NULL,       
       DeviceID        NVARCHAR(10) NULL,       
       TaskType        NVARCHAR(10) NULL,      
       RecGroup        INT NULL,      
       ShowNo          NVARCHAR(1) NULL        
   )      
   --WL03 END      
      
   --WL03 START (Change to DynamicSQL)      
   IF @c_PickType = 'CPK'      
   BEGIN      
      SET @c_SQLJoin = 'LEFT JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo' + CHAR(13) +      
                       'LEFT JOIN Taskdetail TD WITH (NOLOCK) ON ORD.UserDefine09 = TD.WaveKey AND PD.LabelNo = TD.CaseID ' + CHAR(13) +   
                       'AND TD.Qty > 0 '        -- INC1347978  
      
      SET @c_SQL = 'INSERT INTO #RESULT      
                   SELECT PD.Pickslipno      
                          ,ORD.LOADKEY      
                          ,PD.SKU      
                          ,PD.QTY      
                          ,S.BUSR7      
                          ,P.PACKUOM3      
                          ,UPPER(PD.LABELNO) --WL02      
                          ,MAX(ISNULL(TD.UserkeyOverride,''''))   --WL03   --WL04      
                          ,''''      
                          ,PD.CartonNo      
                          ,ISNULL(L.Descr,'''') --WL01      
                          ,ISNULL(L.LOC,'''')   --WL01      
                          ,PIF.CartonType     --WL03      
                          ,ISNULL(TD.DeviceID,'''')   --WL03      
                          ,ISNULL(TD.TaskType,'''')   --WL03      
                    FROM PACKDETAIL PD WITH (NOLOCK)      
                    JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO      
                    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
                    JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = ORD.STORERKEY      
                    JOIN PACK P  WITH (NOLOCK) ON P.PACKKEY = S.PACKKEY      
                    JOIN #Temp_PACKDETAIL T WITH (NOLOCK) ON T.Pickslipno = PD.Pickslipno AND PD.CartonNo BETWEEN T.CartonFrom AND T.CartonTo      
                    LEFT JOIN #Temp_LOC L WITH (NOLOCK) ON L.Loadkey = ORD.LoadKey AND L.Pickslipno = PH.PickSlipNo ' + CHAR(13) +       
                    @c_SQLJoin + '      
                    --WHERE PD.PICKSLIPNO = @c_PickSlipNo --AND PH.STORERKEY = @c_StorerKey                       --WL01      
                    --AND PD.CARTONNO BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT)       --WL01      
                    GROUP BY PD.Pickslipno      
                            ,ORD.LOADKEY      
                            ,PD.SKU      
                            ,PD.QTY      
                            ,S.BUSR7      
                            ,P.PACKUOM3      
                            ,UPPER(PD.LABELNO) --WL02      
                            ,PD.CartonNo      
                            ,ISNULL(L.Descr,'''') --WL01      
                            ,ISNULL(L.LOC,'''')   --WL01      
                            ,PIF.CartonType     --WL03      
                            ,ISNULL(TD.DeviceID,'''')   --WL03      
                            --,ISNULL(TD.UserkeyOverride,'''')   --WL03   --WL04      
                            ,ISNULL(TD.TaskType,'''')   --WL03      
                    ORDER BY PD.Pickslipno, PD.CartonNo --WL01'      
      
      SET @c_ExecStatements = @c_SQL      
      
      EXEC sp_ExecuteSql @c_ExecStatements         
   END      
   ELSE      
   BEGIN      
      --Check CPK (Loose)      
      SET @c_SQLJoin = 'JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo' + CHAR(13) +      
                       'JOIN Taskdetail TD WITH (NOLOCK) ON ORD.UserDefine09 = TD.WaveKey AND PD.LabelNo = TD.CaseID ' + CHAR(13) +       
                       'AND TD.Qty > 0 '        -- INC1347978  
  
      SET @c_SQL = 'INSERT INTO #RESULT      
                    SELECT PD.Pickslipno      
                          ,ORD.LOADKEY      
                          ,PD.SKU      
                          ,PD.QTY      
                          ,S.BUSR7      
                          ,P.PACKUOM3      
                          ,UPPER(PD.LABELNO) --WL02      
                          ,ISNULL(TD.UserkeyOverride,'''')   --WL03      
                          ,''''      
                          ,PD.CartonNo      
                          ,ISNULL(L.Descr,'''') --WL01      
                          ,ISNULL(L.LOC,'''')   --WL01      
                          ,PIF.CartonType     --WL03      
                          ,ISNULL(TD.DeviceID,'''')   --WL03      
                          ,ISNULL(TD.TaskType,'''')   --WL03      
                    FROM PACKDETAIL PD WITH (NOLOCK)      
                    JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO      
                    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
                    JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = ORD.STORERKEY      
                    JOIN PACK P  WITH (NOLOCK) ON P.PACKKEY = S.PACKKEY      
                    JOIN #Temp_PACKDETAIL T WITH (NOLOCK) ON T.Pickslipno = PD.Pickslipno AND PD.CartonNo BETWEEN T.CartonFrom AND T.CartonTo      
                    LEFT JOIN #Temp_LOC L WITH (NOLOCK) ON L.Loadkey = ORD.LoadKey AND L.Pickslipno = PH.PickSlipNo ' + CHAR(13) +       
                    @c_SQLJoin + '      
                    --WHERE PD.PICKSLIPNO = @c_PickSlipNo --AND PH.STORERKEY = @c_StorerKey                       --WL01      
                    --AND PD.CARTONNO BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT)       --WL01      
                    GROUP BY PD.Pickslipno      
                            ,ORD.LOADKEY      
                            ,PD.SKU      
                            ,PD.QTY      
                            ,S.BUSR7      
                            ,P.PACKUOM3      
                            ,UPPER(PD.LABELNO) --WL02      
                            ,PD.CartonNo      
                            ,ISNULL(L.Descr,'''') --WL01      
                            ,ISNULL(L.LOC,'''')   --WL01      
                            ,PIF.CartonType     --WL03      
                            ,ISNULL(TD.DeviceID,'''')   --WL03      
                            ,ISNULL(TD.UserkeyOverride,'''')   --WL03      
                            ,ISNULL(TD.TaskType,'''')   --WL03      
                    ORDER BY PD.Pickslipno, PD.CartonNo --WL01'      
      
      SET @c_ExecStatements = @c_SQL      
      
      EXEC sp_ExecuteSql @c_ExecStatements         
      
      --Check RPF (Full Case)      
      IF NOT EXISTS (SELECT 1 FROM #RESULT)      
      BEGIN      
         SET @c_SQLJoin = 'JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo' + CHAR(13) +      
                          'JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.CaseID = PD.LabelNo AND PID.Orderkey = ORD.Orderkey' + CHAR(13) +      
                          'JOIN Taskdetail TD WITH (NOLOCK) ON ORD.UserDefine09 = TD.WaveKey AND PID.DropID = TD.CaseID'      
      
         SET @c_SQL = 'INSERT INTO #RESULT      
                       SELECT PD.Pickslipno      
                             ,ORD.LOADKEY      
                             ,PD.SKU      
                             ,PD.QTY      
                             ,S.BUSR7      
                             ,P.PACKUOM3      
                             ,UPPER(PD.LABELNO) --WL02      
                             ,ISNULL(TD.UserkeyOverride,'''')   --WL03      
                             ,''''      
                             ,PD.CartonNo      
                             ,ISNULL(L.Descr,'''') --WL01      
                             ,ISNULL(L.LOC,'''')   --WL01      
                             ,PIF.CartonType     --WL03      
                             ,ISNULL(TD.DeviceID,'''')   --WL03      
                             ,ISNULL(TD.TaskType,'''')   --WL03      
                       FROM PACKDETAIL PD WITH (NOLOCK)      
                       JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO      
                       JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
                       JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = ORD.STORERKEY      
                       JOIN PACK P  WITH (NOLOCK) ON P.PACKKEY = S.PACKKEY      
                       JOIN #Temp_PACKDETAIL T WITH (NOLOCK) ON T.Pickslipno = PD.Pickslipno AND PD.CartonNo BETWEEN T.CartonFrom AND T.CartonTo      
                       LEFT JOIN #Temp_LOC L WITH (NOLOCK) ON L.Loadkey = ORD.LoadKey AND L.Pickslipno = PH.PickSlipNo ' + CHAR(13) +       
                       @c_SQLJoin + '      
                       --WHERE PD.PICKSLIPNO = @c_PickSlipNo --AND PH.STORERKEY = @c_StorerKey                       --WL01      
                       --AND PD.CARTONNO BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT)       --WL01      
                       GROUP BY PD.Pickslipno      
                               ,ORD.LOADKEY      
                               ,PD.SKU      
                               ,PD.QTY      
                               ,S.BUSR7      
                               ,P.PACKUOM3      
                               ,UPPER(PD.LABELNO) --WL02      
                               ,PD.CartonNo      
                               ,ISNULL(L.Descr,'''') --WL01      
                               ,ISNULL(L.LOC,'''')   --WL01      
                               ,PIF.CartonType     --WL03      
                               ,ISNULL(TD.DeviceID,'''')   --WL03      
                               ,ISNULL(TD.UserkeyOverride,'''')   --WL03      
                     ,ISNULL(TD.TaskType,'''')   --WL03      
                       ORDER BY PD.Pickslipno, PD.CartonNo --WL01'      
      
         SET @c_ExecStatements = @c_SQL      
               
         EXEC sp_ExecuteSql @c_ExecStatements         
      END      
   END      
   --WL03 END      
         
   DECLARE CUR_EDITDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT PICKSLIPNO, CARTONNO      
   FROM #RESULT      
   ORDER BY PICKSLIPNO, CARTONNO      
         
   OPEN CUR_EDITDATE      
         
   FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @nCartonNo      
         
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
        SELECT @c_editwho   = MAX(EDITWHO) ,      
               @d_editdate  = MAX(EDITDATE)      
        FROM PACKDETAIL (NOLOCK)      
        WHERE PICKSLIPNO = @c_GetPickslipno       
        AND CARTONNO = @nCartonNo      
         
        UPDATE #RESULT      
        SET EditDate = @d_editdate--, EditWho = @c_editwho      
        WHERE PICKSLIPNO = @c_GetPickslipno       
        AND CARTONNO = @nCartonNo      
         
   FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @nCartonNo      
   END      
   --CLOSE CUR_EDITDATE      --WL03      
   --DEALLOCATE CUR_EDITDATE --WL03      
      
   --WL03 START      
   --SELECT * FROM #RESULT      
   --ORDER BY PickSlipNo, CARTONNO  --WL01      
      
   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
   SELECT DISTINCT PickSlipNo, CartonNo                      
   FROM #RESULT                      
                      
   OPEN CUR_PSNO                       
                      
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo, @n_cartonno                      
   WHILE @@FETCH_STATUS <> -1                      
   BEGIN                      
      INSERT INTO #RESULT_1 (      
         PickSlipNo      
       , LoadKey         
       , SKU             
       , Qty             
       , BUSR7           
       , PACKUOM3        
       , LABELNO         
       , EDITWHO         
       , EditDate        
       , CartonNo        
       , Descr           
       , LOC             
       , CartonType      
       , DeviceID        
       , TaskType       
       , RecGroup      
       , ShowNo      
      )      
                               
      SELECT   PickSlipNo      
             , LoadKey         
             , SKU             
             , Qty             
             , BUSR7           
             , PACKUOM3        
             , LABELNO         
             , EDITWHO         
             , EditDate        
             , CartonNo        
             , Descr           
             , LOC             
             , CartonType      
             , DeviceID        
             , TaskType       
             , (Row_Number() OVER (PARTITION BY PickSlipNo, CartonNo ORDER BY PickSlipNo,CartonNo Asc)-1)/@n_MaxLineno + 1 AS recgroup        
             , 'Y'                              
      FROM  #RESULT                      
      WHERE PickSlipNo = @c_PickSlipNo                      
      AND cartonno = @n_cartonno                      
      ORDER BY PickSlipNo, CartonNo              
                      
      SELECT @n_MaxRec = COUNT(ROWID)                       
      FROM #RESULT                       
      WHERE PickSlipNo = @c_PickSlipNo                      
      AND cartonno = @n_cartonno                      
                      
      SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                      
                      
      WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)                   
      BEGIN                       
                      
         INSERT INTO #RESULT_1 (      
            PickSlipNo      
          , LoadKey         
          , SKU             
          , Qty             
          , BUSR7           
          , PACKUOM3        
          , LABELNO         
          , EDITWHO         
          , EditDate        
          , CartonNo        
          , Descr           
          , LOC             
          , CartonType      
          , DeviceID        
          , TaskType       
          , RecGroup      
          , ShowNo      
         )                    
         SELECT TOP 1  PickSlipNo      
                     , LoadKey         
                     , NULL             
                     , NULL             
                     , NULL           
                     , NULL        
                     , LABELNO         
                     , EDITWHO         
                     , EditDate        
                     , CartonNo        
                     , Descr           
                     , LOC             
                     , CartonType      
                     , DeviceID        
                     , TaskType       
                     , RecGroup      
                     , 'N'      
         FROM #RESULT_1                       
         WHERE PickSlipNo = @c_PickSlipNo                      
         AND cartonno = @n_cartonno                      
         --ORDER BY ROWID DESC                      
                      
         SET @n_CurrentRec = @n_CurrentRec + 1                             
      END                       
                      
      SET @n_MaxRec = 0                      
      SET @n_CurrentRec = 0                      
                      
 FETCH NEXT FROM CUR_psno INTO @c_PickSlipNo, @n_cartonno                      
   END                      
                      
   SELECT  PickSlipNo      
         , LoadKey         
         , SKU             
         , Qty             
         , BUSR7           
         , PACKUOM3        
         , LABELNO         
         , EDITWHO         
         , EditDate        
         , CartonNo        
         , Descr           
         , LOC             
         , CartonType      
         , DeviceID        
         , TaskType       
         , RecGroup      
         , ShowNo      
   FROM #RESULT_1                       
   ORDER BY Pickslipno, CartonNo, CASE WHEN ISNULL(SKU,'') = '' THEN 1 ELSE 0 END                  
   -- WL03 END       
      
         
   IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL       
   DROP TABLE #RESULT      
      
   --WL01 Start      
   IF OBJECT_ID('tempdb..#Temp_PACKDETAIL ','u') IS NOT NULL       
   DROP TABLE #Temp_PACKDETAIL       
      
   IF OBJECT_ID('tempdb..#Temp_LOC ','u') IS NOT NULL       
   DROP TABLE #Temp_LOC       
   --WL01 End      
      
   --WL03 START      
   IF CURSOR_STATUS('LOCAL', 'CUR_EDITDATE') IN (0 , 1)      
   BEGIN      
      CLOSE CUR_EDITDATE      
      DEALLOCATE CUR_EDITDATE         
   END      
      
   IF CURSOR_STATUS('LOCAL', 'CUR_psno') IN (0 , 1)      
   BEGIN      
      CLOSE CUR_psno      
      DEALLOCATE CUR_psno         
   END      
      
   IF OBJECT_ID('tempdb..#RESULT_1') IS NOT NULL       
      DROP TABLE #RESULT_1       
   --WL03 END      
END 


GO