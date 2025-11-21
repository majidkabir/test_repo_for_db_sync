SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_GetDFCarrierRef_Wrapper                        */
/* Creation Date: 2021-03-19                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving_Overall_CR     */
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
/* 2021-03-19  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_GetDFCarrierRef_Wrapper]
           @c_Receiptkey         NVARCHAR(10) = '' 
         , @c_TrackingNo         NVARCHAR(40) = '' 
         , @c_DefaultCarrierRef  NVARCHAR(18) = '' OUTPUT        
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT = @@TRANCOUNT
         , @n_Continue                 INT = 1
         , @c_SQL                      NVARCHAR(1000) = ''
         , @c_SQLParms                 NVARCHAR(1000) = ''
         
         , @c_Facility                 NVARCHAR(5) = ''
         , @c_Storerkey                NVARCHAR(15)= '' 
         
         , @c_RFIDGetDFCarrierRef_SP   NVARCHAR(30) = ''        

   SELECT @c_Facility  = R.Facility
         ,@c_Storerkey = R.Storerkey
   FROM RECEIPT AS r WITH (NOLOCK)
   WHERE r.ReceiptKey = @c_Receiptkey
   
   SELECT @c_RFIDGetDFCarrierRef_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'RFIDGetDFCarrierRef_SP')

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDGetDFCarrierRef_SP) AND [Type] = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQL = N'EXEC ' + @c_RFIDGetDFCarrierRef_SP
               +'  @c_Receiptkey       = @c_Receiptkey'    
               +', @c_TrackingNo       = @c_TrackingNo' 
               +', @c_DefaultCarrierRef= @c_DefaultCarrierRef OUTPUT'    

   SET @c_SQLParms= N'@c_ReceiptKey        NVARCHAR(10)'   
                  +', @c_TrackingNo        NVARCHAR(40)'
                  +', @c_DefaultCarrierRef NVARCHAR(18) OUTPUT'
                  --+', @b_Success           INT          OUTPUT'
                  --+', @n_Err               INT          OUTPUT'
                  --+', @c_ErrMsg            NVARCHAR(255)OUTPUT'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_ReceiptKey     
                     , @c_TrackingNo
                     , @c_DefaultCarrierRef  OUTPUT


QUIT_SP:
END -- procedure

GO