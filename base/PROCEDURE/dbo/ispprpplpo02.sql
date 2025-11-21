SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPRPPLPO02                                            */
/* Creation Date: 25-SEP-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6038 - H&M Populate PO validate PO.Termsnote = '1'      */
/*        :                                                             */
/* Called By:  isp_PrePopulatePO_Wrapper                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPRPPLPO02]
           @c_Receiptkey      NVARCHAR(10)
         , @c_POKeys          NVARCHAR(MAX)
         , @c_POLineNumbers   NVARCHAR(MAX) = ''
         , @b_Success         INT OUTPUT    
         , @n_Err             INT OUTPUT
         , @c_Errmsg          NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
          ,@n_Continue           INT
          ,@c_POKey              NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   CREATE TABLE #PREPPL_PO
      (  SeqNo          INT
      ,  POKey          NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  POLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
      )

   INSERT INTO #PREPPL_PO
      (  SeqNo
      ,  POKey
      )     
   SELECT SeqNo
      ,   ColValue
   FROM dbo.fnc_DelimSplit (',', @c_POKeys)
   
   IF @c_POLineNumbers <> ''
   BEGIN
      UPDATE #PREPPL_PO
      SET POLineNumber = ColValue
      FROM dbo.fnc_DelimSplit (',', @c_POLineNumbers) T
      WHERE #PREPPL_PO.SeqNo = T.SeqNo
   END

   SET @c_POKey = ''
   SELECT TOP 1 @c_POKey = PO.POKey
   FROM #PREPPL_PO
   JOIN PO WITH (NOLOCK) ON (#PREPPL_PO.POKey = PO.POKey)
   WHERE PO.TermsNote <> '1' 

   IF ISNULL(@c_POKey,'') <> ''            
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': PO# ' + RTRIM(@c_POKey) + ' TermsNote value is not 1 cannot populate to ASN. (ispPRPPLPO02)'  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRPPLPO02'
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