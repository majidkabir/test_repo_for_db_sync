SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_BookingOutAddShipment_Wrapper                */                                                                                  
/* Creation Date: 2022-03-02                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3336 - Door Booking SPsDB queries clarification        */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2022-03-02  Wan01    1.0   Created.                                  */
/* 2022-03-02  Wan01    1.0   DevOps Combine Script.                    */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_BookingOutAddShipment_Wrapper]                                                                                                                     
      @n_BookingNo            INT 
   ,  @c_ShipmentGIDs         NVARCHAR(1000)                -- Multiple ShipmentGID Seperated by '|' 
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT 
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1
         
   DECLARE @t_Shipment     TABLE 
         (  RowRef         INT         PRIMARY KEY
         ,  ShipmentGID    NVARCHAR(50)   NOT NULL DEFAULT('')
         )      

   SET @b_Success = 1
   SET @n_Err     = 0
   
   SET @n_Err = 0 
 
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END

   BEGIN TRAN  
   BEGIN TRY
      INSERT INTO @t_Shipment (RowRef, ShipmentGID)
      SELECT ts.Rowref, ts.ShipmentGID
      FROM STRING_SPLIT(@c_ShipmentGIDs,'|') AS ss
      JOIN dbo.TMS_Shipment AS ts WITH (NOLOCK) ON ts.ShipmentGID = ss.[value]
      WHERE (ts.BookingNo = 0 OR ts.BookingNo IS NULL)
   
      UPDATE ts WITH (ROWLOCK)
      SET BookingNo = @n_BookingNo
      FROM @t_Shipment AS ts2 
      JOIN dbo.TMS_Shipment AS ts ON ts.RowRef = ts2.RowRef
      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560451
         SET @c_ErrMsg = 'MSQL' + CONVERT(CHAR(6),@n_Err) + ': Update TMS_Shipment fail. (lsp_BookingOutAddShipment_Wrapper)'
         GOTO EXIT_SP
      END
      
      IF EXISTS (SELECT 1 FROM dbo.Booking_Out AS bo WITH (NOLOCK) WHERE bo.BookingNo = @n_BookingNo AND bo.[Status] = 'R')
      BEGIN
         UPDATE dbo.Booking_Out WITH (ROWLOCK)
            SET [Status] = '0'
               ,EditWho = SUSER_SNAME()
               ,EditDate = GETDATE()
         WHERE BookingNo = @n_BookingNo
         AND [Status] = 'R'
         
         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 560452
            SET @c_ErrMsg = 'MSQL' + CONVERT(CHAR(6),@n_Err) + ': Update Booking_Out fail. (lsp_BookingOutAddShipment_Wrapper)'
            GOTO EXIT_SP
         END
      END    
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

EXIT_SP:
   IF (XACT_STATE()) = -1                                     
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt      
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_BookingOutAddShipment_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO