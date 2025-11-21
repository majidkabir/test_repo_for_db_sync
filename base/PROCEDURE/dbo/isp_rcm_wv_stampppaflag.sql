SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_WV_StampPPAFlag                            */
/* Creation Date: 28-Oct-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18273 - SG - Adidas SEA - RCMConfig Stamp PPA Flag      */
/*                                                                      */
/* Called By: Wave RCM configure at listname 'RCMConfig'                */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Oct-2021  WLChooi   1.0   DevOps Combine Script                   */
/* 28-Mar-2022  WLChooi   1.1   WMS-19326 - Change UserDefine03 to      */
/*                              UserDefine10 (WL01)                     */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_WV_StampPPAFlag]
   @c_Wavekey  NVARCHAR(10),
   @b_success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue             INT
         , @n_starttcnt            INT
         , @c_DocType              NVARCHAR(10)
         , @n_StampPPAFlag         INT = 0    -- 1 - Stamp All Orderkey, 2 - Stamp Partial Orderkey
         , @c_STCountry            NVARCHAR(50)
         , @c_UserDefine01         NVARCHAR(50)
         , @c_Orderkey             NVARCHAR(10)
         , @c_Storerkey            NVARCHAR(15)
         , @c_PPA                  NVARCHAR(10) = 'PPA'
         , @c_OHUDF10              NVARCHAR(20) = ''   --WL01
         , @n_PPA_Percent          DECIMAL(10,4) = 0.00
         , @n_NoOfOrdersCurrWave   INT = 0
         , @n_NoOfOrdersOthWave    INT = 0
         , @n_NoOfPPAOrdersOthWave INT = 0
         , @n_NoOfOrderReqPPA      INT = 0
         , @b_Debug                INT = 0


   CREATE TABLE #TMP_WV (
        Orderkey      NVARCHAR(10)
      , DocType       NVARCHAR(10)
      , C_Country     NVARCHAR(100)
      , UserDefine10  NVARCHAR(50)   --WL01
      , Storerkey     NVARCHAR(15)
      , StampPPAFlag  NVARCHAR(1)
   )

   IF @n_err > 0
   BEGIN
      SET @b_Debug = @n_err
   END

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0

   SELECT @c_UserDefine01 = W.UserDefine01
   FROM WAVE W (NOLOCK)
   WHERE W.WaveKey = @c_Wavekey

   IF @c_UserDefine01 = @c_PPA   --Already performed stamping PPA before
   BEGIN
      GOTO QUIT_SP
   END

   IF @n_Continue IN (1,2)
   BEGIN
      SELECT TOP 1 @c_STCountry = ISNULL(ST.Country,'')
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
      WHERE WD.WaveKey = @c_Wavekey
      
      --C_Country <> @c_STCountry --Export Orders, Stamp PPA for all orderkey
      --C_Country = @c_STCountry  --Local Orders, Stamp PPA for some orderkey
      INSERT INTO #TMP_WV (Orderkey, DocType, C_Country, UserDefine10, Storerkey, StampPPAFlag)   --WL01
      SELECT OH.Orderkey, OH.Doctype, ISNULL(OH.C_Country,''), ISNULL(OH.UserDefine10,''), OH.StorerKey   --WL01
           , CASE WHEN ISNULL(OH.C_Country,'') <> @c_STCountry THEN 1 ELSE 2 END
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.Orderkey
      WHERE WD.WaveKey = @c_Wavekey
      
      --IF EXISTS (SELECT 1 FROM #TMP_WV WV
      --           WHERE WV.C_Country <> @c_STCountry)   --Export Orders, Stamp PPA for all orderkey
      --BEGIN
      --   SET @n_StampPPAFlag = 1
      --END
      --ELSE IF EXISTS (SELECT 1 FROM #TMP_WV WV
      --                WHERE WV.C_Country = @c_STCountry)   --Local Orders, Stamp PPA for some orderkey
      --BEGIN
      --   SET @n_StampPPAFlag = 2
      --END
      --ELSE
      --BEGIN
      --   GOTO QUIT_SP
      --END
      
      SELECT TOP 1 @c_Storerkey = WV.Storerkey
      FROM #TMP_WV WV
   END

   --StampPPAFlag = '1' (C_Country <> @c_STCountry)
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT WV.Orderkey
   FROM #TMP_WV WV
   WHERE WV.C_Country <> @c_STCountry
   AND WV.Storerkey = @c_Storerkey
   AND WV.StampPPAFlag = '1'

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE ORDERS
      SET M_vat      = @c_PPA
        , TrafficCop = NULL
        , EditDate   = GETDATE()
        , EditWho    = SUSER_SNAME()
      WHERE OrderKey = @c_Orderkey

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 64005
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Update ORDERS Table Failed - @n_StampPPAFlag = 1. (isp_RCM_WV_StampPPAFlag)'
                       + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT_SP
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   --StampPPAFlag = '2' (C_Country = @c_STCountry)
   SELECT @n_PPA_Percent = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(6,4)) ELSE 0 END
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'ADIPPAPCT' 
   AND CL.Storerkey = @c_Storerkey
   
   DECLARE CUR_PPA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT WV.UserDefine10   --WL01
   FROM #TMP_WV WV
   WHERE WV.DocType = 'N'
   AND WV.C_Country = @c_STCountry
   AND WV.Storerkey = @c_Storerkey
   AND WV.StampPPAFlag = '2'
   
   OPEN CUR_PPA
   
   FETCH NEXT FROM CUR_PPA INTO @c_OHUDF10   --WL01
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_NoOfOrdersCurrWave   = 0
      SET @n_NoOfOrdersOthWave    = 0
      SET @n_NoOfPPAOrdersOthWave = 0
      SET @n_NoOfOrderReqPPA      = 0
   
      SELECT @n_NoOfOrdersCurrWave = COUNT(1)
      FROM #TMP_WV WV
      WHERE WV.UserDefine10 = @c_OHUDF10   --WL01 
      AND WV.C_Country = @c_STCountry
      AND WV.Storerkey = @c_Storerkey
   
      SELECT @n_NoOfOrdersOthWave = COUNT(1)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN WAVE W (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey 
                             AND ST.Country = OH.C_Country
      WHERE OH.UserDefine10 = @c_OHUDF10   --WL01 
      AND WD.WaveKey <> @c_Wavekey
      AND OH.StorerKey = @c_Storerkey
      AND OH.DocType = 'N'
      AND W.UserDefine01 = 'PPA'
      
      SELECT @n_NoOfPPAOrdersOthWave = COUNT(1)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN WAVE W (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey 
                             AND ST.Country = OH.C_Country
      WHERE OH.UserDefine10 = @c_OHUDF10   --WL01 
      AND WD.WaveKey <> @c_Wavekey
      AND OH.StorerKey = @c_Storerkey
      AND OH.DocType = 'N'
      AND OH.M_vat = 'PPA'
      AND W.UserDefine01 = 'PPA'
   
      SET @n_NoOfOrderReqPPA = CEILING((ISNULL(@n_NoOfOrdersOthWave,0) + ISNULL(@n_NoOfOrdersCurrWave,0)) * @n_PPA_Percent)
      SET @n_NoOfOrderReqPPA = @n_NoOfOrderReqPPA - @n_NoOfPPAOrdersOthWave
   
      IF @b_Debug = 1
      BEGIN
         SELECT ISNULL(@n_NoOfOrdersCurrWave,0) AS '@n_NoOfOrdersCurrWave', ISNULL(@n_NoOfOrdersOthWave,0) AS '@n_NoOfOrdersOthWave'
              , @n_PPA_Percent AS '@n_PPA_Percent', @n_NoOfOrderReqPPA AS '@n_NoOfOrderReqPPA'
      END
   
      IF @n_NoOfOrderReqPPA > 0
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TOP (@n_NoOfOrderReqPPA) WV.Orderkey
         FROM #TMP_WV WV
         WHERE WV.DocType = 'N'
         AND WV.UserDefine10 = @c_OHUDF10   --WL01
         AND WV.C_Country = @c_STCountry
         AND WV.Storerkey = @c_Storerkey
         ORDER BY WV.Orderkey
         
         OPEN CUR_UPD
         
         FETCH NEXT FROM CUR_UPD INTO @c_Orderkey
   
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE ORDERS
            SET M_vat      = @c_PPA
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE OrderKey = @c_Orderkey
            
            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 64010
               SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Update ORDERS Table Failed - @n_StampPPAFlag = 2. (isp_RCM_WV_StampPPAFlag)'
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               GOTO QUIT_SP
            END
   
            FETCH NEXT FROM CUR_UPD INTO @c_Orderkey
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   
      FETCH NEXT FROM CUR_PPA INTO @c_OHUDF10
   END
   CLOSE CUR_PPA
   DEALLOCATE CUR_PPA

   IF @n_Continue IN (1,2)
   BEGIN
      UPDATE WAVE 
      SET UserDefine01 = @c_PPA
      WHERE WaveKey = @c_Wavekey

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 64015
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Update WAVE Table Failed. (isp_RCM_WV_StampPPAFlag)'
                       + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT_SP
      END
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
   IF CURSOR_STATUS('LOCAL', 'CUR_PPA') IN (0 , 1)
   BEGIN
      CLOSE CUR_PPA
      DEALLOCATE CUR_PPA   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_UPD') IN (0 , 1)
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD   
   END

   IF OBJECT_ID('tempdb..#TMP_WV') IS NOT NULL
      DROP TABLE #TMP_WV

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_StampPPAFlag'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC

GO