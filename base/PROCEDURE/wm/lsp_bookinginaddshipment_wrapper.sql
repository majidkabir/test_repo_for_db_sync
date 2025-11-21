SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_BookingInAddShipment_Wrapper                 */                                                                                  
/* Creation Date: 2023-12-19                                            */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: 3899 - SCE RG  Inbound Door booking v1.4                    */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2023-12-19  Wan01-v0 1.0   Created.                                  */
/* 2023-12-19  Wan01-v0 1.0   DevOps Combine Script.                    */
/* 2024-07-02  Inv Team 1.1   UWP-17135 - Migrate Inbound Door booking  */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_BookingInAddShipment_Wrapper]                                                                                                                     
      @n_BookingNo            INT                           --Booking In's Booking No
   ,  @c_ShipmentGIDs         NVARCHAR(MAX)                -- Multiple ShipmentGID Seperated by '|' 
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

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1
         
         ,  @dt_ShipmentPlannedStartDate  DATETIME = NULL    
         ,  @dt_ShipmentPlannedEndDate    DATETIME = NULL    
         
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
      WHERE ts.BookingNo IN (0, NULL)

      SELECT @dt_ShipmentPlannedStartDate = bi.BookingDate
            ,@dt_ShipmentPlannedEndDate   = bi.EndTime
      FROM dbo.Booking_In AS bi (NOLOCK) 
      WHERE bi.BookingNo = @n_BookingNo
   
      UPDATE ts WITH (ROWLOCK)
      SET ts.BookingNo = @n_BookingNo
         ,ts.ShipmentPlannedStartDate = @dt_ShipmentPlannedStartDate
         ,ts.ShipmentPlannedEndDate   = @dt_ShipmentPlannedEndDate  
      FROM @t_Shipment AS ts2 
      JOIN dbo.TMS_Shipment AS ts ON ts.RowRef = ts2.RowRef
          
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 562001
         SET @c_ErrMsg = 'MSQL' + CONVERT(CHAR(6),@n_Err) + ': Update TMS_Shipment fail. (lsp_BookingInAddShipment_Wrapper)'
         GOTO EXIT_SP
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_BookingInAddShipment_Wrapper'
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