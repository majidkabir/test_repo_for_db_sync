SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_UpdateAutoAllocBatchDetail_Status               */
/* Creation Date: 19-Apr-2018                                            */
/* Copyright: LFL                                                        */
/* Written by:  Shong                                                    */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.3 (Unicode)                                           */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Rev   Purposes                                   */
/* 29-Sep-2018  TLTING  1.1   remove row LOCK                            */
/* 02-Nov-2018  SHONG   1.2   Move AutoAllocBatch to Log Table           */
/* 05-Jun-2019  WWANG01 1.3   Fix bug, Update AutoAllocBatch.Status      */
/* 20-Jun-2019  NJOW01  1.4   WMS-9408 Update order to indicate completed*/
/*                            auto allocation completed.                 */
/* 18-May-2022  SHONG   1.5   Transfer to Log with @c_Status (SWT02)     */
/*************************************************************************/
CREATE   PROC [dbo].[isp_UpdateAutoAllocBatchDetail_Status] (  
 @n_AABD_RowRef BIGINT,   
 @c_Status      NVARCHAR(10),  
 @n_Err         INT = 0 OUTPUT,  
 @c_ErrMsg      NVARCHAR(250) = '' OUTPUT )  
AS  
BEGIN  
 DECLARE @n_AllocBatchNo BIGINT,   
         @c_OrderKey     NVARCHAR(10),  
         @c_StorerKey    NVARCHAR(15),  
         @c_SKU          NVARCHAR(20),  
         @c_Facility     NVARCHAR(10),   
         @n_TotalSKU     INT = 0,   
         @n_SKUAllocated INT = 0  
   
 SELECT @n_AllocBatchNo = AllocBatchNo,  
        @c_OrderKey     = OrderKey,   
        @n_TotalSKU     = TotalSKU   
 FROM AutoAllocBatchDetail WITH (NOLOCK)   
   WHERE RowRef = @n_AABD_RowRef     
          
   SELECT @n_SKUAllocated = COUNT(DISTINCT SKU)  
   FROM ORDERDETAIL AS o WITH(NOLOCK)  
   WHERE o.OrderKey = @c_OrderKey   
   AND o.QtyAllocated + o.QtyPicked > 0     
         
   SELECT @c_StorerKey = o.StorerKey,   
          @c_Facility = o.Facility  
   FROM ORDERS AS o WITH(NOLOCK)  
   WHERE o.OrderKey = @c_OrderKey  
  
   IF @n_SKUAllocated = @n_TotalSKU   
      SET @c_Status = '9'  
      
   --NJOW01
   IF @c_Status IN('6','8','9')
   BEGIN 
      IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)
                WHERE Listname = 'AUTOALLOC'
                AND Storerkey = @c_Storerkey
                AND Notes = @c_Facility
                AND UDF01 = '1')
      BEGIN
      	
      	 UPDATE ORDERS WITH (ROWLOCK)
      	 SET UpdateSource = '1',
      	     TrafficCop = NULL
      	 WHERE Orderkey = @c_Orderkey
      	 AND UpdateSource <> '1'
      END
   END

   IF @c_Status = '9'
   BEGIN
      -- Caution: Cannot use NOLOCK hints here due to multi threads insertion and causing insertion fail 
      IF NOT EXISTS (SELECT 1 FROM AutoAllocBatchDetail_Log -- WITH (NOLOCK)
                   WHERE RowRef = @n_AABD_RowRef)
      BEGIN
         BEGIN TRY
            INSERT INTO AutoAllocBatchDetail_Log
            (
             RowRef,    AllocBatchNo, OrderKey,
             [Status],  AddDate,      TotalSKU,
             EditDate,  NoStockFound, AllocErrorFound,
             SKUAllocated
            )
            SELECT RowRef,    AllocBatchNo,    OrderKey,
                 --[Status],  (SWT02)
                 @c_Status, 
                 AddDate,       TotalSKU,
                 GETDATE(),  NoStockFound, AllocErrorFound,
                 SKUAllocated
            FROM AutoAllocBatchDetail -- WITH (NOLOCK)
            WHERE RowRef = @n_AABD_RowRef             
         END TRY
         BEGIN CATCH
            SET @n_Err = 81001
            SET @c_ErrMsg = N'NSQL81001: Insert to AutoAllocBatchDetail Failed! RowRef =' + CAST(@n_AABD_RowRef AS VARCHAR(10))
            EXEC [dbo].[nsp_LogError] @n_err = @n_Err, @c_errmsg = @c_ErrMsg, @c_module = 'isp_UpdateAutoAllocBatchDetail_Status'               
         END CATCH

      END
      IF EXISTS (SELECT 1 FROM AutoAllocBatchDetail_Log WITH (NOLOCK)
                 WHERE RowRef = @n_AABD_RowRef)
      BEGIN
         DELETE AutoAllocBatchDetail
         WHERE RowRef = @n_AABD_RowRef                    
      END
   END
   ELSE
   BEGIN
      UPDATE AutoAllocBatchDetail
         SET SKUAllocated = @n_SKUAllocated,
           [Status] = @c_Status,
           EditDate = GETDATE()
      WHERE RowRef = @n_AABD_RowRef
   END
   IF @c_Status IN ('4','5','6','7','8','9')
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM AutoAllocBatchDetail WITH (NOLOCK)
                     WHERE AllocBatchNo = @n_AllocBatchNo
                     AND   [Status] IN ('4','5','6','1'))   --WWANG01
      BEGIN
          EXEC  [dbo].[isp_UpdateAutoAllocBatch_Status]
               @n_AllocBatchNo = @n_AllocBatchNo,
               @c_Status       = '9',
               @n_Err          = @n_Err    OUTPUT,
               @c_ErrMsg       = @c_ErrMsg OUTPUT
      END
   END
END

GO