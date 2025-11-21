SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UpdateAutoAllocBatchJobStatus                  */
/* Creation Date: 19-Apr-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:  Shong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 29Sep2018    TLTING  1.1   remove row LOCK                           */
/************************************************************************/
  
CREATE PROC [dbo].[isp_UpdateAutoAllocBatchJobStatus] (  
 @n_JobRowId BIGINT,   
 @c_Status      NVARCHAR(10),  
 @n_Err         INT = 0 OUTPUT,  
 @c_ErrMsg      NVARCHAR(250) = '' OUTPUT )  
AS  
BEGIN  
   DECLARE @n_AABD_RowRef  BIGINT,   
           @n_AllocBatchNo BIGINT  
  
   SELECT @n_AllocBatchNo = aabj.AllocBatchNo   
   FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)   
   WHERE aabj.RowID = @n_JobRowId              
     
 IF @c_Status = '9'  
 BEGIN  
      IF NOT EXISTS (SELECT 1 FROM AutoAllocBatchJob_Log WITH (NOLOCK)   
                     WHERE RowID = @n_JobRowId)  
      BEGIN  
         INSERT INTO AutoAllocBatchJob_Log  
         (  
            RowID,        AllocBatchNo,   Priority,  
            Facility,     Storerkey,      StrategyKey,  
            SKU,          [Status],       TotalOrders,  
            TotalQty,     TaskSeqNo,      AddDate,  
            EditDate            )  
         SELECT RowID,    AllocBatchNo,   Priority,  
            Facility,     Storerkey,      StrategyKey,  
            SKU,          '9',            TotalOrders,  
            TotalQty,     TaskSeqNo,      AddDate,  
            GETDATE()  
         FROM AutoAllocBatchJob WITH (NOLOCK)  
         WHERE RowID = @n_JobRowId                
                 
      END  
              
      DELETE AutoAllocBatchJob      
      WHERE RowID = @n_JobRowId      
           
 END -- IF @c_Status = '9'  
 ELSE IF @c_Status IN  ('0','5','6') -- 6 = No Stock, 5 = Error  
 BEGIN  
  UPDATE AutoAllocBatchJob     
     SET [Status] = @c_Status, EditDate = GETDATE()   
  WHERE RowID = @n_JobRowId   
    
  IF @c_Status IN  ('5','6')  
  BEGIN  
     DECLARE CUR_AABD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT DISTINCT RowRef  
     FROM AutoAllocBatchDetail AABD WITH (NOLOCK)   
     JOIN ORDERDETAIL AS o WITH(NOLOCK) ON o.OrderKey = AABD.OrderKey   
     JOIN AutoAllocBatchJob AS AABJ WITH(NOLOCK) ON AABJ.AllocBatchNo = AABD.AllocBatchNo   
           AND AABJ.StorerKey = o.StorerKey   
           AND AABJ.Sku = o.Sku  
     WHERE AABJ.RowID = @n_JobRowId   
      
     OPEN CUR_AABD  
    
     FETCH FROM CUR_AABD INTO @n_AABD_RowRef  
    
     WHILE @@FETCH_STATUS = 0  
     BEGIN  
      IF @c_Status = '5'  
      BEGIN  
         UPDATE AutoAllocBatchDetail   
            SET AllocErrorFound = 1, EditDate = GETDATE()  
         WHERE RowRef = @n_AABD_RowRef          
      END  
      ELSE IF @c_Status = '6'  
      BEGIN  
         UPDATE AutoAllocBatchDetail   
            SET NoStockFound = 1,  
                [Status] = CASE WHEN TotalSKU = 1 THEN '6'   
                                WHEN TotalSKU - SKUAllocated = 1 THEN '6'   
                                WHEN [Status] = '0' THEN '1'   
                                ELSE [Status]   
                           END,    
                EditDate = GETDATE()  
         WHERE RowRef = @n_AABD_RowRef       
      END  
    
      FETCH FROM CUR_AABD INTO @n_AABD_RowRef  
     END    
     CLOSE CUR_AABD  
     DEALLOCATE CUR_AABD     
  END   
 END -- IF @c_Status IN  ('0','5','6')  
   
   IF NOT EXISTS(SELECT 1 FROM [dbo].[AutoAllocBatchJob] AS aab WITH(NOLOCK)   
              WHERE aab.AllocBatchNo = @n_AllocBatchNo   
              AND   STATUS IN ('0','1'))   
   BEGIN        
      DECLARE CUR_AABD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT RowRef   
      FROM AutoAllocBatchDetail AABD WITH (NOLOCK)  
      WHERE AABD.AllocBatchNo = @n_AllocBatchNo  
        
      OPEN CUR_AABD  
        
      FETCH FROM CUR_AABD INTO @n_AABD_RowRef  
        
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
       EXEC isp_UpdateAutoAllocBatchDetail_Status  
        @n_AABD_RowRef = @n_AABD_RowRef,  
        @c_Status = '8', -- No Outstanding Job  
        @n_Err = @n_Err  OUTPUT,  
        @c_ErrMsg = @c_ErrMsg OUTPUT  
        
       FETCH FROM CUR_AABD INTO @n_AABD_RowRef  
      END  
      CLOSE CUR_AABD  
      DEALLOCATE CUR_AABD  
   END            

      
   --   IF NOT EXISTS (SELECT 1 FROM AutoAllocBatchDetail WITH (NOLOCK)  
   --                WHERE AllocBatchNo = @n_AllocBatchNo  
   --                  AND   [Status] NOT IN ('4','5','6','8'))  
   --   BEGIN  
   --       EXEC  [dbo].[isp_UpdateAutoAllocBatch_Status]   
   --            @n_AllocBatchNo = @n_AllocBatchNo,   
   --            @c_Status       = '9',  
   --            @n_Err          = @n_Err    OUTPUT,  
   --            @c_ErrMsg       = @c_ErrMsg OUTPUT  
   --   END         

END

GO