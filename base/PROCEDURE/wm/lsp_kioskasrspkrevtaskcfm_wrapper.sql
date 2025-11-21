SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_KioskASRSPKRevTaskCfm_Wrapper                */  
/* Creation Date: 18-JUN-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-572 - Stored Procedures for Release 2 Feature¿C GTM Kiosk*/
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_KioskASRSPKRevTaskCfm_Wrapper]  
   @c_Jobkey               NVARCHAR(10)
,  @c_TaskDetailkey        NVARCHAR(10)  
,  @c_Lot                  NVARCHAR(10)
,  @c_ID                   NVARCHAR(18)
,  @c_PickToID             NVARCHAR(10)
,  @n_QtyInCS              INT 
,  @n_QtyInEA              INT 
,  @n_QtyToPutInCS         INT
,  @n_QtyToPutInEA         INT
,  @n_CaseCnt              FLOAT
,  @c_TaskStatus           NVARCHAR(10) = '0'   OUTPUT
,  @b_Success              INT          = 1     OUTPUT   
,  @n_Err                  INT          = 0     OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''    OUTPUT
,  @c_UserName             NVARCHAR(128)= ''
,  @n_AlertNo              INT          = 0     OUTPUT
,  @c_AlertMsg             NVARCHAR(255)= ''    OUTPUT
,  @c_ProceedWithAlert     CHAR(1)      = 'N'
,  @c_ConfirmAt            CHAR(1)      = 'c' 

AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Qty             INT
         , @n_QtyToPut        INT

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   --(mingle01) - START
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
   --(mingle01) - END

   --(mingle01) - START
   BEGIN TRY

      SET @n_Qty = (@n_QtyInCS * @n_CaseCnt) + @n_QtyInEA
      SET @n_QtyToPut = (@n_QtyToPutInCS * @n_CaseCnt) + @n_QtyToPutInEA

      IF @c_ProceedWithAlert = 'N' AND @n_Qty < 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550851
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) +  ': Qty Picked less than 0.'
         GOTO EXIT_SP
      END

      IF @c_ProceedWithAlert = 'Y' AND @c_AlertMsg <> '' 
      BEGIN
         BEGIN TRY      
            EXEC isp_KioskASRSAlertSupv
               @c_Jobkey         = @c_Jobkey
            ,  @c_ID             = @c_ID 
            ,  @b_Hold           = 1
            ,  @c_AlertCode      = 'SHORT/DMG'
            ,  @b_Success        = @b_Success   OUTPUT   
            ,  @n_Err            = @n_Err       OUTPUT
            ,  @c_Errmsg         = @c_AlertMsg  OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 550852
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': Alert Supervisor fail. ' +  @c_ErrMsg 
         END CATCH  

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END      
      END

      IF @n_AlertNo < 1 AND @n_Qty <> @n_QtyToPut
      BEGIN
         SET @n_AlertNo = 1
         SET @c_AlertMsg= 'Discrepency pick from pallet: ' + RTRIM(@c_ID)
                        + ' to pallet: ' +  RTRIM(@c_PickToID)
                        + '. System suggests to pick ' + CONVERT(NVARCHAR(5), @n_QtyToPutInCS)
                        + ' Carton ' + CONVERT(NVARCHAR(5), @n_QtyToPutInEA) + ' EA '
                        + ' but actual pick ' + CONVERT(NVARCHAR(5), @n_QtyInCS)
                        + ' Carton ' + CONVERT(NVARCHAR(5), @n_QtyInEA) + ' EA.'
               
         SET @n_Continue = 3
         SET @c_ErrMsg = @c_AlertMsg + ' Do you wist to continue and alert supervisor?'
         GOTO EXIT_SP
      END

      BEGIN TRY  
         IF @c_ConfirmAt = 'c'
         BEGIN    
            EXEC isp_KioskASRSPKRevTaskCfm
               @c_Jobkey            = @c_Jobkey
            ,  @c_TaskDetailkey     = @c_TaskDetailkey 
            ,  @c_Lot               = @c_Lot
            ,  @c_ID                = @c_ID
            ,  @c_PickToID          = @c_PickToID
            ,  @n_PickToQty         = @n_Qty
            ,  @n_QtyToPut          = @n_QtyToPut
            ,  @c_TaskStatus        = @c_TaskStatus   OUTPUT
            ,  @b_Success           = @b_Success      OUTPUT   
            ,  @n_Err               = @n_Err          OUTPUT
            ,  @c_Errmsg            = @c_Errmsg       OUTPUT
         END
         ELSE
         BEGIN
            EXEC isp_KioskASRSPKCIPRevTaskCfm
               @c_Jobkey            = @c_Jobkey
            ,  @c_TaskDetailkey     = @c_TaskDetailkey 
            ,  @c_Lot               = @c_Lot
            ,  @c_ID                = @c_ID
            ,  @c_PickToID          = @c_PickToID
            ,  @n_PickToQty         = @n_Qty
            ,  @n_QtyToPut          = @n_QtyToPut
            ,  @c_TaskStatus        = @c_TaskStatus   OUTPUT
            ,  @b_Success           = @b_Success      OUTPUT   
            ,  @n_Err               = @n_Err          OUTPUT
            ,  @c_Errmsg            = @c_Errmsg       OUTPUT
         END
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 550853
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Confirm Reverse Pick Fail. ' +  @c_ErrMsg 
      END CATCH  

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END        
   
      SET @c_ErrMsg = 'Confirm Reverse Pick Successfully.'

   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
   
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

      IF @n_AlertNo = 0
      BEGIN
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_KioskASRSPKRevTaskCfm_Wrapper'
      END
   END
   ELSE
   BEGIN
      SET @n_AlertNo = 0
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END

   REVERT      
END  

GO