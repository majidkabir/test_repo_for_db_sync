SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Stored Procedure: isp_UpdateTCPSpoolerVersion_Startup                */   
/* Creation Date: 2020-11-04                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */
/* Purpose: Update rdtRdtSpooler TCPSocketVersion When Start            */      
/* Return Status: None                                                  */      
/* Called By: TCPSpooler Application                                    */ 
/*                                                                      */  
/* Updates:                                                             */      
/* Date        Author   Ver.  Purposes                                  */     
/* 04-Nov-2020 Wan      1.0   Created                                   */  
/* 10-Nov-2020 Shong    1.1   Log Start Time to Alert                   */
/************************************************************************/      
CREATE PROC [dbo].[isp_UpdateTCPSpoolerVersion_Startup]  
      @c_IPAddress         NVARCHAR(40)
   ,  @c_PortNo            NVARCHAR(5)
   ,  @c_TCPSpoolerVersion NVARCHAR(50) 
   ,  @b_Success           INT            = 1   OUTPUT
   ,  @n_Err               INT            = 0   OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)  = ''  OUTPUT     
AS   
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       
  
   DECLARE @b_Debug        INT = 0   
         , @n_StartTCnt    INT = @@TRANCOUNT
         , @n_Continue     INT = 1
         , @c_SpoolerGroup NVARCHAR(50) = ''
         , @c_AlertMessage	NVARCHAR(255) = ''
  
   SELECT @c_SpoolerGroup = RS.SpoolerGroup FROM rdt.rdtSpooler RS WITH (NOLOCK)
   WHERE RS.IPAddress = @c_IPAddress AND RS.PortNo = @c_PortNo

   UPDATE rdt.rdtSpooler   
      SET TCPSpoolerVersion = @c_TCPSpoolerVersion 
         , EditDate=GETDATE()  
   WHERE SpoolerGroup = @c_SpoolerGroup   
  
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68100
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +  ': Error Update TCPSpooler Version to RDT.RDTSpooler.'
   END

   SET @c_AlertMessage = 'TCPSpooler Started, IP: ' + @c_IPAddress + ' Port: ' + @c_PortNo + ' Version: ' + @c_TCPSpoolerVersion

   EXECUTE nspLogAlert    
      @c_modulename   = 'isp_UpdateTCPSpoolerVersion_Startup',    
      @c_alertmessage = @c_AlertMessage ,    
      @n_severity     = 0,    
      @b_success      = @b_success OUTPUT,    
      @n_err          = @n_err OUTPUT,    
      @c_errmsg       = @c_errmsg OUTPUT    

   QUIT_SP:

   IF @n_Continue = 3 
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND  @@TRANCOUNT > @n_StartTCnt 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UpdateTCPSpoolerVersion_Startup'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END      

GO