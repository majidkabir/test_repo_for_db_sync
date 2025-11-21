SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKLOTCHK02                                      */
/* Creation Date: 27-OCT-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15190 SG Prestige Pack capture lottable validation      */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackLottableCheck_Wrapper         */
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

CREATE PROC [dbo].[ispPKLOTCHK02]   
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

   DECLARE @n_Continue           INT,
           @n_StartTCnt          INT,
           @c_Status             NVARCHAR(10),
           @n_PackedLotQty       INT,
           @n_TotalPackedLotQty  INT,
           @n_OrderLotQty        INT
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 	 
	 IF ISNULL(@c_LottableValue,'') = '' 
	 BEGIN
      SET @n_continue = 3    
      SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Lottable is empty for Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + '. (ispPKLOTCHK02)'   	 	 
      GOTO QUIT_SP
	 END
	 	 
	 SELECT @n_PackedLotQty = SUM(Qty)
	 FROM PACKDETAIL (NOLOCK)
	 WHERE Pickslipno = @c_Pickslipno
	 AND Storerkey = @c_Storerkey
	 AND Sku = @c_Sku
	 AND CartonNo <> @n_Cartonno
	 AND LottableValue = @c_LottableValue                        
	 
	 SELECT @n_TotalPackedLotQty = ISNULL(@n_PackedLotQty,0) + ISNULL(@n_PackingQty,0)  --other carton + current carton (same lottable)
	 
   SELECT @n_OrderLotQty = SUM(PD.Qty)                                          
   FROM PICKHEADER PH (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey                                                 
   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey                    
   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot                            
   WHERE PH.Pickheaderkey = @c_Pickslipno                                               
   AND LA.Lottable01 = @c_LottableValue                                        
   AND PD.Storerkey = @c_Storerkey                                             
   AND PD.Sku = @c_Sku                               

	 IF ISNULL(@n_OrderLotQty,0) < ISNULL(@n_TotalPackedLotQty,0) 
	 BEGIN
      SET @n_continue = 3    
      SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Pack qty: ' + CAST(@n_TotalPackedLotQty AS NVARCHAR) + ' is more than pick qty: ' + CAST(@n_OrderLotQty AS NVARCHAR) + '. Lottable value ' + RTRIM(ISNULL(@c_lottablevalue,'')) + ' of Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + '. (ispPKLOTCHK02)'
      GOTO QUIT_SP            	 	 	 	  	 
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKLOTCHK02'		
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