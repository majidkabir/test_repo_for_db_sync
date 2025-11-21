SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispBookingOutLoadAdd                                  */  
/* Creation Date: 27-OCT-2014                                              */  
/* Copyright: IDS                                                          */  
/* Written by: YTWan                                                       */  
/*                                                                         */  
/* Purpose: SOS#322304 - PH - CPPI WMS Door Booking Enhancement            */                                 
/*                                                                         */  
/* Called By: w_Populate_bo_Load                                           */  
/*            close event                                                  */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/***************************************************************************/    
CREATE PROC [dbo].[ispBookingOutLoadAdd]    
(     @n_BookingNo   INT 
   ,  @c_Loadkey     NVARCHAR(10) 
   ,  @b_Success     INT            OUTPUT
   ,  @n_err         INT            OUTPUT
   ,  @c_ErrMsg      NVARCHAR(255)  OUTPUT
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug     INT  
         , @n_Continue  INT   
         , @n_StartTCnt INT   

 
   SET @b_Debug  = 1
   SET @n_Continue = 1    
   SET @n_StartTCnt = @@TRANCOUNT  

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN
   UPDATE LOADPLAN WITH (ROWLOCK)
      SET BookingNo = @n_BookingNo
         ,Trafficcop = NULL
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_NAME()
   WHERE Loadkey     = @c_Loadkey
   AND (BookingNo = '' OR BookingNo IS NULL)

   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOADPLAN Failed. (ispBookingOutLoadAdd)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
      GOTO QUIT_SP    
   END  

   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      execute nsp_logerror @n_err, @c_errmsg, 'ispBookingOutLoadAdd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO