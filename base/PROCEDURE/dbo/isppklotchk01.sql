SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKLOTCHK01                                      */
/* Creation Date: 03-Jul-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9396 SG THG Pack capture lottable validation            */   
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

CREATE PROC [dbo].[ispPKLOTCHK01]   
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
           @c_Wavekey            NVARCHAR(10),
           @n_WaveLotQty         INT
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
	 IF ISNULL(@c_LottableValue,'') = ''
	 BEGIN
      SET @n_continue = 3    
      SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Lottable is empty for Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + '. (ispPKLOTCHK01)'   	 	 
      GOTO QUIT_SP
	 END
	 
	 /*
	 SELECT @n_PackedLotQty = SUM(Qty)
	 FROM PACKDETAIL (NOLOCK)
	 WHERE Pickslipno = @c_Pickslipno
	 AND Storerkey = @c_Storerkey
	 AND Sku = @c_Sku
	 AND CartonNo <> @n_Cartonno
	 AND LottableValue = @c_LottableValue                        
	 
	 SELECT @n_TotalPackedLotQty = @n_PackedLotQty + @n_PackingQty  --other carton + current carton (same lottable)
	 */
	 
	 SELECT TOP 1 @c_Wavekey = WD.Wavekey
	 FROM PICKHEADER PH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
	 JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
	 WHERE PH.Pickheaderkey = @c_Pickslipno
	 
	 IF ISNULL(@c_Wavekey,'') = ''
	 BEGIN
	    SELECT TOP 1 @c_Wavekey = WD.Wavekey
	    FROM PICKHEADER PH (NOLOCK)
	    JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Externorderkey = LPD.Loadkey
	    JOIN WAVEDETAIL WD (NOLOCK) ON LPD.Orderkey = WD.Orderkey
	    WHERE PH.Pickheaderkey = @c_Pickslipno
	    AND ISNULL(PH.Orderkey,'') = ''
	 END
	 
	 IF ISNULL(@c_Wavekey,'') <> ''
	 BEGIN
	 	  SELECT @n_WaveLotQty = SUM(PD.Qty) 
	 	  FROM WAVEDETAIL WD (NOLOCK)
	 	  JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
	 	  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
	 	  WHERE WD.Wavekey = @c_Wavekey
	 	  AND LA.Lottable01 = @c_LottableValue
	 	  AND PD.Storerkey = @c_Storerkey
	 	  AND PD.Sku = @c_Sku
	 	  
	 	  IF ISNULL(@n_WaveLotQty,0) = 0 
	 	  BEGIN
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Invalid lottable value ' + RTRIM(ISNULL(@c_lottablevalue,'')) + ' for Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + ' at Wave: ' + RTRIM(ISNULL(@c_Wavekey,'')) +'. (ispPKLOTCHK01)'
         GOTO QUIT_SP            	 	 	 	  	 
	 	  END
	 	  
	 	  /*
	 	  IF ISNULL(@c_WaveLotQty,0) < ISNULL(@n_TotalPackedLotQty,0) 
	 	  BEGIN
         SET @n_continue = 3    
         SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Pack qty: ' + CAST(@n_TotalPackedLotQty NVARCHAR) + ' is more than pick qty: ' + CAST(@n_TotalPackedLotQty NVARCHAR) + '. Lottable value ' + RTRIM(ISNULL(@c_lottablevalue,'')) + ' of Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + ' at Wave: ' + RTRIM(ISNULL(@c_Wavekey,'')) +'. (ispPKLOTCHK01)'
         GOTO QUIT_SP            	 	 	 	  	 
	 	  END
	 	  */
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKLOTCHK01'		
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