SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_UpdateAutoAllocBatch_Status                    */
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
/* 18-05-2022   Shong   1.1   Using Try-Catch when insert AutoAllocBatch*/
/************************************************************************/
CREATE   PROC [dbo].[isp_UpdateAutoAllocBatch_Status] (
    @n_AllocBatchNo BIGINT,
    @c_Status       NVARCHAR(10),
    @n_Err          INT = 0 OUTPUT,
    @c_ErrMsg       NVARCHAR(250) = '' OUTPUT )
AS
BEGIN
   IF @c_Status = '9'
   BEGIN
      -- Caution: Cannot use NOLOCK hints here due to multi threads insertion and causing insertion fail 
      IF NOT EXISTS (SELECT 1 FROM AutoAllocBatch_Log 
                     WHERE AllocBatchNo = @n_AllocBatchNo)
      BEGIN
         BEGIN TRY
              INSERT INTO AutoAllocBatch_Log
              (
        	      AllocBatchNo,    Facility,       Storerkey,
        	      BuildParmGroup,  BuildParmCode,  BuildParmString,
        	      StrategyKey,     Duration,       TotalOrderCnt,
        	      Priority,        UDF01,        	UDF02,
        	      UDF03,        	  UDF04,        	UDF05,
        	      [Status],        AddWho,        	AddDate,
        	      EditWho,         EditDate,       TrafficCop,
        	      ArchiveCop
              )
              SELECT AllocBatchNo,
        	      Facility,        	Storerkey,        BuildParmGroup,
        	      BuildParmCode,    BuildParmString,  StrategyKey,
        	      Duration,        	TotalOrderCnt,    [Priority],
        	      UDF01,        	   UDF02,        	   UDF03,
        	      UDF04,        	   UDF05,        	   @c_Status,
        	      AddWho,        	AddDate,        	SUSER_SNAME(),
        	      GETDATE(),       	TrafficCop,      	ArchiveCop
              FROM AutoAllocBatch AS aab -- WITH(NOLOCK)
              WHERE aab.AllocBatchNo = @n_AllocBatchNo  
              
         END TRY
         BEGIN CATCH
             SELECT @c_ErrMsg = 'Insert to AutoAllocBatch Failed! AllocBatchNo = ' + CAST(@n_AllocBatchNo AS VARCHAR(10))

             EXEC dbo.nsp_logerror
                 @n_err = 081000,      -- int
                 @c_errmsg = @c_ErrMsg, -- nvarchar(250)
                 @c_module = N'isp_UpdateAutoAllocBatch_Status'  -- nvarchar(250)
             
         END CATCH

      END

      IF EXISTS (SELECT 1 FROM AutoAllocBatch_Log WITH (NOLOCK)  
                 WHERE AllocBatchNo = @n_AllocBatchNo)
      BEGIN
         DELETE AutoAllocBatch     
         WHERE AllocBatchNo = @n_AllocBatchNo      	
      END
   END  
   ELSE    
   BEGIN  
      UPDATE AutoAllocBatch    
         SET [Status] = @c_Status,   
             EditDate = GETDATE(), 
             EditWho  = SUSER_SNAME()   
      WHERE AllocBatchNo = @n_AllocBatchNo                         
   END  
   
END   

GO