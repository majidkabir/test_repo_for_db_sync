SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadOrderSummary04_rdt                         */
/* Creation Date: 05-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21459 - [CN] Columbia_B2C_Pickslip_Layout               */
/*                                                                      */
/* Called By: r_dw_load_order_summary_04_rdt                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 05-Jan-2023  WLChooi  1.0  DevOps Combine Script                     */
/* 10-Jan-2023  WLChooi  1.1  Bug Fix for WMS-21459 (WL01)              */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadOrderSummary04_rdt]
     @c_LoadKey     NVARCHAR(10)
   , @c_OrderCount  NVARCHAR(5)
   , @c_PickZones   NVARCHAR(4000) -- ZoneA,ZoneB,ZoneC,ZoneD,ZoneE (Comma delimited)
   , @c_Mode        NVARCHAR(1) = '0' -- 0 = Normal, 1 = Only batch order with total qty > 1 and with single pickzone, 2 = Only batch order with tota qty > 1 and with multi pickzone
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
         , @n_Err          INT
         , @n_Continue     INT
         , @n_StartTCnt    INT
         , @c_ErrMsg       NVARCHAR(250)

         , @n_cnt          INT
         , @n_OrderCount   INT

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''

   SET @n_OrderCount = CONVERT (INT, @c_OrderCount)

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   EXEC ispOrderBatching
        @c_LoadKey     = @c_LoadKey
      , @n_OrderCount  = @n_OrderCount
      , @c_PickZones   = @c_PickZones -- ZoneA,ZoneB,ZoneC,ZoneD,ZoneE (Comma delimited)
      , @c_Mode        = @c_Mode      -- 0 = Normal, 1 = Only batch order with total qty > 1 and with single pickzone, 2 = Only batch order with tota qty > 1 and with multi pickzone
      , @b_Success     = @b_Success  OUTPUT
      , @n_Err         = @n_Err      OUTPUT
      , @c_ErrMsg      = @c_ErrMsg   OUTPUT

   IF @n_Err <> 0
   BEGIN
      SET @b_Success = 0
   END

   SELECT LPD.Loadkey
        , OH.Orderkey
        , ISNULL(TRIM(OH.ExternOrderkey),'') AS ExternOrderkey
        , ISNULL(TRIM(LOC.PickZone),'') AS PickZone
        , ISNULL(TRIM(PD.Notes),'') AS Notes
        , @c_Mode AS Mode
        , ISNULL(TRIM(PD.Pickslipno),'') AS Pickslipno
        , DENSE_RANK() OVER (PARTITION by ISNULL(RTRIM(PD.Notes),'') ORDER BY OH.OrderKey ) AS OrderNo
        , ISNULL(TRIM(OH.Salesman),'') AS Salesman
        , ISNULL(TRIM(OH.UserDefine09),'') AS UserDefine09
        , (SELECT SUM(P.Qty) FROM PICKDETAIL P (NOLOCK) WHERE P.PickSlipNo = ISNULL(TRIM(PD.Pickslipno),'')) AS Qty   --WL01
        , CASE ISNULL(TRIM(OH.ECOM_SINGLE_Flag),'') 
          WHEN 'S' THEN N'单件拣货单' 
          WHEN 'M' THEN N'多件拣货单' 
          ELSE '' END AS Title
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON CL.listname = 'EPLATFORM' AND CL.storerkey = OH.Storerkey
                          AND (CL.Description = OH.UserDefine03)
   WHERE LPD.Loadkey = @c_Loadkey
   AND PD.Notes IS NOT NULL
   AND RTRIM(PD.Notes) <> ''
   AND PD.Notes Like '%' + @c_Mode
   AND   1 = @b_Success
   AND 1 = CASE
       WHEN ISNULL(CL.Short,'') = '1' AND (OH.[Status] = '1') THEN '0'
     ELSE '1'
   END
   GROUP BY LPD.Loadkey
          , OH.Orderkey
          , ISNULL(TRIM(OH.ExternOrderkey),'')
          , ISNULL(TRIM(LOC.PickZone),'')
          , ISNULL(TRIM(PD.Notes),'')
          , ISNULL(TRIM(PD.Pickslipno),'')
          , ISNULL(TRIM(OH.Salesman),'')
          , ISNULL(TRIM(OH.UserDefine09),'')
          , CASE ISNULL(TRIM(OH.ECOM_SINGLE_Flag),'') 
            WHEN 'S' THEN N'单件拣货单' 
            WHEN 'M' THEN N'多件拣货单' 
            ELSE '' END
          , ISNULL(RTRIM(PD.Notes),'')
          , ISNULL(RTRIM(LOC.PickZone),'')
   ORDER BY ISNULL(TRIM(PD.Pickslipno),'')   --WL01
          , ISNULL(RTRIM(LOC.PickZone),'')   --WL01

   QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO