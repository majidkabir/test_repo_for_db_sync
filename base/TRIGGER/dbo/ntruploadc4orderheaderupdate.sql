SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrUploadC4OrderHeaderUpdate                                */
/* Creation Date: 11-Apr-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose: Trigger related Update in UploadC4OrderHeader table.        */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Interface                                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 11-Apr-2014  Leong     1.0   SOS308367 - Created.                    */
/************************************************************************/

CREATE TRIGGER ntrUploadC4OrderHeaderUpdate
ON  UploadC4OrderHeader
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
         , @n_Err       INT
         , @c_ErrMsg    NVARCHAR(250)
         , @n_Continue  INT
         , @n_StartTCnt INT
         , @n_Cnt       INT

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      UPDATE UploadC4OrderHeader
         SET EditDate = GETDATE()
           , EditWho  = SUSER_SNAME()
      FROM UploadC4OrderHeader
      JOIN INSERTED
        ON UploadC4OrderHeader.OrderKey = INSERTED.OrderKey

      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 68802
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))
                          + ': Update Failed On Table UploadC4OrderHeader. (ntrUploadC4OrderHeaderUpdate) ( SQLSvr MESSAGE='
                          + ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' )'
      END
   END
END

GO