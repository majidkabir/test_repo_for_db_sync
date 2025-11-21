SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: Delete Order and related records in other table                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-04-27 1.0  SHONG      Created                                         */  
/* 2020-05-06 1.1  SHONG      Not allow to proceed if OrderKey = BLANK or     */
/*                            OrderKey not found                              */
/******************************************************************************/                 
CREATE PROC [dbo].[isp_Std_DeleteOrders] (
   @c_OrderKey    NVARCHAR(10),
   @b_Debug       INT = 0,
   @n_Error       INT = 0 OUTPUT, 
   @c_ErrMsg      NVARCHAR(215)= '' OUTPUT
) AS
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @c_Status          NVARCHAR(10)=''
          ,@c_SOStatus        NVARCHAR(10)=''
          ,@c_PickSlipNo      NVARCHAR(10)=''
          ,@c_StorerKey       NVARCHAR(15)=''
          ,@c_PackStatus      NVARCHAR(10)=''
          ,@c_TaskDetailKey   NVARCHAR(10)=''
          ,@n_starttcnt       INT = 0 
   
   SELECT @n_StartTCnt=@@TRANCOUNT  
   
   BEGIN TRAN;

   IF ISNULL(RTRIM(@c_OrderKey), '') = ''
   BEGIN
      SET @n_Error = 65006
      SET @c_ErrMsg = 'OrderKey is BLANK.'
      GOTO EXIT_SP      
   END

   SET @c_StorerKey=''   
   SELECT  @c_Status   = ISNULL(o.[Status],''), 
           @c_SOStatus = ISNULL(o.SOStatus,''),
           @c_StorerKey = ISNULL(o.StorerKey,'') 
   FROM ORDERS AS o WITH(NOLOCK)
   WHERE o.OrderKey = @c_OrderKey
   IF @c_StorerKey=''
   BEGIN
      SET @n_Error = 65007
      SET @c_ErrMsg = 'StorerKey is Exists.'
      GOTO EXIT_SP            
   END

   IF @c_SOStatus = 'CANC' OR @c_Status = 'CANC.'
   BEGIN
      SET @n_Error = 65001
      SET @c_ErrMsg = 'Canceled Order(s) Not Allow to Delete.'
      GOTO EXIT_SP      
   END         
           
   IF EXISTS(SELECT 1 FROM PICKDETAIL AS p WITH(NOLOCK)
             WHERE p.OrderKey = @c_OrderKey
             AND ( p.[Status]='9' OR p.ShipFlag='Y'))
   BEGIN
      SET @n_Error = 65002
      SET @c_ErrMsg = 'Order Already Shipped, Not allow to delete.'
      GOTO EXIT_SP      
   END
   
   SET @c_PickSlipNo = ''
   SET @c_PackStatus = '0'
   
   SELECT @c_PickSlipNo = ph.PickSlipNo, 
          @c_PackStatus = ph.[Status]
   FROM PackHeader AS ph WITH(NOLOCK)
   WHERE ph.OrderKey = @c_OrderKey
   AND ph.StorerKey=@c_StorerKey
   
   IF @c_PickSlipNo <> '' 
   BEGIN
      DELETE PackDetail 
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Error = 65003
         SET @c_ErrMsg = 'Delete PackDetail Failed.'
         GOTO EXIT_SP      
      END         
      
      DELETE FROM PackInfo
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Error = 65004
         SET @c_ErrMsg = 'Delete PackInfo Failed.'
         GOTO EXIT_SP      
      END       
            
      DELETE FROM PackHeader
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Error = 65005
         SET @c_ErrMsg = 'Delete PackHeader Failed.'
         GOTO EXIT_SP      
      END             
   END
   
   DECLARE CUR_TaskDetail CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT TaskDetailKey
   FROM TaskDetail WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
   AND Storerkey = @c_StorerKey
   AND OrderKey <> ''
   AND [Status] <> '9'
   
   OPEN CUR_TaskDetail
   
   FETCH FROM CUR_TaskDetail INTO @c_TaskDetailKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE FROM TaskDetail
      WHERE TaskDetailKey=@c_TaskDetailKey      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Error = 65006
         SET @c_ErrMsg = 'Delete TaskDetail Failed.'
         GOTO EXIT_SP      
      END             
   
      FETCH FROM CUR_TaskDetail INTO @c_TaskDetailKey
   END
   
   CLOSE CUR_TaskDetail
   DEALLOCATE CUR_TaskDetail
   
   IF EXISTS(SELECT 1 FROM ShortPickLog WITH (NOLOCK)
             WHERE OrderKey=@c_OrderKey)
   BEGIN
      DELETE ShortPickLog
      WHERE OrderKey = @c_OrderKey
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Error = 65007
         SET @c_ErrMsg = 'Delete ShortPickLog Failed.'
         GOTO EXIT_SP      
      END                
   END
   
   DELETE FROM ORDERS
   WHERE OrderKey=@c_OrderKey
   IF @@ERROR <> 0 
   BEGIN
      SET @n_Error = 65008
      SET @c_ErrMsg = 'Delete ORDERS Failed.'
      GOTO EXIT_SP      
   END          
   
   EXIT_SP:
   IF @n_Error > 0   
   BEGIN  
      IF @@TRANCOUNT >= @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END     
END

GO