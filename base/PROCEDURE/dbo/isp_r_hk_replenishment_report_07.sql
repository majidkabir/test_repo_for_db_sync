SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_r_hk_replenishment_report_07                    */  
/* Creation Date: 26-Sep-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Michael Lam (HK LIT)                                      */  
/*                                                                       */  
/* Purpose: Wave Pickslip                                                */  
/*                                                                       */  
/* Called By: RCM - Generate Pickslip in Waveplan                        */  
/*            Datawidnow r_hk_replenishment_report_07 (WMS-6361)         */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 2019-04-04   ML       1.1  Jira WMS8570 - Add Brand code              */  
/* 2021-08-02   ML       1.2  WMS-17623 - Add Extend Validation          */  
/* 2021-09-02   ML       1.3  If Multi-Sku Carton Then ToZone = Residual */  
/* 2022-03-23   ML       1.4  Add NULL to Temp Table                     */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_r_hk_replenishment_report_07] (  
       @as_wavekey  NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_DataWindow        NVARCHAR(40)  = 'r_hk_replenishment_report_07'  
         , @n_StartTCnt         INT           = @@TRANCOUNT  
         , @c_Storerkey         NVARCHAR(15)  = (SELECT TOP 1 Storerkey FROM dbo.ORDERS (NOLOCK) WHERE Userdefine09<>'' AND Userdefine09=@as_wavekey ORDER BY Orderkey)  
         , @b_MultiOrderGroup   INT           = 0  
         , @b_InvalidOrderGroup INT           = 0  
         , @b_BlankLoadkey      INT           = 0  
         , @c_OrderGroup        NVARCHAR(60)  = ''  
         , @b_Success           INT           = 0  
         , @n_Err               INT           = 0  
         , @c_ErrMsg            NVARCHAR(500) = ''  
         , @c_ExtValidateExp    NVARCHAR(MAX) = ''  
         , @c_ExecStatements    NVARCHAR(MAX)  
         , @c_ExecArguments     NVARCHAR(MAX)  
  
   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL  
      DROP TABLE #TEMP_PICKDETAIL  
  
   CREATE TABLE #TEMP_PICKDETAIL (  
        Storerkey        NVARCHAR(15)  NULL  
      , Wavekey          NVARCHAR(10)  NULL  
      , PutawayZone      NVARCHAR(10)  NULL  
      , PA_Descr         NVARCHAR(60)  NULL  
      , LogicalLoc       NVARCHAR(18)  NULL  
      , Loc              NVARCHAR(10)  NULL  
      , ID               NVARCHAR(18)  NULL  
      , Sku              NVARCHAR(20)  NULL  
      , Sku_Descr        NVARCHAR(60)  NULL  
      , Qty              INT           NULL  
      , PikDetUOM        NVARCHAR(10)  NULL  
      , ToZone           NVARCHAR(60)  NULL  
      , Remarks          NVARCHAR(200) NULL  
      , ErrMsg           NVARCHAR(500) NULL  
      , Brand            NVARCHAR(60)  NULL  
   )  
  
   IF ISNULL(@as_wavekey,'')=''  
   BEGIN  
      SET @c_ErrMsg = 'Wavekey is Blank'  
      GOTO REPORT  
   END  
  
  
   SELECT TOP 1  
          @b_MultiOrderGroup   = CASE WHEN COUNT(DISTINCT X.OrderGroup) > 1 THEN 1 ELSE 0 END  
        , @b_InvalidOrderGroup = MAX(IIF(X.OrderGroup IN ('C','D'), 0, 1))  
        , @b_BlankLoadkey      = MAX(X.BlankLoadKey)  
        , @c_OrderGroup        = MAX(X.OrderGroup)  
   FROM (  
      SELECT DISTINCT  
             Wavekey      = ISNULL(a.Userdefine09,'')  
           , OrderGroup   = CASE WHEN a.OrderGroup='W' AND ISNULL(a.DeliveryNote,'') NOT IN ( '','NA') THEN a.DeliveryNote ELSE b.UDF02 END    --D=Discrete C=Consolidate  
           , BlankLoadKey = IIF(ISNULL(a.Loadkey,'')='', 1, 0)  
        FROM dbo.ORDERS   a(NOLOCK)  
        JOIN dbo.CODELKUP b(NOLOCK) ON a.OrderGroup = b.Code AND a.Storerkey = b.Storerkey AND b.Listname = 'ORDERGROUP'  
   ) X  
   WHERE X.Wavekey = @as_wavekey  
   GROUP BY X.Wavekey  
  
  
   IF ISNULL(@b_MultiOrderGroup, 0) <> 0  
      SET @c_ErrMsg += IIF(@c_ErrMsg<>'',', ', '') + 'Multiple OrderGroup Found'  
  
   IF ISNULL(@b_InvalidOrderGroup, 0) <> 0  
      SET @c_ErrMsg += IIF(@c_ErrMsg<>'',', ', '') + 'Invalid OrderGroup Found'  
  
   IF ISNULL(@b_BlankLoadkey, 0) <> 0  
      SET @c_ErrMsg += IIF(@c_ErrMsg<>'',', ', '') + 'Blank Loadkey Found'  
  
   IF ISNULL(@c_ErrMsg,'')<>''  
      GOTO REPORT  
  
  
   SELECT TOP 1  
          @c_ExtValidateExp =  Notes  
     FROM dbo.CodeLkup (NOLOCK)  
    WHERE Listname='REPORTCFG' AND Code='SQLCHECK' AND Long=@c_DataWindow AND Short='Y'  
      AND Storerkey = @c_Storerkey  
    ORDER BY Code2  
  
   IF ISNULL(@c_ExtValidateExp,'')<>''  
   BEGIN  
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PICKDETAIL (ErrMsg) ' + @c_ExtValidateExp  
      SET @c_ExecArguments  = N'@as_wavekey NVARCHAR(10)'  
  
      EXEC sp_ExecuteSql @c_ExecStatements  
                       , @c_ExecArguments  
                       , @as_wavekey  
  
      IF @@ROWCOUNT>0  
      BEGIN  
         UPDATE #TEMP_PICKDETAIL  
            SET Storerkey   = @c_Storerkey  
              , Wavekey     = @as_wavekey  
              , PutawayZone = ''  
              , PA_Descr    = ''  
              , LogicalLoc  = ''  
              , Loc         = ''  
              , ID          = ''  
              , Sku         = ''  
              , Sku_Descr   = ''  
              , Qty         = 0  
              , PikDetUOM   = ''  
              , ToZone      = ''  
              , Remarks     = ''  
              , Brand       = ''  
         GOTO REPORT  
      END  
   END  
  
  
   IF ISNULL(@c_OrderGroup,'') = 'D' --create discrete pickslip for the wave  
   BEGIN  
      EXEC isp_CreatePickSlip  
           @c_Wavekey            = @as_wavekey  
         , @c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno  
         , @b_Success            = @b_Success OUTPUT  
         , @n_Err                = @n_Err     OUTPUT  
         , @c_ErrMsg             = @c_ErrMsg  OUTPUT  
  
      IF @b_Success = 0  
      BEGIN  
         SET @c_ErrMsg = 'Get Discrete PickslipNo Error: ' + ISNULL(@c_ErrMsg,'')  
         GOTO REPORT  
      END  
   END  
   ELSE  
   BEGIN --create load conso pickslip for the wave  
      EXEC isp_CreatePickSlip  
           @c_Wavekey            = @as_wavekey  
         , @c_ConsolidateByLoad  = 'Y'  --Y=Create load consolidate pickslip  
         , @c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno  
         , @b_Success            = @b_Success OUTPUT  
         , @n_Err                = @n_Err     OUTPUT  
         , @c_ErrMsg             = @c_ErrMsg  OUTPUT  
  
      IF @b_Success = 0  
      BEGIN  
         SET @c_ErrMsg = 'Get Conso PickslipNo Error: ' + ISNULL(@c_ErrMsg,'')  
         GOTO REPORT  
      END  
   END  
  
   INSERT INTO #TEMP_PICKDETAIL (  
          Storerkey, Wavekey, PutawayZone, PA_Descr, LogicalLoc, Loc, ID,  
          Sku, Sku_Descr, Qty, PikDetUOM, ToZone, Remarks, ErrMsg, Brand)  
   SELECT X.Storerkey, X.Wavekey, X.PutawayZone, X.PA_Descr, X.LogicalLoc, X.Loc,  
          X.ID, X.Sku, X.Sku_Descr, SUM(X.Qty), X.PikDetUOM, X.ToZone, X.Remarks, '', MAX(X.Brand)  
   FROM (  
      SELECT Storerkey   = RTRIM( OH.Storerkey )  
           , Wavekey     = RTRIM( OH.Userdefine09 )  
           , PutawayZone = RTRIM( LOC.PutawayZone )  
           , PA_Descr    = RTRIM( PA.Descr )  
           , LogicalLoc  = RTRIM( LOC.LogicalLocation )  
           , Loc         = RTRIM( PD.Loc )  
           , ID          = RTRIM( PD.ID )  
           , Sku         = RTRIM( PD.Sku )  
           , Sku_Descr   = RTRIM( SKU.Descr )  
           , Qty         = PD.Qty  
           , PikDetUOM   = RTRIM( PD.UOM )  
           , ToZone      = CASE WHEN (SELECT COUNT(DISTINCT Sku) FROM dbo.LOTxLOCxID a(NOLOCK)  
                                      WHERE a.Storerkey=PD.Storerkey AND a.ID=PD.ID AND a.ID<>'' AND a.Qty>0) > 1    -- Multi Sku Carton  
                                THEN 'Residual'  
                                WHEN PD.UOM='2' THEN 'FCP'  
                                WHEN PD.UOM IN ('6', '7') THEN  
                                   CASE WHEN  
                                     (SELECT SUM(b.Qty) FROM dbo.ORDERS a(NOLOCK), dbo.PICKDETAIL b(NOLOCK)  
                                         WHERE a.Orderkey=b.Orderkey AND b.Status<>'9'  
                                           AND a.Storerkey=OH.Storerkey AND a.Userdefine09=OH.Userdefine09  
                                           AND b.ID=PD.ID AND b.Sku=PD.Sku AND b.Loc=PD.Loc AND b.Lot=PD.Lot) =  
                                     (SELECT SUM(a.Qty) FROM dbo.LOTxLOCxID a(NOLOCK)  
                                         WHERE a.Storerkey=OH.Storerkey  
                                           AND a.ID=PD.ID AND a.Sku=PD.Sku AND a.Loc=PD.Loc AND a.Lot=PD.Lot)  
                                        THEN 'DP'  
                                     ELSE 'Residual'  
                                END  
                           END  
           , Remarks     = CAST(STUFF((SELECT DISTINCT ', ', RTRIM(a.Userdefine09) FROM dbo.ORDERS a(NOLOCK), dbo.PICKDETAIL b(NOLOCK)  
                           WHERE a.Orderkey=b.Orderkey AND a.Userdefine09<>'' AND b.ID<>'' AND a.Userdefine09<>OH.Userdefine09 AND b.ID=PD.ID  
                           FOR XML PATH('')),1,2,'') AS NVARCHAR(200))  
           , Brand       = RTRIM( LEFT(DIV.UDF01, 3) )  
      FROM dbo.ORDERS      OH(NOLOCK)  
      JOIN dbo.PICKDETAIL  PD(NOLOCK) ON OH.Orderkey=PD.Orderkey  
      JOIN dbo.SKU        SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku  
      JOIN dbo.LOC        LOC(NOLOCK) ON PD.Loc=LOC.Loc  
      JOIN dbo.PUTAWAYZONE PA(NOLOCK) ON LOC.PutawayZone=PA.PutawayZone  
      LEFT JOIN dbo.CODELKUP DIV(NOLOCK) ON DIV.Listname='PVHDIV' AND DIV.Storerkey=SKU.Storerkey AND DIV.Code = SKU.BUSR5  
      WHERE OH.Userdefine09<>''  
        AND OH.Userdefine09=@as_wavekey  
        AND LOC.LocationType = 'OTHER'  
   ) X  
   GROUP BY X.Storerkey, X.Wavekey, X.PutawayZone, X.LogicalLoc,  
          X.PA_Descr, X.Loc, X.ID, X.Sku, X.Sku_Descr, X.PikDetUOM,  
          X.ToZone, X.Remarks  
  
  
REPORT:  
   IF ISNULL(@c_ErrMsg,'')<>''  
   BEGIN  
      TRUNCATE TABLE #TEMP_PICKDETAIL  
      INSERT INTO #TEMP_PICKDETAIL (  
             Storerkey, Wavekey, PutawayZone, PA_Descr, LogicalLoc, Loc, ID, Sku, Sku_Descr, Qty, PikDetUOM, ToZone, Remarks, ErrMsg, Brand)  
      VALUES(@c_Storerkey, @as_wavekey, '', '', '', '', '', '', '', 0, '', '', '', @c_ErrMsg, '')  
   END  
   ELSE IF NOT EXISTS(SELECT TOP 1 1 FROM #TEMP_PICKDETAIL)  
   BEGIN  
      INSERT INTO #TEMP_PICKDETAIL (  
             Storerkey, Wavekey, PutawayZone, PA_Descr, LogicalLoc, Loc, ID, Sku, Sku_Descr, Qty, PikDetUOM, ToZone, Remarks, ErrMsg, Brand)  
      VALUES(@c_Storerkey, @as_wavekey, '', '', '', '', '', '', '', 0, '', '', '', 'No Replenishment Record', '')  
   END  
  
  
   SELECT Storerkey, Wavekey, PutawayZone, PA_Descr, LogicalLoc  
        , Loc, ID, Sku, Sku_Descr, Qty, PikDetUOM  
        , ToZone, Remarks, ErrMsg  
        , DWName = @c_DataWindow  
        , Brand  
     FROM #TEMP_PICKDETAIL  
    ORDER BY Wavekey, PutawayZone, LogicalLoc, Loc, ID, Sku  
  
   WHILE @@TRANCOUNT > @n_StartTCnt  
   BEGIN  
      COMMIT TRAN  
   END  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
     BEGIN TRAN  
   END  
END  

GO