SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispWOKIT01                                         */  
/* Creation Date: 28-Feb-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-2133 CN BeamSuntroy WorkOrder Populate To Kitting       */  
/*                                                                      */ 
/* Input Parameters:  @c_Workorderkey                                   */
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
/* Called By: Work Order RCM                                            */
/*            isp_WorkOrderGenerateKitting_Wrapper                      */  
/*            Storerconfig: WorkOrderGenerateKitting_SP = 'isWOKIT01'   */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROC [dbo].[ispWOKIT01] 
   @c_WorkOrderKey NVARCHAR(10),
   @b_Success      INT OUTPUT, 
   @n_err          INT OUTPUT, 
   @c_errmsg       NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue           INT
         , @n_StartTCnt          INT         
         , @c_CreateNewKit       NVARCHAR(10)
         , @c_KitKey             NVARCHAR(10)
         , @c_Type               NVARCHAR(12)
         , @c_Facility           NVARCHAR(5)
         , @c_ExternWorkOrderkey NVARCHAR(20)
         , @c_ExternLineNo       NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ComponentSku       NVARCHAR(20)
         , @c_ComponentQty       INT
         , @c_ParentSku          NVARCHAR(20)
         , @n_ParentQty          INT
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_ParentPackKey      NVARCHAR(10)
         , @c_ParentUOM          NVARCHAR(10)
         , @c_ReasonCode         NVARCHAR(10)
         , @c_KitLineNumber      NVARCHAR(5)
         , @n_kitLineNumber      INT         
         , @n_NoOfkit            INT         
         , @c_WkOrdUdef3         NVARCHAR(18)
         , @c_Unit               NVARCHAR(10)
   
   SET @n_StartTCnt     =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @n_NoOfkit       = 0
   SET @c_ReasonCode = 'COPACKING'   
   SET @c_CreateNewKit  = 'N'   
   
   --Validation
   IF @n_continue IN(1,2)
   BEGIN
   	   SELECT @c_Storerkey = Storerkey,
   	          @c_Facility = Facility
   	   FROM WORKORDER (NOLOCK)
   	   WHERE WorkOrderkey = @c_WorkOrderkey
   	   
       IF EXISTS (SELECT 1  
                  FROM KIT WITH (NOLOCK)
                  WHERE ExternKitKey = @c_WorkOrderkey
                  AND Storerkey = @c_Storerkey)              
       BEGIN
           SET @n_continue = 3  
           SET @n_Err = 31210 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                         + ': Work Order#: ' + RTRIM(@c_WorkOrderKey) + ' already have kitting. (ispWOKIT01)'  
           GOTO QUIT_SP       
       END

       IF EXISTS (SELECT 1 FROM WORKORDERDETAIL (NOLOCK) WHERE Workorderkey = @c_WorkOrderkey AND ISNULL(WkOrdUdef4,'') = '')              
       BEGIN
           SET @n_continue = 3  
           SET @n_Err = 31215 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                         + ': Work Order#: ' + RTRIM(@c_WorkOrderKey) + ' Detail Userdefine 4(component sku) is empty cannot generate kitting. (ispWOKIT01)'  
           GOTO QUIT_SP       
       END

       IF EXISTS (SELECT 1  
                  FROM WORKORDER WITH (NOLOCK)
                  WHERE WorkOrderKey = @c_WorkOrderkey
                  AND ExternStatus <> '1')              
       BEGIN
           SET @n_continue = 3  
           SET @n_Err = 31220 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                         + ': Work Order#: ' + RTRIM(@c_WorkOrderKey) + ' Extern status must be ''1'' to generate. (ispWOKIT01)'  
           GOTO QUIT_SP       
       END
       
       SET @c_ComponentSku = ''
       SELECT TOP 1 @c_ComponentSku = WOD.WkOrdUdef4 
       FROM WORKORDER WO (NOLOCK)
       JOIN WORKORDERDETAIL WOD (NOLOCK) ON WO.WorkOrderKey = WOD.WorkOrderkey
       LEFT JOIN SKU (NOLOCK) ON WO.Storerkey = SKU.Storerkey AND WOD.WkOrdUdef4 = SKU.Sku
       WHERE WO.WorkOrderkey = @c_WorkOrderkey
       AND SKU.Sku IS NULL
       
       IF @@ROWCOUNT > 0
       BEGIN
           SET @n_continue = 3  
           SET @n_Err = 31230 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                         + ': Component Sku(WkordUdef4): ' + RTRIM(@c_ComponentSku) + ' is invalid. (ispWOKIT01)'  
           GOTO QUIT_SP       
       END
              
       SET @c_ComponentSku = ''
       SELECT TOP 1 @c_ComponentSku = WOD.WkOrdUdef4 
       FROM WORKORDERDETAIL WOD (NOLOCK)
       WHERE WOD.WorkOrderkey = @c_WorkOrderkey
       AND (ISNUMERIC(WOD.WkOrdUdef2) <> 1 
           OR WOD.WkOrdUdef2 = '0')

       IF ISNULL(@c_ComponentSku ,'') <> ''
       BEGIN
           SET @n_continue = 3  
           SET @n_Err = 31240 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                         + ': Component Sku(WkordUdef4): ' + RTRIM(@c_ComponentSku) + ' has invalid qty (WkordUdef2). (ispWOKIT01)'  
           GOTO QUIT_SP       
       END
   END
   
   --BACKUP Original Qty value
   IF @n_continue IN(1,2)
   BEGIN
      UPDATE WORKORDERDETAIL WITH (ROWLOCK)
       SET WkOrdUdef9 =  CASE WHEN ISNULL(WkOrdUdef9,'') = '' THEN CAST(Qty AS NVARCHAR) ELSE WkOrdUdef9 END,  --Parent qty
           WkOrdUdef10 =  CASE WHEN ISNULL(WkOrdUdef10,'') = '' THEN WkOrdUdef2 ELSE WkOrdUdef10 END, --component qty
           TrafficCop = NULL
      WHERE WorkOrderkey = @c_WorkOrderkey     

      SET @n_err = @@ERROR
     
      IF @n_err <> 0
      BEGIN
          SET @n_continue = 3  
          SET @n_Err = 31250 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                        + ': Update WORKORDERDETAIL Table Failed. (ispWOKIT01)'  
      END            
   END
   
   --Generate kitting
   IF @n_continue IN(1,2)
   BEGIN
   	  --Retrieve parent sku
      DECLARE CUR_KIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT DISTINCT WOD.ExternLineNo, WOD.Sku
         FROM WORKORDERDETAIL WOD (NOLOCK)
         WHERE WOD.WorkOrderkey = @c_WorkOrderkey
         ORDER BY WOD.ExternLineNo, WOD.Sku
      
      OPEN CUR_KIT   
      
      FETCH NEXT FROM CUR_KIT INTO @c_ExternLineNo, @c_ParentSku

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN      	         
      	 --Generate new kitkey for each parent sku
      	 SET @b_success = 1	  
         EXECUTE nspg_GetKey
                'kitting'
               ,10 
               ,@c_Kitkey        OUTPUT 
               ,@b_success       OUTPUT 
               ,@n_err           OUTPUT 
               ,@c_errmsg        OUTPUT
         
         IF @b_success <> 1
         BEGIN
            SET @n_Continue = 3
         END 
         ELSE  
         BEGIN
            SET @c_CreateNewKit = 'Y'                  
            SET @n_KitLineNumber = 0
            SET @n_NoOfKit =  @n_NoOfKit + 1
         END
         
         --Retrieve component sku    	
         DECLARE CUR_KITDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT WO.Type, WO.ExternWorkOrderkey, WOD.WkOrdUdef4, CONVERT(DECIMAL, WOD.WkOrdUdef2) AS ComponetQty, WOD.Qty AS ParentQty,
                   CPACK.Packkey, CPACK.PackUOM3, PPACK.Packkey AS ParentPackkey, PPACK.PackUOM3 AS ParentUOM,
                   WOD.WkOrdUdef3, WOD.Unit
            FROM WORKORDER WO (NOLOCK) 
            JOIN WORKORDERDETAIL WOD (NOLOCK) ON WO.WorkOrderkey = WOD.WorkOrderkey
            JOIN SKU PSKU (NOLOCK) ON WO.Storerkey = PSKU.Storerkey AND WOD.Sku = PSKU.Sku --parent sku
            JOIN PACK PPACK (NOLOCK) ON PSKU.Packkey = PPACK.Packkey --parent sku pack
            JOIN SKU CSKU (NOLOCK)  ON WO.Storerkey = CSKU.Storerkey AND WOD.WkordUdef4 = CSKU.Sku --component sku
            JOIN PACK CPACK (NOLOCK) ON CSKU.Packkey = CPACK.Packkey --component sku pack            
            WHERE WO.WorkOrderkey = @c_WorkOrderkey
            AND WOD.ExternLineNo = @c_ExternLineNo
            AND WOD.Sku = @c_ParentSku
            ORDER BY WOD.WkordUdef4
         
         OPEN CUR_KITDET   
         
         FETCH NEXT FROM CUR_KITDET INTO @c_Type, @c_ExternWorkOrderkey, @c_ComponentSku, @c_ComponentQty, 
                                         @n_ParentQty, @c_Packkey, @c_UOM, @c_ParentPackKey, @c_ParentUOM,
                                         @c_WkOrdUdef3, @c_Unit
         
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
         BEGIN         	          
         	  SET @n_KitLineNumber = @n_KitLineNumber + 1	
         	  SET @c_KitLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_KitLineNumber AS NVARCHAR))),5)
         	  
         	  IF @c_CreateNewKit = 'Y' --Create new kitting for each parent sku
         	  BEGIN
         	  	 --create kitting header
               INSERT INTO KIT (KitKey, Type, Facility, Storerkey, ToStorerkey, ExternKitkey, CustomerRefNo, ReasonCode, Remarks)
               VALUES (@c_Kitkey, @c_Type, @c_Facility, @c_Storerkey, @c_Storerkey, @c_WorkOrderkey, @c_ExternWorkOrderkey, @c_ReasonCode, @c_WorkOrderkey)               
               
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                   SET @n_continue = 3  
                   SET @n_Err = 31260 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                 + ': Insert KIT Table Failed. (ispWOKIT01)'  
               END     
         	  	
         	  	 --Create kit-to parent sku record
         	  	 INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo)
         	  	                VALUES (@c_Kitkey, @c_KitLineNumber, 'T', @c_Storerkey, @c_ParentSku, @n_ParentQty, @n_ParentQty, @c_ParentPackkey, @c_ParentUOM, @c_WorkOrderkey, @c_ExternLineNo)
         	  	 

               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                   SET @n_continue = 3  
                   SET @n_Err = 31270 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                                 + ': Insert KITDETAIL(T) Table Failed. (ispWOKIT01)'  
               END     

         	  	 SET @c_CreateNewKit = 'N' 
         	  END

         	  --Create kit-from component sku record
         	  INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo)
         	                 VALUES (@c_Kitkey, @c_KitLineNumber, 'F', @c_Storerkey, @c_ComponentSku, @c_ComponentQty, @c_ComponentQty, @c_Packkey, @c_UOM, @c_WorkOrderkey, @c_ExternLineNo)
         	              
            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
                SET @n_continue = 3  
                SET @n_Err = 31280 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                              + ': Insert KITDETAIL(F) Table Failed. (ispWOKIT01)'  
            END              	  
         	
            FETCH NEXT FROM CUR_KITDET INTO @c_Type, @c_ExternWorkOrderkey, @c_ComponentSku, @c_ComponentQty, 
                                            @n_ParentQty, @c_Packkey, @c_UOM, @c_ParentPackKey, @c_ParentUOM,
                                            @c_WkOrdUdef3, @c_Unit
         END          
         CLOSE CUR_KITDET
         DEALLOCATE CUR_KITDET      
   
         FETCH NEXT FROM CUR_KIT INTO @c_ExternLineNo, @c_ParentSku         
      END
      CLOSE CUR_KIT 
      DEALLOCATE CUR_KIT
   END
  
   QUIT_SP:

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
      execute nsp_logerror @n_err, @c_errmsg, 'ispWOKIT01'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      IF @n_NoOfKit > 0 
      BEGIN
         SET @c_errmsg = 'Total ' +CONVERT(NVARCHAR(5), @n_NoOfKit)+ ' Kitting(s) generated from work order sucessfully.'
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'No kitting generated From work order.'
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