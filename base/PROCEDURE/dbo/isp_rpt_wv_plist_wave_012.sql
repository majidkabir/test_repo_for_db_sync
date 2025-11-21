SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_012                          */
/* Creation Date: 28-Jul-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20360 - JP Stussy SSJP Pick Label                       */
/*                                                                      */
/* Called By: RPT_WV_PLIST_WAVE_012                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 28-Jul-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_012]
         @c_Wavekey        NVARCHAR(10)
       , @c_PreGenRptData  NVARCHAR(10) = ''

AS
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
         , @n_Count           INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_pickheaderkey   NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   IF ISNULL(@c_PreGenRptData,'') IN ('','0') SET @c_PreGenRptData = ''

   --Generate Pickslip
   IF NOT EXISTS (SELECT 1
                  FROM PICKHEADER PH (NOLOCK)
                  WHERE PH.WaveKey = @c_Wavekey
                  AND PH.Zone = 'LB'
                  AND PH.PickType = '0') AND @c_PreGenRptData = 'Y'
   BEGIN
      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,
         @c_pickheaderkey  OUTPUT,
         @b_success        OUTPUT,
         @n_err            OUTPUT,
         @c_errmsg         OUTPUT

      SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

      INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, PickType, Zone)
      SELECT @c_pickheaderkey, @c_Wavekey, '', '0', 'LB'

      ;WITH CTE AS (SELECT DISTINCT PICKDETAIL.Pickdetailkey
                    FROM PICKDETAIL (NOLOCK)
                    JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey
                    JOIN WAVEDETAIL (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey
                    WHERE WAVEDETAIL.WaveKey = @c_Wavekey)
      UPDATE dbo.PICKDETAIL
      SET PICKDETAIL.PickSlipNo = @c_pickheaderkey
      FROM CTE
      WHERE CTE.PickDetailKey = PICKDETAIL.PickDetailKey

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT WD.Orderkey
      FROM WAVEDETAIL WD (NOLOCK)
      WHERE WD.WaveKey = @c_Wavekey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN 
         INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
         SELECT PD.PickdetailKey, @c_pickheaderkey, PD.OrderKey, PD.OrderLineNumber 
         FROM PICKDETAIL PD (NOLOCK)  
         LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
         WHERE PD.Orderkey = @c_Orderkey
         AND RKL.Pickdetailkey IS NULL

         UPDATE RefkeyLookup WITH (ROWLOCK)
         SET RefKeyLookup.Pickslipno = @c_pickheaderkey
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey             
         WHERE PD.Orderkey = @c_Orderkey
         AND RefKeyLookup.Pickslipno <> @c_pickheaderkey

         FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
   ELSE
   BEGIN
      SELECT @c_pickheaderkey = PH.PickHeaderKey
      FROM PICKHEADER PH (NOLOCK)
      WHERE PH.WaveKey = @c_Wavekey
      AND PH.Zone = 'LB'
      AND PH.PickType = '0'
   END

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      SELECT WD.Wavekey, @c_pickheaderkey AS Pickslipno
           , OH.LoadKey, SUM(PD.Qty) AS Qty
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON WD.OrderKey = OH.OrderKey 
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      WHERE WD.WaveKey = @c_Wavekey
      GROUP BY WD.Wavekey, OH.LoadKey
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
END -- procedure

GO