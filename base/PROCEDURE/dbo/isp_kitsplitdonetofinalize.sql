SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_KitSplitDoneToFinalize                            */
/* Creation Date: 18-Sep-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-2930 - CN PVH Kit finalize split completed qty to new work */
/*                     order and new kitting to finalize. Remaining qty    */ 
/*                     update to original workorder and kitting.           */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[isp_KitSplitDoneToFinalize]  
(     @c_KitKey            NVARCHAR(10)   
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
  ,   @n_ContinueFinalize  INT           OUTPUT --1,2=continue finalize. 4=Not continue finalize
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue               INT,
           @n_StartTranCount         INT,                               
           @c_ParentSku              NVARCHAR(20),
           @c_KitLineNumber          NVARCHAR(5),
           @n_ParentCompQty          INT,                           
           @n_ParentPrevQty          INT,
           @c_WorkOrderkey           NVARCHAR(10),
           @c_NewWorkOrderKey        NVARCHAR(10),
           @n_ComponentCompQty       INT,           
           @n_ComponentPrevQty       INT,
           @c_ExternLineNo           NVARCHAR(5),
           @c_ComponentSku           NVARCHAR(20),
           @c_WorkOrderLineNumber    NVARCHAR(5),
           @n_WorkOrderLineCnt       INT,
           @c_NewWorkOrderLineNumber NVARCHAR(5),
           @c_NewKitKey              NVARCHAR(10)
                                     
   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '',@n_StartTranCount = @@TRANCOUNT              
   SET @n_WorkOrderLineCnt = 0
          
   IF @n_continue IN (1,2)
   BEGIN
   	  IF EXISTS(SELECT 1 FROM KIT K(NOLOCK) 
   	            JOIN WORKORDER WO (NOLOCK) ON K.ExternKitkey = WO.WorkOrderkey
   	            JOIN WORKORDER WO2 (NOLOCK) ON WO.WkOrdUdef10 = WO2.WorkOrderkey --refer to original workorder
   	            WHERE K.Kitkey = @c_Kitkey
   	            AND ISNULL(WO.WkOrdUdef10,'') <> '')
   	  BEGIN
   	  	 --this is split kit not to split again and continue with finalize
   	     SELECT @n_continue = 4
   	     GOTO QUIT_SP
   	  END
   	  ELSE              
   	  BEGIN               	     
      	 --Not to finalize current kit and split to new kit and new workorder to finalize instead
   	     SET @n_ContinueFinalize = 4
   	     
   	     UPDATE KIT WITH (ROWLOCK)
   	     SET Status = '0',
   	         TrafficCop = NULL
   	     WHERE Kitkey = @c_Kitkey    	  
         
         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63300
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KIT Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      END
   	   	   	  
   	  --Get parent completed qty and previous remaining qty
   	  SELECT TOP 1 @c_ParentSku = KT.Sku,
   	               @c_KitLineNumber = KT.kitLineNumber,
   	               @n_ParentCompQty = KT.Qty,  
   	               @n_ParentPrevQty = WOD.Qty,
   	               @c_WorkOrderkey = WOD.WorkOrderkey
   	  FROM KITDETAIL KT (NOLOCK)
   	  JOIN WORKORDERDETAIL WOD (NOLOCK) ON KT.Externkitkey = WOD.WorkOrderkey AND KT.ExternLineNo = WOD.ExternLineNo AND KT.Sku = WOD.Sku
   	  WHERE KT.Kitkey = @c_Kitkey
   	  AND KT.Type = 'T'
   	  
   	  --Check completed parent qty
   	  IF @n_ParentCompQty = 0
   	  BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63310
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Zero parent sku qty to finalize! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP   	  	
   	  END
 
      --update kit-to parent remaining qty
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET ExpectedQty = @n_ParentPrevQty - @n_ParentCompQty,         	  
          Qty = @n_ParentPrevQty - @n_ParentCompQty
      WHERE Kitkey = @c_Kitkey
      AND KitLineNumber = @c_KitLineNumber
      AND Type = 'T'      

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63320
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KITDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
            
      --update parent openqty
      UPDATE KIT WITH (ROWLOCK)
      SET OpenQty = OpenQty - @n_ParentCompQty,   --(@n_ParentPrevQty - @n_ParentCompQty),
          TrafficCop = NULL
      WHERE KitKey = @c_Kitkey

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63330
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KIT Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
      
      --Create new workorder for completed qty
      SET @b_success = 1	  
      EXECUTE nspg_GetKey
             'WorkOrder                     '
            ,10 
            ,@c_NewWorkOrderKey OUTPUT 
            ,@b_success         OUTPUT 
            ,@n_err             OUTPUT 
            ,@c_errmsg          OUTPUT
      
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         INSERT INTO WorkOrder
         (
         	WorkOrderKey,
         	ExternWorkOrderKey,
         	StorerKey,
         	Facility,
         	[Status],
         	ExternStatus,
         	[Type],
         	Reason,
         	TotalPrice,
         	GenerateCharges,
         	Remarks,
         	Notes1,
         	Notes2,
         	WkOrdUdef1,
         	WkOrdUdef2,
         	WkOrdUdef3,
         	WkOrdUdef4,
         	WkOrdUdef5,
         	WkOrdUdef6,
         	WkOrdUdef7,
         	WkOrdUdef8,
         	WkOrdUdef9,
         	WkOrdUdef10
         )      	
        SELECT @c_NewWorkOrderkey,
         	     ExternWorkOrderKey,
         	     StorerKey,
         	     Facility,
         	     '0',
         	     ExternStatus,
         	     [Type],
         	     Reason,
         	     TotalPrice,
         	     GenerateCharges,
         	     Remarks,
         	     Notes1,
         	     Notes2,
         	     WkOrdUdef1,
         	     WkOrdUdef2,
         	     WkOrdUdef3,
         	     WkOrdUdef4,
         	     WkOrdUdef5,
         	     WkOrdUdef6,
         	     WkOrdUdef7,
         	     WkOrdUdef8,
         	     @c_Kitkey, --original kitkey
         	     @c_WorkOrderkey --original workorderkey
         FROM WORKORDER (NOLOCK)
         WHERE WorkOrderkey = @c_WorkOrderkey	     
         
         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63340
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert WORKORDER Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END         
      END
                          	     	  
      DECLARE CUR_KITDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT KF.KitLineNumber, KF.Qty, CONVERT(DECIMAL, WOD.WkOrdUdef2), WOD.ExternLineNo, KF.Sku, WOD.WorkOrderLineNumber
         FROM KITDETAIL KF (NOLOCK)
         JOIN WORKORDERDETAIL WOD (NOLOCK) ON KF.ExternKitkey = WOD.WorkOrderkey AND KF.ExternLineno = WOD.ExternLineNo AND KF.Sku = WOD.WkOrdUdef4 AND WOD.Sku = @c_ParentSku
         WHERE KF.Type = 'F'
         AND KF.Kitkey = @c_KitKey

      OPEN CUR_KITDET   
      
      FETCH NEXT FROM CUR_KITDET INTO @c_KitLineNumber, @n_ComponentCompQty, @n_ComponentPrevQty, @c_ExternLineNo, @c_ComponentSku, @c_WorkOrderLineNumber
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN         	   
      	  --update kit-from component remaining qty. after split finalize both expected and qty are same. if both zero mean the kitting is completed       
      	  UPDATE KITDETAIL WITH (ROWLOCK)
      	  SET ExpectedQty = @n_ComponentPrevQty - @n_ComponentCompQty,         	  
      	      Qty = @n_ComponentPrevQty - @n_ComponentCompQty
      	  WHERE Kitkey = @c_Kitkey
      	  AND KitLineNumber = @c_KitLineNumber
      	  AND Type = 'F'

          SELECT @n_err = @@ERROR
          IF  @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63350
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KITDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
          END
      	  
      	  --update workorder parent and component remaining qty         	  
      	  UPDATE WORKORDERDETAIL WITH (ROWLOCK)
      	  SET WkOrdUdef2 = @n_ComponentPrevQty - @n_ComponentCompQty,       --component qty
      	      Qty = @n_ParentPrevQty - @n_ParentCompQty       --parent qty
      	  WHERE Workorderkey = @c_WorkOrderkey
      	  AND ExternLineNo = @c_ExternLineNo
      	  AND Sku = @c_ParentSku
      	  AND WkOrdUdef4 = @c_ComponentSku

          SELECT @n_err = @@ERROR
          IF  @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63360
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WORKORDERDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
          END
      	  
      	  --create new workorderdetail for completed qty
      	  IF @n_ComponentCompQty > 0
      	  BEGIN
       	     SET @n_WorkOrderLineCnt = @n_WorkOrderLineCnt + 1	
       	     SET @c_NewWorkOrderLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_WorkOrderLineCnt AS NVARCHAR))),5)
             
      	     INSERT INTO WorkOrderDetail
             (
             	WorkOrderKey,
             	WorkOrderLineNumber,
             	ExternWorkOrderKey,
             	ExternLineNo,
             	[Type],
             	Reason,
             	Unit,
             	Qty,
             	Price,
             	LineValue,
             	Remarks,
             	WkOrdUdef1,
             	WkOrdUdef2,
             	WkOrdUdef3,
             	WkOrdUdef4,
             	WkOrdUdef5,
             	[Status],
             	StorerKey,
             	Sku,
             	WkOrdUdef6,
             	WkOrdUdef7,
             	WkOrdUdef8,
             	WkOrdUdef9,
             	WkOrdUdef10
             )
              SELECT @c_NewWorkOrderkey,
             	       @c_NewWorkOrderLineNumber,
             	       ExternWorkOrderKey,
             	       ExternLineNo,
             	       [Type],
             	       Reason,
             	       Unit,
             	       CAST(@n_ParentCompQty AS NVARCHAR),
             	       Price,
             	       LineValue,
             	       Remarks,
             	       WkOrdUdef1,             	       
             	       @n_ComponentCompQty,
             	       WkOrdUdef3,
             	       WkOrdUdef4,
             	       WkOrdUdef5,
             	       '0',
             	       StorerKey,
             	       Sku,
             	       WkOrdUdef6,
             	       WkOrdUdef7,
             	       WkOrdUdef8,
             	       WkOrdUdef9,
             	       WkOrdUdef10
                FROM WORKORDERDETAIL(NOLOCK)
                WHERE WorkOrderkey = @c_WorkOrderkey
                AND WorkOrderLineNUmber = @c_WorkOrderLineNumber

             SELECT @n_err = @@ERROR
             IF  @n_err <> 0
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63370
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert WORKORDERDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                       + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             END                             	       
          END
      	
         FETCH NEXT FROM CUR_KITDET INTO @c_KitLineNumber, @n_ComponentCompQty, @n_ComponentPrevQty, @c_ExternLineNo, @c_ComponentSku, @c_WorkOrderLineNumber
   	  END
   	  CLOSE CUR_KITDET
   	  DEALLOCATE CUR_KITDET
   	     
   	  --Generate new kitting for the new workorder of completed qty
   	  EXEC ispWOKIT01 
           @c_NewWorkOrderKey, 
           @b_Success OUTPUT, 
           @n_err     OUTPUT, 
           @c_errmsg  OUTPUT 
           
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO QUIT_SP
      END
   	  
   	  --Copy the lot info from original kit
   	  SELECT @c_NewKitkey = Kitkey
   	  FROM KIT (NOLOCK)
   	  WHERE ExternKitkey = @c_NewWorkOrderkey

   	  UPDATE KITDETAIL WITH (ROWLOCK)
   	  SET KITDETAIL.Lot = OKD.Lot,
          KITDETAIL.Loc = OKD.Loc,   	  
          KITDETAIL.ID = OKD.ID,   	  
          KITDETAIL.Lottable01 = OKD.Lottable01,   	  
          KITDETAIL.Lottable02 = OKD.Lottable02,   	  
          KITDETAIL.Lottable03 = OKD.Lottable03,   	  
          KITDETAIL.Lottable04 = OKD.Lottable04,   	  
          KITDETAIL.Lottable05 = OKD.Lottable05,   	  
          KITDETAIL.Lottable06 = OKD.Lottable06,   	  
          KITDETAIL.Lottable07 = OKD.Lottable07,   	  
          KITDETAIL.Lottable08 = OKD.Lottable08,   	  
          KITDETAIL.Lottable09 = OKD.Lottable09,   	  
          KITDETAIL.Lottable10 = OKD.Lottable10,   	  
          KITDETAIL.Lottable11 = OKD.Lottable11,   	  
          KITDETAIL.Lottable12 = OKD.Lottable12,   	  
          KITDETAIL.Lottable13 = OKD.Lottable13,   	  
          KITDETAIL.Lottable14 = OKD.Lottable14,   	  
          KITDETAIL.Lottable15 = OKD.Lottable15   	  
   	  FROM KITDETAIL 
   	  JOIN KITDETAIL OKD (NOLOCK) ON KITDETAIL.Storerkey = OKD.Storerkey AND KITDETAIL.Sku = OKD.Sku AND KITDETAIL.ExternLineNo = OKD.ExternLineNo   	         
   	                              AND KITDETAIL.type = OKD.Type
   	  WHERE KITDETAIL.Kitkey = @c_NewKitKey
   	  AND OKD.Kitkey = @c_KitKey

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63380
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KITDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP                                
      END   	  
   	     	  
   	  --finalize the new kitting for completed qty   	  
   	  UPDATE KIT WITH (ROWLOCK)  
   	  SET Status = '9'  
   	  WHERE kitkey = @c_NewKitKey      	 
   	  
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63390
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KIT Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP                                
      END   	  
      
      --Finalize the new kitting detail for completed qty
      UPDATE KITDETAIL WITH (ROWLOCK)  
   	  SET Status = '9'  
   	  WHERE kitkey = @c_NewKitKey
   	  AND Status <> '9'      	 
   	  
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63400
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KITDETAIL Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP                                
      END   	        
      
      --finalize the new work order for completed qty
      EXEC isp_FinalizeWorkOrder
           @c_WorkOrderKey = @c_NewWorkOrderKey,
           @b_Success   = @b_Success OUTPUT,
           @n_err       = @n_Err  OUTPUT,
           @c_ErrMsg    = @c_ErrMsg OUTPUT  
             	  
      IF  @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO QUIT_SP                                
      END   	        
      
      --Close original kit if completed with zero remaining qty
      IF NOT EXISTS(SELECT 1 FROM KITDETAIL(NOLOCK) WHERE Kitkey = @c_Kitkey AND Qty > 0)
      BEGIN
      	 UPDATE KIT WITH (ROWLOCK)
      	 SET Status = '9',
      	     TrafficCop = NULL
      	 WHERE Kitkey = @c_Kitkey

         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63410
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update KIT Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP                                
         END   	  
      END    

      --Close original workorder if completed with zero remaining qty
      IF NOT EXISTS(SELECT 1 FROM WORKORDERDETAIL(NOLOCK) WHERE WorkOrderkey = @c_WorkOrderkey AND Qty > 0)
      BEGIN
      	 UPDATE WORKORDER WITH (ROWLOCK)
      	 SET Status = '9',
      	     TrafficCop = NULL
      	 WHERE Workorderkey = @c_WorkOrderkey

         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63420
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WORKORDER Table Failed! (isp_KitSplitDoneToFinalize)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP                                
         END   	  
      END    
      
   END
   	   	   	   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_KitSplitDoneToFinalize'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO