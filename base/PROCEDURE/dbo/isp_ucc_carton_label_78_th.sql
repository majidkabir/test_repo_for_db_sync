SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store Procedure:  isp_UCC_Carton_Label_78_th                         */      
/* Creation Date: 13-Jul-2022                                           */      
/* Copyright: LFL                                                       */      
/* Written by: WLChooi                                                  */      
/*                                                                      */      
/* Purpose: WMS-20204 - TH-Nike-CR Picking label                        */      
/*           Copy from isp_UCC_Carton_Label_78                          */      
/*                                                                      */      
/* Input Parameters: (PickSlipNo, FromCartonNo, ToCartonNo, FromLabelNo */      
/*                    ToLabelNo, DropID)                                */      
/*                                                                      */      
/* Output Parameters:                                                   */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Called By:  r_dw_ucc_carton_label_78_th                              */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 13-Jul-2022  WLChooi  1.0  DevOps Combine Script                     */ 
/************************************************************************/      
      
CREATE PROC [dbo].[isp_UCC_Carton_Label_78_th] (       
      @c_Pickslipno     NVARCHAR(10)    
    , @c_FromCartonNo   NVARCHAR(5)  = '' 
    , @c_ToCartonNo     NVARCHAR(5)  = ''
    , @c_FromLabelNo    NVARCHAR(20) = ''  
    , @c_ToLabelNo      NVARCHAR(20) = ''
    , @c_DropID         NVARCHAR(20) = ''
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
          , @c_GetPickslipno NVARCHAR(20) = ''      
          , @n_MaxLineno     INT = 5     
          , @n_CurrentRec    INT    
          , @n_MaxRec        INT    
          , @n_CartonNo      INT    
      
   CREATE TABLE #Temp_PACKDETAIL(      
        Pickslipno     NVARCHAR(10) NULL,      
        CartonFrom     NVARCHAR(10) NULL,      
        CartonTo       NVARCHAR(10) NULL )      
      
   CREATE TABLE #Temp_LOC(      
        Loadkey        NVARCHAR(10) NULL,      
        Pickslipno     NVARCHAR(10) NULL,      
        Descr          NVARCHAR(30) NULL,      
        LOC            NVARCHAR(10) NULL )       
           
   DECLARE @c_ExecStatements       NVARCHAR(4000)        
         , @c_ExecArguments        NVARCHAR(4000)        
         , @c_SQLJoin              NVARCHAR(4000)      
         , @c_SQLJoin1             NVARCHAR(4000)        
         , @c_SQL                  NVARCHAR(MAX)       
  
   IF ISNULL(@c_FromCartonNo,'') = '' OR ISNULL(@c_ToCartonNo,'') = ''
   BEGIN
      SELECT @c_FromCartonNo  = MIN(PD.CartonNo)
           , @c_ToCartonNo    = MAX(PD.CartonNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.LabelNo BETWEEN @c_FromLabelNo AND @c_ToLabelNo
   END

   IF ISNULL(@c_FromLabelNo,'') = '' OR ISNULL(@c_ToLabelNo,'') = ''
   BEGIN
      SELECT @c_FromLabelNo   = MIN(PD.LabelNo)
           , @c_ToLabelNo     = MAX(PD.LabelNo)
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
      AND PD.CartonNo BETWEEN @c_FromCartonNo AND @c_ToCartonNo
   END

   INSERT INTO #Temp_PACKDETAIL (Pickslipno, CartonFrom, CartonTo)  
   SELECT PD.Pickslipno, PD.CartonNo, PD.CartonNo
   FROM PACKDETAIL PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Pickslipno
   AND PD.CartonNo BETWEEN @c_FromCartonNo AND @c_ToCartonNo
      
   INSERT INTO #Temp_LOC (Loadkey, Pickslipno, Descr, LOC)
   SELECT LPD.Loadkey, PH.Pickslipno,       
   CASE WHEN COUNT(DISTINCT LPD.LocationCategory) = 2 THEN 'OBStage Loc:'       
        WHEN COUNT(DISTINCT LPD.LocationCategory) = 1 THEN CASE WHEN MAX(LPD.LocationCategory) = 'Staging' THEN 'OBStage Loc:'       
                                                                WHEN MAX(LPD.LocationCategory) = 'PACK&HOLD' THEN 'P&H Loc:' ELSE '' END      
        ELSE '' END,       
   CASE WHEN COUNT(DISTINCT LPD.LocationCategory) = 1       
        THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = LPD.LOADKEY   
              )      
        WHEN COUNT(DISTINCT LPD.LocationCategory) = 2       
        THEN (SELECT TOP 1 LPLD.LOC FROM LoadPlanLaneDetail LPLD (NOLOCK) WHERE LPLD.LOADKEY = LPD.LOADKEY   
              AND LPLD.LocationCategory = 'STAGING'      
              )      
        ELSE '' END      
   FROM PACKHEADER PH (NOLOCK)      
   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = PH.ORDERKEY      
   JOIN LOADPLANDETAIL L (NOLOCK) ON L.OrderKey = OH.OrderKey
   JOIN LoadplanLaneDetail LPD (NOLOCK) ON LPD.LoadKey = L.LoadKey
   WHERE PH.Pickslipno = @c_pickslipno      
   AND LTRIM(RTRIM(LPD.LocationCategory)) IN ('PACK&HOLD', 'STAGING')      
   GROUP BY LPD.Loadkey, PH.Pickslipno, OH.ExternOrderKey, OH.Consigneekey      
      
   CREATE TABLE #RESULT(      
       rowid           INT NOT NULL identity(1,1) PRIMARY KEY,  
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
       TaskType        NVARCHAR(10) NULL      
   )      
         
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

   INSERT INTO #RESULT (PickSlipNo, LoadKey, SKU, Qty, BUSR7, PACKUOM3, LABELNO, EDITWHO, EditDate, CartonNo, Descr, LOC
                      , CartonType, DeviceID, TaskType)
   SELECT PD.Pickslipno      
        , ORD.LOADKEY      
        , PD.SKU      
        , PD.QTY      
        , S.BUSR7      
        , P.PACKUOM3      
        , UPPER(PD.LABELNO)       
        , ISNULL(TD.UserkeyOverride,'')         
        , ''      
        , PD.CartonNo      
        , ISNULL(L.Descr,'')       
        , ISNULL(L.LOC,'')         
        , PIF.CartonType           
        , ISNULL(TD.DeviceID,'')         
        , ISNULL(TD.TaskType,'')         
   FROM PACKDETAIL PD WITH (NOLOCK)      
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO      
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY      
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = ORD.STORERKEY      
   JOIN PACK P  WITH (NOLOCK) ON P.PACKKEY = S.PACKKEY      
   JOIN #Temp_PACKDETAIL T WITH (NOLOCK) ON T.Pickslipno = PD.Pickslipno AND PD.CartonNo BETWEEN T.CartonFrom AND T.CartonTo      
   LEFT JOIN #Temp_LOC L WITH (NOLOCK) ON L.Loadkey = ORD.LoadKey AND L.Pickslipno = PH.PickSlipNo
   LEFT JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   LEFT JOIN Taskdetail TD WITH (NOLOCK) ON ORD.UserDefine09 = TD.WaveKey AND PD.LabelNo = TD.CaseID AND TD.Qty > 0
   GROUP BY PD.Pickslipno      
          , ORD.LOADKEY      
          , PD.SKU      
          , PD.QTY      
          , S.BUSR7      
          , P.PACKUOM3      
          , UPPER(PD.LABELNO)    
          , PD.CartonNo      
          , ISNULL(L.Descr,'')  
          , ISNULL(L.LOC,'')  
          , PIF.CartonType     
          , ISNULL(TD.DeviceID,'')    
          , ISNULL(TD.UserkeyOverride,'')   
          , ISNULL(TD.TaskType,'')     
   ORDER BY PD.Pickslipno, PD.CartonNo  
         
   DECLARE CUR_EDITDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT PICKSLIPNO, CartonNo      
   FROM #RESULT      
   ORDER BY PICKSLIPNO, CartonNo      
         
   OPEN CUR_EDITDATE      
         
   FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @n_CartonNo      
         
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      SELECT @c_editwho   = MAX(EDITWHO) ,      
             @d_editdate  = MAX(EDITDATE)      
      FROM PACKDETAIL (NOLOCK)      
      WHERE PICKSLIPNO = @c_GetPickslipno       
      AND CartonNo = @n_CartonNo      
       
      UPDATE #RESULT      
      SET EditDate = @d_editdate--, EditWho = @c_editwho      
      WHERE PICKSLIPNO = @c_GetPickslipno       
      AND CartonNo = @n_CartonNo      
         
      FETCH NEXT FROM CUR_EDITDATE INTO @c_GetPickslipno, @n_CartonNo      
   END      
   CLOSE CUR_EDITDATE   
   DEALLOCATE CUR_EDITDATE     
      
   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
   SELECT DISTINCT PickSlipNo, CartonNo                      
   FROM #RESULT                      
                      
   OPEN CUR_PSNO                       
                      
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo, @n_CartonNo  
   
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
      AND CartonNo = @n_CartonNo                      
      ORDER BY PickSlipNo, CartonNo              
                      
      SELECT @n_MaxRec = COUNT(ROWID)                       
      FROM #RESULT                       
      WHERE PickSlipNo = @c_PickSlipNo                      
      AND CartonNo = @n_CartonNo                      
                      
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
         AND CartonNo = @n_CartonNo                                        
                      
         SET @n_CurrentRec = @n_CurrentRec + 1                             
      END                       
                      
      SET @n_MaxRec = 0                      
      SET @n_CurrentRec = 0                      
                      
      FETCH NEXT FROM CUR_psno INTO @c_PickSlipNo, @n_CartonNo                      
   END   
   CLOSE CUR_psno      
   DEALLOCATE CUR_psno   
                      
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
         
   IF OBJECT_ID('tempdb..#RESULT ','u') IS NOT NULL       
   DROP TABLE #RESULT      
          
   IF OBJECT_ID('tempdb..#Temp_PACKDETAIL ','u') IS NOT NULL       
   DROP TABLE #Temp_PACKDETAIL       
      
   IF OBJECT_ID('tempdb..#Temp_LOC ','u') IS NOT NULL       
   DROP TABLE #Temp_LOC       

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
     
END 

GO