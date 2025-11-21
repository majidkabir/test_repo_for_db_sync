SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetHandoverRptSephora_RDT                           */
/* Creation Date: 06-Aug-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14566 - [CN] Sephora WMS Pallet List                    */
/*        :                                                             */
/* Called By: r_dw_handover_rpt_Sephora_rdt                             */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-Jan-2022 WLChooi  1.1   DevOps Combine Script                     */
/* 03-Jan-2022 WLChooi  1.1   WMS-18669 - Customize Report Title (WL01) */
/************************************************************************/
CREATE PROC [dbo].[isp_GetHandoverRptSephora_RDT]
         @c_Storerkey      NVARCHAR(15),
         @c_Palletkey      NVARCHAR(30),
         @c_Type           NVARCHAR(10) = 'H',
         @c_MBOLKey        NVARCHAR(10) = ''
             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
          
   DECLARE @b_Success        INT
         , @n_Err            INT
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_UserId         NVARCHAR(30)
         , @n_cnt            INT
         , @c_Getprinter     NVARCHAR(10) 
         , @n_MaxRowID       INT
         , @n_MaxLine        INT

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''
   SET @c_UserId    = SUSER_SNAME() 
   
   IF ISNULL(@c_Type,'') = '' SET @c_Type = 'H'

   SELECT MAX(OH.Shipperkey) AS Shipperkey
      , (SELECT COUNT(DISTINCT Orderkey) FROM ORDERS (NOLOCK) WHERE ORDERS.MBOLKey = MB.MbolKey) AS OrderCount
      , PLTD.PalletKey
      , MB.MbolKey
      , OH.TrackingNo
      , OH.ExternOrderKey
      , LPD.Loadkey, PH.PickSlipNo
      , PIF.[Weight]
      , @c_Storerkey AS Storerkey
      , CASE WHEN ISNULL(CL.Short,'N') = 'Y'                 --WL01
             THEN ISNULL(CL.Notes,'')                        --WL01
             ELSE N'Sephora GZWH快递交接表' END AS RptTitle   --WL01
   INTO #TMP_PalletList
   FROM PALLETDETAIL PLTD (NOLOCK)
   JOIN MBOL MB (NOLOCK) ON MB.ExternMbolKey = PLTD.PalletKey
   JOIN MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MB.MbolKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = MD.OrderKey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.Loadkey 
                              AND LPD.OrderKey = CASE WHEN PH.OrderKey = '' THEN LPD.OrderKey ELSE PH.OrderKey END
   CROSS APPLY (SELECT SUM(PACKINFO.[Weight]) AS [Weight]
               FROM PACKINFO (NOLOCK)
               WHERE PACKINFO.PickSlipNo = PH.PickSlipNo) AS PIF
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'CustomRptTitle'   --WL01
                                 AND CL.Long = 'r_dw_handover_rpt_Sephora_rdt'                  --WL01
                                 AND CL.Storerkey = OH.StorerKey                                --WL01
   WHERE PLTD.PalletKey = @c_Palletkey AND OH.StorerKey = @c_Storerkey
   GROUP BY PLTD.PalletKey
         , MB.MbolKey
         , OH.TrackingNo
         , OH.ExternOrderKey
         , LPD.Loadkey, PH.PickSlipNo
         , PIF.[Weight]
         , CASE WHEN ISNULL(CL.Short,'N') = 'Y'     --WL01
                THEN ISNULL(CL.Notes,'')            --WL01
                ELSE N'Sephora GZWH快递交接表' END   --WL01
   
   IF @c_Type = 'H'
   BEGIN
      SELECT DISTINCT Shipperkey AS Shipperkey
                    , OrderCount AS OrderCount
                    , PalletKey  AS PalletKey
                    , MbolKey    AS MbolKey
                    , '' AS TrackingNo
                    , '' AS ExternOrderKey
                    , '' AS Loadkey
                    , '' AS Pickslipno
                    , '' AS [Weight]
                    , Storerkey AS Storerkey
                    , RptTitle   --WL01
      FROM #TMP_PalletList
   END
   ELSE IF @c_Type = 'D'
   BEGIN
      SELECT DISTINCT '' AS Shipperkey
                    , '' AS OrderCount
                    , '' AS PalletKey
                    , '' AS MbolKey
                    , TrackingNo AS TrackingNo
                    , ExternOrderKey AS ExternOrderKey
                    , Loadkey AS Loadkey
                    , Pickslipno AS Pickslipno
                    , [Weight] AS [Weight]
                    , '' AS Storerkey
      FROM #TMP_PalletList
      WHERE MBOLKey = @c_MBOLKey
      ORDER BY TrackingNo
   END
    
   IF OBJECT_ID('tempdb..#TMP_PalletList') IS NOT NULL
      DROP TABLE #TMP_PalletList

QUIT_SP:
END -- procedure

GO