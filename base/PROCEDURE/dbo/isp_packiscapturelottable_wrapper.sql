SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackIsCaptureLottable_Wrapper                  */  
/* Creation Date: 29-Jul-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-17565 SG GBT Check capture lottable condition           */  
/*          SP: ispPKISGETLOT??                                         */
/*                                                                      */  
/* Called By: Packing of_isneedcapturelottable()                        */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 26-Oct-2021  NJOW     1.0  DEVOPS combine script                     */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PackIsCaptureLottable_Wrapper]  
   @c_Pickslipno      NVARCHAR(10),
   @c_Facility        NVARCHAR(5),
   @c_Storerkey       NVARCHAR(15),
   @c_Sku             NVARCHAR(20),
   @c_CaptureLottable NVARCHAR(5)   OUTPUT,
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
           @c_SPCode        NVARCHAR(30),
           @c_SQL           NVARCHAR(MAX)
                                                      
   SELECT @c_SPCode='', @n_err=0, @b_success=1, @c_errmsg=''   
           
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackIsCaptureLottable_SP') 
      
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
              ': Storerconfig PackIsCaptureLottable_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_PackIsCaptureLottable_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickslipNo=@c_PickslipnoP, @c_Facility=@c_FacilityP, @c_Storerkey=@c_StorerkeyP, @c_Sku=@c_SkuP, @c_CaptureLottable=@c_CaptureLottableP OUTPUT,' +
                ' @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '
     
   EXEC sp_executesql @c_SQL, 
        N'@c_PickslipnoP NVARCHAR(10), @c_FacilityP NVARCHAR(5), @c_StorerkeyP NVARCHAR(15), @c_SkuP NVARCHAR(20), @c_CaptureLottableP NVARCHAR(5) OUTPUT, @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(250) OUTPUT', 
        @c_Pickslipno,
        @c_Facility,
        @c_Storerkey,
        @c_Sku,
        @c_CaptureLottable OUTPUT, 
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackIsCaptureLottable_Wrapper'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO