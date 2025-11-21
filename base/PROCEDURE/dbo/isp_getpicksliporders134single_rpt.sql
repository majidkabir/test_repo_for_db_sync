SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPickSlipOrders134Single_rpt                          */
/* Creation Date: 18-Sep-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-20669 - [CN] IKEA_Single_PickSlip Report_CR            */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 18/09/2022   Mingle    1.0   DevOps Combine Script(Created)          */
/* 24/11/2022   Mingle    1.1   WMS-21188 Add new logic(ML01)           */
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipOrders134Single_rpt]
            @c_loadkey     NVARCHAR(10),
            @c_Batchkey    NVARCHAR(10) = '',
            @c_Ordergroup  NVARCHAR(20) = ''		--ML01

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1, 
			 @c_Zones NVARCHAR(255) = '', 
			 @c_GetBatchkey NVARCHAR(10) = '',
			 @n_StartTCnt            INT = @@TRANCOUNT,  
          @b_Success INT = 1,
			 @n_err     INT = 0,
			 @c_ErrMsg               NVARCHAR(255)

	SET @b_Success = 1
   SET @n_Err     = 0
               

   IF @c_batchkey = NULL SET @c_batchkey = ''

   BEGIN TRAN

   --START ML01
   IF EXISTS (SELECT 1 FROM LOADPLAN(NOLOCK) WHERE LOADKEY = @c_loadkey AND ISNULL(UserDefine10,'') NOT IN ('VPBATCH',''))
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63920 
          --SET @c_ErrMsg = 'Cannot print pickingslip report for this load now, waiting for Voice Picking return information. (isp_GetPickSlipOrders134Single_rpt) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Cannot print pickingslip report for this load now, waiting for Voice Picking return information. (isp_GetPickSlipOrders134Single_rpt)'
      GOTO QUIT_SP
   END	
   --END ML01




   CREATE TABLE #Temp_Zone(
   BatchKey    NVARCHAR(10),
   Descr       NVARCHAR(255)   )

   INSERT INTO #Temp_Zone
   SELECT DISTINCT PD.Pickslipno, ISNULL(LOC.Descr,'')
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
   WHERE LPD.Loadkey = @c_loadkey
   AND PD.Pickslipno = CASE WHEN @c_batchkey = '' THEN PD.Pickslipno ELSE @c_batchkey END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Batchkey
   FROM #Temp_Zone

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetBatchkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Zones = STUFF((SELECT ' + ' + RTRIM(Descr) FROM #Temp_Zone WHERE Batchkey = @c_GetBatchkey ORDER BY Descr FOR XML PATH('')),1,1,'' )
      SELECT @c_Zones = SUBSTRING(@c_Zones,3,LEN(@c_Zones))

      DELETE FROM #Temp_Zone
      WHERE BatchKey = @c_GetBatchkey

      INSERT INTO #Temp_Zone
      SELECT @c_GetBatchkey, @c_Zones

      FETCH NEXT FROM CUR_LOOP INTO @c_GetBatchkey
   END

   SELECT  OH.Loadkey
         , PD.Pickslipno AS Batchkey
         , Count(Distinct(PD.SKU)) AS TotalSKU
         , SUM(PD.Qty) AS TotalUnit
         , #Temp_Zone.Descr AS AllZones
         , Loc.PickZone AS PickZone
         , ISNULL(CL.long,'') AS Title
         , LPD.UserDefine05 AS Ordergroup		--ML01
         , CASE WHEN OH.SpecialHandling = 'A' THEN 'Autopacking' ELSE '' END AS Remark		--ML01
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = OH.ORDERKEY
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.ORDERKEY = OH.ORDERKEY
   --JOIN PICKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
   JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
   LEFT JOIN #Temp_Zone ON #Temp_Zone.BatchKey = PD.Pickslipno
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'IKEATITLE' AND CL.Storerkey = oh.StorerKey AND CL.Code = oh.ShipperKey --ML01
   WHERE LPD.Loadkey = @c_loadkey
     AND OH.ECOM_Single_Flag = 'S'
     AND PD.Pickslipno = CASE WHEN @c_batchkey = '' THEN PD.Pickslipno ELSE @c_batchkey END
     AND LPD.UserDefine05 = CASE WHEN @c_Ordergroup = '' THEN '' ELSE LPD.UserDefine05 END		--ML01
   GROUP BY OH.Loadkey
          , PD.Pickslipno
          , #Temp_Zone.Descr
          , Loc.PickZone
          , ISNULL(CL.long,'')
          , LPD.UserDefine05		--ML01
          , CASE WHEN OH.SpecialHandling = 'A' THEN 'Autopacking' ELSE '' END		--ML01


QUIT_SP:
   IF OBJECT_ID('tempdb..#Temp_Zone') IS NOT NULL
      DROP TABLE #Temp_Zone

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   --START ML01
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_GetPickSlipOrders134Single_rpt'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   --END ML01
END -- procedure

GO