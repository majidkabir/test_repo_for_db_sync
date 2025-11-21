SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_TRF_SG_UPDSTATUS                           */
/* Creation Date: 07-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22937 - SG - Multi Storer - Transfer Finalization       */
/*                                                                      */
/* Called By: Transfer Dynamic RCM configure at listname 'RCMConfig'    */
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
/* Date         Author    Ver.  Purposes                                */
/* 07-Jul-2023  WLChooi   1.0   DevOps Scripts Combine                  */
/* 14-Jul-2023  WLChooi   1.1   Bug Fix for WMS-22937 (WL01)            */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RCM_TRF_SG_UPDSTATUS]
   @c_Transferkey NVARCHAR(10)
 , @b_Success     INT           OUTPUT
 , @n_Err         INT           OUTPUT
 , @c_Errmsg      NVARCHAR(225) OUTPUT
 , @c_code        NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT
         , @n_cnt       INT
         , @n_Starttcnt INT

   DECLARE @c_Facility                    NVARCHAR(5)
         , @c_Storerkey                   NVARCHAR(15)
         , @n_Authorised                  INT = 0
         , @c_AllowTranType               NVARCHAR(500) = ''
         , @c_AllowStatus                 NVARCHAR(10) = '9'
         , @c_TranferStatus               NVARCHAR(10) = ''
         , @c_Username                    NVARCHAR(100) = ''
         , @c_TransferType                NVARCHAR(50) = ''

   SELECT @n_Continue = 1
        , @b_Success = 1
        , @n_Starttcnt = @@TRANCOUNT
        , @c_Errmsg = ''
        , @n_Err = 0
        , @c_Username = SUSER_SNAME()

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      --Get transfer info
      SELECT @c_TransferType = TRF.[Type]
           , @c_TranferStatus = TRF.[Status]
           , @c_Facility = TRF.Facility
           , @c_Storerkey = TRF.FromStorerKey
      FROM [dbo].[TRANSFER] TRF (NOLOCK)
      WHERE TRF.TransferKey = @c_Transferkey

      IF EXISTS ( SELECT 1
                  FROM CODELKUP (NOLOCK)
                  WHERE LISTNAME = 'TRRCM_AUTH'
                  AND Short = 'UNFINZ'
                  AND Storerkey = @c_Storerkey
                  --AND Code LIKE '%' + @c_Username + '%' )   --WL01
                  AND @c_Username LIKE '%' + Code + '%' )   --WL01
      BEGIN
         SET @n_Authorised = 1
      END
      ELSE
      BEGIN
         SET @n_Authorised = 0
         SELECT @n_Continue = 3
         SELECT @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 82000 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': User: ' + @c_Username + ' is unauthorised. (isp_RCM_TRF_SG_UPDSTATUS)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
         GOTO ENDPROC
      END

      SELECT @c_AllowTranType = STUFF(( SELECT ',' + TRIM(Code) 
                                        FROM CODELKUP (NOLOCK) 
                                        WHERE LISTNAME = 'TRUNF_TYPE' 
                                        AND Storerkey = @c_Storerkey 
                                        ORDER BY Code FOR XML PATH('')),1,1,'' )

      IF EXISTS ( SELECT 1
                  FROM STRING_SPLIT(@c_AllowTranType, ',') SS
                  WHERE SS.[value] = @c_TransferType )
      BEGIN
         SET @n_Authorised = 1
      END
      ELSE
      BEGIN
         SET @n_Authorised = 0
         SELECT @n_Continue = 3
         SELECT @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 82010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Transfer Type: ' + @c_TransferType + '. (isp_RCM_TRF_SG_UPDSTATUS)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
         GOTO ENDPROC
      END

      IF @c_TranferStatus = @c_AllowStatus
      BEGIN
         SET @n_Authorised = 1
      END
      ELSE
      BEGIN
         SET @n_Authorised = 0
         SELECT @n_Continue = 3
         SELECT @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 82020 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Status <> ''9''. (isp_RCM_TRF_SG_UPDSTATUS)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
         GOTO ENDPROC
      END

      IF @n_Authorised = 1
      BEGIN
         UPDATE [dbo].[TRANSFER]
         SET [Status] = '1'
           , TrafficCop = NULL
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         WHERE TransferKey = @c_Transferkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_Errmsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 82030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update Transfer Failed. (isp_RCM_TRF_SG_UPDSTATUS)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
            GOTO ENDPROC
         END
      END
   END

   ENDPROC:

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_Starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_Starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_Errmsg, 'isp_RCM_TRF_SG_UPDSTATUS'
      RAISERROR(@c_Errmsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_Starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC

GO