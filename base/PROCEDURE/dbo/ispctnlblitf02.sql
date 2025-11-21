SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispCTNLBLITF02                                              */
/* Creation Date: 20-Sep-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-10640 [CR] NIKESG E-Com Packing                         */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*        :                                                             */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispCTNLBLITF02]
      @c_Pickslipno   NVARCHAR(10)     
  ,   @n_CartonNo_Min INT 
  ,   @n_CartonNo_Max INT 
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT 
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrdType         NVARCHAR(30)
         , @c_DocType         NVARCHAR(10)
         , @c_ExtOrderkey     NVARCHAR(10)
         , @c_Shipperkey      NVARCHAR(15)

   DECLARE @c_ReportType      NVARCHAR( 10)
         , @c_ProcessType     NVARCHAR( 15)
         , @c_FilePath        NVARCHAR(100)       
         , @c_PrintFilePath   NVARCHAR(100)      
         , @c_PrintCommand    NVARCHAR(MAX)    
         , @c_WinPrinter      NVARCHAR(128)  
         , @c_PrinterName     NVARCHAR(100) 
         , @c_FileName        NVARCHAR( 50)     
         , @c_JobStatus       NVARCHAR( 1)    
         , @c_PrintJobName    NVARCHAR(50)
         , @c_TargetDB        NVARCHAR(20)
         , @n_Mobile          INT   
         , @c_SpoolerGroup    NVARCHAR(20)
         , @c_IPAddress       NVARCHAR(40)               
         , @c_PortNo          NVARCHAR(5)           
         , @c_Command         NVARCHAR(1024)            
         , @c_IniFilePath     NVARCHAR(200)  
         , @c_DataReceived    NVARCHAR(4000) 
         , @c_Facility        NVARCHAR(5) 
         , @c_Application     NVARCHAR(30)           
         , @n_JobID           INT    
         , @n_QueueID         INT 
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10) 
         , @c_PrintData       NVARCHAR(MAX) 
         , @c_userid          NVARCHAR(20) 
         , @c_PrinterID       NVARCHAR(20)   
         , @c_Storerkey       NVARCHAR(20) 
                                                              
              

                                                      
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = '' 
   SET @c_userid = SUSER_SNAME()

   IF EXISTS (SELECT 1   
                FROM PACKINFO PIF (NOLOCK) 
                WHERE PIF.Pickslipno = @c_Pickslipno  
                AND PIF.Weight > 30                  
                )  
     BEGIN  
         SET @n_continue = 3      
         SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Carton weight is not allowed more than 30kg. (ispPCKH02)'           
     END
    ELSE
    BEGIN
        SET @n_continue = 1      
        SET @c_errmsg='CONTINUE'
    END                                   
     
   GOTO QUIT_SP                    

   QUIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispCTNLBLITF02"
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

SET QUOTED_IDENTIFIER OFF 

GO