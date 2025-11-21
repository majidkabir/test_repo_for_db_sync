SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_r_hk_picking_control_list_06                    */  
/* Creation Date: 30-Apr-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Michael Lam (HK LIT)                                      */  
/*                                                                       */  
/* Purpose: Picking Control List                                         */  
/*                                                                       */  
/* Called By: RCM - Popup Discrete Pickslip FPA                          */  
/*                  Popup Combine Pickslip FPA                           */  
/*            Datawidnow r_hk_picking_control_list_06_1                  */  
/*                       r_hk_picking_control_list_06_2                  */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 2019-09-16   ML       1.1  Split subtasks by Pickdetail.PickslipNo    */  
/*                            Add keywords SplitLine, ReSplitLine,       */  
/*                            AssignPicker, ReAssignPicker               */  
/* 2020-11-30   ML       1.2  Fix Divide by zero error (@n_AssignPicker) */  
/* 2021-01-29   ML       1.3  Add Fields C_City, C_Country               */  
/*                            Add ShowField: DropID                      */  
/*                            Convert to Dynamic SQL                     */  
/* 2021-03-06   ML       1.4  Add MapField: DeliveryDate, OrderType,     */  
/*                                          Route, ToteCBM, Notes2       */  
/*                            Add MapValue: T_DeliveryDate*,T_OrderType* */  
/*                            T_Route*, T_Notes2*, T_ShipTo*, T_DropID*  */  
/* 2021-03-17   ML       1.5  Exclude blank PickZone                     */  
/* 2021-04-29   ML       1.6  Add ShowField ShowPutawayZone              */  
/* 2021-04-30   ML       1.7  Add new field Indicator                    */  
/* 2022-03-23   ML       1.8  Add NULL to Temp Table                     */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_06] (  
       @as_Key_Type  NVARCHAR(13)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
/* CODELKUP.REPORTCFG  
   [MAPFIELD]  
      ReserveLoc_Cond, CustomerGroupCode, DeliveryDate, OrderType, Userdefine05, Route, ShipToAddress, ToteCBM, Notes, Notes2  
      DropID, Div, Brand, Indicator  
  
   [MAPVALUE]  
      T_DeliveryDate_1, T_DeliveryDate_2, T_OrderType_1, T_OrderType_2, T_Userdefine05_1, T_Userdefine05_2, T_Route_1 , T_Route_2  
      T_Notes_1, T_Notes_2, T_Notes2_1, T_Notes2_2, T_ShipTo_1, T_ShipTo_2  
  
   [SHOWFIELD]  
      DefaultRDTPick, AllowUserChangePickMethod, C_Country, DropID, Code39, ShowPutawayZone  
  
   [SQLJOIN]  
*/  
  
   DECLARE @c_DataWindow         NVARCHAR(40)  
         , @c_Key                NVARCHAR(10)  
         , @c_Type               NVARCHAR(2)  
         , @b_FirstPrint         INT  
         , @b_Success            INT  
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(250)  
         , @n_AssignPicker       INT  
         , @n_SplitLine    INT  
         , @b_ReAssign           INT  
         , @c_PickdetailKey      NVARCHAR(10)  
         , @c_LogicalLocation    NVARCHAR(10)  
         , @c_Loc                NVARCHAR(10)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_Sku                NVARCHAR(20)  
         , @n_Qty                INT  
         , @n_TotalTasks         INT  
         , @n_AvgTasks           FLOAT  
         , @n_Picker             INT  
         , @n_PrevPicker         INT  
         , @c_PickslipNo         NVARCHAR(20)  
         , @c_PickslipNoTemp     NVARCHAR(20)  
         , @c_PH_PickslipNo      NVARCHAR(20)  
         , @c_PrevPH_PickslipNo  NVARCHAR(20)  
         , @c_OrderStatus        NVARCHAR(10)  
         , @c_PickStatus         NVARCHAR(10)  
         , @c_ExecStatements     NVARCHAR(MAX)  
         , @c_ExecArguments      NVARCHAR(MAX)  
         , @c_JoinClause         NVARCHAR(MAX)  
         , @c_ReserveLoc_Cond    NVARCHAR(MAX)  
         , @c_ShowFields         NVARCHAR(MAX)  
         , @c_CustGrpCodeExp     NVARCHAR(MAX)  
         , @c_ShipToAddressExp   NVARCHAR(MAX)  
         , @c_NotesExp           NVARCHAR(MAX)  
         , @c_DivExp             NVARCHAR(MAX)  
         , @c_BrandExp           NVARCHAR(MAX)  
         , @c_Userdefine05Exp    NVARCHAR(MAX)  
         , @c_DropIDExp          NVARCHAR(MAX)  
         , @c_DeliveryDateExp    NVARCHAR(MAX)  
         , @c_OrderTypeExp       NVARCHAR(MAX)  
         , @c_RouteExp           NVARCHAR(MAX)  
         , @c_ToteCBMExp         NVARCHAR(MAX)  
         , @c_Notes2Exp          NVARCHAR(MAX)  
         , @c_IndicatorExp       NVARCHAR(MAX)  
  
  
   SELECT @c_DataWindow = 'r_hk_picking_control_list_06'  
        , @c_Key  = LEFT(@as_Key_Type, 10)  
        , @c_Type = RIGHT(@as_Key_Type, 2)  
        , @b_FirstPrint   = 1  
        , @n_AssignPicker = 0  
        , @n_SplitLine    = 0  
        , @b_ReAssign     = 0  
  
   IF OBJECT_ID('tempdb..#TEMP_PICKHEADER') IS NOT NULL  
      DROP TABLE #TEMP_PICKHEADER  
   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL  
      DROP TABLE #TEMP_PICKDETAIL  
   IF OBJECT_ID('tempdb..#TEMP_PICKTASK') IS NOT NULL  
      DROP TABLE #TEMP_PICKTASK  
   IF OBJECT_ID('tempdb..#TEMP_PICKTASK2') IS NOT NULL  
      DROP TABLE #TEMP_PICKTASK2  
   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL  
      DROP TABLE #TEMP_PICKSLIPNO  
   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL  
      DROP TABLE #TEMP_PIKDT  
  
  
   CREATE TABLE #TEMP_PICKDETAIL (  
        PickdetailKey     NVARCHAR(20)   NULL  
      , OrderKey          NVARCHAR(10)   NULL  
      , LogicalLocation   NVARCHAR(10)   NULL  
      , Loc               NVARCHAR(10)   NULL  
      , Storerkey         NVARCHAR(15)   NULL  
      , Sku               NVARCHAR(20)   NULL  
      , Qty               INT            NULL  
      , PickslipNo        NVARCHAR(20)   NULL  
      , PH_PickslipNo     NVARCHAR(20)   NULL  
   )  
  
   CREATE TABLE #TEMP_PIKDT (  
        PickSlipNo        NVARCHAR(10)   NULL  
      , Storerkey         NVARCHAR(15)   NULL  
      , Orderkey          NVARCHAR(10)   NULL  
      , ExternOrderKey    NVARCHAR(50)   NULL  
      , Status            NVARCHAR(10)   NULL  
      , LoadKey           NVARCHAR(10)   NULL  
      , WaveKey           NVARCHAR(10)   NULL  
      , DeliveryDate      DATETIME       NULL  
      , Type              NVARCHAR(500)  NULL  
      , Notes2            NVARCHAR(4000) NULL  
      , C_Company         NVARCHAR(45)   NULL  
      , C_Address1        NVARCHAR(45)   NULL  
      , C_Address2        NVARCHAR(45)   NULL  
      , C_Address3        NVARCHAR(45)   NULL  
      , C_Address4        NVARCHAR(45)   NULL  
      , C_City            NVARCHAR(45)   NULL  
      , C_Country         NVARCHAR(45)   NULL  
      , Route             NVARCHAR(500)  NULL  
      , AllocQty          INT            NULL  
      , CBM               FLOAT          NULL  
      , Sku               NVARCHAR(20)   NULL  
      , ToLoc             NVARCHAR(10)   NULL  
      , Loc               NVARCHAR(10)   NULL  
      , Lot               NVARCHAR(10)   NULL  
      , ID                NVARCHAR(20)   NULL  
      , PickdetailKey     NVARCHAR(10)   NULL  
      , ToteCBM           FLOAT          NULL  
      , IsConsol          NVARCHAR(1)    NULL  
      , HasReplen         NVARCHAR(1)    NULL  
      , PrintedFlag       NVARCHAR(1)    NULL  
      , LocationCategory  NVARCHAR(10)   NULL  
      , PD_DropID         NVARCHAR(20)   NULL  
      , PD_PickslipNo     NVARCHAR(10)   NULL  
      , Picker            NVARCHAR(20)   NULL  
      , ShowFields        NVARCHAR(4000) NULL  
      , CustomerGroupCode NVARCHAR(500)  NULL  
      , ShipToAddress     NVARCHAR(500)  NULL  
      , Notes             NVARCHAR(4000) NULL  
      , Div               NVARCHAR(500)  NULL  
      , Brand             NVARCHAR(500)  NULL  
      , Userdefine05      NVARCHAR(500)  NULL  
      , DropID            NVARCHAR(500)  NULL  
      , Indicator         NVARCHAR(500)  NULL  
   )  
  
  
   IF @c_Type = 'WP'  
   BEGIN  
      -- Create PickHeader (WP)  
      IF EXISTS(SELECT TOP 1 1  
                FROM dbo.WAVE     WAVE(NOLOCK)  
                JOIN dbo.ORDERS     OH(NOLOCK) ON WAVE.Wavekey=OH.Userdefine09  
                JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
                JOIN dbo.SKU       SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku  
                LEFT JOIN (  
                 SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))  
                      , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
                   FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'  
                ) RptCfg  
                ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1  
                WHERE OH.Status < '5' AND PD.Qty > 0 AND WAVE.Wavekey = @c_Key  
                HAVING (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(WAVE.Userdefine03),'')='RDT')  
                    OR (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,DefaultRDTPick,%'  
                        AND NOT (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(WAVE.Userdefine03),'')='PICKSLIP'))  
      )  
      BEGIN  
         IF EXISTS(SELECT TOP 1 1  
                   FROM dbo.ORDERS     OH(NOLOCK)  
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Orderkey=PH.Orderkey  
                   WHERE OH.Userdefine09=@c_Key AND PH.Zone='8' AND PH.PickType='0'  
            )  
         BEGIN  
            UPDATE PH WITH(ROWLOCK)  
               SET PickType   = '1'  
                 , EditDate   = GETDATE()  
                 , EditWho    = SUSER_SNAME()  
                 , TrafficCop = NULL  
              FROM dbo.ORDERS     OH(NOLOCK)  
              JOIN dbo.PICKHEADER PH ON OH.Orderkey=PH.Orderkey  
             WHERE OH.Userdefine09=@c_Key AND PH.Zone='8' AND PH.PickType='0'  
         END  
  
         EXEC isp_CreatePickSlip  
              @c_Orderkey           = ''  
            , @c_Loadkey            = ''  
            , @c_Wavekey            = @c_Key  
            , @c_PickslipType       = '8'  
            , @c_ConsolidateByLoad  = 'N'  
            , @c_Refkeylookup       = 'N'  
            , @c_LinkPickSlipToPick = 'N'  
            , @c_AutoScanIn         = 'N'  
            , @b_Success            = @b_Success OUTPUT  
            , @n_Err                = @n_Err     OUTPUT  
            , @c_ErrMsg             = @c_ErrMsg  OUTPUT  
      END  
  
      -- Prepare for Assigning Picker (WP)  
      SELECT @n_AssignPicker = TRY_PARSE(REPLACE(REPLACE(UserDefine04,'ReAssignPicker=',''),'AssignPicker=','') AS FLOAT)  
           , @n_SplitLine    = TRY_PARSE(REPLACE(REPLACE(UserDefine04,'ReSplitLine=',''),'SplitLine=','') AS FLOAT)  
           , @b_ReAssign     = IIF(LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%', 1, 0)  
        FROM dbo.WAVE (NOLOCK)  
      WHERE Wavekey = @c_Key  
        AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'AssignPicker=%'  
          OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%'    OR LTRIM(UserDefine04) LIKE 'SplitLine=%')  
  
      SELECT @c_OrderStatus = MAX(OH.Status)  
           , @c_PickStatus  = MAX(PD.Status)  
           , @c_PickslipNo  = MIN(ISNULL(PD.PickslipNo,''))  
        FROM dbo.ORDERS OH(NOLOCK)  
        JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
       WHERE OH.Userdefine09 = @c_Key AND @c_Key<>''  
  
      IF (@n_AssignPicker > 0 OR @n_SplitLine > 0) AND (@c_PickslipNo='' OR @b_ReAssign=1) AND @c_OrderStatus<'3' AND @c_PickStatus='0'  
      BEGIN  
         INSERT INTO #TEMP_PICKDETAIL (PickdetailKey, OrderKey, LogicalLocation, Loc, Storerkey, Sku, Qty, PickslipNo)  
         SELECT PickdetailKey   = PD.PickdetailKey  
              , OrderKey        = PD.OrderKey  
              , LogicalLocation = IIF(PD.ToLoc<>'', LOC2.LogicalLocation, LOC1.LogicalLocation)  
              , Loc             = IIF(PD.ToLoc<>'', LOC2.Loc, LOC1.Loc)  
              , Storerkey       = PD.Storerkey  
              , Sku             = PD.Sku  
              , Qty             = PD.Qty  
              , PickslipNo      = PD.PickslipNo  
           FROM dbo.ORDERS OH(NOLOCK)  
           JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
           LEFT JOIN dbo.LOC LOC1(NOLOCK) ON PD.Loc=LOC1.Loc  
           LEFT JOIN dbo.LOC LOC2(NOLOCK) ON PD.ToLoc=LOC2.Loc AND PD.ToLoc<>''  
          WHERE OH.Userdefine09 = @c_Key AND @c_Key<>'' AND PD.Status = '0'  
      END  
   END  
   ELSE IF @c_Type = 'LP'  
   BEGIN  
      -- Create PickHeader (LP)  
      IF EXISTS(SELECT TOP 1 1  
                FROM dbo.LOADPLAN   LP(NOLOCK)  
                JOIN dbo.ORDERS     OH(NOLOCK) ON LP.Loadkey=OH.Loadkey  
                JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
                JOIN dbo.SKU       SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku  
                LEFT JOIN (  
                 SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))  
                      , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
                   FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'  
                ) RptCfg  
                ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1  
                WHERE OH.Status < '5' AND PD.Qty > 0 AND LP.Loadkey = @c_Key  
                HAVING (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(LP.Userdefine03),'')='RDT')  
                    OR (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,DefaultRDTPick,%'  
                        AND NOT (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(LP.Userdefine03),'')='PICKSLIP'))  
      )  
      BEGIN  
         IF EXISTS(SELECT TOP 1 1  
                   FROM dbo.ORDERS     OH(NOLOCK)  
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Loadkey=PH.ExternOrderkey AND PH.Orderkey='' AND OH.Loadkey<>''  
                   WHERE OH.Loadkey=@c_Key AND PH.Zone='9' AND PH.PickType='0'  
            )  
         BEGIN  
            UPDATE PH WITH(ROWLOCK)  
               SET PickType   = '1'  
                 , EditDate   = GETDATE()  
                 , EditWho    = SUSER_SNAME()  
                 , TrafficCop = NULL  
              FROM dbo.ORDERS     OH(NOLOCK)  
              JOIN dbo.PICKHEADER PH ON OH.Loadkey=PH.ExternOrderkey AND PH.Orderkey='' AND OH.Loadkey<>''  
             WHERE OH.Loadkey=@c_Key AND PH.Zone='9' AND PH.PickType='0'  
         END  
  
         IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.ORDERS(NOLOCK) WHERE Loadkey=@c_Key AND ISNULL(Userdefine08,'')<>'N')  
         BEGIN  
            EXEC isp_CreatePickSlip  
                 @c_Orderkey           = ''  
               , @c_Loadkey            = @c_Key  
    , @c_Wavekey            = ''  
               , @c_PickslipType       = '9'  
               , @c_ConsolidateByLoad  = 'Y'  
               , @c_Refkeylookup       = 'N'  
               , @c_LinkPickSlipToPick = 'N'  
               , @c_AutoScanIn         = 'N'  
               , @b_Success            = @b_Success OUTPUT  
               , @n_Err                = @n_Err     OUTPUT  
               , @c_ErrMsg             = @c_ErrMsg  OUTPUT  
         END  
      END  
  
      -- Prepare for Assigning Picker (LP)  
      SELECT @n_AssignPicker = TRY_PARSE(REPLACE(REPLACE(UserDefine04,'ReAssignPicker=',''),'AssignPicker=','') AS FLOAT)  
           , @n_SplitLine    = TRY_PARSE(REPLACE(REPLACE(UserDefine04,'ReSplitLine=',''),'SplitLine=','') AS FLOAT)  
           , @b_ReAssign     = IIF(LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%', 1, 0)  
        FROM dbo.LOADPLAN (NOLOCK)  
      WHERE Loadkey = @c_Key  
        AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'AssignPicker=%'  
          OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%'    OR LTRIM(UserDefine04) LIKE 'SplitLine=%')  
  
  
      SELECT @c_OrderStatus = MAX(OH.Status)  
           , @c_PickStatus  = MAX(PD.Status)  
           , @c_PickslipNo  = MIN(ISNULL(PD.PickslipNo,''))  
        FROM dbo.ORDERS OH(NOLOCK)  
        JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
       WHERE OH.Loadkey = @c_Key AND @c_Key<>''  
  
      IF (@n_AssignPicker > 0 OR @n_SplitLine > 0) AND (@c_PickslipNo='' OR @b_ReAssign=1) AND @c_OrderStatus<'3' AND @c_PickStatus='0'  
      BEGIN  
         INSERT INTO #TEMP_PICKDETAIL (PickdetailKey, OrderKey, LogicalLocation, Loc, Storerkey, Sku, Qty, PickslipNo)  
         SELECT PickdetailKey   = PD.PickdetailKey  
              , OrderKey        = PD.OrderKey  
              , LogicalLocation = IIF(PD.ToLoc<>'', LOC2.LogicalLocation, LOC1.LogicalLocation)  
              , Loc             = IIF(PD.ToLoc<>'', LOC2.Loc, LOC1.Loc)  
              , Storerkey       = PD.Storerkey  
              , Sku             = PD.Sku  
              , Qty             = PD.Qty  
              , PickslipNo      = PD.PickslipNo  
           FROM dbo.ORDERS OH(NOLOCK)  
           JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
           LEFT JOIN dbo.LOC LOC1(NOLOCK) ON PD.Loc=LOC1.Loc  
           LEFT JOIN dbo.LOC LOC2(NOLOCK) ON PD.ToLoc=LOC2.Loc AND PD.ToLoc<>''  
          WHERE OH.Loadkey = @c_Key AND @c_Key<>'' AND PD.Status = '0'  
      END  
   END  
  
  
   -- #TEMP_PICKHEADER  
   SELECT Orderkey     = OH.Orderkey  
        , PickslipNo   = MAX(ISNULL(PH1.PickHeaderKey,PH2.PickHeaderKey))  
        , IsConsol     = MAX(IIF(PH2.PickHeaderKey IS NOT NULL, 'Y', 'N'))  
        , Userdefine03 = MAX(IIF(PH2.PickHeaderKey IS NOT NULL, LP.Userdefine03, WAVE.Userdefine03))  
        , PrintedFlag  = MAX(IIF(PH2.PickHeaderKey IS NOT NULL, PH2.PickType, PH1.PickType))  
        , FOK          = MIN(OH.Orderkey) OVER(PARTITION BY MAX(ISNULL(PH1.PickHeaderKey,PH2.PickHeaderKey)))  
        , Storerkey    = MAX(OH.Storerkey)  
  
   INTO #TEMP_PICKHEADER  
  
   FROM dbo.ORDERS OH(NOLOCK)  
   LEFT JOIN dbo.PICKHEADER PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND ISNULL(OH.Orderkey,'')<>''  
   LEFT JOIN dbo.PICKHEADER PH2(NOLOCK) ON OH.Loadkey = PH2.ExternOrderkey AND ISNULL(OH.Loadkey,'')<>'' AND ISNULL(PH2.Orderkey,'')=''  
   LEFT JOIN dbo.WAVE      WAVE(NOLOCK) ON OH.Userdefine09=WAVE.Wavekey AND ISNULL(OH.Userdefine09,'')<>'' AND PH1.PickheaderKey IS NOT NULL  
   LEFT JOIN dbo.LOADPLAN    LP(NOLOCK) ON OH.Loadkey=LP.Loadkey AND ISNULL(OH.Loadkey,'')<>''  AND PH2.PickheaderKey IS NOT NULL  
  
   WHERE OH.Status >= '1' AND OH.Status <= '9'  
     AND (PH1.PickheaderKey IS NOT NULL OR PH2.PickheaderKey IS NOT NULL)  
     AND ( @c_Type = 'WP' OR @c_Type = 'LP' )  
     AND ((@c_Type = 'WP' AND OH.Userdefine09 = @c_Key)  
       OR (@c_Type = 'LP' AND OH.Loadkey      = @c_Key)  
         )  
   GROUP BY OH.Orderkey  
  
  
 -- Assigning Picker  
   UPDATE a SET PH_PickslipNo = b.PickslipNo  
     FROM #TEMP_PICKDETAIL a  
     JOIN #TEMP_PICKHEADER b ON a.OrderKey = b.OrderKey  
  
   SELECT DISTINCT PH_PickslipNo, LogicalLocation, Loc, Storerkey, Sku  
     INTO #TEMP_PICKTASK  
     FROM #TEMP_PICKDETAIL  
    WHERE Qty>0  
    ORDER BY 1,2,3,4,5  
  
   SET @n_TotalTasks = 0  
   SELECT @n_TotalTasks = COUNT(1) FROM #TEMP_PICKTASK  
  
   IF @n_SplitLine > 0  
   BEGIN  
      SET @n_AssignPicker = FLOOR( CAST(@n_TotalTasks AS FLOAT) / @n_SplitLine + (1 - 5.1 / @n_SplitLine) )    -- max 5 more lines  
      IF ISNULL(@n_AssignPicker,0)<=0  
         SET @n_AssignPicker = 1  
   END  
   SET @n_AvgTasks = CASE WHEN @n_AssignPicker <= 0 THEN @n_TotalTasks  
                          ELSE CAST(@n_TotalTasks AS FLOAT) / @n_AssignPicker END  
  
  
   IF ISNULL(@n_AssignPicker,0) <= 0 AND ISNULL(@n_SplitLine,0) <= 0  
   BEGIN  
      UPDATE PD WITH(ROWLOCK)  
         SET PickslipNo = RTRIM(a.PickslipNo)  
           , AltSku     = ''  
           , Trafficcop = NULL  
      FROM #TEMP_PICKHEADER a  
      JOIN PICKDETAIL PD ON a.Orderkey = PD.Orderkey  
      WHERE PD.Status = '0' AND ISNULL(PD.PickslipNo,'')<>ISNULL(a.PickslipNo,'')  
   END  
   ELSE IF EXISTS(SELECT TOP 1 1 FROM #TEMP_PICKTASK) AND ISNULL(@n_AvgTasks,0)>0  
   BEGIN  
      SELECT DISTINCT PickslipNo  
        INTO #TEMP_PICKSLIPNO  
        FROM #TEMP_PICKDETAIL  
       WHERE PickslipNo LIKE 'T%'  
       ORDER BY 1  
  
      SELECT @n_PrevPicker = 0  
           , @c_PrevPH_PickslipNo = ''  
           , @c_PickslipNo = ''  
  
      UPDATE PD WITH (ROWLOCK)  
         SET PickslipNo = NULL  
           , AltSku     = ''  
           , Trafficcop = NULL  
        FROM #TEMP_PICKDETAIL a  
        JOIN dbo.PICKDETAIL PD ON a.PickdetailKey=PD.PickdetailKey  
       WHERE PD.Status='0'  
  
      SELECT PH_PickslipNo, LogicalLocation, Loc, Storerkey, Sku  
           , Picker=FLOOR((ROW_NUMBER() OVER(ORDER BY PH_PickslipNo, LogicalLocation, Loc, Storerkey, Sku)-1) / @n_AvgTasks) + 1  
           , PH_PickslipNo_Used = 0  
        INTO #TEMP_PICKTASK2  
        FROM #TEMP_PICKTASK  
  
      DECLARE C_PICKTASK CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT PH_PickslipNo, LogicalLocation, Loc, Storerkey, Sku, Picker  
        FROM #TEMP_PICKTASK2  
       ORDER BY 1,2,3,4,5  
  
      OPEN C_PICKTASK  
  
      WHILE 1=1  
      BEGIN  
         FETCH NEXT FROM C_PICKTASK  
          INTO @c_PH_PickslipNo, @c_LogicalLocation, @c_Loc, @c_Storerkey, @c_Sku, @n_Picker  
  
         IF @@FETCH_STATUS<>0  
            BREAK  
  
         IF @n_Picker<>@n_PrevPicker OR  
            ISNULL(@c_PH_PickslipNo,'')<>ISNULL(@c_PrevPH_PickslipNo,'') OR  
            ISNULL(@c_PickslipNo,'') = ''  
         BEGIN  
            SELECT @n_PrevPicker        = @n_Picker  
                 , @c_PrevPH_PickslipNo = @c_PH_PickslipNo  
                 , @c_PickslipNoTemp    = ''  
  
            IF (SELECT COUNT(DISTINCT Picker) FROM #TEMP_PICKTASK2 WHERE PH_PickslipNo=@c_PH_PickslipNo)=1 AND  
               EXISTS(SELECT TOP 1 1 FROM #TEMP_PICKTASK2 WHERE PH_PickslipNo=@c_PH_PickslipNo AND PH_PickslipNo_Used=0)  
            BEGIN  
               SET @c_PickslipNoTemp = @c_PH_PickslipNo  
               UPDATE #TEMP_PICKTASK2 SET PH_PickslipNo_Used=1 WHERE PH_PickslipNo=@c_PH_PickslipNo AND PH_PickslipNo_Used=0  
            END  
            ELSE IF EXISTS(SELECT TOP 1 1 FROM #TEMP_PICKSLIPNO)  
            BEGIN  
               SELECT @c_PickslipNoTemp = MIN(PickslipNo) FROM #TEMP_PICKSLIPNO  
               IF ISNULL(@c_PickslipNoTemp,'')<>''  
                  DELETE FROM #TEMP_PICKSLIPNO WHERE PickslipNo = @c_PickslipNoTemp  
            END  
  
            IF ISNULL(@c_PickslipNoTemp,'')=''  
            BEGIN  
               EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_PickslipNoTemp OUTPUT, 0, 0, ''  
               SET @c_PickslipNoTemp = 'T' + @c_PickslipNoTemp  
            END  
  
            IF ISNULL(@c_PickslipNoTemp,'')<>''  
            BEGIN  
               SET @c_PickslipNo = @c_PickslipNoTemp  
            END  
         END  
  
         UPDATE PD WITH (ROWLOCK)  
            SET PickslipNo = RTRIM(@c_PickslipNo)  
              , AltSku     = 'Picker-' + RIGHT(SPACE(10)+ISNULL(CONVERT(VARCHAR(10),@n_Picker),''),2) +'/'+ ISNULL(CONVERT(VARCHAR(10),@n_AssignPicker),'')  
              , Trafficcop = NULL  
           FROM #TEMP_PICKDETAIL a  
           JOIN dbo.PICKDETAIL PD ON a.PickdetailKey=PD.PickdetailKey  
          WHERE a.PH_PickslipNo = @c_PH_PickslipNo AND a.LogicalLocation=@c_LogicalLocation  
            AND a.Loc=@c_Loc AND a.Storerkey=@c_Storerkey AND a.Sku=@c_Sku  
            AND PD.Status='0'  
      END  
  
      CLOSE C_PICKTASK  
      DEALLOCATE C_PICKTASK  
   END  
  
   -- Update PICKDETAIL PickslipNo & Picker # (PD.AltSku)  
   IF EXISTS(SELECT TOP 1 1  
               FROM #TEMP_PICKHEADER a  
               JOIN dbo.PICKDETAIL b(NOLOCK) ON a.Orderkey=b.Orderkey  
              WHERE ISNULL(b.PickslipNo,'')='')  
   BEGIN  
      UPDATE PD WITH(ROWLOCK)  
         SET PickslipNo = X.PickslipNo  
           , AltSku     = X.AltSku  
      FROM dbo.PICKDETAIL PD  
      JOIN (  
         SELECT *  
         FROM (  
            SELECT Orderkey  
                 , AltSku  
                 , PickslipNo  
                 , SeqNo = ROW_NUMBER() OVER(PARTITION BY Orderkey ORDER BY PickslipNo DESC, AltSku DESC)  
            FROM dbo.PICKDETAIL (NOLOCK)  
            WHERE ISNULL(PickslipNo,'')<>''  
              AND Orderkey IN (  
                     SELECT DISTINCT b.Orderkey  
                       FROM #TEMP_PICKHEADER a  
                       JOIN dbo.PICKDETAIL b(NOLOCK) ON a.Orderkey=b.Orderkey  
                      WHERE ISNULL(b.PickslipNo,'')=''  
                  )  
         ) X  
         WHERE X.SeqNo=1  
      ) X ON PD.Orderkey = X.Orderkey  
      WHERE ISNULL(PD.PickslipNo,'')=''  
        AND PD.Status<'9'  
   END  
  
   IF @c_Type = 'WP'  
   BEGIN  
      IF EXISTS(SELECT TOP 1 1 FROM dbo.WAVE (NOLOCK) WHERE Wavekey = @c_Key  
                AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%'))  
      BEGIN  
         UPDATE dbo.WAVE WITH(ROWLOCK)  
            SET UserDefine04 = RTRIM(REPLACE(REPLACE(UserDefine04, 'ReAssignPicker=', 'AssignPicker='), 'ReSplitLine=', 'SplitLine='))  
          WHERE Wavekey = @c_Key  
            AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%')  
      END  
   END  
   ELSE IF @c_Type = 'LP'  
   BEGIN  
      IF EXISTS(SELECT TOP 1 1 FROM dbo.LOADPLAN (NOLOCK) WHERE Loadkey = @c_Key  
                AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%'))  
      BEGIN  
         UPDATE dbo.LOADPLAN WITH(ROWLOCK)  
            SET UserDefine04 = RTRIM(REPLACE(REPLACE(UserDefine04, 'ReAssignPicker=', 'AssignPicker='), 'ReSplitLine=', 'SplitLine='))  
          WHERE Loadkey = @c_Key  
            AND (LTRIM(UserDefine04) LIKE 'ReAssignPicker=%' OR LTRIM(UserDefine04) LIKE 'ReSplitLine=%')  
      END  
   END  
  
  
   -- Get PickdetailKey for Final Result  
   TRUNCATE TABLE #TEMP_PICKDETAIL  
  
   IF @c_Type = 'WP'  
   BEGIN  
      INSERT INTO #TEMP_PICKDETAIL (PickdetailKey, PickslipNo, Storerkey)  
      SELECT PickdetailKey   = PD.PickdetailKey  
           , PickslipNo      = PD.PickslipNo  
           , Storerkey       = PD.Storerkey  
        FROM dbo.ORDERS OH(NOLOCK)  
        JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
       WHERE OH.Userdefine09 = @c_Key AND @c_Key<>'' AND PD.PickslipNo<>''  
   END  
   ELSE IF @c_Type = 'LP'  
   BEGIN  
      INSERT INTO #TEMP_PICKDETAIL (PickdetailKey, PickslipNo, Storerkey)  
      SELECT PickdetailKey   = PD.PickdetailKey  
           , PickslipNo      = PD.PickslipNo  
           , Storerkey       = PD.Storerkey  
        FROM dbo.ORDERS OH(NOLOCK)  
        JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
       WHERE OH.Loadkey = @c_Key AND @c_Key<>'' AND PD.PickslipNo<>''  
   END  
  
  
   -- Storerkey Loop  
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey  
     FROM #TEMP_PICKDETAIL  
    ORDER BY 1  
  
   OPEN C_CUR_STORERKEY  
  
   WHILE 1=1  
   BEGIN  
      FETCH NEXT FROM C_CUR_STORERKEY  
       INTO @c_Storerkey  
  
      IF @@FETCH_STATUS<>0  
         BREAK  
  
      SELECT @c_JoinClause         = ''  
           , @c_ReserveLoc_Cond    = ''  
           , @c_ShowFields         = ''  
           , @c_CustGrpCodeExp     = ''  
           , @c_ShipToAddressExp   = ''  
           , @c_NotesExp           = ''  
           , @c_DivExp             = ''  
           , @c_BrandExp           = ''  
           , @c_Userdefine05Exp    = ''  
           , @c_DropIDExp          = ''  
           , @c_DeliveryDateExp    = ''  
           , @c_OrderTypeExp       = ''  
           , @c_RouteExp           = ''  
           , @c_ToteCBMExp         = ''  
           , @c_Notes2Exp          = ''  
           , @c_IndicatorExp       = ''  
  
      SELECT TOP 1  
             @c_JoinClause = Notes  
        FROM dbo.CodeLkup (NOLOCK)  
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'  
         AND Storerkey = @c_Storerkey  
       ORDER BY Code2  
  
      SELECT TOP 1  
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))  
      FROM dbo.CODELKUP (NOLOCK)  
      WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'  
         AND Storerkey = @c_Storerkey  
       ORDER BY Code2  
  
  
      SELECT TOP 1  
             @c_ReserveLoc_Cond = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='ReserveLoc_Cond')), '' )  
           , @c_CustGrpCodeExp  = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='CustomerGroupCode')), '' )  
           , @c_ShipToAddressExp= ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='ShipToAddress')), '' )  
           , @c_NotesExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Notes')), '' )  
           , @c_DivExp          = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Div')), '' )  
           , @c_BrandExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Brand')), '' )  
           , @c_Userdefine05Exp = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Userdefine05')), '' )  
           , @c_DropIDExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='DropID')), '' )  
           , @c_DeliveryDateExp = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )  
           , @c_OrderTypeExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='OrderType')), '' )  
           , @c_RouteExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )  
           , @c_ToteCBMExp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='ToteCBM')), '' )  
           , @c_Notes2Exp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Notes2')), '' )  
           , @c_IndicatorExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Indicator')), '' )  
                                    
        FROM dbo.CODELKUP (NOLOCK)  
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'  
         AND Storerkey = @c_Storerkey  
       ORDER BY Code2  
  
  
      SET @c_ExecStatements =  
        N'INSERT INTO #TEMP_PIKDT ('  
        +    ' PickSlipNo, Storerkey, Orderkey, ExternOrderKey, Status, LoadKey, WaveKey, DeliveryDate, Type'  
        +   ', Notes2, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City, C_Country, Route'  
        +   ', AllocQty, CBM, Sku, ToLoc, Loc, Lot, ID, PickdetailKey, ToteCBM, IsConsol, HasReplen'  
        +   ', PrintedFlag, LocationCategory, PD_DropID, PD_PickslipNo, Picker'  
        +   ', ShowFields, CustomerGroupCode, Notes, Div, Brand, Userdefine05, DropID, ShipToAddress, Indicator)'  
  
      SET @c_ExecStatements = @c_ExecStatements  
        + ' SELECT PickslipNo        = RTRIM( PH.PickslipNo )'  
        +       ', Storerkey         = RTRIM( PH.Storerkey )'  
        +       ', Orderkey          = RTRIM( IIF(PH.IsConsol=''Y'', '''', OH.Orderkey) )'  
        +       ', ExternOrderkey    = RTRIM( IIF(PH.IsConsol=''Y'', '''', OH.ExternOrderkey) )'  
        +       ', Status            = RTRIM( OH.Status )'  
        +       ', Loadkey           = RTRIM( IIF(PH.IsConsol=''Y'', OH.Loadkey, ''''))'  
        +       ', Wavekey           = RTRIM( IIF(PH.IsConsol=''Y'', '''', OH.Userdefine09) )'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', DeliveryDate      = '              + CASE WHEN ISNULL(@c_DeliveryDateExp ,'')<>'' THEN @c_DeliveryDateExp  ELSE 'CONVERT(DATETIME, CONVERT(VARCHAR(10),OH.DeliveryDate,120))' END  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Type              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderTypeExp    ,'')<>'' THEN @c_OrderTypeExp     ELSE 'OH.Type'   END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Notes2            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes2Exp       ,'')<>'' THEN @c_Notes2Exp        ELSE 'OH.Notes2' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', C_Company         = ISNULL(RTRIM( OH.C_Company), '''')'  
        +       ', C_Address1        = ISNULL(RTRIM( OH.C_Address1), '''')'  
        +       ', C_Address2        = ISNULL(RTRIM( OH.C_Address2), '''')'  
        +       ', C_Address3        = ISNULL(RTRIM( OH.C_Address3), '''')'  
        +       ', C_Address4        = ISNULL(RTRIM( OH.C_Address4), '''')'  
        +       ', C_City            = ISNULL(RTRIM( OH.C_City), '''')'  
        +       ', C_Country         = ISNULL(RTRIM( OH.C_Country), '''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Route             = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp        ,'')<>'' THEN @c_RouteExp         ELSE 'OH.Route'  END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', AllocQty          = PD.Qty'  
        +       ', CBM               = PD.Qty * SKU.StdCube'  
        +       ', Sku               = ISNULL(RTRIM( PD.Sku), '''')'  
        +       ', ToLoc             = ISNULL(RTRIM( PD.ToLoc), '''')'  
        +       ', Loc               = ISNULL(RTRIM( PD.Loc), '''')'  
        +       ', Lot               = ISNULL(RTRIM( PD.Lot), '''')'  
        +       ', ID                = ISNULL(RTRIM( PD.ID), '''')'  
        +       ', PickdetailKey     = ISNULL(RTRIM( PD.PickdetailKey), '''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', ToteCBM           = '              + CASE WHEN ISNULL(@c_ToteCBMExp      ,'')<>'' THEN @c_ToteCBMExp       ELSE  
                                      'CASE WHEN ISNULL(TRY_PARSE(ISNULL(CBM.Long,'''') AS FLOAT),0.0)=0.0 OR ISNULL(TRY_PARSE(ISNULL(RTO.Long,'''') AS FLOAT),0.0)=0.0 THEN 0.0'  
        +                                 ' ELSE ISNULL(TRY_PARSE(ISNULL(CBM.Long,'''') AS FLOAT),0.0) / ISNULL(TRY_PARSE(ISNULL(RTO.Long,'''') AS FLOAT),0.0)'  
        +                                 ' END' END  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', IsConsol          = PH.IsConsol'  
        +       ', HasReplen         = IIF((' + CASE WHEN ISNULL(@c_ReserveLoc_Cond,'')<>'' THEN @c_ReserveLoc_Cond ELSE 'LOC.LocationCategory=''SELECTIVE''' END + '),''Y'',''N'')'  
        +       ', PrintedFlag       = RTRIM( PH.PrintedFlag )'  
        +       ', LocationCategory  = ISNULL(RTRIM( LOC.LocationCategory), '''')'  
        +       ', PD_DropID         = ISNULL(RTRIM( PD.DropID), '''')'  
        +       ', PD_PickslipNo     = ISNULL(RTRIM( ISNULL(TPD.PickslipNo, PH.PickslipNo)), '''')'  
        +       ', Picker            = RTRIM( IIF( PD.AltSku LIKE ''Picker-%'', PD.AltSku, ''''))'  
        +       ', ShowFields        = ISNULL(@c_ShowFields,'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', CustomerGroupCode = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CustGrpCodeExp  ,'')<>'' THEN @c_CustGrpCodeExp   ELSE 'ST.CustomerGroupCode' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Notes             = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_NotesExp        ,'')<>'' THEN @c_NotesExp         ELSE 'OH.Notes'  END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Div               = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DivExp          ,'')<>'' THEN @c_DivExp           ELSE ''''''      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Brand             = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BrandExp        ,'')<>'' THEN @c_BrandExp         ELSE ''''''      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Userdefine05      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Userdefine05Exp ,'')<>'' THEN @c_Userdefine05Exp  ELSE ''''''      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', DropID            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DropIDExp       ,'')<>'' THEN @c_DropIDExp        ELSE 'IIF(PH.IsConsol=''Y'','''',''ID''+OH.Orderkey+''001'')' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', ShipToAddress     = RTRIM('        + CASE WHEN ISNULL(@c_ShipToAddressExp,'')<>'' THEN @c_ShipToAddressExp ELSE 'NULL'      END + ')'  
      SET @c_ExecStatements = @c_ExecStatements  
        +       ', Indicator         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_IndicatorExp    ,'')<>'' THEN @c_IndicatorExp     ELSE 'NULL'      END + '),'''')'  
  
      SET @c_ExecStatements = @c_ExecStatements  
        +   ' FROM #TEMP_PICKHEADER  PH'  
        +   ' JOIN dbo.ORDERS        OH (NOLOCK) ON PH.FOK=OH.Orderkey'  
        +   ' JOIN dbo.STORER        ST (NOLOCK) ON PH.Storerkey=ST.Storerkey'  
        +   ' JOIN dbo.PICKDETAIL    PD (NOLOCK) ON PH.Orderkey=PD.Orderkey'  
        +   ' JOIN dbo.LOC           LOC(NOLOCK) ON PD.Loc=LOC.Loc'  
        +   ' JOIN dbo.SKU           SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku'  
        +   ' LEFT JOIN #TEMP_PICKDETAIL TPD     ON PD.PickDetailKey=TPD.PickdetailKey'  
        +   ' LEFT JOIN dbo.CODELKUP CBM(NOLOCK) ON CBM.LISTNAME=''ToteCBM'' AND CBM.Storerkey=PH.Storerkey'  
        +   ' LEFT JOIN dbo.CODELKUP RTO(NOLOCK) ON RTO.LISTNAME=''Ratio'' AND RTO.Storerkey=PH.Storerkey'  
      SET @c_ExecStatements = @c_ExecStatements  
        +   CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END  
  
      SET @c_ExecStatements = @c_ExecStatements  
        +  ' WHERE PD.Qty > 0'  
        +    ' AND ((ISNULL(@c_ShowFields,'''') LIKE ''%,AllowUserChangePickMethod,%'' AND ISNULL(PH.Userdefine03,'''')=''RDT'')'  
        +      ' OR (ISNULL(@c_ShowFields,'''') LIKE ''%,DefaultRDTPick,%'''  
        +       ' AND NOT (ISNULL(@c_ShowFields,'''') LIKE ''%,AllowUserChangePickMethod,%'' AND ISNULL(PH.Userdefine03,'''')=''PICKSLIP'')))'  
  
  
      SET @c_ExecArguments = N'@c_ShowFields  NVARCHAR(MAX)'  
                           + ',@c_Storerkey   NVARCHAR(15)'  
                           + ',@c_Type        NVARCHAR(2)'  
                           + ',@c_DataWindow  NVARCHAR(40)'  
  
      EXEC sp_ExecuteSql @c_ExecStatements  
                       , @c_ExecArguments  
                       , @c_ShowFields  
                       , @c_Storerkey  
                       , @c_Type  
                       , @c_DataWindow  
   END  
   CLOSE C_CUR_STORERKEY  
   DEALLOCATE C_CUR_STORERKEY  
  
  
   -- Final Result  
   SELECT PickslipNo        = X.PickslipNo  
        , CustomerGroupCode = MAX( X.CustomerGroupCode )  
        , Orderkey          = MAX( X.Orderkey )  
        , ExternOrderkey    = MAX( X.ExternOrderkey )  
        , Status            = MAX( X.Status )  
        , Loadkey           = MAX( X.Loadkey )  
        , Wavekey           = MAX( X.Wavekey )  
        , DeliveryDate      = MAX( X.DeliveryDate )  
        , Type              = MAX( X.Type )  
        , Notes             = MAX( X.Notes )  
        , Notes2            = MAX( X.Notes2 )  
        , Userdefine05      = MAX( X.Userdefine05 )  
        , C_Company         = MAX( X.C_Company )  
        , C_Address1        = MAX( X.C_Address1 )  
        , C_Address2        = MAX( X.C_Address2 )  
        , C_Address3        = MAX( X.C_Address3 )  
        , C_Address4        = MAX( X.C_Address4 )  
        , Route             = MAX( X.Route )  
        , AllocQty          = SUM( X.AllocQty )  
        , CBM               = SUM( X.CBM )  
        , SkuCount          = COUNT( DISTINCT X.Sku )  
        , LocCount          = COUNT( DISTINCT IIF(X.ToLoc<>'', X.ToLoc, X.Loc) )  
        , PickDetailCount   = COUNT( DISTINCT IIF(X.IsConsol='Y', RTRIM(X.Lot)+'|'+RTRIM(X.Loc)+'|'+RTRIM(X.ID), X.PickdetailKey ) )  
        , NoOfTotes         = CASE WHEN MAX(X.ToteCBM) = 0.0 THEN 0.0 ELSE CEILING(SUM( X.CBM ) / MAX(X.ToteCBM)) END  
        , IsConsol          = MAX( X.IsConsol )  
        , HasReplen         = MAX( X.HasReplen )  
, KeyType           = @c_Type  
        , datawindow        = @c_DataWindow  
        , Div               = MAX( X.Div )  
        , Brand             = MAX( X.Brand )  
        , PrintedFlag       = MAX( X.PrintedFlag )  
        , PickZones         = CAST( CASE MAX( X.IsConsol )  
                              WHEN 'N' THEN  
                                 STUFF((SELECT ', ', ISNULL(RTRIM(Y.PickZone),''), RTRIM(Y.Replen)  
                                 FROM (  
                                    SELECT PickZone = CASE WHEN X.ShowFields LIKE '%,showputawayzone,%' THEN IIF(c.ToLoc<>'',e.PutawayZone,d.PutawayZone)  
                                                                                                        ELSE IIF(c.ToLoc<>'',e.PickZone,d.PickZone) END  
                                         , Replen   = IIF(ISNULL(MAX(c.ToLoc),'')<>'', IIF(ISNULL(MIN(c.ToLoc),'')=ISNULL(MAX(c.ToLoc),''), N'Γûá',N'Γû╝'),'')  
                                    FROM PICKHEADER      a(NOLOCK)  
                                    LEFT JOIN PICKDETAIL c(NOLOCK) ON a.Orderkey=c.Orderkey  
                                    LEFT JOIN LOC        d(NOLOCK) ON c.Loc=d.Loc  
                                    LEFT JOIN LOC        e(NOLOCK) ON c.ToLoc=e.Loc AND c.ToLoc<>''  
                                    WHERE c.PickslipNo = X.PD_PickslipNo AND c.Qty>0  
                                    GROUP BY CASE WHEN X.ShowFields LIKE '%,showputawayzone,%' THEN IIF(c.ToLoc<>'',e.PutawayZone,d.PutawayZone)  
                                                                                               ELSE IIF(c.ToLoc<>'',e.PickZone,d.PickZone) END  
                                 ) Y  
                                 WHERE Y.PickZone<>''  
                                 ORDER BY IIF(Y.Replen=N'Γûá',3,IIF(Y.Replen=N'Γû╝',2,1)), 2  
                                 FOR XML PATH('')), 1, 2, '')  
                              WHEN 'Y' THEN  
                                 STUFF((SELECT ', ', ISNULL(RTRIM(Y.PickZone),''), RTRIM(Y.Replen)  
                                 FROM (  
                                    SELECT PickZone = CASE WHEN X.ShowFields LIKE '%,showputawayzone,%' THEN IIF(c.ToLoc<>'',e.PutawayZone,d.PutawayZone)  
                                                                                                        ELSE IIF(c.ToLoc<>'',e.PickZone,d.PickZone) END  
                                         , Replen   = IIF(ISNULL(MAX(c.ToLoc),'')<>'', IIF(ISNULL(MIN(c.ToLoc),'')=ISNULL(MAX(c.ToLoc),''), N'Γûá',N'Γû╝'),'')  
                                    FROM PICKHEADER      a(NOLOCK)  
                                    LEFT JOIN ORDERS     b(NOLOCK) ON a.ExternOrderkey=b.Loadkey AND ISNULL(a.Orderkey,'')=''  
                                    LEFT JOIN PICKDETAIL c(NOLOCK) ON b.Orderkey=c.Orderkey  
                                    LEFT JOIN LOC        d(NOLOCK) ON c.Loc=d.Loc  
                                    LEFT JOIN LOC        e(NOLOCK) ON c.ToLoc=e.Loc AND c.ToLoc<>''  
                                    WHERE c.PickslipNo = X.PD_PickslipNo AND c.Qty>0  
                                    GROUP BY CASE WHEN X.ShowFields LIKE '%,showputawayzone,%' THEN IIF(c.ToLoc<>'',e.PutawayZone,d.PutawayZone)  
                                                                                               ELSE IIF(c.ToLoc<>'',e.PickZone,d.PickZone) END  
                                 ) Y  
                                 WHERE Y.PickZone<>''  
                                 ORDER BY IIF(Y.Replen=N'Γûá',3,IIF(Y.Replen=N'Γû╝',2,1)), 2  
                                 FOR XML PATH('')), 1, 2, '')  
                              END AS NVARCHAR(4000))  
        , ReplenCount       = COUNT(DISTINCT CASE WHEN X.HasReplen='Y' THEN X.PD_DropID END)  
        , PD_PickslipNo     = UPPER( X.PD_PickslipNo )  
        , Picker            = X.Picker  
        , PTL_TaskCount     = COUNT( DISTINCT RTRIM(X.Loc) +'|'+ RTRIM(X.Sku) )  
        , PickSlip_SeqNo    = ROW_NUMBER() OVER(PARTITION BY X.PickslipNo ORDER BY PD_PickslipNo )  
        , PickSlip_Count    = COUNT(1)     OVER(PARTITION BY X.PickslipNo)  
        , ShowFields        = MAX( X.ShowFields )  
        , C_City            = MAX( X.C_City )  
        , C_Country         = MAX( X.C_Country )  
        , ShipToAddress     = MAX( X.ShipToAddress )  
        , DropID            = MAX( X.DropID )  
        , Lbl_Notes_1       = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Notes_1') ) AS NVARCHAR(500))  
        , Lbl_Notes_2       = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Notes_2') ) AS NVARCHAR(500))  
        , Lbl_Userdefine05_1= CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Userdefine05_1') ) AS NVARCHAR(500))  
        , Lbl_Userdefine05_2= CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Userdefine05_2') ) AS NVARCHAR(500))  
        , Lbl_DeliveryDate_1= CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate_1') ) AS NVARCHAR(500))  
        , Lbl_DeliveryDate_2= CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate_2') ) AS NVARCHAR(500))  
        , Lbl_OrderType_1   = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_OrderType_1') ) AS NVARCHAR(500))  
        , Lbl_OrderType_2   = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_OrderType_2') ) AS NVARCHAR(500))  
        , Lbl_Route_1       = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Route_1') ) AS NVARCHAR(500))  
        , Lbl_Route_2       = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Route_2') ) AS NVARCHAR(500))  
        , Lbl_Notes2_1      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Notes2_1') ) AS NVARCHAR(500))  
        , Lbl_Notes2_2      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Notes2_2') ) AS NVARCHAR(500))  
        , Lbl_ShipTo_1      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo_1') ) AS NVARCHAR(500))  
        , Lbl_ShipTo_2      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo_2') ) AS NVARCHAR(500))  
        , Lbl_DropID_1      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DropID_1') ) AS NVARCHAR(500))  
        , Lbl_DropID_2      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DropID_2') ) AS NVARCHAR(500))  
        , Indicator         = MAX( X.Indicator )  
  
   FROM #TEMP_PIKDT X  
  
   LEFT JOIN (  
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'  
   ) RptCfg3  
   ON RptCfg3.Storerkey=X.Storerkey AND RptCfg3.SeqNo=1  
  
   GROUP BY X.PickslipNo  
          , X.PD_PickslipNo  
          , X.Picker  
          , X.ShowFields  
  
   ORDER BY CustomerGroupCode, PickslipNo, PickSlip_SeqNo  
END  

GO