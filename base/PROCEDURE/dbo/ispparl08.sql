SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPARL08                                          */
/* Creation Date: 09-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-18495 - TH Adidas Sea Release PA Tasks                  */
/*                                                                      */
/* Input Parameters:  @c_ReceiptKey                                     */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                   , @n_err                                           */
/*                   , @c_errmsg                                        */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: isp_ASNReleasePATask_Wrapper                              */
/*            Storerconfig ASNReleasePATask_SP                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 09-Dec-2021  NJOW     1.0  DEVOPS combine script                     */
/************************************************************************/

CREATE PROC [dbo].[ispPARL08]
   @c_ReceiptKey  NVARCHAR(10),
   @b_Success     INT OUTPUT,
   @n_err         INT OUTPUT,
   @c_errmsg      NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_Cnt             INT
         , @b_debug            INT
         , @n_StartTCnt       INT
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_SourceKey       NVARCHAR(30)
         , @c_PickMethod      NVARCHAR(10)
         , @c_FromID          NVARCHAR(18)
         , @c_FromLoc         NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_PnDLoc          NVARCHAR(10)
         , @c_TaskType        NVARCHAR(10)
         , @c_PutawayZone     NVARCHAR(10)                 
         , @n_NoOfTasks       INT
		     , @n_MixSkuUcc       INT
		 
   SELECT @n_StartTCnt=@@TRANCOUNt,  @n_continue=1, @b_Success=1, @n_err=0, @c_Errmsg='', @n_NoOfTasks=0, @b_debug=0
   
   SET @c_PickMethod = 'FP'   
   
   --Normal ASN PA
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      	
         SELECT RD.Storerkey, 
                MIN(RD.Sku) AS Sku,
                RD.ToLoc AS FromLoc,
                RD.ToID AS FromID,
                ISNULL(UCCINFO.MixSkuUcc,0) AS MixSkuUcc,
                MIN(RTRIM(RD.ReceiptKey) + RTRIM(RD.ReceiptLineNumber)) AS Sourcekey
         FROM RECEIPT R (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
         OUTER APPLY (SELECT SUM(CASE WHEN UCC.Userdefined07='1' THEN 1 ELSE 0 END) MixSkuUcc
                      FROM UCC (NOLOCK) 
                      WHERE UCC.Storerkey = RD.Storerkey AND UCC.ID = RD.ToID) AS UCCINFO
         WHERE R.Receiptkey = @c_Receiptkey
         AND R.Doctype = 'A'
         GROUP BY RD.Storerkey,
                  RD.ToLoc,
                  RD.ToID,
                  ISNULL(UCCINFO.MixSkuUcc,0)

      OPEN CUR_RECDET
      
      FETCH NEXT FROM CUR_RECDET INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_FromID, @n_MixSkuUcc, @c_Sourcekey
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
      	  IF @b_debug = 1
      	  BEGIN
      	  	 PRINT ''
      	  	 PRINT '@c_Sku: ' + @c_Sku
      	  	 PRINT '@c_FromLoc: ' + @c_Fromloc
      	  	 PRINT '@c_FromID: ' + @c_FromID
      	  	 PRINT '@n_MixSkuUcc: ' + CAST(@n_MixSkuUcc AS NVARCHAR) 
      	  	 PRINT '@c_SourceKey: ' + @c_Sourcekey
      	  END
      	  
      	  --Two steps PA for pallet with mix sku UCC
      	  IF @n_MixSkuUcc > 0
      	  BEGIN      	  	 
      	  	 SET @c_PutawayZone = ''
      	  	 SET @c_ToLoc = ''
      	     SET @c_TaskType = 'PAF'
      	     SET @n_cnt = 0
      	     
      	     SELECT @c_PutawayZone = Putawayzone
      	     FROM SKU (NOLOCK)
      	     WHERE Storerkey = @c_Storerkey
      	     AND Sku = @c_Sku

             IF ISNULL(@c_Putawayzone,'') = ''
             BEGIN
                SET @n_Continue = 3
                SET @n_Err = 30100
                SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Putawayzone not found for Sku: ' + RTRIM(@c_Sku) + ' (ispPARL08)'
             END         	     
             ELSE
             BEGIN         	     
      	        SELECT @c_ToLoc = MIN(CL.UDF02),
      	               @n_cnt = COUNT(1)
      	        FROM CODELKUP CL (NOLOCK)
      	        WHERE CL.ListName = 'RDTEXTPA'
      	        AND CL.UDF01 = @c_PutawayZone
      	        AND CL.UDF03 = @c_FromLoc
      	        AND CL.Short = 'A'
      	        AND CL.Storerkey = @c_Storerkey
      	        
      	        IF ISNULL(@c_ToLoc ,'') = '' OR @n_cnt > 1
      	        BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 30110
                  SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Unable find or duplicate PnD loc found for ID: ' + RTRIM(@c_FromID) + ' (ispPARL08)'
      	        END         	        
      	     END

             IF @b_debug = 1
      	     BEGIN
      	  	    PRINT '@c_TaskType: ' + @c_TaskType
      	  	    PRINT '@c_Putawayzone: ' + @c_Putawayzone
      	  	    PRINT '@c_ToLoc: ' + @c_ToLoc
      	     END

             IF @n_continue IN(1,2)
             BEGIN
             	  --From staging to MEZZ PnD
      	  	    EXEC isp_InsertTaskDetail
      	  	       @c_TaskType = @c_TaskType
      	  	      ,@c_Storerkey = @c_Storerkey
      	  	      ,@c_FromLoc = @c_FromLoc
      	  	      ,@c_FromID = @c_FromID
      	  	      ,@c_ToLoc = @c_Toloc
      	  	      ,@c_LogicalToLoc = @c_ToLoc
      	  	      ,@c_PickMethod = @c_PickMethod         	  	   
      	  	      ,@c_SourceType = 'ispPARL08'
      	  	      ,@c_SourceKey = @c_Sourcekey
                  ,@c_Priority = '5'
                  ,@c_SourcePriority = '9'         	  	 
                  ,@b_Success = @b_Success OUTPUT
                  ,@n_Err = @n_Err         OUTPUT 
                  ,@c_ErrMsg = @c_ErrMsg   OUTPUT

                IF @b_success = 0                 
                   SET @n_continue = 3            
                    
                SET @n_NoOfTasks = @n_NoOfTasks + 1           	  
                 
                --From MEZZ PnD to DPBulk
      	        /*
      	        SET @c_PnDLoc = @c_Toloc
      	  	    SET @c_ToLoc = 'DPBULK'
      	        SET @c_TaskType = 'ASTPA'

                IF @b_debug = 1
      	        BEGIN
      	  	       PRINT '@c_TaskType: ' + @c_TaskType
      	  	       PRINT '@c_PnDLoc: ' + @c_PnDLoc
      	  	       PRINT '@c_ToLoc: ' + @c_ToLoc
      	        END
                
      	  	    EXEC isp_InsertTaskDetail
      	  	       @c_TaskType = @c_TaskType
      	  	      ,@c_Storerkey = @c_Storerkey
      	  	      ,@c_FromLoc = @c_PnDLoc
      	  	      ,@c_FromID = @c_FromID
      	  	      ,@c_ToLoc = @c_Toloc
      	  	      ,@c_LogicalToLoc = @c_ToLoc
      	  	      ,@c_PickMethod = @c_PickMethod         	  	   
      	  	      ,@c_SourceType = 'ispPARL08'
      	  	      ,@c_SourceKey = @c_Sourcekey
                  ,@c_Priority = '5'
                  ,@c_SourcePriority = '9'       
                  ,@b_Success = @b_Success OUTPUT
                  ,@n_Err = @n_Err         OUTPUT 
                  ,@c_ErrMsg = @c_ErrMsg   OUTPUT

                IF @b_success = 0                 
                   SET @n_continue = 3    
                        
                SET @n_NoOfTasks = @n_NoOfTasks + 1  
                */         	                   
             END   	  	            	     	           	  	          	     
      	  END
      	  ELSE
      	  BEGIN -- --One step PA for pallet without mix sku UCC                 	  	   	  	 
      	  	 SET @c_TaskType = 'PAF'
      	  	 SET @c_ToLoc = ''

             IF @b_debug = 1
      	     BEGIN
      	  	    PRINT '@c_TaskType: ' + @c_TaskType
      	  	    PRINT '@c_ToLoc: ' + @c_ToLoc
      	     END
      	  	 
      	  	 EXEC isp_InsertTaskDetail
      	  	    @c_TaskType = @c_TaskType
      	  	   ,@c_Storerkey = @c_Storerkey
      	  	   ,@c_FromLoc = @c_FromLoc
      	  	   ,@c_FromID = @c_FromID
      	  	   ,@c_ToLoc = @c_Toloc
    	  	     ,@c_LogicalToLoc = @c_ToLoc
      	  	   ,@c_PickMethod = @c_PickMethod
      	  	   ,@c_SourceType = 'ispPARL08'
      	  	   ,@c_SourceKey = @c_Sourcekey
               ,@c_Priority = '5'
               ,@c_SourcePriority = '9'
               ,@b_Success = @b_Success OUTPUT
               ,@n_Err = @n_Err         OUTPUT 
               ,@c_ErrMsg = @c_ErrMsg   OUTPUT

              IF @b_success = 0                 
                 SET @n_continue = 3     
                 
              SET @n_NoOfTasks = @n_NoOfTasks + 1           	                         	  	            	  	           	  	 
      	  END
      	        	
         FETCH NEXT FROM CUR_RECDET INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_FromID, @n_MixSkuUcc, @c_Sourcekey
      END
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET            	
   END
   
   --Return ASN PA
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      	
         SELECT RD.Storerkey, 
                MIN(RD.Sku) AS Sku,
                RD.ToLoc AS FromLoc,
                RD.ToID AS FromID,
                MIN(RTRIM(RD.ReceiptKey) + RTRIM(RD.ReceiptLineNumber)) AS Sourcekey                               
         FROM RECEIPT R (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
         WHERE R.Receiptkey = @c_Receiptkey
         AND R.Doctype = 'R'
         GROUP BY RD.Storerkey,
                  RD.ToLoc,
                  RD.ToID

      OPEN CUR_RECDET
      
      FETCH NEXT FROM CUR_RECDET INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_FromID, @c_Sourcekey
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
  	     SET @c_PutawayZone = ''
       	 SET @c_ToLoc = ''
       	 SET @n_cnt = 0
          
         SELECT @c_PutawayZone = Putawayzone
         FROM SKU (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku

         IF ISNULL(@c_Putawayzone,'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 30120
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Putawayzone not found for Sku: ' + RTRIM(@c_Sku) + ' (ispPARL08)'
         END         	     
         ELSE
         BEGIN         	     
            SELECT @c_ToLoc = MIN(CL.UDF02),
                   @n_cnt = COUNT(1)
            FROM CODELKUP CL (NOLOCK)
            WHERE CL.ListName = 'RDTEXTPA'
            AND CL.UDF01 = @c_PutawayZone
            AND CL.UDF03 = @c_FromLoc
            AND CL.Short = 'R'
            AND CL.Storerkey = @c_Storerkey
            
            IF @n_cnt = 0
            BEGIN
              SET @n_Continue = 3
              SET @n_Err = 30130
              SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': PnD loc Not found for ID: ' + RTRIM(@c_FromID) + ' (ispPARL08)'
            END         	        
            
            IF @n_cnt > 1
            BEGIN
              SET @n_Continue = 3
              SET @n_Err = 30140
              SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Duplicate PnD loc found for ID: ' + RTRIM(@c_FromID) + ' (ispPARL08)'
            END         	        
         END
          
         IF ISNULL(@c_ToLoc,'') <> '' AND @n_continue IN(1,2)
         BEGIN
         	  SET @c_TaskType = 'PAF'
         	  
         	  --From stating to MEZZ PnD
  	        EXEC isp_InsertTaskDetail
       	       @c_TaskType = @c_TaskType
       	      ,@c_Storerkey = @c_Storerkey
       	      ,@c_FromLoc = @c_FromLoc
       	      ,@c_FromID = @c_FromID
       	      ,@c_ToLoc = @c_Toloc
   	  	      ,@c_LogicalToLoc = @c_ToLoc
       	      ,@c_PickMethod = @c_PickMethod         	  	   
       	      ,@c_SourceType = 'ispPARL08'
       	      ,@c_SourceKey = @c_Sourcekey
              ,@c_Priority = '5'
              ,@c_SourcePriority = '9'         	  	            	  
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_Err         OUTPUT 
              ,@c_ErrMsg = @c_ErrMsg   OUTPUT

            IF @b_success = 0                 
               SET @n_continue = 3            
            
            SET @n_NoOfTasks = @n_NoOfTasks + 1           	  
               
            --From MEZZ PnD to DPBulk
      	    /*
      	    SET @c_PnDLoc = @c_Toloc
       	    SET @c_ToLoc = 'DPBULK'
            SET @c_TaskType = 'ASTPA'
             
       	    EXEC isp_InsertTaskDetail
       	       @c_TaskType = @c_TaskType
       	      ,@c_Storerkey = @c_Storerkey
       	      ,@c_FromLoc = @c_PnDLoc
       	      ,@c_FromID = @c_FromID
       	      ,@c_ToLoc = @c_Toloc
       	      ,@c_LogicalToLoc = @c_ToLoc       	      
       	      ,@c_PickMethod = @c_PickMethod         	  	   
       	      ,@c_SourceType = 'ispPARL08'
       	      ,@c_SourceKey = @c_Sourcekey
              ,@c_Priority = '5'
              ,@c_SourcePriority = '9'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_Err         OUTPUT 
              ,@c_ErrMsg = @c_ErrMsg   OUTPUT             

            IF @b_success = 0
               SET @n_continue = 3

            SET @n_NoOfTasks = @n_NoOfTasks + 1       
            */    	                        	  	            	        	    	
         END         	
         ELSE IF @n_continue IN(1,2)
         BEGIN
 	  	      SET @c_TaskType = 'PAF'
       	    SET @c_ToLoc = ''
       	    
       	    EXEC isp_InsertTaskDetail
       	       @c_TaskType = @c_TaskType
       	      ,@c_Storerkey = @c_Storerkey
       	      ,@c_FromLoc = @c_FromLoc
       	      ,@c_FromID = @c_FromID
       	      ,@c_ToLoc = @c_Toloc
   	  	      ,@c_LogicalToLoc = @c_ToLoc
       	      ,@c_PickMethod = @c_PickMethod
       	      ,@c_SourceType = 'ispPARL08'
       	      ,@c_SourceKey = @c_Sourcekey
              ,@c_Priority = '5'
              ,@c_SourcePriority = '9'         	  	 
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_Err         OUTPUT 
              ,@c_ErrMsg = @c_ErrMsg   OUTPUT
              
            IF @b_success = 0
               SET @n_continue = 3
           
            SET @n_NoOfTasks = @n_NoOfTasks + 1           	                             	    	
         END
      	
         FETCH NEXT FROM CUR_RECDET INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_FromID, @c_Sourcekey
      END
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET
   END	   
 
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
             
      execute nsp_logerror @n_err, @c_errmsg, 'ispPARL08'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      IF @n_NoOfTasks > 0
      BEGIN
         SET @c_errmsg = 'Total ' +CONVERT(NVARCHAR(5), @n_NoOfTasks)+ ' Putaway From tasks released sucessfully.'
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'No Putaway From tasks released.'
      END

      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      
      RETURN
   END
END

GO