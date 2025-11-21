SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_AllocateUpd_OPORDERLINES_Wrapper                   */
/* Creation Date: 03-Feb-2023                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-19078 Allow custom SP to update #OPORDERLINES before start */
/*                    allocation                                           */
/*          storerconfig AllocateUpdOPOrderLines_SP = ispALUPDORDLN??      */
/*                                                                         */
/* Called By: Allocation                                                   */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/

CREATE   PROC [dbo].[isp_AllocateUpd_OPORDERLINES_Wrapper] 
   @c_Storerkey       NVARCHAR(15) = '',
   @c_Facility        NVARCHAR(5) = '',
   @c_Orderkey        NVARCHAR(10) = '', 
   @c_Loadkey         NVARCHAR(10) = '',
   @c_Wavekey         NVARCHAR(10) = '',
   @c_SourceType      NVARCHAR(30) = '',  --calling sp name
   @b_Success         INT = 1            OUTPUT,
   @n_Err             INT = 0            OUTPUT, 
   @c_ErrMsg          NVARCHAR(250) = '' OUTPUT 
AS 
BEGIN
   SET NOCOUNT ON                                                                                                                                                                                                                        	
   SET QUOTED_IDENTIFIER OFF                                                                                                                                                                                                            	
   SET ANSI_NULLS OFF                                                                                                                                                                                                                     
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                                                                                                        
                                                                                                                                                                                                                                          
   DECLARE @n_continue      INT,                                                                                                                                                                                                          
           @c_SPCode        NVARCHAR(30),                                                                                                                                                                                                 
           @c_SQL           NVARCHAR(MAX),
           @n_StartTCnt     INT                                                                                                                                                                                                  
                                                                                                                                                                                                                                          
   SELECT @c_SPCode='', @n_err=0, @b_success=1, @c_errmsg='', @n_StartTCnt=@@TRANCOUNT
                                                                                                                                                                                                                                          
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateUpdOPOrderLines_SP')                                                                                                                                         
                                                                                                                                                                                                                                          
   IF ISNULL(RTRIM(@c_SPCode),'') IN( '','0')                                                                                                                                                                                             
   BEGIN                                                                                                                                                                                                                                  
       GOTO QUIT_SP                                                                                                                                                                                                                       
   END                                                                                                                                                                                                                                    
                                                                                                                                                                                                                                          
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')                                                                                                                                              
   BEGIN                                                                                                                                                                                                                                  
       SELECT @n_continue = 3                                                                                                                                                                                                             
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),                                                                                                                                                                                     
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                                                                                                        
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +                                                                                                                                                                             
              ': Storerconfig AllocateUpdOPOrderLines_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_AllocateUpd_OPORDERLINES_Wrapper)'                                                                                  
       GOTO QUIT_SP                                                                                                                                                                                                                       
   END                                                                                                                                                                                                                                    
                                                                                                                                                                                                                                          
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey=@c_StorerkeyP, @c_Facility=@c_FacilityP, @c_Orderkey=@c_OrderkeyP, @c_Loadkey=@c_LoadkeyP, @c_Wavekey=@c_WavekeyP, @c_SourceType=@c_SourceTypeP, ' +                                             
                ' @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '                                                                                                                                     
                                                                                                                                                                                                                                          
   EXEC sp_executesql @c_SQL,                                                                                                                                                                                                             
        N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_OrderkeyP NVARCHAR(10), @c_LoadkeyP NVARCHAR(10), @c_WavekeyP NVARCHAR(10), @c_SourceTypeP NVARCHAR(30), @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(250) OUTPUT',  
        @c_Storerkey,                                                                                                                                                                                                                    
        @c_Facility,                                                                                                                                                                                                                      
        @c_Orderkey,                                                                                                                                                                                                                   
        @c_Loadkey,                                                                                                                                                                                                                           
        @c_Wavekey,
        @c_SourceType,
        @b_Success OUTPUT,                                                                                                             
        @n_Err OUTPUT,                                                                                                                                                                                                                    
        @c_ErrMsg OUTPUT                                                                                                                                                                                                                  
                                                                                                                                                                                                                                          
   IF @b_Success <> 1                                                                                                                                                                                                                     
   BEGIN                                                                                                                                                                                                                                  
       SELECT @n_continue = 3                                                                                                                                                                                                             
       GOTO QUIT_SP                                                                                                                                                                                                                       
   END                                                                                                                                                                                                                                    
                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_AllocateUpd_OPORDERLINES_Wrapper'  
  		--RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END

GO