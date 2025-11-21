SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GenEOrder_Replenishment_Wrapper                */  
/* Creation Date: 06-Aug-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-9276 release order Ecom replenishment wrapper           */  
/*          SP: ispGenEOrderReplen??                                    */
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
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_GenEOrder_Replenishment_Wrapper]  
   @c_LoadKeyList NVARCHAR(1000),  
   @c_BatchNoList NVARCHAR(4000) = '',  
   @b_Debug       BIT = 0, 
   @b_Success     BIT = 1 OUTPUT,  
   @n_Err         INTEGER = 0 OUTPUT,  
   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_SQL           NVARCHAR(MAX),
           @c_Facility      NVARCHAR(5),
           @c_Storerkey     NVARCHAR(15)
                                                      
   SELECT @c_SPCode='', @n_err=0, @b_success=1, @c_errmsg='', @c_Storerkey='', @c_Facility=''   

   SELECT @c_Storerkey = MAX(O.Storerkey), 
          @c_Facility = MAX(O.Facility) 
   FROM [dbo].[fnc_DelimSplit]('|', @c_LoadKeyList) AS LP
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LP.ColValue = LPD.Loadkey
   JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   HAVING COUNT(DISTINCT RTRIM(O.Storerkey)+O.Facility) = 1         
   
   IF ISNULL(@c_Storerkey,'') <> '' AND ISNULL(@c_Facility,'') <> ''     
      SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'GenEOrderReplenishment_SP') 
      
   IF ISNULL(RTRIM(@c_SPCode),'') IN( '','0')
   BEGIN
   	   SET @c_SPCode = 'isp_GenEOrder_Replenishment'
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig GenEOrderReplenishment_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_GenEOrder_Replenishment_Wrapper)'  
       GOTO QUIT_SP
   END
      
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_LoadKeyList, @c_BatchNoList, @b_Debug, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
     
   EXEC sp_executesql @c_SQL, 
        N'@c_LoadKeyList NVARCHAR(1000), @c_BatchNoList NVARCHAR(4000), @b_Debug INT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT', 
        @c_LoadKeyList,
        @c_BatchNoList,
        @b_Debug,
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_GenEOrder_Replenishment_Wrapper'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO