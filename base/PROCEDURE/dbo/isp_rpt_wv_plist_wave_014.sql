SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_014                          */
/* Creation Date: 29-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20317 - JP Dcode DCJ Pick Label                         */
/*                                                                      */
/* Called By: RPT_WV_PLIST_WAVE_014                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 29-Aug-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_014]
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
         , @c_Loadkey         NVARCHAR(10)
         , @c_PrevLoadkey     NVARCHAR(10)
         , @c_Pos             NVARCHAR(10)
         , @n_PosIndex        INT = 0
         , @n_ASCIIIndex      INT = 65   --A

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   IF ISNULL(@c_PreGenRptData,'') IN ('','0') SET @c_PreGenRptData = ''

   CREATE TABLE #TMP_PD (
      RowID       INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , Loc         NVARCHAR(20)
    , SKU         NVARCHAR(20)
    , Wavekey     NVARCHAR(10)
    , Orderkey    NVARCHAR(10)
    , DESCR       NVARCHAR(250)
    , Qty         INT
    , Pickslipno  NVARCHAR(10) NULL
    , Pos         NVARCHAR(20) NULL
   )

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
      SELECT @c_pickheaderkey, @c_Wavekey, @c_pickheaderkey, '0', 'LB'

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

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      INSERT INTO #TMP_PD (Loc, SKU, Wavekey, Orderkey, DESCR, Qty, Pickslipno)
      SELECT PD.LOC, PD.SKU, WD.Wavekey, OH.Orderkey
           , S.DESCR, SUM(PD.Qty), PD.Pickslipno
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
      JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey = PD.Storerkey
      JOIN LOC L (NOLOCK) ON L.LOC = PD.LOC
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY PD.LOC, PD.SKU, WD.Wavekey, OH.Orderkey
           , S.DESCR, PD.Pickslipno, L.LogicalLocation
      ORDER BY L.LogicalLocation

      DECLARE CUR_POS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.Loadkey, OH.Orderkey
      FROM ORDERS OH (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
      WHERE WD.WaveKey = @c_Wavekey
      ORDER BY OH.LoadKey, OH.OrderKey
      
      OPEN CUR_POS
      
      FETCH NEXT FROM CUR_POS INTO @c_Loadkey, @c_Orderkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_PosIndex = @n_PosIndex + 1
      
         IF @c_PrevLoadkey <> @c_Loadkey
         BEGIN
            IF ISNULL(@c_Pos,'') <> ''
               SET @n_ASCIIIndex = @n_ASCIIIndex + 1
               
            SET @c_Pos = CHAR(@n_ASCIIIndex)
            SET @n_PosIndex = 1
         END
      
         UPDATE #TMP_PD
         SET Pos = @c_Pos + CAST(@n_PosIndex AS NVARCHAR)
         WHERE Orderkey = @c_Orderkey
      
         SET @c_PrevLoadkey = @c_Loadkey
      
         FETCH NEXT FROM CUR_POS INTO @c_Loadkey, @c_Orderkey
      END
      CLOSE CUR_POS
      DEALLOCATE CUR_POS

      SELECT Loc       
           , SKU       
           , Wavekey   
           , Orderkey  
           , DESCR     
           , Qty       
           , Pickslipno
           , Pos       
      FROM #TMP_PD TP
      ORDER BY RowID
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_POS') IN (0 , 1)
   BEGIN
      CLOSE CUR_POS
      DEALLOCATE CUR_POS   
   END

   IF OBJECT_ID('tempdb..#TMP_PD') IS NOT NULL
      DROP TABLE #TMP_PD
   
END -- procedure

GO