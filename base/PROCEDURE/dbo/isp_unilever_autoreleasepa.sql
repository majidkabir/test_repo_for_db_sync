SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_UNILEVER_AutoReleasePA                            */
/* Creation Date: 06-Jul-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-20157 - MYS ULM Auto Release PA Task and Pallet Label      */
/*                                                                         */
/* Called By: SQL Backend Job every 5 minutes                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 06-Jul-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 15-Feb-2023  WLChooi 1.1   WMS-21739 Codelkup to enable/disable print   */
/*                            label (WL01)                                 */
/* 01-Mar-2023  WLChooi 1.2   WMS-21739 Filter out old ASN and skip print  */
/*                            if user not found (WL02)                     */
/* 22-Mar-2023  WLChooi 1.3   WMS-21739 Continue despite error (WL03)      */
/***************************************************************************/
CREATE   PROC [dbo].[isp_UNILEVER_AutoReleasePA]
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success             INT,
           @n_Err                 INT,
           @c_ErrMsg              NVARCHAR(255),
           @n_Continue            INT,
           @n_StartTranCount      INT

   DECLARE  @c_Storerkey          NVARCHAR(15) 
           ,@c_ReceiptLineNumber  NVARCHAR(5)
           ,@c_Receiptkey         NVARCHAR(10)
           ,@c_ReceivingLBL_DW    NVARCHAR(50)
           ,@c_UserName           NVARCHAR(128)

   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT
   
   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN

   IF @n_continue IN(1,2)
   BEGIN      
      SET @c_Storerkey = 'UNILEVER'
      --SET @c_UserName = 'ULVPALABEL'   --WL01
      
      SELECT TOP 1 @c_ReceivingLBL_DW = PB_Datawindow
      FROM RCMREPORT (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND ReportType = 'POSTRECV'
      ORDER BY EditDate DESC   
   END   
   
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_ASN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT RD.Receiptkey, RD.ReceiptLineNumber, RD.EditWho  --WL01
         FROM RECEIPT R (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
         WHERE R.StorerKey = @c_Storerkey
         AND R.DOCTYPE = 'A'
         AND RD.FinalizeFlag = 'Y'
         AND RD.PutawayLoc = ''
         AND R.ASNStatus <> '9'   --WL02
         ORDER BY RD.Receiptkey, RD.ReceiptLineNumber
        
      
      OPEN CUR_ASN
      
      FETCH NEXT FROM CUR_ASN INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_UserName   --WL01
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN   
         EXEC [dbo].[ispPARL06] @c_ReceiptKey        = @c_Receiptkey,           
                                @b_Success           = @b_Success  OUTPUT,
                                @n_err               = @n_err      OUTPUT,        
                                @c_errmsg            = @c_errmsg   OUTPUT,
                                @c_ReceiptLineNumber = @c_ReceiptLineNumber
         
         --WL03 S
         IF @b_Success <> 1
         BEGIN
            --SELECT @n_continue = 3
            --GOTO QUIT_SP
            GOTO NEXT_LOOP
         END  
         --WL03 E

         --WL02 S
         IF NOT EXISTS (SELECT 1
                        FROM RDT.RDTUSER (NOLOCK)
                        WHERE UserName = @c_UserName)
         BEGIN
            GOTO NEXT_LOOP
         END
         --WL02 E
         
         --WL01 S
         IF EXISTS (SELECT 1
                    FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Listname = 'ULVPALABEL'
                    AND CL.Code = 'LABEL'
                    AND CL.Storerkey = @c_Storerkey
                    AND CL.Short = 'Y')
         BEGIN
            --Print Receiving Label
            EXEC [dbo].[isp_PrintToRDTSpooler]
                 @c_ReportType     = 'PALABEL',
                 @c_Storerkey      = @c_Storerkey,
                 @b_success        = @b_Success OUTPUT,
                 @n_err            = @n_err     OUTPUT,
                 @c_errmsg         = @c_errmsg  OUTPUT,
                 @n_Noofparam      = 3,
                 @c_Param01        = @c_Receiptkey,        
                 @c_Param02        = @c_ReceiptLineNumber,     
                 @c_Param03        = @c_ReceiptLineNumber, 
                 @c_UserName       = @c_UserName,
                 @c_PrinterID      = '',
                 @c_Datawindow     = @c_ReceivingLBL_DW,
                 @c_IsPaperPrinter = 'N', 
                 @c_JobType        = 'TCPSPOOLER',
                 @n_Function_ID    = 999

            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               GOTO QUIT_SP
            END
         END
         --WL01 E
         
         NEXT_LOOP:   --WL02
         FETCH NEXT FROM CUR_ASN INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_UserName   --WL01
      END          
      CLOSE CUR_ASN
      DEALLOCATE CUR_ASN
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_ASN') IN (0 , 1)
   BEGIN
      CLOSE CUR_ASN
      DEALLOCATE CUR_ASN   
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UNILEVER_AutoReleasePA'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO