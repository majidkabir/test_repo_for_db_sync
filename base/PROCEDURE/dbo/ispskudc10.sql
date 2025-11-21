SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSKUDC10                                         */
/* Creation Date: 29/03/2023                                            */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-21989 CN Yonex Decode & Capture serialno and sku at the */
/*          same scanning without prompt antidiversion serial capture   */
/*                                                                      */
/* Called By: isp_SKUDecode_Wrapper                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 29-MAR-2023 NJOW     1.0   DEVOPS combine scirpt                     */
/* 03-JUL-2023 NJOW01   1.1   WMS-23012 Fix over pack serial no issue   */
/* 26-SEP-2023 NJOW02   1.2   WMS-23778 support scan both UPC and serial*/
/*                            when serialnocapture=1                    */
/* 18-OCT-2023 NJOW03   1.3   WMS-23952 Fix, not to return sku if scanned*/
/*                            in UPC.                                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispSKUDC10]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(60)      OUTPUT
   , @c_Code01           NVARCHAR(60) = '' OUTPUT
   , @c_Code02           NVARCHAR(60) = '' OUTPUT
   , @c_Code03           NVARCHAR(60) = '' OUTPUT
   , @b_Success          INT          = 1  OUTPUT
   , @n_Err              INT          = 0  OUTPUT
   , @c_ErrMsg           NVARCHAR(250)= '' OUTPUT
   , @c_Pickslipno       NVARCHAR(10) = ''
   , @n_CartonNo         INT = 0
   , @c_UCCNo            NVARCHAR(20) = ''  --Pack by UCC when UCCtoDropID = '1'    
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT = 1
         , @n_StartTcnt    INT = @@TRANCOUNT
         , @c_TempSku      NVARCHAR(60) = ''
         , @c_Orderkey     NVARCHAR(10)
         , @c_SerialNo     NVARCHAR(50) = ''
         , @c_FoundSku     NVARCHAR(20) = ''
         , @c_SerialNoCapture NVARCHAR(1) = ''
         , @c_Susr4           NVARCHAR(18) = ''
         , @c_ADAllowInsertExistingSerialNo NVARCHAR(30) = ''
         , @c_ADAllowInsertExistingSerialNo_Opt1 NVARCHAR(50) = ''
         , @c_SerialNoKey  NVARCHAR(10) = ''
         , @n_SkuOrdQty    INT = 0      --NJOW01
         , @n_SkuPackSerialCnt INT = 0  --NJOW01
         , @c_IsUPC        NVARCHAR(5) = 'N'  --NJOW03
         
   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''   
   
   SELECT @c_Orderkey = Orderkey
   FROM SERIALNO (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND SerialNo = @c_Sku
   AND Status >= '6'
   
   IF @@ROWCOUNT > 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 83000
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': The Serial# was packed before for order# ' + RTRIM(ISNULL(@c_Orderkey,'')) + ' (ispSKUDC10)'     
      GOTO QUIT_SP   	   	
   END
   
   SET @c_TempSku = @c_Sku

   EXEC nspg_GETSKU_PACK
      @c_PickSlipNo = @c_Pickslipno
     ,@c_StorerKey  = @c_Storerkey OUTPUT   
     ,@c_SKU        = @c_TempSku   OUTPUT  
     ,@b_Success    = @b_Success   OUTPUT  
     ,@n_Err        = @n_Err       OUTPUT  
     ,@c_ErrMsg     = @c_ErrMsg    OUTPUT  

   IF @b_Success = 0
   BEGIN      
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   SELECT @c_SerialNoCapture = SerialNoCapture,
          @c_Susr4  = Susr4,
          @c_FoundSku = Sku
   FROM SKU(NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_TempSku 
   
   IF ISNULL(@c_FoundSku,'') = ''
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 83010
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Serial#/Sku: ' + RTRIM(ISNULL(@c_TempSku,'')) + ' (ispSKUDC10)'     
      GOTO QUIT_SP   	
   END
        
   SET @c_Orderkey = ''     
   SELECT @c_Orderkey = O.Orderkey
   FROM PACKHEADER PH (NOLOCK) 
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PickSlipNo = @c_Pickslipno
   
   IF NOT EXISTS(SELECT 1
                 FROM ORDERS O (NOLOCK)
                 JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                 WHERE O.Orderkey = @c_Orderkey
                 AND OD.Sku = @c_TempSku)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 83020
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Sku for the order: ' + RTRIM(ISNULL(@c_TempSku,'')) + ' (ispSKUDC10)'     
      GOTO QUIT_SP
   END
   
   --NJOW03
   IF EXISTS(SELECT 1 
   	         FROM UPC (NOLOCK)
             JOIN SKU (NOLOCK) ON SKU.StorerKey = UPC.StorerKey AND SKU.Sku = UPC.SKU
             WHERE UPC.UPC = @c_SKU
             AND UPC.StorerKey = @c_StorerKey)
   BEGIN
      SET @c_IsUPC = 'Y'
   END          
   ELSE
   BEGIN
      SET @c_IsUPC = 'N'
   END
                       
   IF (@c_Susr4 = 'AD' AND ISNULL(@c_UCCNo,'') = '') --Will capture serial at Antidiversion, if have UCC proceed to update serialno because AD will skip for UCC scanning
      OR @c_SerialNoCapture NOT IN('1','3')  --Not require capture serial no
   BEGIN
   	 IF @c_IsUPC = 'N' --NJOW03  if UPC not to return new sku value becuase packing need the orginal value for UPC function to work.
   	    SET @c_NewSku = @c_TempSku  
   	 
   	 GOTO QUIT_SP
   END

   IF @c_TempSku <> @c_Sku 
   BEGIN
   	  IF @c_IsUPC = 'N' --NJOW02 NJOW03 if not UPC mean scan value is serial no
      BEGIN              
   	     SET @c_SerialNo = @c_Sku
   	  END   
   END
   ELSE IF ISNULL(@c_UCCNo,'') = ''  --UCC Scanning will insert sku instead of serial#, so no error
   BEGIN  --user scan sku code instead of serial#
      /*  --NJOW02 Removed
      SELECT @n_Continue = 3
      SELECT @n_Err = 83030
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Serial#: ' + RTRIM(ISNULL(@c_Sku,'')) + ' (ispSKUDC10)'     
      */
      SET @c_NewSku = @c_Sku  --NJOW02
      GOTO QUIT_SP   	  
   END   
    
   --NJOW01 S 
   IF ISNULL(@c_UCCNo,'') = ''
   BEGIN
      SELECT @n_SkuPackSerialCnt = COUNT(DISTINCT SR.SerialNo)   
      FROM SERIALNO SR (NOLOCK)
      JOIN UPC (NOLOCK) ON SR.Userdefine02 = UPC.Upc AND SR.Storerkey = UPC.Storerkey
      JOIN SKU (NOLOCK) ON UPC.Storerkey = SKU.Storerkey AND UPC.Sku = SKU.Sku
      WHERE SR.Pickslipno = @c_PickSlipno
      AND SKU.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_TempSku       	 
      
      SELECT @n_SkuOrdQty = SUM(Qty) 
      FROM PICKDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND Sku = @c_TempSku
      
      IF @n_SkuOrdQty < (@n_SkuPackSerialCnt + 1) AND @n_SkuOrdQty > 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 83040
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Over packed for the Serial#: ' + RTRIM(ISNULL(@c_Sku,'')) + ' Of Sku: ' + RTRIM(ISNULL(@c_TempSku,'')) + ' (ispSKUDC10)'     
      	 GOTO QUIT_SP 
      END
   END
   --NJOW01 E
   
   SELECT @c_ADAllowInsertExistingSerialNo = SC.Authority,
          @c_ADAllowInsertExistingSerialNo_Opt1 = SC.Option1
   FROM dbo.fnc_GetRight2('',@c_Storerkey,'','ADAllowInsertExistingSerialNo') AS SC
   
   IF ISNULL(@c_UCCNo,'') <> ''  --Pack by UCC 
   BEGIN
   	  IF @c_ADAllowInsertExistingSerialNo = '1' 
   	  BEGIN 
      	 UPDATE SERIALNO WITH (ROWLOCK)
      	 SET Orderkey = @c_Orderkey,
      	     OrderLineNumber = CAST(@n_CartonNo AS NVARCHAR),
      	     Status = '6',
      	     Pickslipno = @c_Pickslipno,
      	     CartonNo = @n_CartonNo,
      	     LabelLine = '',
      	     TrafficCop = NULL,
      	     EditWho = SUSER_SNAME(),
      	     EditDate = GETDATE()
      	 WHERE Userdefine01 = @c_UCCNo
      	 AND Status < '6'
      	 AND Storerkey = @c_Storerkey
      	 
      	 SET @n_Err = @@ERROR
      	 
      	 IF @n_Err <> 0
      	 BEGIN      	       	 	
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 83050
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC table failed. (ispSKUDC10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP   	  
      	 END   	  	
   	  END
   END
   ELSE IF ISNULL(@c_SerialNo,'') <> ''
   BEGIN      
	    SELECT @c_SerialNokey = SerialNokey
      FROM SERIALNO (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND SerialNo = @c_SerialNo
      
      IF @c_ADAllowInsertExistingSerialNo = '1' AND @c_ADAllowInsertExistingSerialNo_Opt1 = 'NotAllowInsertNewSerialNo' AND ISNULL(@c_SerialNoKey,'') = ''
      BEGIN   	  
         SELECT @n_Continue = 3
         SELECT @n_Err = 83060
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Serial# not found: ' + RTRIM(ISNULL(@c_SerialNo,'')) + ' (ispSKUDC10)'     
         GOTO QUIT_SP   	  
      END                   
      ELSE IF @c_ADAllowInsertExistingSerialNo <> '1' AND ISNULL(@c_SerialNoKey,'') <> ''  
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 83070
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Serial# already exists: ' + RTRIM(ISNULL(@c_SerialNo,'')) + ' (ispSKUDC10)'     
         GOTO QUIT_SP   	  
      END
      
      IF @c_ADAllowInsertExistingSerialNo = '1' AND @c_ADAllowInsertExistingSerialNo_Opt1 = 'NotAllowInsertNewSerialNo' 
      BEGIN
      	 UPDATE SERIALNO WITH (ROWLOCK)
      	 SET Orderkey = @c_Orderkey,
      	     OrderLineNumber = CAST(@n_CartonNo AS NVARCHAR),
      	     Status = '6',
      	     Pickslipno = @c_Pickslipno,
      	     CartonNo = @n_CartonNo,
      	     LabelLine = '',
      	     TrafficCop = NULL,
      	     EditWho = SUSER_SNAME(),
      	     EditDate = GETDATE()
      	 WHERE SerialNokey = @c_SerialNoKey      	          
      	 
      	 SET @n_Err = @@ERROR
      	 
      	 IF @n_Err <> 0
      	 BEGIN      	       	 	
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 83080
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update SERIALNO table failed. (ispSKUDC10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP   	  
      	 END
      END
      ELSE IF @c_ADAllowInsertExistingSerialNo <> '1'
      BEGIN      	
      	 EXEC dbo.nspg_GetKey                
            @KeyName = 'SERIALNO'    
           ,@fieldlength = 10    
           ,@keystring = @c_SerialNoKey OUTPUT    
           ,@b_Success = @b_success OUTPUT    
           ,@n_err = @n_err OUTPUT    
           ,@c_errmsg = @c_errmsg OUTPUT
           ,@b_resultset = 0    
           ,@n_batch     = 1       
         
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3                   	 
            GOTO QUIT_SP
         END
      	
         INSERT INTO SERIALNO (SerialNoKey, Orderkey, OrderLineNumber, Storerkey, Sku, SerialNo, Qty, Status, Pickslipno, CartonNo, LabelLine)
         VALUES (@c_SerialNoKey, @c_Orderkey, CAST(@n_CartonNo AS NVARCHAR), @c_Storerkey, @c_TempSku, @c_SerialNo, 1, '6', @c_PickSlipNo, @n_CartonNo, '')      	

      	 SET @n_Err = @@ERROR
      	 
      	 IF @n_Err <> 0
      	 BEGIN      	       	 	
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 83090
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert SERIALNO table failed. (ispSKUDC10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP   	  
      	 END
      END
      ELSE IF @c_ADAllowInsertExistingSerialNo = '1' AND @c_ADAllowInsertExistingSerialNo_Opt1 <> 'NotAllowInsertNewSerialNo' 
      BEGIN
         IF ISNULL(@c_SerialNoKey,'') <> ''  
         BEGIN
      	    UPDATE SERIALNO WITH (ROWLOCK)
      	    SET Orderkey = @c_Orderkey,
      	        OrderLineNumber = CAST(@n_CartonNo AS NVARCHAR),
      	        Status = '6',
      	        Pickslipno = @c_Pickslipno,
      	        CartonNo = @n_CartonNo,
      	        LabelLine = '',
      	        TrafficCop = NULL,
      	        EditWho = SUSER_SNAME(),
      	        EditDate = GETDATE()
      	    WHERE SerialNokey = @c_SerialNoKey      	          
      	    
      	    SET @n_Err = @@ERROR
      	    
      	    IF @n_Err <> 0
      	    BEGIN      	       	 	
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 83100
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update SERIALNO table failed. (ispSKUDC10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               GOTO QUIT_SP   	  
      	    END         	
         END
         ELSE
         BEGIN
      	    EXEC dbo.nspg_GetKey                
               @KeyName = 'SERIALNO'    
              ,@fieldlength = 10    
              ,@keystring = @c_SerialNoKey OUTPUT    
              ,@b_Success = @b_success OUTPUT    
              ,@n_err = @n_err OUTPUT    
              ,@c_errmsg = @c_errmsg OUTPUT
              ,@b_resultset = 0    
              ,@n_batch     = 1       
            
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3                   	 
               GOTO QUIT_SP
            END
      	    
            INSERT INTO SERIALNO (SerialNoKey, Orderkey, OrderLineNumber, Storerkey, Sku, SerialNo, Qty, Status, Pickslipno, CartonNo, LabelLine)
            VALUES (@c_SerialNoKey, @c_Orderkey, CAST(@n_CartonNo AS NVARCHAR), @c_Storerkey, @c_TempSku, @c_SerialNo, 1, '6', @c_PickSlipNo, @n_CartonNo, '')      	
            
      	    SET @n_Err = @@ERROR
      	    
      	    IF @n_Err <> 0
      	    BEGIN      	       	 	
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 83110
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert SERIALNO table failed. (ispSKUDC10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               GOTO QUIT_SP   	  
      	    END         	
         END
      END      
   END
   
   IF @c_IsUPC = 'N' --NJOW03     
      SET @c_NewSku = @c_TempSku

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC10'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO