SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPSDS01                                          */  
/* Creation Date: 19-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15201 - Check if need to print shipment invoice         */  
/*                                                                      */  
/* Called By: isp_PrintShipmentDocs_Wrapper                             */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispPSDS01]
   @c_Orderkey       NVARCHAR(10),
   @c_StorerKey      NVARCHAR(15),  
   @n_RecCnt         INT,
   @c_Printer        NVARCHAR(100)      OUTPUT,
   @c_DataWindow     NVARCHAR(100)      OUTPUT,
   @c_UsrDef01       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef02       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef03       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef04       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef05       NVARCHAR(500) = '' OUTPUT,
   @b_Success        INT                OUTPUT,  
   @n_err            INT                OUTPUT,  
   @c_errmsg         NVARCHAR(255)      OUTPUT    
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue      INT = 1,
           @c_UserDefine01  NVARCHAR(100),
           @c_InvoiceNo     NVARCHAR(100),
           @n_StartTCnt     INT,
           @c_ReportType    NVARCHAR(100),
           @c_PrintSIFlag   NVARCHAR(1) = 'Y',
           @c_GetInvoiceNo  NVARCHAR(10) = '',
           @n_CurrKeyCount  BIGINT
   
   SELECT @n_StartTCnt = @@TRANCOUNT
   
   CREATE TABLE #TMP_INV (
   	RowID           INT NOT NULL IDENTITY(1,1), 
   	ReportType      NVARCHAR(100) NULL,
   	Datawindow      NVARCHAR(100) NULL,
   	Printer         NVARCHAR(500) NULL,
   )
   
   INSERT INTO #TMP_INV
   (
      ReportType,
   	Datawindow,
   	Printer
   )
   SELECT ISNULL(CL.Short,''), ISNULL(CL.Long,''), ISNULL(CL.UDF01,'')
   FROM CODELKUP CL (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Storerkey = CL.Storerkey
   WHERE CL.LISTNAME = 'PRINTCFG' AND CL.Storerkey = @c_StorerKey
   AND CL.code2 = OH.[Type] AND OH.OrderKey = @c_Orderkey
   ORDER BY CAST(CL.UDF02 AS INT) ASC
   
   SELECT @c_UserDefine01 = ISNULL(UserDefine01,''),
          @c_InvoiceNo    = ISNULL(InvoiceNo,'')
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   SELECT TOP 1 @c_ReportType = t.ReportType
   FROM #TMP_INV t
   WHERE t.RowID = @n_RecCnt
   
   IF ISNULL(@c_ReportType,'') = '' GOTO QUIT_SP
   
   --Check if need to print sales invoice
   IF EXISTS (SELECT 1 FROM #TMP_INV t WHERE t.ReportType = 'SI' AND t.RowID = @n_RecCnt)
   BEGIN
   	IF @c_UserDefine01 <> 'Y'
   	BEGIN
   		IF @c_InvoiceNo <> ''
   		BEGIN
   			DELETE FROM #TMP_INV WHERE ReportType = 'SI'
            SET @c_Printer    = 'SKIP'
            SET @c_DataWindow = 'SKIP'
            SET @c_PrintSIFlag = 'N'
   		END
   	END
   END

   IF @c_Printer <> 'SKIP' AND @c_DataWindow <> 'SKIP'
   BEGIN
      SELECT TOP 1 @c_Printer    = t.Printer,
                   @c_DataWindow = t.Datawindow
      FROM #TMP_INV t
      WHERE t.RowID = @n_RecCnt
   END
   
   IF ISNULL(@c_Printer,'') = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 75000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Printer (Codelkup.UDF01) is blank. (ispPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO QUIT_SP 
   END
   
   IF ISNULL(@c_DataWindow,'') = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 75001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Datawindow (Codelkup.Long) is blank. (ispPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO QUIT_SP 
   END
   
   IF @c_ReportType = 'SI' AND @c_PrintSIFlag = 'Y'
   BEGIN
   	SELECT @n_CurrKeyCount = keycount
      FROM NCOUNTER (NOLOCK) 
   	WHERE keyname = 'NCCI_InvoiceNo'
   	
      EXECUTE nspg_getkey
            'NCCI_InvoiceNo'
            , 10
            , @c_GetInvoiceNo  OUTPUT
            , @b_success       OUTPUT
            , @n_err           OUTPUT
            , @c_errmsg        OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 75002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain InvoiceNo . (ispPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO QUIT_SP  
      END
      
      SELECT @c_UsrDef01 = REPLACE(LTRIM(REPLACE(@c_GetInvoiceNo,'0',' ')),' ','0')   --@c_GetInvoiceNo
      SELECT @c_UsrDef02 = CAST(ISNULL(@n_CurrKeyCount,0) AS NVARCHAR(10))   --RIGHT('0000000000' + CAST(ISNULL(@n_CurrKeyCount,0) AS NVARCHAR(10)), 10)
   
      INSERT INTO TraceInfo
      (
         TraceName,
         TimeIn,
         [TimeOut],
         Step1,
         Step2,
         Step3,
         Col1,
         Col2,
         Col3
      )
      VALUES
      (
         'ispPSDS01',
         GETDATE(),
         GETDATE(),
         'Orderkey',
         'UsrDef01',
         'UsrDef02',
         @c_Orderkey,
         @c_UsrDef01,
         @c_UsrDef02
      )
   END

   --BEGIN TRAN
   
   --UPDATE ORDERS WITH (ROWLOCK)
   --SET PrintFlag = 'Y'
   --WHERE OrderKey = @c_Orderkey

   --IF @@ERROR <> 0
   --BEGIN
   --   SELECT @n_continue = 3
   --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 75003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orders Table Failed . (ispPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   --   GOTO QUIT_SP  
   --END
   
   --UPDATE PACKHEADER WITH (ROWLOCK)
   --SET ManifestPrinted = 'Y'
   --WHERE OrderKey = @c_Orderkey

   --IF @@ERROR <> 0
   --BEGIN
   --   SELECT @n_continue = 3
   --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 75004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Packheader Table Failed . (ispPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   --   GOTO QUIT_SP  
   --END
      
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispPSDS01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
   
END -- End Procedure

GO