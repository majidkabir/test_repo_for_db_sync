SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_FinalizeBookingOut_Wrapper                   */                                                                                  
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
CREATE PROC [WM].[lsp_FinalizeBookingOut_Wrapper]                                                                                                                     
      @n_BookingNo            INT 
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_Err                  INT = 0           OUTPUT                                                                                                             
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
         
         ,  @c_Facility             NVARCHAR(5)    = ''
         ,  @c_Facility_SCFG        NVARCHAR(5)    = ''
         ,  @c_Storerkey            NVARCHAR(15)   = ''

         ,  @c_Status               NVARCHAR(10)   = ''
         ,  @c_Finalizeflag         NVARCHAR(10)   = ''
         ,  @c_Bayoutloc            NVARCHAR(10)   = ''
         
         ,  @c_BKOValidationRules   NVARCHAR(30)   = ''
         ,  @c_SQL                  NVARCHAR(1000) = ''

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
   
   BEGIN TRY
      SELECT @c_Status = Status   
         , @c_FinalizeFlag = Finalizeflag  
         , @c_Bayoutloc = Loc  
      FROM BOOKING_OUT WITH (NOLOCK)   
      WHERE BookingNo = @n_BookingNo  
  
      IF @c_Status = 'R'  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 560501  
         SET @c_ErrMsg = 'NSQL' + CONVERT(char(6),@n_Err)+': Finalize rejected. BOOKING OUT in Reserved stage. (lsp_FinalizeBookingOut_Wrapper)'  
         GOTO EXIT_SP  
      END  
   
      IF @c_Status = '9'  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 560502  
         SET @c_ErrMsg = 'NSQL' + CONVERT(char(6),@n_Err)+': Finalize rejected. BOOKING OUT had been completed. (lsp_FinalizeBookingOut_Wrapper)'  
         GOTO EXIT_SP  
      END  
   
      IF @c_FinalizeFlag = 'Y'  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 560503  
         SET @c_ErrMsg = 'NSQL' + CONVERT(char(6),@n_Err)+': Finalize rejected. BOOKING OUT had been finalized. (lsp_FinalizeBookingOut_Wrapper)'  
         GOTO EXIT_SP  
      END 
   
      SELECT TOP 1 @c_Facility = o.Facility
               ,   @c_Storerkey= o.StorerKey
      FROM dbo.TMS_Shipment AS ts WITH (NOLOCK)
      JOIN dbo.TMS_ShipmentTransOrderLink AS tstol WITH (NOLOCK) ON tstol.ShipmentGID = ts.ShipmentGID
      JOIN dbo.TMS_TransportOrder AS tto WITH (NOLOCK) ON tto.ProvShipmentID = tstol.ProvShipmentID
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = tto.OrderSourceID
      WHERE ts.BookingNo = @n_BookingNo
      ORDER BY ts.Rowref
            ,  tto.Rowref
   
      IF @c_Storerkey <> ''   
      BEGIN  
         SELECT TOP 1 @c_BKOValidationRules = ISNULL(SC.sValue,'')
               ,  @c_Facility_SCFG = SC.Facility
         FROM dbo.STORERCONFIG SC (NOLOCK)  
         WHERE SC.StorerKey = @c_StorerKey  
         AND SC.Configkey = 'BKOExtendedValidation' 
         ORDER BY CASE WHEN SC.Facility = @c_Facility THEN 1
                       WHEN SC.Facility = '' THEN 2
                       END 
  
         IF @c_Facility_SCFG <> '' AND @c_Facility_SCFG <> @c_Facility
         BEGIN
            SET @c_BKOValidationRules = ''
         END
  
         IF @c_BKOValidationRules <> ''
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_BKOValidationRules) AND type = 'P')            
            BEGIN    
               SET @c_SQL = 'EXEC ' + @c_BKOValidationRules + ' @n_BookingNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
  
               EXEC sp_executesql @c_SQL            
                   , N'@n_BookingNo NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'  
                   , @n_BookingNo             
                   , @b_Success  OUTPUT             
                   , @n_Err      OUTPUT            
                   , @c_ErrMsg   OUTPUT   
               
               IF @b_Success <> 1       
               BEGIN      
                  SET @n_Continue = 3      
                  SET @n_err = 560504   
                  SET @c_errmsg = 'NSQL' + CONVERT(char(6),@n_err)+': Booking Out Extended Validation Failed. ([lsp_FinalizeBookingOut_Wrapper])  ( '      
                                + RTRIM(@c_errmsg) + ' ) '    
                  GOTO EXIT_SP  
               END           
            END   
            ELSE
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.CODELKUP AS c WITH (NOLOCK) WHERE c.Listname = @c_BKOValidationRules)
               BEGIN
                  EXEC isp_BKO_ExtendedValidation @n_BookingNo = @n_BookingNo   
                                         ,  @c_BKOValidationRules = @c_BKOValidationRules  
                                         ,  @b_Success = @b_Success  OUTPUT  
                                         ,  @c_ErrMsg  = @c_ErrMsg   OUTPUT  
  
  
                  IF @b_Success <> 1  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_err = 560505  
                     SET @c_errmsg = 'NSQL' + CONVERT(char(6),@n_err)+': Executing isp_BKO_ExtendedValidation Fail - Booking Out Extended Validation. ([lsp_FinalizeBookingOut_Wrapper])  ( '      
                                   + RTRIM(@c_errmsg) + ' ) '  
                     GOTO EXIT_SP    
                  END               
               END
            END
         END
      END

      BEGIN TRAN
      
      UPDATE o WITH (ROWLOCK)
      SET Door = @c_Bayoutloc
         ,EditWho = SUSER_NAME()  
         ,EditDate= GETDATE()  
         ,Trafficcop = NULL  
      FROM dbo.TMS_Shipment AS ts WITH (NOLOCK)
      JOIN dbo.TMS_ShipmentTransOrderLink AS tstol WITH (NOLOCK) ON tstol.ShipmentGID = ts.ShipmentGID
      JOIN dbo.TMS_TransportOrder AS tto WITH (NOLOCK) ON tto.ProvShipmentID = tstol.ProvShipmentID
      JOIN dbo.ORDERS AS o ON o.OrderKey = tto.OrderSourceID
      WHERE ts.BookingNo = @n_BookingNo
      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560506
         SET @c_ErrMsg = 'MSQL' + CONVERT(CHAR(6),@n_Err) + ': Update ORDERS Fail. (lsp_FinalizeBookingOut_Wrapper)'
         GOTO EXIT_SP
      END 
      
      UPDATE dbo.Booking_Out WITH (ROWLOCK)
         SET FinalizeFlag = 'Y'
            ,EditWho = SUSER_SNAME()
            ,EditDate = GETDATE()
      WHERE BookingNo = @n_BookingNo
       
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560507
         SET @c_ErrMsg = 'MSQL' + CONVERT(CHAR(6),@n_Err) + ': Update Booking_Out Fail. (lsp_FinalizeBookingOut_Wrapper)'
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

   IF @n_Continue = 3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'lsp_FinalizeBookingOut_Wrapper'
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