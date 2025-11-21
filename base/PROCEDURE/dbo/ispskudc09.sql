SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSKUDC09                                         */  
/* Creation Date: 01/11/2021                                            */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-18189 SG LM - Packing extract UPC and lottable from     */ 
/*          barcode                                                     */
/*                                                                      */  
/* Called By: isp_SKUDecode_Wrapper                                     */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 03-Nov-2021 NJOW     1.0   DEVOPS combine scirpt                     */
/* 17-Dec-2021 NJOW01   1.1   WMS-18602 change decode logic             */
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSKUDC09]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(30)      OUTPUT     
   , @c_Code01           NVARCHAR(60) = '' OUTPUT      
   , @c_Code02           NVARCHAR(60) = '' OUTPUT      
   , @c_Code03           NVARCHAR(60) = '' OUTPUT       
   , @b_Success          INT          = 1  OUTPUT
   , @n_Err              INT          = 0  OUTPUT 
   , @c_ErrMsg           NVARCHAR(250)= '' OUTPUT
   , @c_Pickslipno       NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue     INT = 1 
         , @n_StartTcnt    INT = @@TRANCOUNT       
         , @c_TmpSku       NVARCHAR(20) = ''
         , @c_LottableVal  NVARCHAR(18) = ''        

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''

   IF LEN(@c_Sku) > 20 AND LEFT(@c_Sku,2) = '01'
   BEGIN
   	 SET @c_TmpSku = SUBSTRING(@c_Sku, 3, 14)
   	 
   	 IF SUBSTRING(@c_Sku,17,2) IN ('17') --NJOW01
   	 BEGIN
   	 	  SET @c_LottableVal = RTRIM(SUBSTRING(@c_Sku, 27, 15))   
   	 	  IF CHARINDEX('37', @c_LottableVal) > 0
   	 	     SET @c_LottableVal = LEFT(@c_LottableVal, LEN(@c_LottableVal)-3)  
   	 END 
   	 ELSE IF SUBSTRING(@c_Sku,17,2) IN ('10','21') 
   	 BEGIN
   	 	  SET @c_LottableVal = SUBSTRING(@c_Sku, 19, 10)
   	 END 
   	                                 
     EXEC nspg_GETSKU
        @c_StorerKey = @c_Storerkey OUTPUT 
       ,@c_sku       = @c_TmpSku    OUTPUT 
       ,@b_success   = @b_Success   OUTPUT
       ,@n_err       = @n_err       OUTPUT
       ,@c_errmsg    = @c_errmsg    OUTPUT   	    	 
       
      IF @b_Success = 0
      BEGIN
         /*
         SET @n_Continue = 3
         SET @n_Err = 83010
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Sku: ' + RTRIM(ISNULL(@c_TmpSku,'')) + ' (ispSKUDC09)'
         */
      	 SET @c_NewSku = LEFT(@c_TmpSku,20)
         GOTO QUIT_SP 	
      END            
      
      IF ISNULL(@c_Pickslipno,'') <> '' 
      BEGIN
      	 IF NOT EXISTS(SELECT 1
      	               FROM PICKHEADER PH (NOLOCK)
      	               JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      	               JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      	               WHERE PH.Pickheaderkey = @c_Pickslipno
      	               AND OD.Storerkey = @c_Storerkey
      	               AND OD.Sku = @c_TmpSku)      	             
      	 BEGIN
            /*
            SET @n_Continue = 3
            SET @n_Err = 83020
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Sku: ' + RTRIM(ISNULL(@c_TmpSku,'')) + ' for the order. (ispSKUDC09)'
            */     
          	SET @c_NewSku = LEFT(@c_TmpSku,20)
            GOTO QUIT_SP 	      	   	
      	 END
         
      	 IF ISNULL(@c_LottableVal,'') <> ''
      	 BEGIN
      	    IF NOT EXISTS(SELECT 1
      	                  FROM PICKHEADER PH (NOLOCK)
      	                  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      	                  JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      	                  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
      	                  WHERE PH.Pickheaderkey = @c_Pickslipno
      	                  AND PD.Storerkey = @c_Storerkey
      	                  AND PD.Sku = @c_TmpSku
      	                  AND LA.Lottable01 = @c_LottableVal)
      	    BEGIN
               SET @n_Continue = 3
               SET @n_Err = 83030
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Lottable01: ' + RTRIM(ISNULL(@c_LottableVal,'')) + ' (ispSKUDC09)'     
               GOTO QUIT_SP 	      	   	
      	    END
         END      	      	
      END
      
      SET @c_NewSku = @c_TmpSku
      SET @c_Code01 = @c_LottableVal
   END

QUIT_SP:     

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC09'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END -- End Procedure

GO