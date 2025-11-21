SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispUAUCC01                                                  */
/* Creation Date: 20-Apr-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#337957 - ANF - CR on unallocation logic (for handling   */
/*          shared UCC in multiple orders)                              */
/* Called By: ntrPickdetaildelete Trigger when StorerConfig             */
/*            UnAllocUCCPickCode is setup                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 06/10/2016   TLTING    1.1 ADD NOLOCK                                */
/* 07/09/2017   Leong     1.2 IN00459369 - Add StorerKey.               */
/************************************************************************/

CREATE PROC [dbo].[ispUAUCC01]
(   @c_Storerkey  NVARCHAR(15)
  , @b_Success    INT           OUTPUT
  , @n_Err        INT           OUTPUT
  , @c_ErrMsg     NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT
         , @n_StartTCount        INT

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   SET @b_Debug   = '0'
   SET @n_Continue= 1
   SET @n_StartTCount = @@TRANCOUNT


   BEGIN TRAN

   UPDATE UCC SET STATUS = '1'
      ,UCC.PickdetailKey = ''
      ,UCC.OrderKey = ''
      ,UCC.OrderLineNumber = ''
      ,UCC.WaveKey = ''
   FROM UCC U
   WHERE  U.Storerkey = @c_Storerkey
   AND    U.Status > '2' AND U.Status < '6'
   AND    EXISTS (SELECT 1 FROM #D_PICKDETAIL d WHERE d.DropID = U.UCCNo AND d.Storerkey = @c_Storerkey AND d.Status < '9') -- IN00459369
   AND    NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) WHERE PD.DropID = U.UCCNo AND PD.Storerkey = @c_Storerkey AND PD.Status < '9') -- IN00459369

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      Execute nsp_logerror @n_err, @c_errmsg, 'ispUAUCC01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END

      RETURN
   END
END

GO