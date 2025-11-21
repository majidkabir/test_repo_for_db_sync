SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_GetAllowASNStatusChg                                   */
/* Creation Date: 2024-01-29                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-14379-Implement pre-save ASN standard validation check  */ 
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* V2 GIT Version: 1.0                                                  */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */  
/* 2024-01-29  Wan      1.0   Initial Creation                          */
/* 2024-02-07  Wan      1.0   UWP-14770-Reverse receipt                 */
/* **********************************************************************/    
CREATE   FUNCTION [dbo].[fnc_GetAllowASNStatusChg]
(
   @c_Facility    NVARCHAR(5) 
,  @c_StorerKey   NVARCHAR(15) 
,  @c_Type        NVARCHAR(10)
,  @c_ReceiptKey  NVARCHAR(10)
,  @c_ChangeFrom  NVARCHAR(30)
,  @c_ChangeTo    NVARCHAR(30)
)
RETURNS @tCodelkup TABLE  
(  AllowChange    INT
)       
AS
BEGIN   
   DECLARE @n_Cnt                   INT          = 0
         , @n_AllowChange           INT          = 1
         , @c_DocTypes              NVARCHAR(60) = ''
         , @c_ASNStatusCheckBySTR   NVARCHAR(10) = '0'

   SET @c_ASNStatusCheckBySTR = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ASNStatusCheckByStorer')
   
   IF @c_ASNStatusCheckBySTR IN ('0', '') SET @c_Storerkey = ''
   SET @n_Cnt = 0
   SELECT TOP 1 
         @n_Cnt = 1
      ,@c_DocTypes = c.UDF01
   FROM dbo.Codelkup c (NOLOCK)
   WHERE c.ListName = 'ASNStatChk'
   AND c.UDF02 IN (@c_ChangeFrom, '')
   AND c.UDF03 IN (@c_ChangeTo, '')
   AND c.Storerkey = @c_Storerkey
   ORDER BY c.Code

   IF @n_Cnt = 1
   BEGIN
      IF @c_DocTypes = '' SET @c_DocTypes = 'A,R,X' 
      IF CHARINDEX( @c_Type, @c_DocTypes, 1) > 0   SET @n_AllowChange = 0
   END

   --System default checks below change to 0/1 condition and overwrite codelkup setup if any
   IF @c_ChangeTo = '1'                                                               --(Wan)-START
   BEGIN
      SET @n_AllowChange = 0
      SELECT TOP 1 @n_AllowChange = 1
      FROM dbo.RECEIPTDETAIL r(NOLOCK)
      WHERE r.ReceiptKey = @c_ReceiptKey
      AND r.BeforeReceivedQty > 0
   END

   IF @c_ChangeTo = '0' 
   BEGIN
      SET @n_AllowChange = 1
      SELECT TOP 1 @n_AllowChange = 0
      FROM dbo.RECEIPTDETAIL r(NOLOCK)
      WHERE r.ReceiptKey = @c_ReceiptKey
      AND  (r.BeforeReceivedQty > 0 OR r.QtyReceived > 0 OR r.FinalizeFlag = 'Y')
   END                                                                              --(Wan)-END

   EXIT_FUNCTION: 
   INSERT INTO @tCodelkup ( AllowChange ) 
   VALUES ( @n_AllowChange )

   RETURN
END   

GO