SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Robot_ToteID                                        */
/* Creation Date: 22-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5426 - CN SKECHERS TJ ROBOT -Toteid Report              */
/*        :                                                             */                                             
/*        :                                                             */
/* Called By: r_dw_robot_toteid                                         */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Robot_ToteID]
           @c_Storerkey    NVARCHAR(15) 
         , @c_Facility     NVARCHAR(5)
         , @c_FromToteID   NVARCHAR(10)  
         , @c_ToToteID     NVARCHAR(10)  
         , @c_RobotITF     CHAR(1) = 'N'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         
         , @n_StartDigit      INT 
         , @n_EndDigit        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Storerkey = ISNULL(RTRIM(@c_Storerkey),'')
   SET @c_Facility  = ISNULL(RTRIM(@c_Facility),'')
   SET @c_FromToteID = ISNULL(RTRIM(@c_FromToteID),'')
   SET @c_ToToteID = ISNULL(RTRIM(@c_ToToteID),'')
   SET @c_RobotITF = ISNULL(RTRIM(@c_RobotITF),'')

   CREATE TABLE #PRINT_TOTEID
   (  RowID    INT            IDENTITY (1,1)       
   ,  ToteID   NVARCHAR(10)
   )
  
   IF LEN(@c_FromToteID) <> 10 
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60010    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Form Tote ID format' 
                     + '.(isp_Robot_ToteID)' 
      GOTO QUIT_SP  
   END

   SET @n_StartDigit = RIGHT(@c_FromToteID,9)
   IF LEFT(@c_FromToteID,1) <> 'T' OR ISNUMERIC( @n_StartDigit ) <> 1  
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60020    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Form Tote ID format' 
                     + '.(isp_Robot_ToteID)' 
      GOTO QUIT_SP 
   END

   IF LEN(@c_ToToteID) <> 10 
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60030    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid To Tote ID format' 
                     + '.(isp_Robot_ToteID)' 
      GOTO QUIT_SP 
   END

   SET @n_EndDigit = RIGHT(@c_ToToteID,9)

   IF LEFT(@c_ToToteID,1) <> 'T' OR ISNUMERIC( @n_EndDigit) <> 1  
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60040    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid To Tote ID format' 
                     + '.(isp_Robot_ToteID)' 
      GOTO QUIT_SP 
   END

   WHILE @n_StartDigit <= @n_EndDigit
   BEGIN
      INSERT INTO  #PRINT_TOTEID
      VALUES ('T' + RIGHT('0000000000' + RTRIM(CONVERT(NVARCHAR(10), @n_StartDigit)),9))

      SET @n_StartDigit = @n_StartDigit + 1
   END

   IF @c_RobotITF = 'Y'
   BEGIN
      EXEC dbo.isp_WSITF_GeekPlusRBT_CONTAINER_Outbound 
        @c_StorerKey = @c_StorerKey            
      , @c_Facility = @c_Facility
      , @c_ITFType = 'T'                     
      , @c_FromToteId =@c_FromToteId
      , @c_ToToteId = @c_ToToteId
      , @c_TransmitlogKey = ''       
      , @b_Success = @b_Success  OUTPUT          
      , @n_Err     = @n_Err      OUTPUT
      , @c_ErrMsg  = @c_ErrMsg   OUTPUT  
 
      IF @b_Success <> 1 
      BEGIN 
         SET @n_Continue= 3    
         SET @n_Err     = 60050    
         SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing isp_WSITF_GeekPlusRBT_CONTAINER_Outbound ' 
                        + '.(isp_Robot_ToteID) ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg)+ ' )' 
         GOTO QUIT_SP  
      END
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_Robot_ToteID'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   SELECT RowID
         ,ToteID
   FROM #PRINT_TOTEID
  
END -- procedure

GO