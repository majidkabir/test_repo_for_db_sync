SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_023                           */  
/* Creation Date: 25-Apr-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-22364 - [CN] Logitech_Pickslip_Report                    */  
/*                                                                       */  
/* Called By: RPT_WV_PLIST_WAVE_023                                      */  
/*                                                                       */  
/* GitLab Version: 1.2                                                   */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author  Ver   Purposes                                    */  
/* 25-Apr-2023 WLChooi 1.0   DevOps Combine Script                       */  
/* 26-May-2023 WLChooi 1.1   WMS-22364 - Show TotalQty & Ctn (WL01)      */  
/* 21-Jun-2023 WLChooi 1.2   WMS-22364 - Remove Externorderkey (WL02)    */  
/*************************************************************************/  
  
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_023]  
(  
   @c_Wavekey       NVARCHAR(10)  
 , @c_PreGenRptData NVARCHAR(10) = ''  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue      INT           = 1  
         , @n_starttcnt     INT  
         , @b_Success       INT           = 1  
         , @b_debug         INT           = 0  
         , @c_Prefix        NVARCHAR(100) = N''  
         , @c_DropID        NVARCHAR(100) = N''  
         , @c_GetDropID     NVARCHAR(100) = N''   --WL01  
         , @c_errmsg        NVARCHAR(255) = N''  
         , @n_err           INT  
         , @c_Pickdetailkey NVARCHAR(10)  
         , @c_Storerkey     NVARCHAR(15)  
         , @c_Facility      NVARCHAR(5)  
  
   SELECT @n_starttcnt = @@TRANCOUNT  
   SET @c_PreGenRptData = IIF(ISNULL(@c_PreGenRptData, '') IN ( '', '0' ), '', @c_PreGenRptData)  
  
   SELECT @c_Storerkey = ORDERS.Storerkey  
        , @c_Facility  = ORDERS.Facility  
   FROM WAVEDETAIL (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey  
   WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
  
   IF @c_PreGenRptData = 'Y'  
   BEGIN  
      SELECT @c_Prefix = ISNULL(CL.Long, '')  
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.LISTNAME = 'LOGIDROPID' AND CL.Storerkey = @c_Storerkey AND CL.code2 = @c_Facility  
  
      IF ISNULL(@c_Prefix, '') = ''  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)  
              , @n_err = 60090  
         SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)  
                            + N': DropID prefix not set up (Codelkup.Listname = LOGIDROPID). (isp_RPT_WV_PLIST_WAVE_023)'  
                            + N' ( ' + N' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + N' ) '  
         GOTO QUIT_SP  
      END  
  
      IF ISNULL(@c_Wavekey, '') = ''  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)  
              , @n_err = 60090  
         SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)  
                            + N': Wavekey is blank! (isp_RPT_WV_PLIST_WAVE_023)'  
                            + N' ( ' + N' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + N' ) '  
         GOTO QUIT_SP  
      END  
  
      SET @c_DropID = TRIM(@c_Prefix) + RIGHT(CONVERT(NVARCHAR(8), GETDATE(), 112), 4) + TRIM(@c_Wavekey)  
  
      --Update Pickdetail.Status to 5 and Generate DropID  
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.PickDetailKey, PD.DropID   --WL01  
      FROM PICKDETAIL PD (NOLOCK)  
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey  
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey  
      WHERE WD.WaveKey = @c_Wavekey  
  
      OPEN CUR_PD  
  
      FETCH NEXT FROM CUR_PD  
      INTO @c_Pickdetailkey, @c_GetDropID   --WL01  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         --WL01 S  
         IF ISNULL(@c_GetDropID,'') = ''  
         BEGIN  
            UPDATE PICKDETAIL  
            SET DropID = @c_DropID  
            , WaveKey = CASE WHEN ISNULL(WaveKey,'') <> '' THEN WaveKey  
                              ELSE @c_Wavekey END  
            , [Status] = CASE WHEN [Status] = '5' THEN [Status]  
                              ELSE '5' END  
            WHERE PickDetailKey = @c_Pickdetailkey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)  
                  , @n_err = 60091  
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)  
                                 + N': Update Pickdetail Failed! (isp_RPT_WV_PLIST_WAVE_023)' + N' ( '  
                                 + N' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + N' ) '  
               GOTO QUIT_SP  
            END  
         END  
         --WL01 E  
  
         FETCH NEXT FROM CUR_PD  
         INTO @c_Pickdetailkey, @c_GetDropID   --WL01  
      END  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
   END  
  
   QUIT_SP:  
   IF @c_PreGenRptData = ''  
   BEGIN  
      --WL01 S  
      CREATE TABLE #TMP_DET (  
            RowID             INT NOT NULL IDENTITY(1,1) PRIMARY KEY  
          , UserDefine09      NVARCHAR(10)  NULL  
          , ExternOrderKey    NVARCHAR(100) NULL  
          , Sku               NVARCHAR(20)  NULL  
          , Loc               NVARCHAR(10)  NULL  
          , Lottable08        NVARCHAR(100) NULL  
          , DropID            NVARCHAR(100) NULL  
          , CaseCnt           FLOAT         NULL  
          , Qty               INT           NULL  
          , CTN               FLOAT         NULL  
          , C_Company         NVARCHAR(100) NULL  
          , ConsigneeKey      NVARCHAR(100) NULL  
          , C_Country         NVARCHAR(100) NULL  
          , C_Address4        NVARCHAR(100) NULL  
          , Method            NVARCHAR(100) NULL  
          , [Print]           NVARCHAR(100) NULL  
          , Pack              NVARCHAR(100) NULL  
          , Lottable05        DATETIME      NULL  
          , OVAS              NVARCHAR(100) NULL  
          , ID                NVARCHAR(100) NULL  
          , HL                NVARCHAR(100) NULL  
          , NOTES             NVARCHAR(100) NULL  
          , CTNAV             FLOAT         NULL  
          , PStation          NVARCHAR(100) NULL  
          , NoOfOrder         INT           NULL  
       )  
  
      ;WITH CTE AS (  
         SELECT OH.UserDefine09
              , '' AS ExternOrderKey -- , OH.ExternOrderKey   --WL02  
              , PD.Sku
              , CASE WHEN PD.Loc LIKE '%-%' THEN RIGHT(PD.Loc, 8)
                     WHEN PD.Loc NOT LIKE '%-%' THEN RIGHT(PD.Loc, 6)
                     ELSE PD.Loc END AS 'Loc'
              , LA.Lottable08
              , PD.DropID
              , P.CaseCnt
              , SUM(PD.Qty) AS Qty --WL01  
              , CASE WHEN ISNULL(P.CaseCnt, 0) = 0 THEN 0
                     ELSE SUM(PD.Qty / P.CaseCnt)END AS CTN --WL01  
              , OH.C_Company
              , OH.ConsigneeKey
              , OH.C_Country
              , OH.C_Address4
              , CASE WHEN OH.UserDefine03 = 'AIR OUT' THEN N'空运订单'
                     WHEN OH.UserDefine03 = 'EXPRESS' THEN N'UPS订单'
                     ELSE OH.UserDefine03 END AS 'Method'
              , CASE WHEN OH.UserDefine10 = 'DSN' THEN N'打印两张标签'
                     WHEN OH.UserDefine10 = 'PSN' THEN N'打印韩国二维码标'
                     WHEN OH.ConsigneeKey = '2108966' THEN N'不贴箱贴'
                     WHEN OH.ConsigneeKey = '7284034' THEN N'不贴箱贴'
                     ELSE N'正常标签' END AS 'Print'
              , CASE WHEN SUBSTRING(OH.C_Company, 1, 6) = 'INGRAM'
                     AND  OH.UserDefine03 = 'SEA OUT'
                     AND  OH.C_Address4 <> 'HONG KONG' THEN N'散装'
                     ELSE N'正常打托' END AS 'Pack'
              , LA.Lottable05
              , S.OVAS
              , PD.ID
              , CASE WHEN OH.UserDefine03 = 'AIR OUT' AND OH.ConsigneeKey <> '2070' THEN N'不超过1.55米'
                     WHEN OH.UserDefine03 = 'AIR OUT' AND OH.ConsigneeKey = '2070' THEN N'不超过1.4米'
                     WHEN OH.UserDefine03 = 'SCA' THEN N'不超过1.55米'
                     ELSE N' ' END AS 'HL'
              , CASE WHEN OH.StorerKey = 'LOGIEU' AND OH.UserDefine03 = 'TRUCK OUT' THEN N'盖顶,电池标签朝内'
                     ELSE N' ' END AS 'NOTES'
              , T1.CTNAV --WL02
              --  , CASE WHEN ISNULL(P.CaseCnt,0) = 0 THEN 0 ELSE SUM((ISNULL(LLI.Qty, 0) - ISNULL(LLI.QtyAllocated, 0) - ISNULL(LLI.QtyPicked, 0)) / P.CaseCnt) END AS 'CTNAV'   --WL01  
              , RIGHT(PD.DropID, 3) AS PStation
              , NoOfOrder = (  SELECT COUNT(DISTINCT WAVEDETAIL.OrderKey)
                               FROM WAVEDETAIL (NOLOCK)
                               WHERE WAVEDETAIL.WaveKey = WD.WaveKey)
              -- , OH.OrderKey   --WL02  
         FROM dbo.WAVEDETAIL WD (NOLOCK)
         JOIN dbo.ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
         JOIN dbo.PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
         JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot AND PD.Storerkey = LA.StorerKey AND PD.Sku = LA.Sku
         JOIN dbo.SKU S (NOLOCK) ON S.Sku = PD.Sku AND S.StorerKey = PD.Storerkey
         JOIN dbo.PACK P (NOLOCK) ON P.PackKey = S.PACKKey
         JOIN dbo.LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = PD.Loc AND LLI.Lot = PD.Lot AND PD.ID = LLI.Id
         JOIN (  SELECT LLI2.Sku   --WL02 S
                      , P.CaseCnt
                      , LLI2.Id
                      , LLI2.Loc
                      , CASE WHEN ISNULL(P.CaseCnt, 0) = 0 THEN 0
                             ELSE
                                SUM((ISNULL(LLI2.Qty, 0) - ISNULL(LLI2.QtyAllocated, 0) - ISNULL(LLI2.QtyPicked, 0)) / P.CaseCnt) END AS 'CTNAV'
                 FROM LOTxLOCxID (NOLOCK) LLI2
                 JOIN SKU (NOLOCK) SKU2 ON LLI2.Sku = SKU2.Sku AND LLI2.StorerKey = SKU2.StorerKey
                 JOIN PACK (NOLOCK) P ON SKU2.PACKKey = P.PackKey
                 WHERE LLI2.StorerKey = @c_Storerkey
                 GROUP BY LLI2.Sku
                        , P.CaseCnt
                        , LLI2.Loc
                        , LLI2.Id) T1 ON T1.Loc = LLI.Loc AND T1.Sku = LLI.Sku AND T1.Id = LLI.Id   --WL02 E
         WHERE WD.WaveKey = @c_Wavekey
         GROUP BY --WL01 S  
            OH.UserDefine09
          -- , OH.ExternOrderKey   --WL02
          , PD.Sku
          , CASE WHEN PD.Loc LIKE '%-%' THEN RIGHT(PD.Loc, 8)
                 WHEN PD.Loc NOT LIKE '%-%' THEN RIGHT(PD.Loc, 6)
                 ELSE PD.Loc END
          , LA.Lottable08
          , PD.DropID
          , P.CaseCnt
          , OH.C_Company
          , OH.ConsigneeKey
          , OH.C_Country
          , OH.C_Address4
          , CASE WHEN OH.UserDefine03 = 'AIR OUT' THEN N'空运订单'
                 WHEN OH.UserDefine03 = 'EXPRESS' THEN N'UPS订单'
                 ELSE OH.UserDefine03 END
          , CASE WHEN OH.UserDefine10 = 'DSN' THEN N'打印两张标签'
                 WHEN OH.UserDefine10 = 'PSN' THEN N'打印韩国二维码标'
                 WHEN OH.ConsigneeKey = '2108966' THEN N'不贴箱贴'
                 WHEN OH.ConsigneeKey = '7284034' THEN N'不贴箱贴'
                 ELSE N'正常标签' END
          , CASE WHEN SUBSTRING(OH.C_Company, 1, 6) = 'INGRAM' AND OH.UserDefine03 = 'SEA OUT' AND OH.C_Address4 <> 'HONG KONG' THEN
                    N'散装'
                 ELSE N'正常打托' END
          , LA.Lottable05
          , S.OVAS
          , PD.ID
          , CASE WHEN OH.UserDefine03 = 'AIR OUT' AND OH.ConsigneeKey <> '2070' THEN N'不超过1.55米'
                 WHEN OH.UserDefine03 = 'AIR OUT' AND OH.ConsigneeKey = '2070' THEN N'不超过1.4米'
                 WHEN OH.UserDefine03 = 'SCA' THEN N'不超过1.55米'
                 ELSE N' ' END
          , CASE WHEN OH.StorerKey = 'LOGIEU' AND OH.UserDefine03 = 'TRUCK OUT' THEN N'盖顶,电池标签朝内'
                 ELSE N' ' END
          , RIGHT(PD.DropID, 3)
          --  , OH.OrderKey   --WL02
          , WD.WaveKey
          , T1.CTNAV --WL02
     
      )   --WL01 E  
      INSERT INTO #TMP_DET (UserDefine09, ExternOrderKey, Sku, Loc, Lottable08, DropID, CaseCnt, Qty, CTN, C_Company  
                          , ConsigneeKey, C_Country, C_Address4, Method, [Print], Pack, Lottable05, OVAS, ID, HL, NOTES  
                          , CTNAV, PStation, NoOfOrder)  
      SELECT CTE.UserDefine09  
           , CTE.ExternOrderKey  
           , CTE.Sku  
           , CTE.Loc  
           , CTE.Lottable08  
           , CTE.DropID  
           , CTE.CaseCnt  
           , CTE.Qty  
           , CTE.CTN  
           , CTE.C_Company  
           , CTE.ConsigneeKey  
           , CTE.C_Country  
           , CTE.C_Address4  
           , CTE.Method  
           , CTE.[Print]  
           , CTE.Pack  
           , CTE.Lottable05  
           , CTE.OVAS  
           , CTE.ID  
           , CTE.HL  
           , CTE.NOTES  
           , CTE.CTNAV  
           , CTE.PStation  
           , CTE.NoOfOrder  
      FROM CTE  
      ORDER BY CTE.Sku -- CTE.OrderKey,   --WL02  
  
      INSERT INTO #TMP_DET (UserDefine09, ExternOrderKey, Sku, Loc, Lottable08, DropID, CaseCnt, Qty, CTN, C_Company  
                          , ConsigneeKey, C_Country, C_Address4, Method, [Print], Pack, Lottable05, OVAS, ID, HL, NOTES  
                          , CTNAV, PStation, NoOfOrder)  
      SELECT TOP 1  
             CTE.UserDefine09  
           , CTE.ExternOrderKey  
           , NULL  
           , NULL  
           , CTE.Lottable08  
           , CTE.DropID  
           , CTE.CaseCnt  
           , (SELECT SUM(Qty) FROM #TMP_DET)  
           , (SELECT SUM(CTN) FROM #TMP_DET)  
           , CTE.C_Company  
           , CTE.ConsigneeKey  
           , CTE.C_Country  
           , CTE.C_Address4  
           , CTE.Method  
           , CTE.[Print]  
           , CTE.Pack  
           , NULL  
           , CTE.OVAS  
           , NULL  
           , CTE.HL  
           , CTE.NOTES  
           , NULL  
           , CTE.PStation  
           , CTE.NoOfOrder  
      FROM #TMP_DET CTE  
  
      SELECT TD.UserDefine09      
           , TD.ExternOrderKey    
           , TD.Sku               
           , TD.Loc               
           , TD.Lottable08        
           , TD.DropID            
           , TD.CaseCnt           
           , TD.Qty               
           , TD.CTN               
           , TD.C_Company         
           , TD.ConsigneeKey      
           , TD.C_Country         
           , TD.C_Address4        
           , TD.Method            
           , TD.[Print]           
           , TD.Pack              
           , TD.Lottable05        
           , TD.OVAS              
           , TD.ID                
           , TD.HL                
           , TD.NOTES             
           , TD.CTNAV             
           , TD.PStation          
           , TD.NoOfOrder         
      FROM #TMP_DET TD  
      ORDER BY TD.RowID  
      --WL01 E  
   END  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_PD') IN ( 0, 1 )  
   BEGIN  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
   END  
  
   --WL01 S  
   IF OBJECT_ID('tempdb..#TMP_DET') IS NOT NULL  
      DROP TABLE #TMP_DET  
   --WL01 E  
  
   IF @n_continue = 3 -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err  
                         , @c_errmsg  
                         , 'isp_RPT_WV_PLIST_WAVE_023'  
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END  

GO