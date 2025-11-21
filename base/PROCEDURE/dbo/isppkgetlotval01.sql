SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKGETLOTVAL01                                   */
/* Creation Date: 26-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19392 TBLTW Get default lottable value from sku         */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackGetLottableValue_Wrapper      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 26-Apr-2022  NJOW     1.0  DEVOPS combine script                     */
/************************************************************************/

CREATE PROC [dbo].[ispPKGETLOTVAL01]    
   @c_Pickslipno      NVARCHAR(10),
   @c_Facility        NVARCHAR(5),
   @c_Storerkey       NVARCHAR(15),
   @c_Sku             NVARCHAR(20),
   @c_LottableValue   NVARCHAR(60)  OUTPUT,
   @c_ConfirmLinePack NVARCHAR(10)  OUTPUT,
   @b_Success         INT           OUTPUT,
   @n_Err             INT           OUTPUT, 
   @c_ErrMsg          NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT,
           @n_StartTCnt          INT,
           @c_CountryOfOrigin    NVARCHAR(30)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1	 
	 
	 SET @c_CountryOfOrigin = ''
	 	 
	 SELECT @c_CountryOfOrigin = CountryOfOrigin
	 FROM SKU (NOLOCK)
	 WHERE Storerkey = @c_Storerkey
	 AND Sku = @c_Sku
	 
	 IF ISNULL(@c_CountryOfOrigin,'') <> ''
	    SET @c_LottableValue = @c_CountryOfOrigin	 
	 	   
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKGETLOTVAL01 '		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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