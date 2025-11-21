SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_BuildLoad_Bartender_Print                      */  
/* Creation Date: 30-SEP-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-10157 - BuildLoad module print to bartender             */  
/*          Call custom SP ispBLBTxx                                    */
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_BuildLoad_Bartender_Print]
   @c_printerid  NVARCHAR(50) = '',  
   @c_labeltype  NVARCHAR(30) = '',  
   @c_userid     NVARCHAR(18) = '',  
   @c_Parm01     NVARCHAR(60) = '', --Loadkey         
   @c_Parm02     NVARCHAR(60) = '',          
   @c_Parm03     NVARCHAR(60) = '',          
   @c_Parm04     NVARCHAR(60) = '',          
   @c_Parm05     NVARCHAR(60) = '',          
   @c_Parm06     NVARCHAR(60) = '',          
   @c_Parm07     NVARCHAR(60) = '',          
   @c_Parm08     NVARCHAR(60) = '',          
   @c_Parm09     NVARCHAR(60) = '',          
   @c_Parm10     NVARCHAR(60) = '',    
   @c_Storerkey  NVARCHAR(15) = '',
   @c_NoOfCopy   NVARCHAR(5) = '1',
   @c_Subtype    NVARCHAR(20) = '',
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(10),
           @c_SQL           NVARCHAR(MAX),
           @c_Loadkey    NVARCHAR(10),
           @c_Module        NVARCHAR(10)
                                                      
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''
   
   SET @c_Loadkey = @c_Parm01
   SET @c_Module  = 'BuildLoad'   
   
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT @c_Storerkey = ORDERS.Storerkey
      FROM Loadplandetail (NOLOCK)
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = Loadplandetail.ORDERKEY
      WHERE Loadplandetail.Loadkey = @c_Loadkey
   END
   
   IF ISNULL(@c_UserId,'') = ''
      SELECT @c_UserId = SUSER_SNAME()
      
   IF ISNULL(@c_NoOfCopy,'') = '' 
      SELECT @c_NoOfCopy = '1'    
      
   IF ISNULL(@c_PrinterId,'') = ''
   BEGIN
      SELECT @c_PrinterId = DefaultPrinter 
      FROM RDT.RDTUser WITH (NOLOCK) 
      WHERE UserName = @c_UserID
   END
   
   IF ISNULL(@c_LabelType,'') = ''
   BEGIN
      SELECT TOP 1 @c_LabelType = Labeltype
      FROM BartenderCmdConfig (NOLOCK) 
      WHERE Type01 = @c_Module
      AND (Type02 = @c_Storerkey OR ISNULL(type02,'')='')  
      AND Type03 = @c_SubType       
   END   
      
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'BuildLoad_Bartender_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
                 @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
                 ': Storerconfig BuildLoad_Bartender_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_BuildLoad_Bartender_Print)'  
          GOTO QUIT_SP
      END

      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PrinterId, @c_LabelType, @c_UserId, @c_Parm01, @c_Parm02, @c_Parm03, @c_Parm04, @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08 ' +
                   ', @c_Parm09, @c_Parm10, @c_StorerKey, @c_NoOfCopy, @c_SubType, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
                   
      EXEC sp_executesql @c_SQL, 
           N'@c_PrinterId NVARCHAR(30), @c_LabelType NVARCHAR(30), @c_UserId NVARCHAR(18), @c_Parm01 NVARCHAR(60), @c_Parm02 NVARCHAR(60), @c_Parm03 NVARCHAR(60)
             ,@c_Parm04 NVARCHAR(60), @c_Parm05 NVARCHAR(60), @c_Parm06 NVARCHAR(60), @c_Parm07 NVARCHAR(60), @c_Parm08 NVARCHAR(60), @c_Parm09 NVARCHAR(60), @c_Parm10 NVARCHAR(60)
             ,@c_Storerkey NVARCHAR(15), @c_NoOfCopy NVARCHAR(5), @c_Subtype NVARCHAR(20), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
           @c_printerid,  
           @c_labeltype,  
           @c_userid,  
           @c_Parm01,          
           @c_Parm02,          
           @c_Parm03,          
           @c_Parm04,          
           @c_Parm05,          
           @c_Parm06,          
           @c_Parm07,          
           @c_Parm08,          
           @c_Parm09,          
           @c_Parm10,    
           @c_Storerkey,
           @c_NoOfCopy,             
           @c_Subtype,             
           @b_Success OUTPUT,                      
           @n_Err OUTPUT, 
           @c_ErrMsg OUTPUT
                          
      --IF @b_Success <> 1    --Wan01
      IF @b_Success = 0       --Wan01
      BEGIN
          SELECT @n_continue = 3  
          GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
        EXEC isp_BT_GenBartenderCommand        
          @cPrinterID = @c_PrinterID
         ,@c_LabelType = @c_LabelType
         ,@c_userid = @c_UserId
         ,@c_Parm01 = @c_Parm01
         ,@c_Parm02 = @c_Parm02
         ,@c_Parm03 = @c_Parm03
         ,@c_Parm04 = @c_Parm04
         ,@c_Parm05 = @c_Parm05
         ,@c_Parm06 = @c_Parm06
         ,@c_Parm07 = @c_Parm07
         ,@c_Parm08 = @c_Parm08
         ,@c_Parm09 = @c_Parm09
         ,@c_Parm10 = @c_Parm10
         ,@c_Storerkey = @c_Storerkey
         ,@c_NoCopy = @c_NoOfCopy
         ,@c_Returnresult = 'N' 
         ,@n_err = @n_Err OUTPUT
         ,@c_errmsg = @c_ErrMsg OUTPUT    

      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3  
          GOTO QUIT_SP
      END
   END
                      
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_BuildLoad_Bartender_Print'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO