SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Open_Key_Cert_Orders_PI                        */
/* Creation Date: 13-Jul-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: Open key and certificate with admin right                   */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE PROC [dbo].[isp_Open_Key_Cert_Orders_PI]
(
	 @n_err     INT            OUTPUT
   ,@c_ErrMsg  NVARCHAR(255)  OUTPUT 
)
WITH EXECUTE AS 'excel2wms'
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT = 1
           
   BEGIN TRY  
      OPEN SYMMETRIC KEY Smt_Key_Orders_PI  
      DECRYPTION BY CERTIFICATE Cert_Orders_PI;
   END TRY  
   BEGIN CATCH  
      SELECT @n_continue = 3  
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 60000  
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Failed to open key and certificate.' + ' ( '+  
                         ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
   END CATCH 
   
   IF @n_continue = 3
   BEGIN
      execute nsp_logerror @n_err, @c_errmsg, 'isp_Open_Key_Cert_Orders_PI'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END
END -- Procedure

GO