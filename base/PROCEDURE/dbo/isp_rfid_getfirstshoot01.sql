SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RFID_GetFirstShoot01                                */
/* Creation Date: 28-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-22837 - [CN]NIKE_B2C_RFID Receiving_FIRST Shoot-CR     */
/*        :                                                             */
/* Called By: isp_RFID_GetFirstShoot_Wrapper                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-Jun-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RFID_GetFirstShoot01]
           @c_Facility           NVARCHAR(5)  
         , @c_Storerkey          NVARCHAR(15) 
         , @c_FirstShoot         NVARCHAR(100)
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT = @@TRANCOUNT
         , @n_Continue              INT = 1
         , @c_PassFlag              NVARCHAR(10)= 'TRUE'

   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF NOT EXISTS ( SELECT 1
                   FROM RDT.rdtDataCapture R WITH (NOLOCK)
                   WHERE R.V_String1 = @c_FirstShoot)
   BEGIN
      SET @c_PassFlag = 'FALSE'
      SET @n_Continue = 3
      SET @n_err = 81005
      SET @c_errmsg = N'NSQL'+CONVERT(CHAR(5),@n_err) + N': 快递没交接. (isp_RFID_GetFirstShoot01)'   
   END

   INSERT INTO dbo.DocInfo (TableName, Key1, Key2, Key3, StorerKey, LineSeq, DataType, StoredProc)
   VALUES (N'FIRSTSCAN'
         , @c_FirstShoot
         , @c_PassFlag
         , N''
         , @c_Storerkey
         , 1
         , N'STRING'
         , N'isp_RFID_GetFirstShoot01'
   )

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81010   
      SET @c_errmsg ='NSQL'+CONVERT(CHAR(5),@n_err)+': Error Inserting DocInfo. (isp_RFID_GetFirstShoot01)'   
      GOTO QUIT_SP  
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_GetFirstShoot01'
   END
   ELSE
   BEGIN
      IF @b_Success <> 2
         SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO