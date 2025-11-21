SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPOMBD03                                         */
/* Creation Date: 28-May-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-13515 MY-TMS-WMS Update storersodefault destination to  */
/*          MBOL VoyageNumber                                           */
/*                                                                      */
/* Called By: Populate MBOL. POSTAddMBOLDETAILSP                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[ispPOMBD03] 
   @c_mbolkey     NVARCHAR( 10), 
   @c_OrderKey    NVARCHAR( 10),  
   @c_loadkey     NVARCHAR( 10), 
   @b_Success     INT           OUTPUT,    
   @n_Err         INT           OUTPUT,    
   @c_ErrMsg      NVARCHAR(250) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Cnt                INT  
         , @n_Continue           INT   
         , @n_StartTCount        INT   
         , @c_VoyageNumber       NVARCHAR(30)
        
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCount = @@TRANCOUNT    
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN
      	
   IF @n_continue IN(1,2)
   BEGIN
   	  IF EXISTS(SELECT 1 FROM MBOL(NOLOCK) WHERE Mbolkey = @c_Mbolkey
   	            AND (VoyageNumber = '' OR VoyageNumber IS NULL OR Route = VoyageNumber)) 
   	  BEGIN
   	  	 SELECT TOP 1 @c_VoyageNumber = SD.Destination 
   	  	 FROM ORDERS O (NOLOCK)
   	  	 JOIN STORERSODEFAULT SD (NOLOCK) ON O.Route = SD.Route AND O.Consigneekey = SD.Storerkey
   	  	 WHERE O.Orderkey = @c_Orderkey
   	  	 
   	  	 IF ISNULL(@c_VoyageNumber,'') <> ''
   	  	 BEGIN
   	  	 	  UPDATE MBOL WITH (ROWLOCK)
   	  	 	  SET VoyageNumber = @c_VoyageNumber,
   	  	 	      Trafficcop = NULL   	  	 	      
   	  	 	  WHERE Mbolkey = @c_Mbolkey

            SET @n_Err = @@ERROR 
            
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
               SET @n_Err = 61500
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update MBOL Fail. (ispPOMBD03)'
                              + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
            END                           	  	 	     	  	 	  
   	  	 END   	  	 
   	  END          
   END

   QUIT_SP:  
    
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOMBD03'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END

GO