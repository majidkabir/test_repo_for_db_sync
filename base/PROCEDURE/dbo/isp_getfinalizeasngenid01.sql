SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetFinalizeASNGenID01                               */
/* Creation Date: 2022-06-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19894 -CN EXCEED CONVERSE RECEIPT NOT AUTO GENERATE TOID*/
/*        :                                                             */
/* Called By: isp_GetFinalizeASNGenID_Wrapper                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-06-15  Wan      1.0   Created & DevOps Combine Script.          */
/************************************************************************/
CREATE PROC [dbo].[isp_GetFinalizeASNGenID01]
  @c_ReceiptKey         NVARCHAR(255)
, @c_GenID              NVARCHAR(10)         OUTPUT
, @c_RF_Enable          NVARCHAR(10)         OUTPUT
, @b_Success            INT            = 1   OUTPUT
, @n_Err                INT            = 0   OUTPUT
, @c_ErrMsg             NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT            = @@TRANCOUNT
         , @n_Continue           INT            = 1 
         
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Facility           NVARCHAR(5)    = ''
         
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   IF EXISTS ( SELECT 1
               FROM dbo.RECEIPT AS r WITH (NOLOCK)
               WHERE r.ReceiptKey = @c_ReceiptKey
               AND r.UserDefine02 = 'B2C'
               AND r.ExternReceiptKey LIKE 'LF%'
             )
   BEGIN
      SET @c_GenID = '0'         --When 1: Gen ID
      SET @c_RF_Enable = '1'     --When 0: Gen ID
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetFinalizeASNGenID01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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