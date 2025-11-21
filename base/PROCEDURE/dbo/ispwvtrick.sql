SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWVTRICK                                         */
/* Creation Date: 06-FEB-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-3642 - SG Triple Check Wave allocate PTL availability   */   
/*                                                                      */
/* Called By: isp_WaveCheckAllocateMode_Wrapper from Wave allocation    */
/*            storerconfig: WaveCheckAllocateMode_SP                    */
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

CREATE PROC [dbo].[ispWVTRICK]   
   @c_WaveKey       NVARCHAR(10),
   @c_AllocateMode  NVARCHAR(10) OUTPUT,  -- not applicable for SG triple
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Loadkey         NVARCHAR(10),
           @c_Userdefine02    NVARCHAR(20),
           @c_Userdefine03    NVARCHAR(20),
           @c_Facility        NVARCHAR(5),
           @n_Ordercnt        INT,
           @n_Loccnt          INT,
           @c_LocCategoryFrom NVARCHAR(10),
           @c_LocCategoryTo   NVARCHAR(10),
           @c_LoadPlanGroup   NVARCHAR(10)                    
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
	 SET @c_AllocateMode = ''
	 
	 SELECT @n_Ordercnt = COUNT(1), 
	        @c_Userdefine02 = MAX(WAVE.Userdefine02),
	        @c_Userdefine03 = MAX(WAVE.Userdefine03),
	        @c_Facility = MAX(ORDERS.Facility),
	        @c_LoadPlanGroup = MAX(WAVE.LoadPlanGroup)
	 FROM WAVE (NOLOCK)
	 JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.Wavekey
	 JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
	 WHERE WAVE.Wavekey = @c_Wavekey
	 
	 IF ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '' 
	 BEGIN
      SELECT @n_continue = 3  
      SELECT @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found empty wave userdefine02 or userdefine03 value. (ispWVTRICK)' 
      GOTO QUIT_SP	 	
	 END
	 	 
	 SELECT @c_LocCategoryFrom = LocationCategory
	 FROM LOC(NOLOCK)
	 WHERE Loc = @c_Userdefine02

	 SELECT @c_LocCategoryTo = LocationCategory
	 FROM LOC(NOLOCK)
	 WHERE Loc = @c_Userdefine03


	 IF @c_LocCategoryFrom NOT IN('FLOWRACK','SCANPACK') OR @c_LocCategoryTo NOT IN('FLOWRACK','SCANPACK') 
	 BEGIN
      SELECT @n_continue = 3  
      SELECT @n_err = 36110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid location catetory. (ispWVTRICK)' 
      GOTO QUIT_SP	 	
	 END	 	 	     

	 IF @c_LocCategoryFrom <> @c_LocCategoryTo 
	 BEGIN
      SELECT @n_continue = 3  
      SELECT @n_err = 36120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Location Category of Userdefine02 and Userdefine03 are not same. (ispWVTRICK)' 
      GOTO QUIT_SP	 	
	 END	 	 	     
	 	 
	 IF @c_LocCategoryFrom = 'FLOWRACK'
	 BEGIN
	    SELECT @n_Loccnt = COUNT(1)
	    FROM LOC (NOLOCK)
	    WHERE Facility = @c_Facility
	    AND LocationCategory = 'FLOWRACK'
	    AND Loc >= @c_Userdefine02
	    AND Loc <= @c_Userdefine03
	    
	    IF @n_Loccnt < @n_Ordercnt	 	
	    BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 36130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': NOT Enough Flow Rack location for this wave, please removed some orders to continue... (ispWVTRICK)' 
         GOTO QUIT_SP
      END
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWVTRICK'		
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