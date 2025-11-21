SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispMBPRF01                                                  */
/* Creation Date: 25-JUN-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Dummy default STD SP.Will deploy to all db together with ML */
/*        : (SOS#346256 - Project Merlion - Mbol Case Count Add On)     */
/*        : Who required need to enable and test before go live         */
/* Called By: ispPreRefreshWrapper                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispMBPRF01] 
            @c_MBOLKey     NVARCHAR(10) 
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 


         , @n_CustCnt         INT
         , @n_Casecnt         FLOAT
         , @n_PalletCnt       FLOAT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   BEGIN TRAN
  
QUIT:
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispMBPRF01'
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