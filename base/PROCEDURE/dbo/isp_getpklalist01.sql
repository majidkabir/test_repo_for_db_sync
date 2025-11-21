SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPKLAList01                                  */
/* Creation Date: 27-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16079 - RG - LEGO - EXCEED Packing                      */ 
/*          Call by isp_GetLottableList                                 */
/*                                                                      */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 27-Jan-2021 Wan01    1.0   Created.                                  */   
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GetPKLAList01] (
      @c_Storerkey         NVARCHAR(15)
   ,  @c_Sku               NVARCHAR(20) 
   ,  @c_LottableNum       NVARCHAR(2)       -- lottable number 01 - 15
   ,  @c_Datawindow        NVARCHAR(50) = '' --source datawindow
   ,  @c_Pickslipno        NVARCHAR(10) = '' --optional only for pack by lottable
   ,  @c_lottabledddwtype  NVARCHAR(20) = '' --optional only for pack by lottable
   ,  @b_Success           INT          = 0  OUTPUT
   ,  @n_Err               INT          = 0  OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)= '' OUTPUT
)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
     
   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT
         
         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_Loadkey         NVARCHAR(10) = ''
         
         , @c_Country_ST      NVARCHAR(30) = ''
         
   DECLARE @tCOO  TABLE 
      (     Code        NVARCHAR(30) NOT NULL DEFAULT('')
      ,     DESCRIPTION NVARCHAR(60) NOT NULL DEFAULT('')
      )      

   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1
   
   SELECT @c_Orderkey = ph.OrderKey
         ,@c_Loadkey  = ph.LoadKey
   FROM PickHeader AS ph WITH (NOLOCK)
   WHERE ph.PickHeaderkey = @c_Pickslipno
   
   IF @c_Orderkey = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = lpd.OrderKey
      FROM LoadPlanDetail AS lpd WITH (NOLOCK)
      WHERE lpd.LoadKey = @c_Loadkey
   END
   
   
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_Country_ST = ISNULL(s.Country,'')
      FROM STORER AS s WITH (NOLOCK)
      WHERE s.StorerKey = @c_Storerkey
      
      IF EXISTS ( SELECT 1
                  FROM ORDERS AS oh WITH (NOLOCK)
                  WHERE oh.OrderKey = @c_Orderkey
                  AND oh.C_Country = @c_Country_ST
      )
      BEGIN
         SET @b_Success = 2
         
         INSERT INTO @tCOO (Code, [DESCRIPTION])
         VALUES('', '')
         
         SELECT Code
               ,[DESCRIPTION] 
         FROM @tCOO
      END
   END
   
   QUIT_SP: 
 
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GetPKLAList01'
      RETURN
   END
   ELSE
   BEGIN
      IF @b_success <> 2 
      BEGIN
         SET @b_success = 1
      END
      
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END     
END -- End PROC

GO