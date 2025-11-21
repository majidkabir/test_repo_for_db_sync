SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPOALKIT01                                          */
/* Creation Date: 09-SEP-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-17858 CN Diageo Post kit allocation Update tokitdetail     */
/*                                                                         */
/* Called By: isp_PostKitAllocation_Wrapper: PostKitAllocation_SP          */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-Oct-2021  NJOW01  1.0   DEVOPS combine script                        */
/* 15-Sep-2022  NJOW02  1.1   WMS-20808 change formula and field update    */
/***************************************************************************/  
CREATE PROC [dbo].[ispPOALKIT01]  
(     @c_Kitkey      NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
         , @c_Storerkey       NVARCHAR(15)
         , @c_ParentSku       NVARCHAR(20)
         , @c_ParentPackkey   NVARCHAR(10)
         , @c_ParentUOM       NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_Lottable01      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @dt_Lottable04     DATETIME
         , @dt_Lottable05     DATETIME
         , @c_Lottable06      NVARCHAR(30)
         , @c_Lottable07      NVARCHAR(30)
         , @c_Lottable08      NVARCHAR(30)
         , @c_Lottable09      NVARCHAR(30)
         , @c_Lottable10      NVARCHAR(30)
         , @c_Lottable11      NVARCHAR(30)
         , @c_Lottable12      NVARCHAR(30)
         , @dt_Lottable13     DATETIME
         , @dt_Lottable14     DATETIME
         , @dt_Lottable15     DATETIME    
         , @c_KitLineNumber   NVARCHAR(5)
         , @n_LineCnt         INT         
         , @n_Qty             INT
         , @n_ExpectedQty     INT        
         , @c_Externkitkey    NVARCHAR(20)  
         , @c_ExternLineNo    NVARCHAR(10)
         , @c_CustomerRefNo   NVARCHAR(10) --NJOW02
        
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
   
   
   IF @n_continue IN(1,2)   
   BEGIN
   	   SELECT TOP 1 @c_ParentSku = KT.SKU,
   	                @c_ParentPackkey = KT.Packkey 
   	   FROM KITDETAIL KT (NOLOCK)
   	   JOIN BILLOFMATERIAL BOM (NOLOCK) ON KT.Storerkey = BOM.Storerkey AND KT.SKU = BOM.Sku   	   
   	   WHERE KT.Kitkey = @c_KitKey
   	   AND KT.Type = 'T'
   	   ORDER BY KT.KitLineNumber
   	   
   	   IF ISNULL(@c_ParentSku,'') = ''
   	   BEGIN
          SELECT @n_Continue = 3 
	        SELECT @n_Err = 38010
	        SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': BOM Sku not found for the kit. (ispPOALKIT01)'   	   	
   	   END
   END
   
   IF @n_continue IN(1,2)     	   
   BEGIN	      	      	   
   	   DECLARE CUR_KITFR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	      SELECT KF.Storerkey, FC.Userdefine10 AS ToLoc, KF.UOM, 
   	             ((CASE WHEN ISNUMERIC(SKU.Susr5) = 1 THEN CAST(SKU.Susr5 AS INT) ELSE BOM.Qty END / BOM.Qty) / BOM.ParentQty) * KF.ExpectedQty AS ExpectedQty,  --NJOW02
   	             ((CASE WHEN ISNUMERIC(SKU.Susr5) = 1 THEN CAST(SKU.Susr5 AS INT) ELSE BOM.Qty END / BOM.Qty) / BOM.ParentQty) * KF.Qty AS Qty,  --NJOW02
   	             KF.Lottable01, KF.Lottable02, KF.Lottable03, KF.Lottable04, KF.Lottable05,    	      
   	             KF.Lottable06, KF.Lottable07, KF.Lottable08, KF.Lottable09, KF.Lottable10,    	      
   	             KF.Lottable11, KF.Lottable12, KF.Lottable13, KF.Lottable14, KF.Lottable15,
   	             KF.ExternKitkey, KF.ExternLineNo,
   	             KIT.CustomerRefNo  -- NJOW02   	      
   	      FROM KIT (NOLOCK) 
   	      JOIN KITDETAIL KF (NOLOCK) ON KIT.Kitkey = KF.Kitkey
   	      JOIN SKU (NOLOCK) ON KF.Storerkey = SKU.Storerkey AND KF.Sku = SKU.Sku 
   	      JOIN BILLOFMATERIAL BOM (NOLOCK) ON KF.Storerkey = BOM.Storerkey AND KF.Sku = BOM.ComponentSku AND BOM.Sku = @c_ParentSku
   	      JOIN CODELKUP CL (NOLOCK) ON KF.UOM = CL.Code AND KF.Storerkey = CL.Storerkey AND CL.Listname = 'DIABLT'
   	      JOIN FACILITY FC (NOLOCK) ON KIT.Facility = FC.Facility   	      
   	      WHERE KF.Type = 'F'
   	      AND KF.Kitkey = @c_Kitkey

       OPEN CUR_KITFR    
         
       FETCH NEXT FROM CUR_KITFR INTO @c_Storerkey, @c_ToLoc, @c_ParentUOM, @n_ExpectedQty, @n_Qty,
                                      @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05,
                                      @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                      @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15,
                                      @c_Externkitkey, @c_ExternLineNo, @c_CustomerRefNo --NJOW02                                                                            
                                            
       SET @n_LineCnt = 0   
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
       BEGIN
       	  SET @n_LineCnt = @n_LineCnt + 1
       	  
       	  SET @c_KitLineNumber = RIGHT('00000' + RTRIM(LTRIM(CAST(@n_LineCnt AS NVARCHAR))),5)
       	  
       	  SET @c_Lottable10 = @c_Kitkey + @c_KitLineNumber
       	  
       	  --NJOW02
       	  SET @c_Lottable07 = ISNULL(@c_Externkitkey,'')
       	  SET @c_Lottable08 = ISNULL(@c_CustomerRefNo,'')
       	  
       	  IF EXISTS(SELECT 1 
       	            FROM KITDETAIL KT (NOLOCK)
       	            WHERE KT.Kitkey = @c_Kitkey
       	            AND KT.Type = 'T'
       	            AND KT.KitLineNumber = @c_KitLineNumber)
       	  BEGIN
       	     UPDATE KITDETAIL WITH (ROWLOCK)
       	     SET Sku = @c_ParentSku,
       	         Loc = @c_ToLoc,
       	         ExpectedQty = @n_ExpectedQty,
       	         Qty = @n_Qty,
       	         Packkey = @c_ParentPackkey,
       	         UOM = @c_ParentUOM,
       	         Lottable01 = @c_Lottable01,
       	         Lottable02 = @c_Lottable02,
       	         Lottable03 = @c_Lottable03,
       	         Lottable04 = @dt_Lottable04,
       	         Lottable05 = @dt_Lottable05,
       	         Lottable06 = @c_Lottable06,
       	         Lottable07 = @c_Lottable07,
       	         Lottable08 = @c_Lottable08,
       	         Lottable09 = @c_Lottable09,
       	         Lottable10 = @c_Lottable10,
       	         Lottable11 = @c_Lottable11,
       	         Lottable12 = @c_Lottable12,
       	         Lottable13 = @dt_Lottable13,
       	         Lottable14 = @dt_Lottable14,
       	         Lottable15 = @dt_Lottable15,
       	         Externkitkey = @c_Externkitkey, 
       	         ExternLineNo = @c_ExternLineNo
       	     WHERE Kitkey = @c_Kitkey
       	     AND Type = 'T'
       	     AND KitLineNumber = @c_KitLineNumber           	         
       	     
       	     SET @n_err = @@ERROR
       	     
       	     IF @n_err <> 0
   	         BEGIN
                SELECT @n_continue = 3
                SELECT @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kitdetail Failed! (ispPOALKIT01)' + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
   	         END
       	  END           
       	  ELSE
       	  BEGIN       	  	 
       	     INSERT INTO KITDETAIL (Kitkey, KitLineNumber, Type, Storerkey, Sku, Loc, ExpectedQty, Qty, Packkey, UOM, 
       	                            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07,
       	                            Lottable08, Lottable09, Lottable10, Lottable11, LOttable12, Lottable13, Lottable14, 
       	                            Lottable15, ExternKitkey, ExternLineNo)
       	                    VALUES (@c_Kitkey, @c_KitLineNumber, 'T', @C_Storerkey, @c_ParentSku, @c_ToLoc, @n_ExpectedQty, @n_Qty, @c_ParentPackkey, @c_ParentUOM,
       	                            @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Lottable06, @c_Lottable07,
       	                            @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14,
       	                            @dt_Lottable15, @c_Externkitkey, @c_ExternLineNo)                        
       	     SET @n_err = @@ERROR
       	     
       	     IF @n_err <> 0
   	         BEGIN
                SELECT @n_continue = 3
                SELECT @n_err = 38030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Insert Kitdetail Failed! (ispPOALKIT01)' + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
   	         END       	                            
       	  END
   
          FETCH NEXT FROM CUR_KITFR INTO @c_Storerkey, @c_ToLoc, @c_ParentUOM, @n_ExpectedQty, @n_Qty, 
                                         @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05,
                                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                         @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15,
                                         @c_Externkitkey, @c_ExternLineNo, @c_CustomerRefNo --NJOW02                                                                                                                                                               	
       END
       CLOSE CUR_KITFR
       DEALLOCATE CUR_KITFR
       
       IF @n_LineCnt > 0 
       BEGIN
       	  DELETE FROM KITDETAIL
       	  WHERE Kitkey = @c_Kitkey
       	  AND Type = 'T'
       	  AND KitLineNumber > @c_KitLineNumber

       	  SET @n_err = @@ERROR
       	  
       	  IF @n_err <> 0
   	      BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 38040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Delete Kitdetail Failed! (ispPOALKIT01)' + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
   	      END       	                            
       END                                       	   
   END
   
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPOALKIT01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO