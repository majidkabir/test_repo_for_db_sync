SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: dbo.fnc_ASNExceptionGetOverdue                             */
/* Creation Date: 12-MAY-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-16957 - [CN]Nike_Phoeix_B2C_Exceed_Exception_Tracking  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver Purposes                                   */
/* 2021-05-12  Wan      1.0   Created                                   */
/* 2021-10-21  Wan01    1.1   WMS-18121 - [CN]Nike_Phoeix_B2C_Exceed_   */
/*                            Exception_Tracking-CR                     */
/* 23-Apr-2024 WLChooi  1.2   WMS-25317 - Return Receipt.Signatory(WL01)*/
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_ASNExceptionGetOverdue] 
(
   @n_RowRef      BIGINT
,  @c_documentno  NVARCHAR(10)
)
RETURNS @t_Overdue TABLE  
(  RowRef            BIGINT
,  Documentno        NVARCHAR(10)
,  [Status]          NVARCHAR(20)
,  Message_Pass      NVARCHAR(20)
,  Signatory         NVARCHAR(50)   --WL01
)       
AS
BEGIN   
   DECLARE  
           @c_Receiptkey      NVARCHAR(10)   = ''
         , @c_Overdue         NVARCHAR(20)   = ''
         , @dt_Userdefine06   DATETIME    
         
         , @c_UserDefine02    NVARCHAR(30)   = '' 
         , @c_Message_Pass    NVARCHAR(20)   = ''
         , @c_Signatory       NVARCHAR(50)   = ''   --WL01

   SELECT TOP 1 @c_ReceiptKey = di.Key1 
   FROM DocStatusTrack AS dst WITH (NOLOCK)  
   JOIN DocInfo AS di WITH (NOLOCK) ON di.TableName  = 'RECEIPT'
                                       AND di.Key3 = dst.Userdefine01
                                       AND di.StorerKey = dst.Storerkey
   WHERE dst.RowRef = @n_RowRef
   AND dst.DocumentNo= @c_DocumentNo
   AND dst.TableName = 'ASNException'
   ORDER BY di.AddDate DESC
   
   SELECT @dt_Userdefine06 = r.UserDefine06
         ,@c_UserDefine02 = ISNULL(r.UserDefine02,'')
         ,@c_Signatory = ISNULL(r.Signatory,'')   --WL01
   FROM RECEIPT AS r WITH (NOLOCK)
   WHERE r.ReceiptKey = @c_ReceiptKey

   IF DATEDIFF(DAY, @dt_Userdefine06, GETDATE()) > 0 
   BEGIN
      SET @c_Overdue = N'加急！'
   END
   
   IF @c_UserDefine02 = 'Y'         --(Wan02)
   BEGIN
      SET @c_Message_Pass = N'绿通'    
   END

   EXIT_FUNCTION: 
   INSERT INTO @t_Overdue ( RowRef, DocumentNo, [Status], Message_Pass, Signatory )   --WL01
   VALUES ( @n_RowRef, @c_DocumentNo, @c_Overdue, @c_Message_Pass, @c_Signatory )     --WL01

   RETURN
END -- procedure

GO