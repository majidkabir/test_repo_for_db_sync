SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_TPP_CheckPrintRequire                           */
/* Creation Date: 2-Aug-2021                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Check Trade Partner Printing is required                   */
/*                                                                      */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/************************************************************************/ 

CREATE PROC [dbo].[isp_TPP_CheckPrintRequire] (
   @c_Pickslipno        NVARCHAR(10),                                           
   @c_Module            NVARCHAR(20), --PACKING, EPACKING
   @c_ReportType        NVARCHAR(10), --UCCLABEL,
   @c_IsTPPRequired     NVARCHAR(5) OUTPUT,  --Y/N
   @b_success           INT OUTPUT,
   @n_err               INT OUTPUT,
   @c_errmsg            NVARCHAR(255) OUTPUT  
   )   
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF     

   DECLARE @n_starttcnt    INT,
           @n_continue     INT,           
           @c_Shipperkey   NVARCHAR(15),
           @c_Storerkey    NVARCHAR(15),
           @c_Platform     NVARCHAR(30) 
                    
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''
   
   SELECT @c_Storerkey = O.Storerkey,          
          @c_Shipperkey = O.Shipperkey,
          @c_Platform = O.ECOM_Platform
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.Pickslipno = @c_Pickslipno
     
   IF EXISTS(SELECT 1 
             FROM TPPRINTCONFIG (NOLOCK)
               WHERE Storerkey = @c_Storerkey
               AND Shipperkey = @c_Shipperkey
               AND Module = @c_Module
               AND ReportType =@c_ReportType
               AND Platform = @c_Platform
               AND ActiveFlag = '1')
               
   BEGIN
      SET @c_IsTPPRequired = 'Y'
   END
   ELSE
   BEGIN
      SET @c_IsTPPRequired = 'N'
   END
     
   EXIT_SP:
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_TPP_CheckPrintRequire"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO