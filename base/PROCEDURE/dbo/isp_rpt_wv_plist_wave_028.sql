SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_028                           */
/* Creation Date: 26-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22849 - [TW] PMA Wave PickSlip LogiReport New            */
/*                                                                       */
/* Called By: RPT_WV_PLIST_WAVE_028                                      */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 26-Jun-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_028]
(@c_Wavekey NVARCHAR(10), @c_PreGenRptData NVARCHAR(10) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT           = 1
         , @n_starttcnt INT
         , @b_Success   INT           = 1
         , @b_debug     INT           = 0
         , @c_errmsg    NVARCHAR(255) = N''
         , @n_err       INT
         , @c_Storerkey NVARCHAR(15)
         , @c_Floor     NVARCHAR(50)

   DECLARE @n_Load01_Qty      INT
         , @n_Load02_Qty      INT
         , @n_Load03_Qty      INT
         , @n_Load04_Qty      INT
         , @n_Load05_Qty      INT
         , @n_Load06_Qty      INT
         , @c_Loadkey         NVARCHAR(10)
         , @c_SKU             NVARCHAR(20)
         , @c_FromLoc         NVARCHAR(10)
         , @n_Qty             INT
         , @n_PDQty           INT
         , @n_Count           INT
         , @c_SQL             NVARCHAR(MAX)
         , @c_SDescr          NVARCHAR(250)
         , @c_AutoScanIn      NVARCHAR(10) = 'N'
         , @c_Pickheaderkey   NVARCHAR(10) = ''
         , @c_Orderkey        NVARCHAR(10) = ''

   SELECT @n_starttcnt = @@TRANCOUNT
   SELECT @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')

   DECLARE @T_TEMP TABLE
   (
      SKU          NVARCHAR(20) NULL
    , FromLOC      NVARCHAR(10) NULL
    , LLIQty       INT NULL
    , Load01_Qty   INT NULL
    , Load02_Qty   INT NULL
    , Load03_Qty   INT NULL
    , Load04_Qty   INT NULL
    , Load05_Qty   INT NULL
    , Load06_Qty   INT NULL
    , TotalQty     INT NULL
    , RemainingQty INT NULL
    , SDescr       NVARCHAR(250) NULL
   )

   SELECT @c_Storerkey = OH.Storerkey
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.orderkey
   WHERE WD.Wavekey = @c_Wavekey

   SELECT @c_Floor = CL.Code2 
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'SHOWPICKLOC' 
   AND CL.Code = 'PLIST_WAVE' 
   AND CL.Storerkey = @c_Storerkey

   IF @c_PreGenRptData = 'Y'
   BEGIN
      --Create Pickslip
      IF EXISTS ( SELECT 1
                  FROM Storerconfig (NOLOCK)
                  WHERE ConfigKey = 'AutoScanIn'
                  AND Storerkey = @c_Storerkey
                  AND SValue = '1')
      BEGIN
         SET @c_AutoScanIn = 'Y'
      END
      ELSE
      BEGIN
         SET @c_AutoScanIn = 'N'
      END

      EXEC dbo.isp_CreatePickSlip @c_Wavekey = @c_Wavekey
                              , @c_PickslipType = N'3'
                              , @c_ConsolidateByLoad = N'N'
                              , @c_AutoScanIn = @c_AutoScanIn
                              , @b_Success = @b_Success OUTPUT
                              , @n_Err = @n_Err OUTPUT
                              , @c_ErrMsg = @c_ErrMsg OUTPUT
      
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      --Update Loadkey into Pickheader.ExternLoadkey & Loadkey
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PH.Pickheaderkey, PH.Orderkey, OH.Loadkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN PICKHEADER PH (NOLOCK) ON WD.OrderKey = PH.OrderKey
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      WHERE WD.WaveKey = @c_Wavekey
      AND PH.ExternOrderKey = ''

      OPEN CUR_UPD

      FETCH NEXT FROM CUR_UPD INTO @c_Pickheaderkey, @c_Orderkey, @c_Loadkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET ExternOrderKey = @c_Loadkey
           , LoadKey = @c_Loadkey
         WHERE PickHeaderKey = @c_Pickheaderkey
         AND ExternOrderKey = ''

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65535
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Update PICKHEADER Failed for Pickslip# '
                             + @c_Pickheaderkey + ' (isp_RPT_WV_PLIST_WAVE_028)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_UPD INTO @c_Pickheaderkey, @c_Orderkey, @c_Loadkey
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   IF ISNULL(@c_Floor,'') = ''
   BEGIN
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.Storerkey
           , R.Sku
           , R.Loc
           , LLI.Qty
           , S.DESCR
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON WD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL R (NOLOCK) ON R.OrderKey = OH.Orderkey
      JOIN LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = R.Loc AND LLI.Lot = R.Lot AND LLI.Id = R.ID
      JOIN SKU S (NOLOCK) ON S.StorerKey = R.Storerkey AND S.Sku = R.Sku
      WHERE WD.WaveKey = @c_Wavekey
      ORDER BY R.Sku
             , R.Loc
   END
   ELSE
   BEGIN
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.Storerkey
           , R.Sku
           , R.Loc
           , LLI.Qty
           , S.DESCR
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON WD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL R (NOLOCK) ON R.OrderKey = OH.Orderkey
      JOIN LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = R.Loc AND LLI.Lot = R.Lot AND LLI.Id = R.ID
      JOIN SKU S (NOLOCK) ON S.StorerKey = R.Storerkey AND S.Sku = R.Sku
      JOIN LOC L (NOLOCK) ON L.LOC = LLI.LOC
      WHERE WD.WaveKey = @c_Wavekey
      AND L.[Floor] = @c_Floor
      ORDER BY R.Sku
             , R.Loc
   END
   
   OPEN CUR_PD

   FETCH NEXT FROM CUR_PD
   INTO @c_Storerkey
      , @c_SKU
      , @c_FromLoc
      , @n_Qty
      , @c_SDescr

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Load01_Qty = 0
      SET @n_Load02_Qty = 0
      SET @n_Load03_Qty = 0
      SET @n_Load04_Qty = 0
      SET @n_Load05_Qty = 0
      SET @n_Load06_Qty = 0
      SET @n_Count = 1
      SET @c_Loadkey = ''

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TOP 6 OH.LoadKey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey
      ORDER BY OH.LoadKey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP
      INTO @c_Loadkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_PDQty = 0

         SELECT @n_PDQty = SUM(PD.Qty)
         FROM PICKDETAIL PD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
         JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
         WHERE LPD.LoadKey = @c_Loadkey AND PD.Storerkey = @c_Storerkey AND PD.Sku = @c_SKU

         SET @c_SQL = N' SET @n_Load0' + CAST(@n_Count AS NVARCHAR) + N'_Qty = ISNULL(@n_PDQty,0) '

         EXEC sp_executesql @c_SQL
                          , N' @n_Load01_Qty INT OUTPUT, @n_Load02_Qty INT OUTPUT, @n_Load03_Qty INT OUTPUT, @n_Load04_Qty INT OUTPUT, @n_Load05_Qty INT OUTPUT, @n_Load06_Qty INT OUTPUT, @n_PDQty INT '
                          , @n_Load01_Qty OUTPUT
                          , @n_Load02_Qty OUTPUT
                          , @n_Load03_Qty OUTPUT
                          , @n_Load04_Qty OUTPUT
                          , @n_Load05_Qty OUTPUT
                          , @n_Load06_Qty OUTPUT
                          , @n_PDQty

         SET @n_Count = @n_Count + 1
         FETCH NEXT FROM CUR_LOOP
         INTO @c_Loadkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      INSERT INTO @T_TEMP (SKU, FromLOC, LLIQty, Load01_Qty, Load02_Qty, Load03_Qty, Load04_Qty, Load05_Qty, Load06_Qty
                         , TotalQty, RemainingQty, SDescr)
      VALUES (@c_SKU, @c_FromLoc, @n_Qty, @n_Load01_Qty, @n_Load02_Qty, @n_Load03_Qty, @n_Load04_Qty, @n_Load05_Qty
            , @n_Load06_Qty
            , (@n_Load01_Qty + @n_Load02_Qty + @n_Load03_Qty + @n_Load04_Qty + @n_Load05_Qty + @n_Load06_Qty)
            , @n_Qty - (@n_Load01_Qty + @n_Load02_Qty + @n_Load03_Qty + @n_Load04_Qty + @n_Load05_Qty + @n_Load06_Qty)
            , @c_SDescr)

      FETCH NEXT FROM CUR_PD
      INTO @c_Storerkey
         , @c_SKU
         , @c_FromLoc
         , @n_Qty
         , @c_SDescr
   END
   CLOSE CUR_PD
   DEALLOCATE CUR_PD

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      SELECT TT.SKU
         , TT.FromLOC
         , TT.LLIQty
         , TT.Load01_Qty
         , TT.Load02_Qty
         , TT.Load03_Qty
         , TT.Load04_Qty
         , TT.Load05_Qty
         , TT.Load06_Qty
         , TT.TotalQty
         , TT.RemainingQty
         , TT.SDescr
         , @c_Wavekey AS Wavekey
      FROM @T_TEMP TT
      ORDER BY TT.SKU
            , TT.FromLOC
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PD') IN (0 , 1)
   BEGIN
      CLOSE CUR_PD
      DEALLOCATE CUR_PD   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_UPD') IN (0 , 1)
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD   
   END

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_028'
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