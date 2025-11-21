SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetFinalizeASNGenID_Wrapper                         */
/* Creation Date: 2022-06-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19894 -CN EXCEED CONVERSE RECEIPT NOT AUTO GENERATE TOID*/
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_GetFinalizeASNGenID_Wrapper]
  @c_ReceiptKey         NVARCHAR(255)
, @c_MUID_Enable        NVARCHAR(30)         OUTPUT
, @c_GenID              NVARCHAR(30)         OUTPUT
, @c_RF_Enable          NVARCHAR(30)         OUTPUT
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
         
         , @c_Option5_GenID      NVARCHAR(4000) = ''
         , @c_Option5_RFEnable   NVARCHAR(4000) = ''   
         
         , @c_GetGenID_SP        NVARCHAR(50) = ''
         , @c_GetRFEnable_SP     NVARCHAR(50) = ''
         
         , @c_SQL                NVARCHAR(4000) = ''     
         , @c_SQLParms           NVARCHAR(4000) = ''  
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SELECT @c_Facility  = r.Facility
         ,@c_Storerkey = r.Storerkey
   FROM dbo.RECEIPT AS r WITH (NOLOCK)
   WHERE r.ReceiptKey = @c_ReceiptKey
   
   SET @c_MUID_Enable = ''
   SET @c_GenID = ''
   SET @c_RF_Enable = ''
   
   SELECT @c_MUID_Enable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MUID_Enable')
   SELECT @c_GenID = fgr.Authority, @c_Option5_GenID = fgr.Option5 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'GenID') AS fgr
   SELECT @c_RF_Enable = fgr.Authority, @c_Option5_RFEnable = fgr.Option5  FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'RF_Enable') AS fgr
   
   SELECT @c_GetGenID_SP = dbo.fnc_GetParamValueFromString('@c_StoredProcName', @c_Option5_GenID, @c_GetGenID_SP) 
   SELECT @c_GetRFEnable_SP = dbo.fnc_GetParamValueFromString('@c_StoredProcName', @c_Option5_RFEnable, @c_GetRFEnable_SP) 
 
   IF @c_GenID = '1' AND @c_GetGenID_SP <> '' AND
      EXISTS (SELECT 1 FROM sys.objects AS o (NOLOCK) WHERE SCHEMA_NAME(o.[schema_id]) = 'dbo' AND o.[name] = @c_GetGenID_SP AND o.[type] = 'P')
   BEGIN
      SET @b_Success = 1
      SET @c_SQL = N'EXEC ' + @c_GetGenID_SP
                 +'  @c_ReceiptKey = @c_ReceiptKey'
                 +', @c_GenID      = @c_GenID      OUTPUT'
                 +', @c_RF_Enable  = @c_RF_Enable  OUTPUT'
                 +', @b_Success    = @b_Success    OUTPUT'
                 +', @n_Err        = @n_Err        OUTPUT'
                 +', @c_ErrMsg     = @c_ErrMsg     OUTPUT'

      SET @c_SQLParms= N'@c_ReceiptKey       NVARCHAR(10)'
                     +', @c_GenID            NVARCHAR(10) OUTPUT'
                     +', @c_RF_Enable        NVARCHAR(10) OUTPUT'
                     +', @b_Success          INT          OUTPUT'
                     +', @n_Err              INT          OUTPUT'
                     +', @c_ErrMsg           NVARCHAR(255)OUTPUT'

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_ReceiptKey        
                        , @c_GenID        OUTPUT
                        , @c_RF_Enable    OUTPUT
                        , @b_Success      OUTPUT
                        , @n_Err          OUTPUT
                        , @c_ErrMsg       OUTPUT
   END   
   
   IF @c_GenID = '1' AND @c_GetGenID_SP <> '' AND @c_GetGenID_SP = @c_GetRFEnable_SP
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_RF_Enable = '0' AND @c_GetRFEnable_SP <> '' AND
      EXISTS (SELECT 1 FROM sys.objects AS o (NOLOCK) WHERE SCHEMA_NAME(o.[schema_id]) = 'dbo' AND o.[name] = @c_GetRFEnable_SP AND o.[type] = 'P')
   BEGIN
      SET @b_Success = 1
      SET @c_SQL = N'EXEC ' + @c_GetRFEnable_SP
                 +'  @c_ReceiptKey = @c_ReceiptKey'
                 +', @c_GenID      = @c_GenID      OUTPUT'
                 +', @c_RF_Enable  = @c_RF_Enable  OUTPUT'
                 +', @b_Success    = @b_Success    OUTPUT'
                 +', @n_Err        = @n_Err        OUTPUT'
                 +', @c_ErrMsg     = @c_ErrMsg     OUTPUT'

      SET @c_SQLParms= N'@c_ReceiptKey       NVARCHAR(10)'
                     +', @c_GenID            NVARCHAR(10) OUTPUT'
                     +', @c_RF_Enable        NVARCHAR(10) OUTPUT'
                     +', @b_Success          INT          OUTPUT'
                     +', @n_Err              INT          OUTPUT'
                     +', @c_ErrMsg           NVARCHAR(255)OUTPUT'

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_ReceiptKey        
                        , @c_GenID        OUTPUT
                        , @c_RF_Enable    OUTPUT
                        , @b_Success      OUTPUT
                        , @n_Err          OUTPUT
                        , @c_ErrMsg       OUTPUT
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetFinalizeASNGenID_Wrapper'
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