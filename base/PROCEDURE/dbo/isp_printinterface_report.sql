SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_PrintInterface_Report                             */  
/* Creation Date: 31-MAY-2016                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: PH - Nike mbol print PDF                                       */                                 
/*          storerconfig PrintITFReport='1' option1='',option3 = SPname    */
/*                                                                         */  
/* Called By: Mbol Module - Print ITF Label                                */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */ 
/* 2023-04-20  Wan01    1.1   LFWM-3913-Ship Reference Enhancement-Print   */
/*                            Interface Document                           */
/*                            DevOps Combine Script                        */
/***************************************************************************/    
CREATE   PROC [dbo].[isp_PrintInterface_Report]    
(     @c_Parm01      NVARCHAR(50)     
  ,   @c_Parm02      NVARCHAR(50) = ''
  ,   @c_Parm03      NVARCHAR(50) = ''
  ,   @c_Parm04      NVARCHAR(50) = ''
  ,   @c_Parm05      NVARCHAR(50) = ''
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
  ,   @c_PrinterID   NVARCHAR(30) = ''                                              --(Wan01)    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug                 INT  
         , @n_Continue              INT   
         , @n_StartTCount           INT   
         , @c_Storerkey             NVARCHAR(10)
         , @c_PrintITFReport        NVARCHAR(10)
         , @c_Option1               NVARCHAR(50)
         , @c_Option2               NVARCHAR(50)
         , @c_Option3               NVARCHAR(50)
         , @c_CartonNo              NVARCHAR(10)
         , @c_UserName              NVARCHAR(18)         
         , @c_Facility              NVARCHAR(5)
         , @c_PrintData             NVARCHAR(4000)
         , @c_Orderkey              NVARCHAR(10)
         , @c_RefNo                 NVARCHAR(20)
         , @c_LabelNo               NVARCHAR(20)
         , @c_trmlogkey             NVARCHAR(10)
         , @c_RDTDefaultPrinter    NVARCHAR(128)
         , @c_RDTWinPrinter         NVARCHAR(128)
         , @c_SPCode                NVARCHAR(50)
         , @c_SQL                   NVARCHAR(MAX)

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 0
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  
   

   IF EXISTS (SELECT 1 FROM MBOLDETAIL WITH (NOLOCK) WHERE Mbolkey =@c_Parm01)
   BEGIN
    SELECT TOP 1 @c_Storerkey = Storerkey
    FROM  MBOLDETAIL md (nolock)
    JOIN  ORDERS ord (nolock) on ord.orderkey = md.orderkey
    WHERE md.mbolkey = @c_Parm01 
   END
   ELSE
   BEGIN
    GOTO QUIT_SP
   END

   Execute nspGetRight 
      '',  
      @c_StorerKey,              
      '',                    
      'PrintITFReport', 
      @b_success               OUTPUT,
      @c_PrintITFReport        OUTPUT,
      @n_err                   OUTPUT,
      @c_errmsg                OUTPUT,
      @c_Option1               OUTPUT,
      @c_Option2               OUTPUT,
      @c_Option3               OUTPUT      

   --NJOW01 Start
   SELECT @c_SPCode = @c_Option3   

   IF ISNULL(@c_SPCode,'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
      BEGIN  
            SET @n_Continue = 3
            SET @n_err      = 83000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
            ': Storerconfig PrintITFReport.Option3 - Stored Proc name invalid (PrintITFReport )'        
            GOTO QUIT_SP  
      END        
            
      SET @c_SQL = 'EXEC ' + @c_SPCode 
                 + ' @c_Parm01=@c_Parm01, @c_Parm02=@c_Parm02, @c_Parm03=@c_Parm03,@c_Parm04=@c_Parm04,@c_Parm05=@c_Parm05,'
                 + ' @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT,'
                 + ' @c_ErrMsg=@c_ErrMsgP OUTPUT, @c_PrinterID=@c_PrinterID '       --(Wan01)  
      
      EXEC sp_executesql @c_SQL   
          ,N'@c_Parm01 NVARCHAR(50), @c_Parm02 NVARCHAR(50), @c_Parm03 NVARCHAR(50),@c_Parm04 NVARCHAR(50), @c_Parm05 NVARCHAR(50),
             @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(255) OUTPUT,
             @c_PrinterID NVARCHAR(30) '                                            --(Wan01)        
          ,@c_Parm01       
          ,@c_Parm02
          ,@c_Parm03
          ,@c_Parm04
          ,@c_Parm05
          ,@b_Success      OUTPUT  
          ,@n_Err          OUTPUT  
          ,@c_ErrMsg       OUTPUT   
          ,@c_PrinterID                                                             --(Wan01)              

       IF @b_Success <> 1
       BEGIN
         SET @n_Continue = 3
       END                    

       GOTO QUIT_SP             
   END      
   --NJOW01 End
      
   IF @c_PrintITFReport = '1'
   BEGIN
      IF ISNULL(@c_Option1,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 83000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
            ': Please setup table name at option1 of storerconfig ''PrintITFReport'' (isp_PrintInterface_Report)'
         GOTO QUIT_SP
      END
                                                               
   END
                 
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_PrintInterface_Report'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO