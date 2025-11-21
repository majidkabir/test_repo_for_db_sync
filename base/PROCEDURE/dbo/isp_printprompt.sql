SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_PrintPrompt                                     */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 339440-RCM report prompt before print                       */
/*                                                                      */
/* Called By: nep_n_cst_print_util                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintPrompt] 
   @c_Storerkey   NVARCHAR(15), 
   @c_reporttype  NVARCHAR(10), 
   @c_datawindowname NVARCHAR(40), 
   @c_parameter01   NVARCHAR(100), 
   @c_parameter02   NVARCHAR(100), 
   @c_parameter03   NVARCHAR(100), 
   @c_parameter04   NVARCHAR(100), 
   @c_parameter05   NVARCHAR(100), 
   @c_promptmessage   NVARCHAR(2000) OUTPUT, 
   @b_success   INT OUTPUT, 
   @n_err       INT OUTPUT, 
   @c_errmsg  NVARCHAR(250) OUTPUT 
AS 
BEGIN
	 DECLARE @c_short_type NVARCHAR(10),
	         @c_udf01_spname NVARCHAR(60),
	         @c_notes_prnprompt NVARCHAR(2000),
	         @n_cnt INT,
	         @cSQL NVARCHAR(2000)
	         
	 SELECT @b_success = 1, @n_err = 0, @c_errmsg = '', @c_promptmessage = '', @cSQL = ''
	 
	 SELECT TOP 1 @c_notes_prnprompt = Notes, 
	        @c_short_type = Short,
	        @c_udf01_spname = udf01
	 FROM CODELKUP (NOLOCK)
	 WHERE Listname = 'PRNPROMPT'
	 AND Storerkey = @c_Storerkey
	 AND Code = @c_reporttype
	 AND Long = @c_datawindowname	 
	 
	 SELECT @n_cnt = @@ROWCOUNT
	 
	 IF @n_cnt > 0 
	 BEGIN
	 	  IF @c_short_type = 'STOREDPROC'
	 	  BEGIN
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_udf01_spname) AND type = 'P')  
         BEGIN               
            SET @cSQL = 'EXEC ' + @c_udf01_spname+ ' @c_Storerkey, @c_Reporttype, @c_Datawindowname, @c_Parameter01, @c_Parameter02, @c_Parameter03, @c_Parameter04, @c_Parameter05 ' 
                       + ', @c_promptmessage OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
            EXEC sp_executesql @cSQL,          
                 N'@c_Storerkey NVARCHAR(15), @c_Reporttype NVARCHAR(10), @c_Datawindowname NVARCHAR(40), @c_Parameter01 NVARCHAR(100), @c_Parameter02 NVARCHAR(100), @c_Parameter03 NVARCHAR(100)
                   ,@c_Parameter04 NVARCHAR(100), @c_Parameter05 NVARCHAR(100), @c_promptmessage NVARCHAR(2000) OUTPUT, @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT ',
                 @c_Storerkey,          
                 @c_reporttype, 
                 @c_datawindowname, 
                 @c_parameter01, 
                 @c_parameter02, 
                 @c_parameter03, 
                 @c_parameter04, 
                 @c_parameter05, 
                 @c_notes_prnprompt OUTPUT, 
                 @b_Success OUTPUT,          
                 @n_Err OUTPUT,          
                 @c_ErrMsg OUTPUT             
         END         
	 	  END	 	  
	 END
	 ELSE
	    SELECT @b_success = 0
	    
   QUIT:
   
   SELECT @c_promptmessage = @c_notes_prnprompt
   
   IF @n_Err <> 0      
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PrintPrompt'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END                
END

GO