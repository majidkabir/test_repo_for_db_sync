SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_CheckRDTReportSetup                            */  
/* Creation Date: 17-Dec-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-10486 - Check RDTReport Setup                           */  
/*                                                                      */
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_CheckRDTReportSetup]  
   @c_Storerkey       NVARCHAR(15),
   @c_ReportType      NVARCHAR(10),
   @n_FunctionID      INT,
   @c_Facility        NVARCHAR(5),
   @c_CallFrom        NVARCHAR(30), --Call from which screen
   @c_Datawindow      NVARCHAR(50)  OUTPUT,
   @b_Success         INT           OUTPUT,
   @n_Err             INT           OUTPUT, 
   @c_ErrMsg          NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SQL           NVARCHAR(MAX)
                                                      
   SELECT @n_err=0, @b_success=1, @c_errmsg='', @n_continue = 1   
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM CODELKUP CL (NOLOCK)
                     WHERE CL.Listname = 'SpoolerPrn' 
                     AND CL.Storerkey = @c_Storerkey 
                     AND CL.Code = @c_ReportType
                     AND CL.Code2 = @c_CallFrom
                     AND CL.Short = 'Y' )
      BEGIN
         SET @c_Datawindow = ''
         GOTO QUIT_SP
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Datawindow = LTRIM(RTRIM(Datawindow))
      FROM RDT.RDTREPORT (NOLOCK)
      WHERE REPORTTYPE = @c_ReportType AND STORERKEY = @c_Storerkey
      AND Function_ID = @n_FunctionID
      AND (Facility = @c_Facility OR Facility = '')
      ORDER BY Facility DESC
   END

   IF @c_Datawindow = NULL SET @c_Datawindow = ''
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_CheckRDTReportSetup'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO