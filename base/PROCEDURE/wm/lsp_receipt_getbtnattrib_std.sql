SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Receipt_GetBTNAttrib_Std                        */  
/* Creation Date: 09-MAR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1056 - Stored procedure - to enabledisable action button*/
/*          based document statusconfigkey                               */
/*                                                                       */  
/* Called By: WM.lsp_GetModuleButtonAttrib_Wrapper                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Receipt_GetBTNAttrib_Std]  
   @c_ButtonFunc  NVARCHAR(30) 
,  @c_Dockey1     NVARCHAR(50)
,  @c_Dockey2     NVARCHAR(50) = ''
,  @c_Dockey3     NVARCHAR(50) = ''
,  @c_Dockey4     NVARCHAR(50) = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT = 1
         , @n_StartTCnt             INT = @@TRANCOUNT

         , @b_Success               INT = 1
         , @n_err                   INT = 0
         , @c_errmsg                NVARCHAR(255) = ''
         
         , @n_Count                 INT
         , @n_CountHdr              INT = 0
         , @n_CountDet              INT = 0
         , @n_Enabled               BIT = NULL 

         , @c_Facility              NVARCHAR(5)  = ''
         , @c_Storerkey             NVARCHAR(15) = ''
         , @c_RecType               NVARCHAR(10) = ''
         , @c_Status                NVARCHAR(10) = ''
         , @c_ASNStatus             NVARCHAR(10) = ''

         , @c_Receiptkey            NVARCHAR(10) = ''
         , @c_ReceiptLineNumber     NVARCHAR(3)  = ''
         , @c_FinalizeFlag          NVARCHAR(10) = 'N'

         , @b_DependentFuncCheck    INT          = 0
         , @n_RowID                 INT          = 0
         
         , @c_AllowRefinalizeASN    NVARCHAR(30) = ''  
         , @c_CloseASNStatus        NVARCHAR(30) = ''  

   CREATE TABLE #TMP_NEXTBTNFUNC
      (
         RowID          INT            IDENTITY (1,1)    PRIMARY KEY
      ,  ButtonFunc     NVARCHAR(30)   NOT NULL DEFAULT ('')
      )

   SET @c_Receiptkey = @c_Dockey1
   SET @c_ReceiptLineNumber = @c_Dockey2
   
   --(mingle01) - START
   BEGIN TRY
      SELECT @n_CountHdr = 1
            ,@c_Facility = RH.Facility    
            ,@c_Storerkey= RH.Storerkey
            ,@c_RecType  = RH.RecType
            ,@c_Status   = RH.[Status]
            ,@c_ASNStatus= RH.ASNStatus
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.Receiptkey = @c_Receiptkey

      IF ISNULL(RTRIM(@c_ReceiptLineNumber),'') <> ''
      BEGIN
         SELECT @n_CountDet = 1
         FROM RECEIPTDETAIL RD WITH (NOLOCK)
         WHERE RD.Receiptkey = @c_Receiptkey
         AND   RD.ReceiptLineNumber = @c_ReceiptLineNumber
      END

      IF @n_CountHdr = 0
      BEGIN
         GOTO EXIT_SP
      END

      NEXT_BTNFUNC:
      IF @c_ButtonFunc = 'finalizereceipt'
      BEGIN
         SET @c_FinalizeFlag = 'Y'

         IF @c_ASNStatus <> '9' AND @c_ASNStatus <> 'CANC' AND @c_Status = '0'
         BEGIN 
            SET @c_FinalizeFlag = 'N'
         END 

         BEGIN TRY
            EXECUTE dbo.nspGetRight 
                  @c_facility  = @c_Facility
               ,  @c_storerkey = @c_Storerkey 
               ,  @c_sku       = NULL
               ,  @c_configkey = 'AllowRefinalizeASN'
               ,  @b_Success   = @b_Success              OUTPUT
               ,  @c_authority = @c_AllowRefinalizeASN   OUTPUT
               ,  @n_err       = @n_err                  OUTPUT
               ,  @c_errmsg    = @c_errmsg               OUTPUT 
         END TRY

         BEGIN CATCH
            SET @n_err = 551351
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - AllowRefinalizeASN'
                           + '. (lsp_Receipt_GetBTNAttrib_Std)'

            GOTO EXIT_SP
         END CATCH

         IF @c_AllowRefinalizeASN = '1'
         BEGIN
            SET @c_FinalizeFlag = ''

            SELECT TOP 1 @c_FinalizeFlag = RD.FinalizeFlag
            FROM RECEIPTDETAIL RD (NOLOCK)
            WHERE RD.Receiptkey = @c_Receiptkey
            ORDER BY RD.FinalizeFlag
      
            BEGIN TRY
               EXECUTE dbo.nspGetRight 
                     @c_facility  = @c_Facility
                  ,  @c_storerkey = @c_Storerkey 
                  ,  @c_sku       = NULL
                  ,  @c_configkey = 'CloseASNStatus'
                  ,  @b_Success   = @b_Success        OUTPUT
                  ,  @c_authority = @c_CloseASNStatus OUTPUT
                  ,  @n_err       = @n_err            OUTPUT
                  ,  @c_errmsg    = @c_errmsg         OUTPUT 
            END TRY

            BEGIN CATCH
               SET @n_err = 551352
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - CloseASNStatus'
                              + '. (lsp_Receipt_GetBTNAttrib_Std)'

               GOTO EXIT_SP
            END CATCH

            IF @c_CloseASNStatus = '1' AND @c_FinalizeFlag = 'Y' AND @c_ASNStatus = '0'
            BEGIN
               SET @c_FinalizeFlag = 'N'
            END
         END
         
         SET @n_Enabled = 0
         IF @c_FinalizeFlag = 'N'
         BEGIN
            SET @n_Enabled = 1
         END

         SET @b_DependentFuncCheck = 1 -- DO NOT Initial it at the Next Button Function Logic

         SET @n_RowID = 0  -- DO NOT Initial it at the Next Button Function Logic
         INSERT #TMP_NEXTBTNFUNC (ButtonFunc)
         VALUES ('holdreceivedlot')

         INSERT #TMP_NEXTBTNFUNC (ButtonFunc)
         VALUES ('createshipmentorder')
      END

      IF @c_ButtonFunc = 'holdreceivedlot'
      BEGIN
         IF @b_DependentFuncCheck = 0
         BEGIN
            GOTO EXIT_SP
         END

         SET @n_Enabled = 0

         IF @c_FinalizeFlag = 'Y'
         BEGIN
            SET @n_Enabled = 1
         END
      END

      IF @c_ButtonFunc = 'createshipmentorder'
      BEGIN
         IF @b_DependentFuncCheck = 0
         BEGIN
            GOTO EXIT_SP
         END

         SET @n_Enabled = 1

         IF @c_FinalizeFlag = 'N' AND @c_ASNStatus <> '9'
         BEGIN
            SET @n_Enabled = 0
         END
      END

      IF @c_ButtonFunc IN ( 'populatefrompos', 'populatepodetail', 'populatemultipotoasn')
      BEGIN
         SET @n_Count = 0
         SELECT TOP 1 @n_Count = 1
         FROM RECEIPTDETAIL RD (NOLOCK)
         WHERE RD.Receiptkey = @c_Receiptkey
         AND RD.Finalizeflag = 'Y'

         SET @n_Enabled = 0

         IF @n_Count = 0 AND @c_ASNStatus <> '9' AND @c_ASNStatus <> 'CANC'
         BEGIN
            SET @n_Enabled = 1   
         END
      END

      IF @c_ButtonFunc = 'createorder'
      BEGIN
         SET @n_Enabled = 0

         IF @c_RecType NOT IN ('NORMAL', 'RPO', 'RRB', 'TBLRRP')
         BEGIN
            IF @c_ASNStatus = '9'
            BEGIN
               SET @n_Enabled = 1
            END
         END
      END

      IF @c_ButtonFunc IN ( 'populatefromorder', 'populateorderdetail')
      BEGIN
         SET @n_Enabled = 0

         IF @c_RecType NOT IN ('NORMAL', 'RPO', 'RRB', 'TBLRRP')
         BEGIN
            IF @c_ASNStatus < '9'
            BEGIN
               SET @n_Enabled = 1
            END
         END
      END

      IF @n_Enabled IN (0,1)
      BEGIN
         INSERT INTO #TMP_BUTTONATTRIB
            (
               ButtonFunc
            ,  [Enabled]
            )
         VALUES 
            (  
               @c_ButtonFunc
            ,  @n_Enabled
            )
      END

      SELECT TOP 1 
            @n_RowID = RowID
         ,  @c_ButtonFunc = ButtonFunc
      FROM #TMP_NEXTBTNFUNC
      WHERE RowID > @n_RowID
      ORDER BY RowID

      IF @n_RowID > 0 AND @@ROWCOUNT > 0
      BEGIN
         GOTO NEXT_BTNFUNC
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      TRUNCATE TABLE #TMP_BUTTONATTRIB
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:

   DROP TABLE #TMP_NEXTBTNFUNC
END  

GO