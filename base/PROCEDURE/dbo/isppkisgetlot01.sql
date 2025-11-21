SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKISGETLOT01                                    */
/* Creation Date: 29-Jul-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10048 WMS-17565 SG GBT Check capture lottable condition */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackIsCaptureLottable_Wrapper     */
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

CREATE PROC [dbo].[ispPKISGETLOT01]    
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
     
   DECLARE @n_Continue           INT,
           @n_StartTCnt          INT,
           @c_Country            NVARCHAR(30)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1	 
	 
	 SELECT @c_Country = O.C_Country
	 FROM PICKHEADER PKH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PKH.Orderkey = O.Orderkey
	 WHERE PKH.Pickheaderkey = @c_Pickslipno
	 
	 IF @@ROWCOUNT = 0
	 BEGIN
	    SELECT TOP 1 @c_Country = O.C_Country
	    FROM PICKHEADER PKH (NOLOCK)
	    JOIN LOADPLANDETAIL LPD (NOLOCK) ON PKH.ExternOrderkey = LPD.Loadkey 
	    JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
	    WHERE PKH.Pickheaderkey = @c_Pickslipno	 	 
	 END	 	 	 
	 
   IF EXISTS(SELECT 1
             FROM SKU (NOLOCK) 
             JOIN CODELKUP CL (NOLOCK) ON SKU.Busr4 = CL.Code AND SKU.Storerkey = CL.Storerkey
             WHERE CL.Listname = 'IMPLBL'
             AND SKU.Storerkey = @c_Storerkey
             AND SKU.Sku = @c_Sku) AND ISNULL(@c_Country,'') IN ('SG')
   BEGIN
	 	  SET @c_CaptureLottable = 'Y'
   END            
   ELSE
   BEGIN
	 	  SET @c_CaptureLottable = 'N'   	 
   END
	 	   
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKISGETLOT01 '		
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