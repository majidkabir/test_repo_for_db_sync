SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_ConfirmPick                                    */    
/* Creation Date:                                                       */    
/* Copyright: LF Logistics                                              */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Update ORDERS to Status 5                                   */    
/*                                                                      */    
/* Return Status: None                                                  */    
/*                                                                      */    
/* Usage: For Backend Schedule job                                      */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: SQL Schedule Job                                          */    
/*                                                                      */    
/* PVCS Version: 1.4                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author       Purposes                                   */    
/************************************************************************/    
CREATE PROC [dbo].[isp_ConfirmPick]    
( @c_OrderKey NVARCHAR(10) = '',    
  @c_LoadKey  NVARCHAR(10) = '',    
  @b_Success  INT = 1 OUTPUT,    
  @n_err      INT = 0 OUTPUT,    
  @c_errmsg   NVARCHAR(215) = '' OUTPUT)    
AS    
BEGIN    
   DECLARE @n_Continue        INT, 
           @c_OrderLineNumber NVARCHAR(5) = '', 
           @c_Status          NVARCHAR(10)     
       
   SET @n_Continue = 1    
   SET @b_Success = 1    
   SET @n_err = 0     
   SET @c_errmsg = ''    
       
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''    
   BEGIN    
      IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK)    
                 WHERE ([Status] < '5' AND ShipFlag NOT IN ('P', 'Y'))     
                 AND   [Status] NOT IN ('5','6','7','8','9')    
                 AND   OrderKey = @c_OrderKey)       
      BEGIN    
         GOTO QUIT    
      END          
          
      DECLARE CUR_OrderKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT OrderKey     
      FROM   ORDERS WITH (NOLOCK)    
      WHERE  OrderKey = @c_OrderKey     
                
   END    
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''    
   BEGIN    
      DECLARE CUR_OrderKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT OrderKey     
      FROM   LoadPlanDetail AS lpd WITH (NOLOCK)    
      WHERE  lpd.LoadKey = @c_LoadKey     
          
   END --IF ISNULL(RTRIM(@c_LoadKey), '') <> ''    
    
   OPEN CUR_OrderKey    
       
   FETCH NEXT FROM CUR_OrderKey INTO @c_OrderKey     
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK)    
                 WHERE ([Status] < '5' AND ShipFlag NOT IN ('P', 'Y'))     
                 AND   [Status] NOT IN ('5','6','7','8','9')    
                 AND   OrderKey = @c_OrderKey)       
      BEGIN    
         GOTO FETCH_NEXT    
      END               
      
      DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, OrderLineNumber
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey 
      AND   [Status] < '5'
      
      OPEN CUR_ORDER_LINES
      
      FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE ORDERDETAIL WITH (ROWLOCK)     
            SET [Status] = '5', EditDate = GETDATE(), EditWho=sUser_sName(), TrafficCop = NULL     
         WHERE OrderKey = @c_OrderKey   
         AND   OrderLineNumber = @c_OrderLineNumber
         
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_Continue = 3    
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)    
            SET @n_err=72801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_ConfirmPick)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            ROLLBACK TRAN    
            BREAK             
         END    
      
      	FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber
      END      
      CLOSE CUR_ORDER_LINES
      DEALLOCATE CUR_ORDER_LINES     

      SET @c_Status = ''                  	
      SELECT @c_Status = o.[Status]
      FROM ORDERS AS o WITH(NOLOCK)
      WHERE o.OrderKey = @c_OrderKey
                     
      IF @c_Status < '5' AND @c_Status <> ''      
      BEGIN
         UPDATE ORDERS WITH (ROWLOCK)     
            SET [Status] = '5', EditDate = GETDATE(), EditWho=sUser_sName()      
         WHERE OrderKey = @c_OrderKey     
     
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_Continue = 3    
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)    
            SET @n_err=72802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Update Failed On Table ORDERS. (isp_ConfirmPick)' + ' ( ' 
                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            ROLLBACK TRAN    
            BREAK             
         END               	
      END
    
      FETCH_NEXT:    
      FETCH NEXT FROM CUR_OrderKey INTO @c_OrderKey     
          
   END    
   CLOSE CUR_OrderKey    
   DEALLOCATE CUR_OrderKey                       
                         
QUIT:    
       
END -- Procedure

GO