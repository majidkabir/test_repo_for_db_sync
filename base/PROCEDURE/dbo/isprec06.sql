SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispREC06                                           */
/* Creation Date: 03-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:WMS-18630-[TW] Exceed StorerConfig SP for Return Trigger CR  */   
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*             duplicate from ispREC0                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 03-Jan-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[ispREC06]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Receiptkey      NVARCHAR(10),
           @c_CarrierName     NVARCHAR(30),
           @c_PlaceOfDelivery NVARCHAR(18),
           @c_UDF01           NVARCHAR(60),
           @c_UDF02           NVARCHAR(60),
           @c_UDF03           NVARCHAR(60),
           @c_UDF05           NVARCHAR(60),
           @c_Code            NVARCHAR(30),
           @c_TrackingNo      NVARCHAR(60),
           @n_len             INT, 
           @c_VehicleNumber   NVARCHAR(20)

                                                       
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
    IF @c_Action IN('INSERT') 
    BEGIN
      DECLARE Cur_Receipt CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Receiptkey, I.Carriername, I.Placeofdelivery,ISNULL(I.VehicleNumber,'')
         FROM #INSERTED I
         JOIN CODELKUP C (NOLOCK) ON C.Listname = 'RTNTRACKNO' AND C.Code = I.Placeofdelivery AND C.code2 = ISNULL(I.VehicleNumber,'')
         WHERE I.Storerkey = @c_Storerkey         
         AND I.DocType = 'R'

      OPEN Cur_Receipt
     
       FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_CarrierName, @c_PlaceOfDelivery,@c_VehicleNumber

       WHILE @@FETCH_STATUS <> -1 
       BEGIN       
          IF ISNULL(@c_CarrierName,'') = ''
          BEGIN
              SELECT @n_continue = 3, @n_err = 60090, @c_errmsg = 'ASN# ' + RTRIM(@c_Receiptkey) + '. Empty Carrier Name is not allowed. (ispREC06)' 
              GOTO QUIT_SP
          END

          /*IF ISNULL(@c_PlaceOfDelivery,'') = ''
          BEGIN
              SELECT @n_continue = 3, @n_err = 60091, @c_errmsg = 'ASN# ' + RTRIM(@c_Receiptkey) + '. Empty Place Of Delivery is not allowed. (ispREC06)' 
              GOTO QUIT_SP
          END*/
          
          SELECT @c_Code = Code, 
                 @c_UDF01 = UDF01, --Min number
                 @c_UDF02 = UDF02, --Max number
                 @c_UDF03 = UDF03, --Current number
                 @c_UDF05 = UDF05,
                 @n_Len = LEN(RTRIM(@c_UDF01))             
          FROM CODELKUP (NOLOCK) 
          WHERE Listname ='RTNTRACKNO'
          AND Code = @c_PlaceOfDelivery
          AND Storerkey = @c_Storerkey 
          AND Code2 = @c_VehicleNumber
          
          /*IF ISNULL(@c_Code,'') = ''
          BEGIN
              SELECT @n_continue = 3, @n_err = 60092, @c_errmsg = 'ASN# ' + RTRIM(@c_Receiptkey) + '. Tracking Number configuration not yet setup for ' + RTRIM(@c_PlaceOfDelivery) + '. (ispREC06)' 
              GOTO QUIT_SP
          END*/
          
          IF ISNUMERIC(@c_UDF01) <>  1 OR ISNUMERIC(@c_UDF02) <>  1 OR @c_UDF01 > @c_UDF02
          BEGIN
              SELECT @n_continue = 3, @n_err = 60093, @c_errmsg = 'ASN# ' + RTRIM(@c_Receiptkey) + '. Invalid Tracking Number range setup for ' + RTRIM(@c_PlaceOfDelivery) + '. (ispREC06)' 
              GOTO QUIT_SP
          END         
          
          IF NOT EXISTS(SELECT 1 FROM CARTONTRACK(NOLOCK) WHERE KeyName = 'RETURN' and LabelNo = @c_Receiptkey AND CarrierName = @c_CarrierName)
          BEGIN         
             IF ISNUMERIC(@c_UDF03) <> 1            
                SET @c_UDF03 = @c_UDF01
                
             SET @c_UDF03 = RIGHT(REPLICATE('0',@n_Len) + RTRIM(LTRIM(CONVERT(NVARCHAR, CAST(@c_UDF03 AS BIGINT) + 1))), @n_Len) 
                         
             IF @c_UDF03 > @c_UDF02
             BEGIN
                 SELECT @n_continue = 3, @n_err = 60094, @c_errmsg = 'ASN# ' + RTRIM(@c_Receiptkey) + '. New Tracking Number ' + RTRIM(@c_UDF03) + ' exceeded limit for ' + RTRIM(@c_PlaceOfDelivery) + '. (ispREC06)' 
                 GOTO QUIT_SP
             END
             
             --SET @c_TrackingNo =  RTRIM(LTRIM(CONVERT(NVARCHAR,(CAST(@c_UDF03 AS BIGINT) * 10)+(CAST(@c_UDF03 AS BIGINT) % 7))))
             SET @c_TrackingNo = RIGHT(REPLICATE('0',@n_Len) + RTRIM(LTRIM(CONVERT(NVARCHAR,(CAST(@c_UDF03 AS BIGINT) * 10)+(CAST(@c_UDF03 AS BIGINT) % 7)))), @n_Len + 1)  --add check digit 
             
             INSERT INTO CARTONTRACK (LabelNo, CarrierName, KeyName, TrackingNo, UDF03)
             VALUES (@c_Receiptkey, @c_PlaceOfDelivery, 'RETURN', @c_TrackingNo, @c_UDF05)
             
             UPDATE CODELKUP WITH (ROWLOCK)
             SET UDF03 = @c_UDF03
             WHERE Listname ='RTNTRACKNO'
             AND Code = @c_PlaceOfDelivery       
             AND Storerkey = @c_Storerkey  
             AND Code2 = @c_VehicleNumber   
             
            
             UPDATE RECEIPT WITH (ROWLOCK)
             SET PlaceOfLoading = @c_TrackingNo,
                 Trafficcop = NULL,
                 EditWho = SUSER_SNAME(),
                 EditDate = GETDATE()
             WHERE Receiptkey = @c_Receiptkey
          END
                           
         FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_CarrierName, @c_PlaceOfDelivery,@c_VehicleNumber
       END
   END
      
   QUIT_SP:
    IF CURSOR_STATUS('GLOBAL' , 'Cur_Receipt') in (0 , 1)          
   BEGIN          
      CLOSE Cur_Receipt
       DEALLOCATE Cur_Receipt
   END    
   
    IF @n_Continue=3  -- Error Occured - Process AND Return
    BEGIN
       SELECT @b_Success = 0
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC06'     
       --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_Success = 1
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
         COMMIT TRAN
       END
       RETURN
    END  
END  

GO