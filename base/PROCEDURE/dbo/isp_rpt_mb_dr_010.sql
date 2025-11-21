SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_MB_DR_010                                   */
/* Creation Date: 26-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22878 - CR-PUMA Delivery Report                          */
/*                                                                       */
/* Called By: RPT_MB_DR_010                                              */
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

CREATE   PROC [dbo].[isp_RPT_MB_DR_010]
(@c_Mbolkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_starttcnt INT
         , @b_Success   INT = 1
         , @b_debug     INT = 0
         , @n_Err       INT = 0
         , @c_errmsg    NVARCHAR(250)

   SELECT @n_starttcnt = @@TRANCOUNT

   SELECT DISTINCT MD.OrderKey
   FROM MBOLDETAIL MD (NOLOCK)
   WHERE MD.MbolKey = @c_Mbolkey

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
      EXECUTE nsp_logerror @n_Err, @c_errmsg, 'isp_RPT_MB_DR_010'
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