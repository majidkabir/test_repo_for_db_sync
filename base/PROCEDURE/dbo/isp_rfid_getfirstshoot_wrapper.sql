SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RFID_GetFirstShoot_Wrapper                          */
/* Creation Date: 28-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-22837 - [CN]NIKE_B2C_RFID Receiving_FIRST Shoot-CR     */
/*        :                                                             */
/* Called By: ue_ic_firstshoot_rule                                     */
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
CREATE   PROC [dbo].[isp_RFID_GetFirstShoot_Wrapper]
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

         , @c_RFIDGetFirstShoot_SP  NVARCHAR(30) = '' 
         
         , @c_SQL                   NVARCHAR(1000)= ''
         , @c_SQLParms              NVARCHAR(1000)= ''  
  
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF ISNULL(@c_Facility,'') = '' OR ISNULL(@c_StorerKey,'') = '' 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81005   
      SET @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': Facility and Storerkey is required to get First Shoot #. (isp_RFID_GetFirstShoot_Wrapper)'   
      GOTO QUIT_SP  
   END

   SET @c_RFIDGetFirstShoot_SP = ''

   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'RFIDGetFirstShoot_SP' 
      ,  @b_Success    = @b_Success                OUTPUT
      ,  @c_authority  = @c_RFIDGetFirstShoot_SP   OUTPUT 
      ,  @n_err        = @n_err                    OUTPUT
      ,  @c_errmsg     = @c_errmsg                 OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81010   
      SET @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_RFID_GetFirstShoot_Wrapper)'   
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   IF @c_RFIDGetFirstShoot_SP IN ('', '0')
   BEGIN
      GOTO QUIT_SP
   END
   ELSE
   BEGIN   
      IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDGetFirstShoot_SP) AND [Type] = 'P')
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81020   
         SET @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': Custom Stored Procedure:' + @c_RFIDGetFirstShoot_SP 
                       +' not found. (isp_RFID_GetFirstShoot_Wrapper)'   
         GOTO QUIT_SP
      END

      SET @b_Success = 1
      SET @c_SQL = N'EXEC ' + @c_RFIDGetFirstShoot_SP
                 +'  @c_Facility    = @c_Facility'    
                 +', @c_Storerkey   = @c_Storerkey' 
                 +', @c_FirstShoot  = @c_FirstShoot'
                 +', @b_Success     = @b_Success      OUTPUT'
                 +', @n_Err         = @n_Err          OUTPUT'
                 +', @c_ErrMsg      = @c_ErrMsg       OUTPUT'

      SET @c_SQLParms= N'@c_Facility   NVARCHAR(5)'   
                     +', @c_Storerkey  NVARCHAR(15)'
                     +', @c_FirstShoot NVARCHAR(100)'
                     +', @b_Success    INT            OUTPUT'
                     +', @n_Err        INT            OUTPUT'
                     +', @c_ErrMsg     NVARCHAR(255)  OUTPUT'

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Facility     
                        , @c_Storerkey   
                        , @c_FirstShoot
                        , @b_Success      OUTPUT
                        , @n_Err          OUTPUT
                        , @c_ErrMsg       OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81030   
         SET @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_RFIDGetFirstShoot_SP + '. (isp_RFID_GetFirstShoot_Wrapper)'   
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP  
      END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_GetFirstShoot_Wrapper'
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