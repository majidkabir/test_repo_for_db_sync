SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_009                           */
/* Creation Date: 26-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22849 - [TW] PMA Wave PickSlip LogiReport New            */
/*                                                                       */
/* Called By: RPT_WV_WAVPICKSUM_009                                      */
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

CREATE   PROC [dbo].[isp_RPT_WV_WAVPICKSUM_009]
(@c_Wavekey NVARCHAR(10))
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
         , @c_Floor     NVARCHAR(10) = N''

   SELECT @c_Storerkey = OH.Storerkey
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.orderkey
   WHERE WD.Wavekey = @c_Wavekey

   SELECT @c_Floor = CL.Code2 
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'SHOWPICKLOC' 
   AND CL.Code = 'WAVPICKSUM' 
   AND CL.Storerkey = @c_Storerkey

   IF ISNULL(@c_Floor,'') = ''
   BEGIN
      SELECT PD.Storerkey
           , WD.WaveKey
           , OH.LoadKey
           , ISNULL(L.[Floor], '') AS [Floor]
           , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, '')) AS StyleColor
           , L.Loc
           , S.Size
           , SUM(PD.Qty) AS Qty
           , ISNULL(OH.LoadKey, '') + ISNULL(L.[Floor], '') AS Group1
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
      JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
      WHERE WD.WaveKey = @c_Wavekey
      GROUP BY PD.Storerkey
             , WD.WaveKey
             , OH.LoadKey
             , ISNULL(L.[Floor], '')
             , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, ''))
             , L.Loc
             , S.Size
             , L.LogicalLocation
      ORDER BY OH.LoadKey
             , ISNULL(L.[Floor], '')
             , L.LogicalLocation
             , L.Loc
             , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, ''))
             , S.Size
   END
   ELSE
   BEGIN
      SELECT PD.Storerkey
           , WD.WaveKey
           , OH.LoadKey
           , ISNULL(L.[Floor], '') AS [Floor]
           , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, '')) AS StyleColor
           , L.Loc
           , S.Size
           , SUM(PD.Qty) AS Qty
           , ISNULL(OH.LoadKey, '') + ISNULL(L.[Floor], '') AS Group1
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
      JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
      WHERE WD.WaveKey = @c_Wavekey
      AND L.[Floor] = @c_Floor
      GROUP BY PD.Storerkey
             , WD.WaveKey
             , OH.LoadKey
             , ISNULL(L.[Floor], '')
             , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, ''))
             , L.Loc
             , S.Size
             , L.LogicalLocation
      ORDER BY OH.LoadKey
             , ISNULL(L.[Floor], '')
             , L.LogicalLocation
             , L.Loc
             , TRIM(ISNULL(S.Style, '')) + TRIM(ISNULL(S.Color, ''))
             , S.Size
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_WAVPICKSUM_009'
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