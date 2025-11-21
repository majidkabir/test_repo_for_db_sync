SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackLottableCheck_Wrapper                      */  
/* Creation Date: 03-Jul-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-9396 SG THG Pack capture lottable validation            */  
/*          SP: ispPKLOTCHK??                                           */
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
/* 27-OCT-2020  NJOW01   1.0  WMS-15190 Fix                             */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PackLottableCheck_Wrapper]  
   @c_PickslipNo    NVARCHAR(10),    
   @c_Storerkey     NVARCHAR(15),
   @c_Sku           NVARCHAR(20),
   @c_LottableValue NVARCHAR(60),
   @n_Cartonno      INT,
   @n_PackingQty    INT,
   @b_Success       INT           OUTPUT,
   @n_Err           INT           OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_SQL           NVARCHAR(MAX),
           @c_Facility      NVARCHAR(5)
                                                      
   SELECT @c_SPCode='', @n_err=0, @b_success=1, @c_errmsg=''   
      
   SELECT @c_Facility = O.Facility
   FROM PICKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey 
   WHERE PH.Pickheaderkey = @c_Pickslipno
   
   IF ISNULL(@c_Facility,'') = ''
   BEGIN
      SELECT TOP 1 @c_Facility = O.Facility
      FROM PICKHEADER PH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey
      JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
      WHERE PH.Pickheaderkey = @c_Pickslipno
   END
   
   
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackByLottableValidate_SP') 
      
   IF ISNULL(RTRIM(@c_SPCode),'') IN( '','0')
   BEGIN
       /*
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration PackByLottableValidate_SP for '+RTRIM(@c_StorerKey)+' (isp_PackLottableCheck_Wrapper)'
       */  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig PackByLottableValidate_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_PackLottableCheck_Wrapper)'  
       GOTO QUIT_SP
   END
      
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Pickslipno=@c_Pickslipno, @c_Storerkey=@c_Storerkey, @c_Sku=@c_Sku, @c_LottableValue=@c_LottableValue, 
                 @n_Cartonno=@n_Cartonno, @n_PackingQty=@n_PackingQty, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '
     
   EXEC sp_executesql @c_SQL, 
        N'@c_Pickslipno NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_LottableValue NVARCHAR(60), @n_CartonNo INT, @n_PackingQty INT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
        @c_Pickslipno,
        @c_Storerkey,
        @c_Sku,
        @c_LottableValue, 
        @n_Cartonno,
        @n_PackingQty,
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackLottableCheck_Wrapper'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO