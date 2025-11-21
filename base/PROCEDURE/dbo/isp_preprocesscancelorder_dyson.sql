SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PreprocessCancelOrder_Dyson                    */
/* Creation Date: 10-05-2023                                            */
/* Copyright: IDS                                                       */
/* Written by: TLTING                                                   */
/*                                                                      */
/* Purpose: Preprocess for Dyson Orders cancel                          */
/*                                                                      */
/* Called By: SQL Jobs                                                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 10-05-2023   TLTING   1.0  Initial Version                           */
/* 26-05-2023   TLTING01 1.1  add Orders status filtering               */
/************************************************************************/

CREATE    PROC [dbo].[isp_PreprocessCancelOrder_Dyson]   
   @c_Storerkey   NVARCHAR(15)   
AS   
BEGIN  
SET NOCOUNT ON  
SET ANSI_NULLS OFF                
SET QUOTED_IDENTIFIER OFF                 
SET CONCAT_NULL_YIELDS_NULL OFF     
  
  DECLARE   @c_Key1              NVARCHAR(10)      
            ,@c_Key2              NVARCHAR(5)      
            ,@c_Key3              NVARCHAR(20)      
            ,@c_TransmitBatch     NVARCHAR(30)      
            ,@b_success           INT      
            ,@n_err               INT      
            ,@c_errmsg            NVARCHAR(250)      
            ,@n_continue          INT      
            ,@n_rowcount          INT   
  
   Declare @c_Orderkey     Nvarchar(10)  = ''  
   , @c_status             Nvarchar (10) = ''  
   , @c_SOstatus           Nvarchar (10) = ''  
   , @c_WorkOrderKey       Nvarchar(10) = ''  
   , @c_PreWorkOrderKey    Nvarchar(10) = ''  
   , @c_WorkOrderLineNumber Nvarchar(5) = '00000'  
   , @c_externOrderKey     nvarchar(50)  
   , @c_UserDefine01       Nvarchar(20)  
   , @c_TotalOriginalQty    INT  
   , @c_WrkDetStatus Nvarchar(10)  
   , @c_Type         Nvarchar(12) = '10'  

   SET @c_Key2 = 'CANC'  -- follow IML sp
  
  
   DECLARE CUR_OrderItem CURSOR LOCAL FAST_FORWARD READ_ONLY       
   FOR                    
   SELECT W.WorkOrderKey, O.Orderkey, O.Status, O.SOstatus , O.ExternOrderKey, O.UserDefine01  
   FROM Orders O (nolock)     
   JOIN workorder W (nolock)    on O.userdefine01= W.WkOrdUdef8  and O.storerkey=W.storerkey  
   WHERE O.storerkey = @c_Storerkey   
   AND W.status = '0'
   AND O.Status <= '5'   --tlting01
   AND not exists ( Select 1   
      FROM workorderdetail (nolock) wd    
      WHERE O.storerkey=wd.storerkey and O.ExternOrderKey=wd.WkOrdUdef1 )  
   Order by W.WorkOrderKey, O.Orderkey  
     
   OPEN CUR_OrderItem       
   FETCH NEXT FROM CUR_OrderItem INTO @c_WorkOrderKey, @c_Orderkey, @c_Status , @c_SOstatus , @c_externOrderKey, @c_UserDefine01  
               
   WHILE (@@FETCH_STATUS<>-1)      
   BEGIN      
      BEGIN TRAN  
      SET @c_Type = '10'  
  
      IF @c_PreWorkOrderKey <> @c_WorkOrderKey   
      BEGIN  
         Select @c_WorkOrderLineNumber = MAX(WorkOrderLineNumber)  
         From WorkOrderDetail (NOLOCK)  
         Where WorkOrderKey = @c_WorkOrderKey  
      END  
  
      SET @c_WorkOrderLineNumber = @c_WorkOrderLineNumber + 1    
      SET @c_WorkOrderLineNumber = RIGHT('00000' + RTRIM(CAST(CAST(@c_WorkOrderLineNumber AS INT) AS NVARCHAR(5))),5)    
  
      IF @c_Status in ('0','1','2','3','5')  
      BEGIN  
  
      --update those orders status is pendcancel. insert those orders infomation into workorderdetail ,   
      --set status is 9, generate transmitlog2 record, tablename is WSCANCCSRM,key1=orderkey  
         BEGIN TRY  
            UPDATE Orders  
            SET SOstatus = 'PENDCANC', editdate = getdate(), editwho = SUSER_SNAME()  
            WHERE Orders.Orderkey = @c_Orderkey  
  
          END TRY  
          BEGIN CATCH  
            SET @n_continue = 3     
            SET @n_err = 551510  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                           + ': Update Orders Table Fail. (isp_PreprocessCancelOrder_Dyson)'  
                           + '(' + @c_errmsg + ')'   
                             
            IF (XACT_STATE()) = -1     --(Wan02) - START    
            BEGIN    
               ROLLBACK TRAN;    
            END;                       --(Wan02) - END                                
            GOTO EXIT_SP  
         END CATCH  
           
         SET @c_WrkDetStatus = '9'  
    
         BEGIN TRY  
            EXEC ispGenTransmitLog2 'WSCANCCSRM'      
                  ,@c_Orderkey      
                  ,@c_Key2      
                  ,@c_StorerKey      
                  ,@c_TransmitBatch      
                  ,@b_Success OUTPUT      
                  ,@n_err OUTPUT      
                  ,@c_errmsg OUTPUT   
          END TRY  
          BEGIN CATCH  
            SET @n_continue = 3     
            SET @n_err = 551550  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                           + ': Get TransmitLog2 key Orders Table Fail. (isp_PreprocessCancelOrder_Dyson)'  
                           + '(' + @c_errmsg + ')'   
                             
            IF (XACT_STATE()) = -1     --(Wan02) - START    
            BEGIN    
               ROLLBACK TRAN;    
            END;                       --(Wan02) - END                                
            GOTO EXIT_SP  
         END CATCH  
           
      END  
  
  
      IF @c_Status = '9'  
      BEGIN   
         SET @c_Type = '20'   
         SET @c_WrkDetStatus = '0'  
           
         BEGIN TRY  
            EXEC ispGenTransmitLog2 'WSCANCCMS'      
                  ,@c_Orderkey      
                  ,@c_Key2      
                  ,@c_StorerKey      
                  ,@c_TransmitBatch      
                  ,@b_Success OUTPUT      
                  ,@n_err OUTPUT      
                  ,@c_errmsg OUTPUT      
          END TRY  
          BEGIN CATCH  
            SET @n_continue = 3     
            SET @n_err = 551560  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                           + ': Get TransmitLog2 key Orders Table Fail. (isp_PreprocessCancelOrder_Dyson)'  
                           + '(' + @c_errmsg + ')'   
                             
            IF (XACT_STATE()) = -1     --(Wan02) - START    
            BEGIN    
               ROLLBACK TRAN;    
            END;                       --(Wan02) - END                                
            GOTO EXIT_SP  
         END CATCH                    
      END  
  
      SELECT @c_TotalOriginalQty = SUM(OriginalQty)  
      FROM Orderdetail (NOLOCK)  
      WHERE Orderkey = @c_Orderkey  
  
      IF not exists ( SELECT 1 from WorkOrderDetail (NOLOCK) 
                     WHERE WkOrdUdef1 = SUBSTRING(@c_externOrderKey,1,18)
                     AND  StorerKey = @c_StorerKey  )
      BEGIN
         BEGIN TRY 
         INSERT INTO  WorkOrderDetail ( WorkOrderKey, WorkOrderLineNumber, ExternWorkOrderKey, ExternLineNo, Type, Reason, Unit, Qty, Price,  
                                       WkOrdUdef1, WkOrdUdef2, Status, StorerKey, WkOrdUdef8, WkOrdUdef9)    
         VALUES(@c_WorkOrderKey, -- WorkOrderKey - nvarchar(10)    
         @c_WorkOrderLineNumber , -- WorkOrderLineNumber - nvarchar(5)    
         N'' , -- ExternWorkOrderKey - nvarchar(20)    
         N'' , -- ExternLineNo - nvarchar(5)    
         @c_Type , -- Type - nvarchar(12)    
         N'' , -- Reason - nvarchar(10)    
         N'' , -- Unit - nvarchar(10) 
         0   , -- Qty - int 
         0   , -- Price - int  
         SUBSTRING(@c_externOrderKey,1,18) , -- WkOrdUdef1 - nvarchar(18)    
         CAST(@c_TotalOriginalQty AS NVARCHAR(10)) , -- WkOrdUdef2 - nvarchar(18)    
         @c_WrkDetStatus , -- Status - nvarchar(10)    
         @c_StorerKey, -- StorerKey - nvarchar(15)    
         SUBSTRING(@c_UserDefine01,1,30) , -- WkOrdUdef8 - nvarchar(30)    
         ''   -- WkOrdUdef9 - nvarchar(30)    
               )    
            END TRY  
            BEGIN CATCH  
            SET @n_continue = 3     
            SET @n_err = 551520  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                           + ': INSERT WorkOrderDetail Table Fail. (isp_PreprocessCancelOrder_Dyson)'  
                           + '(' + @c_errmsg + ')'   
                             
            IF (XACT_STATE()) = -1     --(Wan02) - START    
            BEGIN    
               ROLLBACK TRAN;    
            END;                       --(Wan02) - END                                
            GOTO EXIT_SP  
         END CATCH  
      END

      COMMIT TRAN  
  
      FETCH NEXT FROM CUR_OrderItem INTO @c_WorkOrderKey, @c_Orderkey, @c_Status , @c_SOstatus , @c_externOrderKey, @c_UserDefine01  
   END --(@@FETCH_STATUS <> -1)        
   CLOSE CUR_OrderItem       
   DEALLOCATE CUR_OrderItem   
     
  
   DECLARE CUR_WrkOrderItem CURSOR LOCAL FAST_FORWARD READ_ONLY       
   FOR          
   Select WorkOrderKey  
   FROM WorkOrder (NOLOCK)  
   Where Status = '0'  
   AND StorerKey = @c_Storerkey  
   AND  CAST(WorkOrder.WkOrdUdef2 as INT)  =  ( SELECT sum( CAST(ISNULL(workorderdetail.WkOrdUdef2, 0) as INT) )    
                  FROM WorkorderDetail (NOLOCK)   
                  Where WorkOrder.WorkOrderKey = WorkorderDetail.WorkOrderKey   
                     )  
   AND Not exists ( SELECT 1   
                  FROM WorkorderDetail (NOLOCK)   
                  Where WorkOrder.WorkOrderKey = WorkorderDetail.WorkOrderKey  
                  AND  workorderdetail.status = '0' )  
     
   OPEN CUR_WrkOrderItem       
   FETCH NEXT FROM CUR_WrkOrderItem INTO @c_WorkOrderKey  
               
   WHILE (@@FETCH_STATUS<>-1)      
   BEGIN      
      BEGIN TRAN      
         
       BEGIN TRY    
       Update  WorkOrder   
       SET status = '9', EditDate = getdate() , EditWho = SUSER_SNAME()  
       WHERE WorkOrderKey = @c_WorkOrderKey  
          END TRY  
          BEGIN CATCH  
            SET @n_continue = 3     
            SET @n_err = 551530  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err)   
                           + ': Update WorkOrder Table Fail. (isp_PreprocessCancelOrder_Dyson)'  
                           + '(' + @c_errmsg + ')'   
                             
            IF (XACT_STATE()) = -1     --(Wan02) - START    
            BEGIN    
               ROLLBACK TRAN;    
            END;                       --(Wan02) - END                                
            GOTO EXIT_SP  
         END CATCH  
  
      COMMIT TRAN  
  
         FETCH NEXT FROM CUR_WrkOrderItem INTO @c_WorkOrderKey  
   END --(@@FETCH_STATUS <> -1)        
   CLOSE CUR_WrkOrderItem       
   DEALLOCATE CUR_WrkOrderItem   
  
   EXIT_SP:  
  
END

GO