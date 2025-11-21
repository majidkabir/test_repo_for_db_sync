SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_NFC_GetReaderInfo                                   */
/* Creation Date: 2023-01-05                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-21467- [CN]NIKE_Ecom_NFC RFID Receiving-CR             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-01-05  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   PROC isp_NFC_GetReaderInfo
  @c_ComputerName       NVARCHAR(30) 
, @c_Storerkey          NVARCHAR(15)
, @n_ReceiveTimeOut     INT          = 0  OUTPUT   -- in miliseconds 
, @n_TimerIdleInterval  INT          = 0  OUTPUT   -- in seconds 
, @n_Reader_NFC         INT          = 0  OUTPUT   -- in seconds 
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
           @n_StartTCnt                INT = @@TRANCOUNT
         , @n_Continue                 INT = 1
         , @n_ReceiveTimeOut_Orig      INT = @n_ReceiveTimeOut
         , @n_TimerIdleInterval_Orig   INT = @n_TimerIdleInterval        

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @n_ReceiveTimeOut    = ISNULL(CLST.UDF01,5000) 
         ,@n_TimerIdleInterval = ISNULL(CLST.UDF02,600) -- 60 x 10 min = 600 seconds 
   FROM CODELIST CLST (NOLOCK)
   WHERE CLST.ListName = 'NFCReader'

   IF @n_ReceiveTimeOut IN ('', '0')
   BEGIN  
      SET @n_ReceiveTimeOut = @n_ReceiveTimeOut_Orig
   END 
   
   IF @n_ReceiveTimeOut IN ('', '0')
   BEGIN  
      SET @n_ReceiveTimeOut = 5000
   END 
   
   IF @n_TimerIdleInterval IN ('', '0')
   BEGIN   
      SET @n_TimerIdleInterval = @n_TimerIdleInterval_Orig
   END 

   IF @n_TimerIdleInterval IN ('', '0')
   BEGIN   
      SET @n_TimerIdleInterval = 600
   END 
   
   SET @n_Reader_NFC = 0
   IF EXISTS (SELECT 1 FROM dbo.CODELKUP AS c WITH (NOLOCK) 
              WHERE c.Listname = 'NFCReader'
              AND   c.Storerkey= @c_Storerkey
              AND   c.Code2 = @c_ComputerName
              )
   BEGIN
      SET @n_Reader_NFC = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_NFC_GetReaderInfo'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO